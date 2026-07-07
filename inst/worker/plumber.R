# ==============================================================================
# metasurvey Compute Worker — plumber + metasurvey
#
# Internal service that executes survey estimations. NOT exposed to the
# public internet. Only the main API or internal services call this worker.
#
# Endpoints:
#   POST /compute  — Execute recipe + workflow on private microdata
#   GET  /health   — Worker health check
#
# The worker:
#   1. Loads microdata from private storage (SURVEY_DATA_DIR)
#   2. Fetches recipes from MongoDB
#   3. Applies recipes to the survey (bake_recipes)
#   4. Runs workflow() with optional filters (by variable, domain subset)
#   5. Returns the computed result (value, se, cv, CI)
#
# Config (env vars):
#   METASURVEY_MONGO_URI   — MongoDB connection string (required)
#   METASURVEY_DB          — Database name (default: metasurvey)
#   SURVEY_DATA_DIR        — Path to private microdata directory (required)
#   METASURVEY_API_URL     — Main API URL (for publishing indicators)
#
# Launch:
#   Rscript -e 'plumber::plumb("inst/worker/plumber.R")$run(port=8788)'
# ==============================================================================

library(plumber)
library(jsonlite)
library(mongolite)
library(metasurvey)
library(data.table)
library(survey)

# -- Config -------------------------------------------------------------------

MONGO_URI <- Sys.getenv("METASURVEY_MONGO_URI", "")
DATABASE <- Sys.getenv("METASURVEY_DB", "metasurvey")
DATA_DIR <- Sys.getenv("SURVEY_DATA_DIR", "/data/surveys")

if (!nzchar(MONGO_URI)) {
  stop("METASURVEY_MONGO_URI environment variable is required.")
}

if (!dir.exists(DATA_DIR)) {
  warning(sprintf(
    "[worker] SURVEY_DATA_DIR '%s' does not exist. Set it to the microdata directory.",
    DATA_DIR
  ))
}

# -- MongoDB connections (recipes + workflows for metadata) -------------------

db_recipes <- mongolite::mongo(
  collection = "recipes",
  db = DATABASE, url = MONGO_URI
)
db_workflows <- mongolite::mongo(
  collection = "workflows",
  db = DATABASE, url = MONGO_URI
)

db_indicators <- mongolite::mongo(
  collection = "indicators",
  db = DATABASE, url = MONGO_URI
)

message(sprintf(
  "[metasurvey-worker] Connected to MongoDB (db: %s)",
  DATABASE
))
message(sprintf(
  "[metasurvey-worker] Data dir: %s (%s)",
  DATA_DIR,
  if (dir.exists(DATA_DIR)) "exists" else "NOT FOUND"
))

# -- Redis connection ---------------------------------------------------------

REDIS_URL <- Sys.getenv("REDIS_URL", "")
REDIS_HOST <- Sys.getenv("REDIS_HOST", "")
REDIS_PORT <- Sys.getenv("REDIS_PORT", "6379")
REDIS_PASSWORD <- Sys.getenv("REDIS_PASSWORD", "")
ENABLE_REDIS_WORKER <- nzchar(REDIS_URL) || nzchar(REDIS_HOST)

redis_con <- NULL

# Resolve Redis params: individual env vars > parse REDIS_URL
resolve_redis_params <- function() {
  host <- Sys.getenv("REDIS_HOST", "")
  port <- Sys.getenv("REDIS_PORT", "6379")
  pass <- Sys.getenv("REDIS_PASSWORD", "")
  if (nzchar(host)) {
    return(list(
      host = host,
      port = as.integer(port),
      password = if (nzchar(pass)) pass else NULL
    ))
  }
  url <- trimws(Sys.getenv("REDIS_URL", ""))
  if (!grepl("^redis://", url)) {
    return(NULL)
  }
  rest <- sub("^redis://", "", url)
  password <- NULL
  if (grepl("@", rest)) {
    auth <- sub("@.*$", "", rest)
    rest <- sub("^[^@]+@", "", rest)
    if (grepl(":", auth)) {
      password <- sub("^[^:]*:", "", auth)
    } else {
      password <- auth
    }
  }
  rest <- sub("/.*$", "", rest)
  parts <- strsplit(rest, ":")[[1]]
  host <- parts[1]
  port <- if (length(parts) >= 2) as.integer(parts[2]) else 6379L
  if (!nzchar(host)) {
    return(NULL)
  }
  list(host = host, port = port, password = password)
}

if (ENABLE_REDIS_WORKER) {
  redis_params <- resolve_redis_params()
  message(sprintf(
    "[metasurvey-worker] Connecting to Redis: %s:%s",
    if (!is.null(redis_params)) redis_params$host else "?",
    if (!is.null(redis_params)) redis_params$port else "?"
  ))
  redis_con <- tryCatch(
    {
      if (!is.null(redis_params)) {
        clean_url <- sprintf("redis://%s:%d", redis_params$host, redis_params$port)
        r <- redux::hiredis(url = clean_url)
        if (!is.null(redis_params$password)) {
          r$AUTH(redis_params$password)
        }
        r
      } else {
        redux::hiredis()
      }
    },
    error = function(e) {
      message(sprintf(
        "[metasurvey-worker] Redis connection failed: %s",
        e$message
      ))
      NULL
    }
  )
  if (!is.null(redis_con)) {
    message("[metasurvey-worker] Redis: connected")
  }
} else {
  message("[metasurvey-worker] Redis: disabled (no REDIS_URL or REDIS_HOST)")
}

# -- Helpers ------------------------------------------------------------------

#' Find microdata file for a survey type + edition
#' Looks for: {survey_type}_{edition}.csv, .rds, .sav, .dta
find_survey_file <- function(survey_type, edition) {
  base <- file.path(DATA_DIR, survey_type)
  if (!dir.exists(base)) base <- DATA_DIR

  patterns <- c(
    sprintf("%s_%s.rds", survey_type, edition),
    sprintf("%s_%s.csv", survey_type, edition),
    sprintf("%s_%s.sav", survey_type, edition),
    sprintf("%s_%s.dta", survey_type, edition)
  )

  for (p in patterns) {
    path <- file.path(base, p)
    if (file.exists(path)) {
      return(path)
    }
  }

  NULL
}

#' Load survey data from file
load_survey_data <- function(path) {
  ext <- tolower(tools::file_ext(path))
  switch(ext,
    rds = readRDS(path),
    csv = data.table::fread(path),
    sav = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' required to read .sav files")
      }
      data.table::as.data.table(haven::read_sav(path))
    },
    dta = {
      if (!requireNamespace("haven", quietly = TRUE)) {
        stop("Package 'haven' required to read .dta files")
      }
      data.table::as.data.table(haven::read_dta(path))
    },
    stop(sprintf("Unsupported file format: .%s", ext))
  )
}

#' Fetch a recipe from MongoDB and reconstruct it
fetch_recipe <- function(recipe_id) {
  iter <- db_recipes$iterate(
    query = toJSON(list(id = recipe_id), auto_unbox = TRUE),
    limit = 1
  )
  doc <- iter$one()
  if (is.null(doc)) {
    return(NULL)
  }
  doc
}

#' Fetch a workflow from MongoDB
fetch_workflow <- function(workflow_id) {
  iter <- db_workflows$iterate(
    query = toJSON(list(id = workflow_id), auto_unbox = TRUE),
    limit = 1
  )
  doc <- iter$one()
  if (is.null(doc)) {
    return(NULL)
  }
  doc
}

#' Apply recipe steps to a survey
apply_recipe_steps <- function(svy, steps) {
  for (step_str in steps) {
    step_expr <- tryCatch(
      parse(text = step_str)[[1]],
      error = function(e) {
        warning(sprintf("Cannot parse step: %s", step_str))
        NULL
      }
    )
    if (is.null(step_expr)) next

    # Replace first argument with current survey
    step_call <- as.list(step_expr)
    step_call[[2]] <- quote(svy)
    step_expr <- as.call(step_call)

    svy <- tryCatch(
      eval(step_expr),
      error = function(e) {
        warning(sprintf(
          "Step failed: %s — %s",
          step_str, e$message
        ))
        svy
      }
    )
  }
  svy
}

#' Build and execute estimation calls
execute_estimation <- function(svy, calls, estimation_type, filters) {
  svy$ensure_design()
  design <- svy$design[[estimation_type]]

  if (is.null(design)) {
    available <- names(svy$design)
    stop(sprintf(
      "Design '%s' not available. Available: %s",
      estimation_type,
      paste(available, collapse = ", ")
    ))
  }

  # Apply domain filter if specified
  if (!is.null(filters$domain) && nzchar(filters$domain)) {
    domain_expr <- tryCatch(
      parse(text = filters$domain)[[1]],
      error = function(e) {
        stop(sprintf(
          "Invalid domain filter: %s",
          filters$domain
        ))
      }
    )
    design <- subset(design, eval(domain_expr))
  }

  results <- list()

  for (i in seq_along(calls)) {
    call_str <- calls[[i]]

    # If by_variable is specified, wrap non-svyby calls
    if (!is.null(filters$by_variable) && nzchar(filters$by_variable) && !grepl("svyby", call_str)) {
      # Transform svymean(~var, ...) -> svyby(~var, ~by, design, svymean, ...)
      call_str <- transform_to_svyby(call_str, filters$by_variable)
    }

    call_expr <- tryCatch(
      parse(text = call_str)[[1]],
      error = function(e) {
        warning(sprintf("Cannot parse call: %s", call_str))
        NULL
      }
    )
    if (is.null(call_expr)) next

    # Inject design into the call
    call_list <- as.list(call_expr)
    fn_name <- deparse(call_list[[1]])

    estimation <- tryCatch(
      {
        if (grepl("svyby", fn_name)) {
          # svyby(formula, by, design, FUN, ...)
          call_list[["design"]] <- quote(design)
          eval(as.call(call_list))
        } else {
          # svymean(formula, design, ...)
          call_list[["design"]] <- quote(design)
          eval(as.call(call_list))
        }
      },
      error = function(e) {
        warning(sprintf(
          "Estimation failed: %s — %s",
          call_str, e$message
        ))
        NULL
      }
    )
    if (is.null(estimation)) next

    result_dt <- format_estimation(
      estimation, fn_name, call_str
    )
    results[[length(results) + 1L]] <- result_dt
  }

  if (length(results) == 0) {
    return(data.table::data.table(
      stat = character(0),
      value = numeric(0),
      se = numeric(0),
      cv = numeric(0),
      confint_lower = numeric(0),
      confint_upper = numeric(0)
    ))
  }

  data.table::rbindlist(results, fill = TRUE)
}

#' Transform a svymean/svytotal call to svyby
transform_to_svyby <- function(call_str, by_variable) {
  # Parse: svymean(~var, na.rm = TRUE) ->
  #   svyby(~var, ~by_variable, design, svymean, na.rm = TRUE)
  call_expr <- parse(text = call_str)[[1]]
  call_list <- as.list(call_expr)
  fn_name <- deparse(call_list[[1]])

  # Extract formula (first arg after function name)
  formula <- call_list[[2]]
  # Get remaining args (skip design if present)
  extra_args <- list()
  if (length(call_list) > 2) {
    for (j in 3:length(call_list)) {
      nm <- names(call_list)[j]
      if (!is.null(nm) && nm == "design") next
      extra_args <- c(extra_args, call_list[j])
    }
  }

  by_formula <- parse(text = paste0("~", by_variable))[[1]]
  fn_sym <- as.symbol(fn_name)

  new_call <- as.call(c(
    list(quote(svyby), formula, by_formula, quote(design), fn_sym),
    extra_args
  ))
  deparse(new_call, width.cutoff = 500L)
}

#' Format estimation output to a data.table
format_estimation <- function(estimation, fn_name, call_str) {
  if (inherits(estimation, "svyby")) {
    # svyby result — has by-variable columns
    margins <- attr(estimation, "svyby")$margins
    by_vars <- if (is.numeric(margins)) {
      names(estimation)[margins]
    } else {
      margins
    }

    stat_vars <- attr(estimation, "svyby")$variables
    if (is.null(stat_vars)) {
      # Fallback: non-by, non-se columns
      all_cols <- names(estimation)
      se_cols <- grepl("^se\\.", all_cols)
      stat_vars <- all_cols[!se_cols & !all_cols %in% by_vars]
    }

    rows <- list()
    for (sv in stat_vars) {
      se_col <- paste0("se.", sv)
      if (!se_col %in% names(estimation)) {
        se_col <- "se"
      }

      for (r in seq_len(nrow(estimation))) {
        by_label <- paste(
          vapply(by_vars, function(bv) {
            paste0(bv, "=", estimation[r, bv])
          }, character(1)),
          collapse = ", "
        )

        val <- as.numeric(estimation[r, sv])
        se_val <- if (se_col %in% names(estimation)) {
          as.numeric(estimation[r, se_col])
        } else {
          NA_real_
        }
        cv_val <- if (!is.na(se_val) && val != 0) {
          se_val / abs(val)
        } else {
          NA_real_
        }

        rows[[length(rows) + 1L]] <- data.table::data.table(
          stat = sprintf("%s: %s [%s]", fn_name, sv, by_label),
          value = val,
          se = se_val,
          cv = cv_val,
          confint_lower = val - 1.96 * se_val,
          confint_upper = val + 1.96 * se_val,
          by_group = by_label,
          call = call_str
        )
      }
    }
    return(data.table::rbindlist(rows, fill = TRUE))
  }

  # Simple svymean/svytotal result
  ci <- tryCatch(
    stats::confint(estimation),
    error = function(e) NULL
  )

  var_names <- names(estimation)
  rows <- list()
  for (i in seq_along(var_names)) {
    val <- as.numeric(estimation[i])
    se_val <- as.numeric(SE(estimation)[i])
    cv_val <- if (val != 0) se_val / abs(val) else NA_real_
    ci_lo <- if (!is.null(ci)) ci[i, 1] else val - 1.96 * se_val
    ci_hi <- if (!is.null(ci)) ci[i, 2] else val + 1.96 * se_val

    rows[[length(rows) + 1L]] <- data.table::data.table(
      stat = sprintf("%s: %s", fn_name, var_names[i]),
      value = val,
      se = se_val,
      cv = cv_val,
      confint_lower = ci_lo,
      confint_upper = ci_hi,
      call = call_str
    )
  }
  data.table::rbindlist(rows, fill = TRUE)
}

# -- Job execution (shared by POST /compute and queue consumer) ---------------

#' Execute a compute job. Returns list(results=...) on success or
#' list(error=...) on failure.
execute_job <- function(params, db_rec, db_wf) {
  survey_type <- params$survey_type
  edition <- params$edition
  workflow_id <- params$workflow_id
  recipe_ids <- params$recipe_ids
  estimation_type <- params$estimation_type %||% "annual"
  weight_var <- params$weight
  filters <- params$filters %||% list()

  # 1. Fetch workflow
  wf <- fetch_workflow(workflow_id)
  if (is.null(wf)) stop(paste("Workflow not found:", workflow_id))

  if (is.null(recipe_ids) || length(recipe_ids) == 0) {
    recipe_ids <- wf$recipe_ids
  }

  # 2. Load microdata
  data_path <- find_survey_file(survey_type, edition)
  if (is.null(data_path)) {
    stop(sprintf(
      "Microdata not found for %s %s in %s",
      survey_type, edition, DATA_DIR
    ))
  }

  message(sprintf(
    "[worker] Loading %s (%s)",
    data_path, format(file.size(data_path), big.mark = ",")
  ))
  dt <- load_survey_data(data_path)

  # 3. Create survey object
  weight_spec <- if (!is.null(weight_var)) {
    args <- list()
    args[[estimation_type]] <- weight_var
    do.call(add_weight, args)
  } else if (!is.null(wf$weight_spec)) {
    wf$weight_spec
  } else {
    NULL
  }

  svy <- Survey$new(
    data = dt, edition = edition, type = survey_type,
    engine = "data.table", weight = weight_spec
  )

  # 4. Fetch and apply recipes
  if (length(recipe_ids) > 0) {
    for (rid in recipe_ids) {
      recipe_doc <- fetch_recipe(rid)
      if (is.null(recipe_doc)) {
        warning(sprintf("Recipe not found: %s (skipping)", rid))
        next
      }
      steps <- recipe_doc$steps
      if (length(steps) > 0) {
        message(sprintf(
          "[worker] Applying recipe '%s' (%d steps)",
          recipe_doc$name, length(steps)
        ))
        svy <- apply_recipe_steps(svy, steps)
      }
    }
    svy <- bake_steps(svy)
  }

  # 5. Execute estimation calls
  calls <- wf$calls
  if (is.null(calls) || length(calls) == 0) {
    stop("Workflow has no estimation calls")
  }

  message(sprintf(
    "[worker] Executing %d estimation calls (type: %s)",
    length(calls), estimation_type
  ))

  result_dt <- execute_estimation(svy, calls, estimation_type, filters)

  results <- lapply(
    seq_len(nrow(result_dt)),
    function(i) as.list(result_dt[i, ])
  )

  list(results = results)
}

# -- Redis queue consumer -----------------------------------------------------

JOB_TTL <- 3600L
QUEUE_KEY <- "queue:compute"
consumer_process <- NULL

#' Run the blocking Redis queue consumer.
#' Designed to run in a separate R process via callr::r_bg().
run_queue_consumer <- function(redis_host, redis_port, redis_password,
                               mongo_uri, db_name, data_dir) {
  library(redux)
  library(mongolite)
  library(jsonlite)
  library(metasurvey)
  library(data.table)
  library(survey)

  `%||%` <- function(x, y) if (is.null(x)) y else x

  clean_url <- sprintf("redis://%s:%d", redis_host, as.integer(redis_port))
  redis <- redux::hiredis(url = clean_url)
  if (nzchar(redis_password %||% "")) {
    redis$AUTH(redis_password)
  }
  db_rec <- mongolite::mongo("recipes", db = db_name, url = mongo_uri)
  db_wf <- mongolite::mongo("workflows", db = db_name, url = mongo_uri)
  db_ind <- mongolite::mongo("indicators", db = db_name, url = mongo_uri)

  JOB_TTL <- 3600L
  QUEUE_KEY <- "queue:compute"

  # Helper: read job from Redis
  read_job <- function(job_id) {
    raw <- tryCatch(redis$GET(paste0("job:", job_id)), error = function(e) NULL)
    if (is.null(raw)) {
      return(NULL)
    }
    tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE), error = function(e) NULL)
  }

  # Helper: write job to Redis
  write_job <- function(job_id, data) {
    json <- jsonlite::toJSON(data, auto_unbox = TRUE, null = "null")
    redis$SETEX(paste0("job:", job_id), JOB_TTL, json)
  }

  # Helper: invalidate cache patterns
  invalidate_cache <- function(pattern) {
    tryCatch(
      {
        cursor <- "0"
        repeat {
          result <- redis$SCAN(cursor, "MATCH", pattern, "COUNT", "100")
          cursor <- result[[1]]
          keys <- result[[2]]
          if (length(keys) > 0) for (k in keys) redis$DEL(k)
          if (cursor == "0") break
        }
      },
      error = function(e) invisible(NULL)
    )
  }

  # Re-define helpers that the consumer needs (since this runs in a fresh process)
  find_survey_file_local <- function(survey_type, edition) {
    base <- file.path(data_dir, survey_type)
    if (!dir.exists(base)) base <- data_dir
    patterns <- c(
      sprintf("%s_%s.rds", survey_type, edition),
      sprintf("%s_%s.csv", survey_type, edition),
      sprintf("%s_%s.sav", survey_type, edition),
      sprintf("%s_%s.dta", survey_type, edition)
    )
    for (p in patterns) {
      path <- file.path(base, p)
      if (file.exists(path)) {
        return(path)
      }
    }
    NULL
  }

  load_survey_data_local <- function(path) {
    ext <- tolower(tools::file_ext(path))
    switch(ext,
      rds = readRDS(path),
      csv = data.table::fread(path),
      sav = data.table::as.data.table(haven::read_sav(path)),
      dta = data.table::as.data.table(haven::read_dta(path)),
      stop(sprintf("Unsupported file format: .%s", ext))
    )
  }

  apply_recipe_steps_local <- function(svy, steps) {
    for (step_str in steps) {
      step_expr <- tryCatch(parse(text = step_str)[[1]], error = function(e) NULL)
      if (is.null(step_expr)) next
      step_call <- as.list(step_expr)
      step_call[[2]] <- quote(svy)
      step_expr <- as.call(step_call)
      svy <- tryCatch(eval(step_expr), error = function(e) {
        warning(e$message)
        svy
      })
    }
    svy
  }

  message("[worker-consumer] Started. Waiting for jobs on ", QUEUE_KEY)

  repeat {
    popped <- tryCatch(
      redis$BRPOP(QUEUE_KEY, 30L),
      error = function(e) {
        message("[worker-consumer] BRPOP error: ", e$message)
        Sys.sleep(5)
        NULL
      }
    )

    if (is.null(popped)) next

    job_id <- popped[[2]]
    message(sprintf("[worker-consumer] Dequeued job: %s", job_id))

    job <- read_job(job_id)
    if (is.null(job)) {
      message(sprintf("[worker-consumer] Job %s not found, skipping", job_id))
      next
    }

    # Mark running
    job$status <- "running"
    job$started_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
    write_job(job_id, job)

    # Execute computation
    result <- tryCatch(
      {
        params <- job$params
        survey_type <- params$survey_type
        edition <- params$edition
        workflow_id <- params$workflow_id
        recipe_ids <- params$recipe_ids
        estimation_type <- params$estimation_type %||% "annual"
        weight_var <- params$weight
        filters <- params$filters %||% list()

        # Fetch workflow
        wf_iter <- db_wf$iterate(
          query = jsonlite::toJSON(list(id = workflow_id), auto_unbox = TRUE),
          limit = 1
        )
        wf <- wf_iter$one()
        if (is.null(wf)) stop(paste("Workflow not found:", workflow_id))

        if (is.null(recipe_ids) || length(recipe_ids) == 0) {
          recipe_ids <- wf$recipe_ids
        }

        # Load microdata
        data_path <- find_survey_file_local(survey_type, edition)
        if (is.null(data_path)) {
          stop(sprintf("Microdata not found for %s %s", survey_type, edition))
        }
        dt <- load_survey_data_local(data_path)

        # Create survey
        weight_spec <- if (!is.null(weight_var)) {
          args <- list()
          args[[estimation_type]] <- weight_var
          do.call(add_weight, args)
        } else if (!is.null(wf$weight_spec)) {
          wf$weight_spec
        } else {
          NULL
        }

        svy <- Survey$new(
          data = dt, edition = edition, type = survey_type,
          engine = "data.table", weight = weight_spec
        )

        # Apply recipes
        if (length(recipe_ids) > 0) {
          for (rid in recipe_ids) {
            rec_iter <- db_rec$iterate(
              query = jsonlite::toJSON(list(id = rid), auto_unbox = TRUE),
              limit = 1
            )
            rdoc <- rec_iter$one()
            if (!is.null(rdoc) && length(rdoc$steps) > 0) {
              svy <- apply_recipe_steps_local(svy, rdoc$steps)
            }
          }
          svy <- bake_steps(svy)
        }

        # Execute estimation
        svy$ensure_design()
        calls <- wf$calls
        if (is.null(calls) || length(calls) == 0) stop("No estimation calls")

        design <- svy$design[[estimation_type]]
        if (is.null(design)) {
          stop(sprintf("Design '%s' not available", estimation_type))
        }

        # Apply domain filter
        if (!is.null(filters$domain) && nzchar(filters$domain)) {
          domain_expr <- parse(text = filters$domain)[[1]]
          design <- subset(design, eval(domain_expr))
        }

        results_list <- list()
        for (call_str in calls) {
          # Transform to svyby if by_variable specified
          if (!is.null(filters$by_variable) && nzchar(filters$by_variable) && !grepl("svyby", call_str)) {
            call_expr <- parse(text = call_str)[[1]]
            cl <- as.list(call_expr)
            fn_name <- deparse(cl[[1]])
            formula <- cl[[2]]
            by_formula <- parse(text = paste0("~", filters$by_variable))[[1]]
            fn_sym <- as.symbol(fn_name)
            extra <- if (length(cl) > 2) cl[3:length(cl)] else list()
            extra <- extra[!names(extra) %in% "design"]
            call_str <- deparse(as.call(c(
              list(quote(svyby), formula, by_formula, quote(design), fn_sym),
              extra
            )), width.cutoff = 500L)
          }

          call_expr <- tryCatch(parse(text = call_str)[[1]], error = function(e) NULL)
          if (is.null(call_expr)) next

          cl <- as.list(call_expr)
          cl[["design"]] <- quote(design)
          est <- tryCatch(eval(as.call(cl)), error = function(e) NULL)
          if (is.null(est)) next

          fn_name <- deparse(cl[[1]])
          if (inherits(est, "svyby")) {
            margins <- attr(est, "svyby")$margins
            by_vars <- if (is.numeric(margins)) names(est)[margins] else margins
            stat_vars <- attr(est, "svyby")$variables
            if (is.null(stat_vars)) {
              all_cols <- names(est)
              stat_vars <- all_cols[!grepl("^se\\.", all_cols) & !all_cols %in% by_vars]
            }
            for (sv in stat_vars) {
              se_col <- if (paste0("se.", sv) %in% names(est)) paste0("se.", sv) else "se"
              for (r in seq_len(nrow(est))) {
                by_label <- paste(vapply(by_vars, function(bv) {
                  paste0(bv, "=", est[r, bv])
                }, character(1)), collapse = ", ")
                val <- as.numeric(est[r, sv])
                se_val <- if (se_col %in% names(est)) as.numeric(est[r, se_col]) else NA_real_
                cv_val <- if (!is.na(se_val) && val != 0) se_val / abs(val) else NA_real_
                results_list[[length(results_list) + 1L]] <- list(
                  stat = sprintf("%s: %s [%s]", fn_name, sv, by_label),
                  value = val, se = se_val, cv = cv_val,
                  confint_lower = val - 1.96 * se_val,
                  confint_upper = val + 1.96 * se_val,
                  by_group = by_label, call = call_str
                )
              }
            }
          } else {
            ci <- tryCatch(stats::confint(est), error = function(e) NULL)
            var_names <- names(est)
            for (i in seq_along(var_names)) {
              val <- as.numeric(est[i])
              se_val <- as.numeric(SE(est)[i])
              cv_val <- if (val != 0) se_val / abs(val) else NA_real_
              results_list[[length(results_list) + 1L]] <- list(
                stat = sprintf("%s: %s", fn_name, var_names[i]),
                value = val, se = se_val, cv = cv_val,
                confint_lower = if (!is.null(ci)) ci[i, 1] else val - 1.96 * se_val,
                confint_upper = if (!is.null(ci)) ci[i, 2] else val + 1.96 * se_val,
                call = call_str
              )
            }
          }
        }

        list(results = results_list)
      },
      error = function(e) list(error = e$message)
    )

    if (!is.null(result$error)) {
      job$status <- "failed"
      job$error <- result$error
      job$finished_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
      write_job(job_id, job)
      message(sprintf("[worker-consumer] Job %s FAILED: %s", job_id, result$error))
      next
    }

    # Store indicators in MongoDB
    indicator_ids <- character(0)
    body <- job$params
    for (r in result$results) {
      ind_id <- paste0("ind_", as.integer(Sys.time()), "_", sample.int(9999L, 1L))
      ind_doc <- list(
        id = ind_id,
        name = r$stat %||% "Computed indicator",
        workflow_id = body$workflow_id,
        recipe_id = if (length(body$recipe_ids) > 0) body$recipe_ids[[1]] else NULL,
        survey_type = body$survey_type,
        edition = body$edition,
        estimation_type = body$estimation_type %||% "annual",
        stat = r$stat, value = r$value, se = r$se, cv = r$cv,
        confint_lower = r$confint_lower, confint_upper = r$confint_upper,
        metadata = list(
          call = r$call, by_group = r$by_group,
          filters = body$filters, computed_on_demand = TRUE,
          job_id = job_id
        ),
        user = job$user,
        user_info = list(
          name = job$user_name, user_type = job$user_type,
          email = job$user
        ),
        published_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
        metasurvey_version = "0.0.16"
      )
      db_ind$insert(jsonlite::toJSON(ind_doc, auto_unbox = TRUE, null = "null"))
      indicator_ids <- c(indicator_ids, ind_id)
    }

    # Invalidate indicator list cache
    invalidate_cache("cache:ind_list:*")

    # Mark job complete
    job$status <- "completed"
    job$finished_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
    job$indicator_ids <- indicator_ids
    job$count <- length(result$results)
    job$results <- result$results
    write_job(job_id, job)

    message(sprintf(
      "[worker-consumer] Job %s DONE: %d indicators stored",
      job_id, length(indicator_ids)
    ))
  }
}

# -- Start background queue consumer -----------------------------------------

if (!is.null(redis_con)) {
  message("[metasurvey-worker] Starting background queue consumer...")
  consumer_process <- callr::r_bg(
    func = run_queue_consumer,
    args = list(
      redis_host     = redis_params$host,
      redis_port     = redis_params$port,
      redis_password = redis_params$password %||% "",
      mongo_uri      = MONGO_URI,
      db_name        = DATABASE,
      data_dir       = DATA_DIR
    ),
    supervise = TRUE
  )
  message(sprintf(
    "[metasurvey-worker] Consumer started (PID: %d)",
    consumer_process$get_pid()
  ))
} else {
  message("[metasurvey-worker] Redis not available — queue consumer not started")
}

# -- Global serializer --------------------------------------------------------

#* @plumber
function(pr) {
  pr$setSerializer(serializer_json(auto_unbox = TRUE))
  spec <- pr$getApiSpec()
  spec$info <- list(
    title = "metasurvey Worker",
    description = paste(
      "Internal compute service for metasurvey.",
      "Executes survey recipes and workflows",
      "on private microdata.",
      "NOT exposed to the public internet."
    ),
    version = "1.0.0"
  )
  pr$setApiSpec(spec)
}

# ==============================================================================
# COMPUTE
# ==============================================================================

#* Execute a survey estimation. Loads microdata,
#* applies recipe steps, runs workflow calls,
#* and returns computed results.
#*
#* Request body:
#*   recipe_ids: array of recipe IDs to apply
#*   workflow_id: workflow ID (for calls + metadata)
#*   survey_type: survey type (e.g. "ech")
#*   edition: survey edition (e.g. "2024")
#*   estimation_type: weight period ("annual", "monthly", "quarterly")
#*   weight: weight variable name (e.g. "W_ANO")
#*   filters: optional object with:
#*     by_variable: variable for subgroup estimation (svyby)
#*     domain: R expression for domain subset (e.g. "region == 1")
#*
#* @tag Compute
#* @post /compute
#* @response 200 Returns {ok, results: [{stat, value, se, cv, ...}]}.
#* @response 400 Missing required fields or invalid request.
#* @response 404 Recipe, workflow, or data file not found.
#* @response 500 Computation error.
function(req, res) {
  body <- req$body
  if (is.null(body)) {
    res$status <- 400L
    return(list(error = "Request body is required"))
  }

  required <- c("workflow_id", "survey_type", "edition")
  missing_fields <- required[!required %in% names(body)]
  if (length(missing_fields) > 0) {
    res$status <- 400L
    return(list(error = paste(
      "Missing required fields:",
      paste(missing_fields, collapse = ", ")
    )))
  }

  tryCatch(
    {
      result <- execute_job(body, db_recipes, db_workflows)

      list(
        ok = TRUE,
        survey_type = body$survey_type,
        edition = body$edition,
        estimation_type = body$estimation_type %||% "annual",
        workflow_id = body$workflow_id,
        recipe_ids = body$recipe_ids,
        filters = body$filters %||% list(),
        count = length(result$results),
        results = result$results
      )
    },
    error = function(e) {
      message(sprintf("[worker] ERROR: %s", e$message))
      res$status <- 500L
      list(error = paste("Computation failed:", e$message))
    }
  )
}

# ==============================================================================
# HEALTH
# ==============================================================================

#* Worker health check. Returns service status,
#* MongoDB connection, and data directory info.
#* @tag System
#* @get /health
#* @response 200 Returns {status, service, ...}.
function() {
  mongo_ok <- tryCatch(
    {
      db_recipes$count()
      TRUE
    },
    error = function(e) FALSE
  )

  data_ok <- dir.exists(DATA_DIR)
  data_files <- if (data_ok) {
    length(list.files(
      DATA_DIR,
      pattern = "\\.(csv|rds|sav|dta)$",
      recursive = TRUE
    ))
  } else {
    0L
  }

  redis_ok <- if (!is.null(redis_con)) {
    tryCatch(
      {
        identical(redis_con$PING(), "PONG")
      },
      error = function(e) FALSE
    )
  } else {
    NA
  }

  queue_depth <- if (!is.na(redis_ok) && redis_ok) {
    tryCatch(redis_con$LLEN(QUEUE_KEY), error = function(e) NA_integer_)
  } else {
    NA_integer_
  }

  consumer_alive <- if (!is.null(consumer_process)) {
    consumer_process$is_alive()
  } else {
    NA
  }

  list(
    status = if (mongo_ok && data_ok) "ok" else "degraded",
    service = "metasurvey-worker",
    version = "1.0.0",
    mongodb = if (mongo_ok) "connected" else "disconnected",
    redis = if (is.na(redis_ok)) {
      "disabled"
    } else if (redis_ok) {
      "connected"
    } else {
      "disconnected"
    },
    queue_depth = queue_depth,
    consumer_alive = consumer_alive,
    data_dir = DATA_DIR,
    data_dir_exists = data_ok,
    survey_files = data_files,
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  )
}
