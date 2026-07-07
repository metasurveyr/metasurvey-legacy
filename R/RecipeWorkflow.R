#' RecipeWorkflow R6 class
#'
#' R6 class representing a publishable workflow that captures statistical
#' estimations applied to survey data. Workflows reference the recipes they
#' use and document the estimation calls made.
#'
#' @name RecipeWorkflow-class
#' @aliases RecipeWorkflow
#' @docType class
#' @format An R6 class generator (R6ClassGenerator)
#'
#' @field id Unique identifier (character).
#' @field name Descriptive name (character).
#' @field description Workflow description (character).
#' @field user Author/owner (character).
#' @field user_info RecipeUser object or NULL.
#' @field survey_type Survey type (character).
#' @field edition Survey edition (character).
#' @field estimation_type Character vector of estimation types used.
#' @field recipe_ids Character vector of recipe IDs referenced.
#' @field calls List of deparsed call strings.
#' @field call_metadata List of lists with type,
#'   formula, by, description fields.
#' @field categories List of RecipeCategory objects.
#' @field downloads Integer download count.
#' @field certification RecipeCertification object.
#' @field version Version string.
#' @field doi DOI or external identifier (character|NULL).
#' @field created_at Creation timestamp (character).
#' @field weight_spec Named list with weight
#'   configuration per periodicity (list|NULL).
#'
#' @section Methods:
#' \describe{
#'   \item{$new(...)}{Class constructor.}
#'   \item{$doc()}{Generate documentation for the workflow.}
#'   \item{$to_list()}{Serialize to a plain list for JSON export.}
#'   \item{$increment_downloads()}{Increment the download counter.}
#'   \item{$add_category(category)}{Add a category.}
#'   \item{$certify(user, level)}{Certify the workflow.}
#' }
#'
#' @return An object of class \code{RecipeWorkflow}.
#'
#' @examples
#' wf <- RecipeWorkflow$new(
#'   name = "Labor workflow", description = "Unemployment rate",
#'   user = "test", survey_type = "ech", edition = "2023",
#'   estimation_type = "annual", recipe_ids = "r_001",
#'   calls = list("svymean(~desocupado, na.rm = TRUE)")
#' )
#'
#' @seealso \code{\link{save_workflow}}, \code{\link{read_workflow}},
#'   \code{\link{workflow}}
#' @family workflows
#' @export
RecipeWorkflow <- R6Class("RecipeWorkflow",
  public = list(
    id = NULL,
    name = NULL,
    description = NULL,
    user = NULL,
    user_info = NULL,
    survey_type = NULL,
    edition = NULL,
    estimation_type = character(0),
    recipe_ids = character(0),
    calls = list(),
    call_metadata = list(),
    categories = list(),
    downloads = 0L,
    certification = NULL,
    version = "1.0.0",
    doi = NULL,
    created_at = NULL,
    weight_spec = NULL,

    #' @description Create a RecipeWorkflow object
    #' @param id Unique identifier
    #' @param name Descriptive name
    #' @param description Workflow description
    #' @param user Author name
    #' @param user_info RecipeUser object or NULL
    #' @param survey_type Survey type
    #' @param edition Survey edition
    #' @param estimation_type Character vector of estimation types
    #' @param recipe_ids Character vector of recipe IDs
    #' @param calls List of deparsed call strings
    #' @param call_metadata List of call metadata lists
    #' @param categories List of RecipeCategory objects
    #' @param downloads Integer download count
    #' @param certification RecipeCertification or NULL
    #' @param version Version string
    #' @param doi DOI or NULL
    #' @param created_at Timestamp string or NULL (auto-generated)
    #' @param weight_spec Named list with weight configuration per periodicity
    initialize = function(id = NULL, name, description = "", user = "Unknown",
                          user_info = NULL, survey_type = "Unknown",
                          edition = "Unknown", estimation_type = character(0),
                          recipe_ids = character(0), calls = list(),
                          call_metadata = list(), categories = list(),
                          downloads = 0L, certification = NULL,
                          version = "1.0.0", doi = NULL, created_at = NULL,
                          weight_spec = NULL) {
      self$id <- id %||% generate_id("w")
      self$name <- name
      self$description <- description
      self$user <- user
      self$user_info <- user_info
      self$survey_type <- survey_type
      self$edition <- edition
      self$estimation_type <- estimation_type
      self$recipe_ids <- as.character(recipe_ids)
      self$calls <- calls
      self$call_metadata <- call_metadata
      self$categories <- categories
      self$downloads <- as.integer(downloads)
      self$certification <- certification %||%
        RecipeCertification$new(level = "community")
      self$version <- version
      self$doi <- doi
      self$created_at <- created_at %||%
        format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
      self$weight_spec <- weight_spec
    },

    #' @description Generate documentation for this workflow
    #' @return List with meta, recipe_ids, estimations, and estimation_types
    doc = function() {
      cat_names <- vapply(
        self$categories, function(c) c$name, character(1)
      )
      list(
        meta = list(
          name = self$name,
          user = self$user,
          edition = self$edition,
          survey_type = self$survey_type,
          description = self$description,
          doi = self$doi,
          id = self$id,
          categories = if (length(cat_names) > 0) {
            paste(cat_names, collapse = ", ")
          } else {
            NULL
          },
          certification = self$certification$level,
          version = self$version,
          downloads = self$downloads,
          created_at = self$created_at
        ),
        recipe_ids = self$recipe_ids,
        estimations = self$call_metadata,
        estimation_types = self$estimation_type
      )
    },

    #' @description Serialize to a plain list for JSON export
    #' @return A list suitable for jsonlite::write_json
    to_list = function() {
      list(
        id = self$id,
        name = self$name,
        description = self$description,
        user = self$user,
        user_info = if (!is.null(self$user_info)) {
          self$user_info$to_list()
        } else {
          NULL
        },
        survey_type = self$survey_type,
        edition = self$edition,
        estimation_type = as.list(self$estimation_type),
        recipe_ids = as.list(self$recipe_ids),
        calls = as.list(self$calls),
        call_metadata = self$call_metadata,
        categories = lapply(
          self$categories, function(c) c$to_list()
        ),
        downloads = self$downloads,
        certification = self$certification$to_list(),
        version = self$version,
        doi = self$doi,
        created_at = self$created_at,
        weight_spec = self$weight_spec,
        metasurvey_version = as.character(
          utils::packageVersion("metasurvey")
        )
      )
    },

    #' @description Increment the download counter
    increment_downloads = function() {
      self$downloads <- self$downloads + 1L
    },

    #' @description Certify the workflow at a given level
    #' @param user RecipeUser who is certifying
    #' @param level Character certification level
    certify = function(user, level) {
      self$certification <- RecipeCertification$new(
        level = level, certified_by = user
      )
    },

    #' @description Add a category to the workflow
    #' @param category RecipeCategory to add
    add_category = function(category) {
      existing <- vapply(
        self$categories, function(c) c$name, character(1)
      )
      if (!category$name %in% existing) {
        self$categories <- c(self$categories, list(category))
      }
    },

    #' @description Remove a category by name
    #' @param name Character category name to remove
    remove_category = function(name) {
      self$categories <- Filter(function(c) c$name != name, self$categories)
    }
  )
)

#' Construct a RecipeWorkflow from a plain list
#'
#' @param lst A list (typically from JSON) with workflow fields
#' @return A RecipeWorkflow object
#' @export
#' @examples
#' lst <- list(
#'   name = "example", user = "test", survey_type = "ech",
#'   edition = "2023", estimation_type = "svymean"
#' )
#' wf <- workflow_from_list(lst)
#' @family workflows
workflow_from_list <- function(lst) {
  # Reconstruct categories
  categories <- list()
  if (!is.null(lst$categories)) {
    raw_cats <- lst$categories
    if (is.data.frame(raw_cats)) {
      for (i in seq_len(nrow(raw_cats))) {
        row <- as.list(raw_cats[i, ])
        if (is.data.frame(row$parent) && (nrow(row$parent) == 0 || ncol(row$parent) == 0)) {
          row$parent <- NULL
        }
        categories[[i]] <- RecipeCategory$from_list(row)
      }
    } else if (is.list(raw_cats)) {
      categories <- lapply(raw_cats, RecipeCategory$from_list)
    }
  }

  # Reconstruct certification
  certification <- NULL
  if (!is.null(lst$certification)) {
    certification <- tryCatch(
      RecipeCertification$from_list(lst$certification),
      error = function(e) NULL
    )
  }

  # Reconstruct user_info
  user_info <- NULL
  if (!is.null(lst$user_info)) {
    user_info <- tryCatch(
      RecipeUser$from_list(lst$user_info),
      error = function(e) NULL
    )
  }

  # Reconstruct call_metadata
  call_metadata <- lst$call_metadata %||% list()
  if (is.data.frame(call_metadata)) {
    call_metadata <- lapply(
      seq_len(nrow(call_metadata)),
      function(i) as.list(call_metadata[i, ])
    )
  }

  RecipeWorkflow$new(
    id = lst$id %||% generate_id("w"),
    name = lst$name %||% "Unnamed Workflow",
    description = lst$description %||% "",
    user = lst$user %||% "Unknown",
    user_info = user_info,
    survey_type = lst$survey_type %||% "Unknown",
    edition = lst$edition %||% "Unknown",
    estimation_type = as.character(
      unlist(lst$estimation_type %||% character(0))
    ),
    recipe_ids = as.character(
      unlist(lst$recipe_ids %||% character(0))
    ),
    calls = as.list(lst$calls %||% list()),
    call_metadata = call_metadata,
    categories = categories,
    downloads = as.integer(lst$downloads %||% 0),
    certification = certification,
    version = lst$version %||% "1.0.0",
    doi = lst$doi,
    created_at = lst$created_at,
    weight_spec = lst$weight_spec
  )
}

#' Save a RecipeWorkflow to a JSON file
#'
#' @param wf A RecipeWorkflow object
#' @param file Character file path
#' @return NULL (called for side-effect)
#' @keywords workflow
#' @family workflows
#' @export
#' @examples
#' wf <- RecipeWorkflow$new(
#'   name = "Example", description = "Test",
#'   survey_type = "ech", edition = "2023",
#'   recipe_ids = "r_001", estimation_type = "svymean"
#' )
#' f <- tempfile(fileext = ".json")
#' save_workflow(wf, f)
save_workflow <- function(wf, file) {
  if (!inherits(wf, "RecipeWorkflow")) {
    stop("Can only save RecipeWorkflow objects", call. = FALSE)
  }
  wf_data <- wf$to_list()
  jsonlite::write_json(
    wf_data,
    path = file,
    auto_unbox = TRUE, pretty = TRUE
  )
  metasurvey_msg(glue::glue("Workflow saved to {file}"))
}

#' Read a RecipeWorkflow from a JSON file
#'
#' @param file Character file path
#' @return A RecipeWorkflow object
#' @keywords workflow
#' @family workflows
#' @export
#' @examples
#' wf <- RecipeWorkflow$new(
#'   name = "Example", description = "Test",
#'   survey_type = "ech", edition = "2023",
#'   recipe_ids = "r_001", estimation_type = "svymean"
#' )
#' f <- tempfile(fileext = ".json")
#' save_workflow(wf, f)
#' wf2 <- read_workflow(f)
read_workflow <- function(file) {
  json_data <- jsonlite::read_json(
    file,
    simplifyVector = TRUE
  )
  workflow_from_list(json_data)
}

#' Print method for RecipeWorkflow objects
#'
#' @param x A RecipeWorkflow object
#' @param ... Additional arguments (unused)
#' @return Invisibly returns the object
#' @examples
#' wf <- RecipeWorkflow$new(
#'   id = "w1", name = "Example Workflow", user = "tester",
#'   edition = "2023", survey_type = "test",
#'   recipe_ids = "r1",
#'   calls = list(), description = "Demo"
#' )
#' print(wf)
#' @keywords workflow
#' @family workflows
#' @export
print.RecipeWorkflow <- function(x, ...) {
  doc_info <- x$doc()

  cat(cli::style_bold(cli::col_blue(paste0(
    "\n\u2500\u2500 Workflow: ", x$name, " \u2500\u2500\n"
  ))))

  cat(cli::col_silver("Author:  "), x$user, "\n", sep = "")
  cat(
    cli::col_silver("Survey:  "),
    x$survey_type, " / ", x$edition, "\n",
    sep = ""
  )
  cat(cli::col_silver("Version: "), x$version, "\n", sep = "")
  if (!is.null(x$doi)) {
    cat(cli::col_silver("DOI:     "), x$doi, "\n", sep = "")
  }
  if (nzchar(x$description)) {
    cat(
      cli::col_silver("Description: "),
      x$description, "\n",
      sep = ""
    )
  }

  # Certification badge
  cert_label <- switch(x$certification$level,
    "community" = cli::col_yellow("community"),
    "reviewed" = cli::col_cyan("reviewed"),
    "official" = cli::col_green("official"),
    x$certification$level
  )
  cat(cli::col_silver("Certification: "), cert_label, "\n", sep = "")

  if (x$downloads > 0) {
    cat(cli::col_silver("Downloads: "), x$downloads, "\n", sep = "")
  }

  # Estimation types
  if (length(x$estimation_type) > 0) {
    cat(
      cli::col_silver("Estimation types: "),
      paste(x$estimation_type, collapse = ", "),
      "\n",
      sep = ""
    )
  }

  # Weight configuration
  if (!is.null(x$weight_spec) && length(x$weight_spec) > 0) {
    cat(cli::style_bold(cli::col_blue("\n\u2500\u2500 Weights \u2500\u2500\n")))
    for (pname in names(x$weight_spec)) {
      ws <- x$weight_spec[[pname]]
      if (ws$type == "simple") {
        cat(sprintf("  %s: %s\n", pname, ws$variable))
      } else if (ws$type == "replicate") {
        src <- ws$replicate_source
        src_str <- if (!is.null(src) && src$provider == "anda") {
          paste0("anda:", src$resource)
        } else {
          "local"
        }
        cat(sprintf(
          "  %s: %s (%s, %s)\n",
          pname, ws$variable,
          ws$replicate_type, src_str
        ))
      }
    }
  }

  # Recipe references
  if (length(x$recipe_ids) > 0) {
    cat(cli::style_bold(cli::col_blue(paste0(
      "\n\u2500\u2500 Uses Recipes (", length(x$recipe_ids), ") \u2500\u2500\n"
    ))))
    cat("  ", paste(x$recipe_ids, collapse = ", "), "\n", sep = "")
  }

  # Estimations
  if (length(x$call_metadata) > 0) {
    est_hdr <- paste0(
      "\n\u2500\u2500 Estimations (",
      length(x$call_metadata), ") \u2500\u2500\n"
    )
    cat(cli::style_bold(cli::col_blue(est_hdr)))
    for (i in seq_along(x$call_metadata)) {
      cm <- x$call_metadata[[i]]
      type_str <- cm$type %||% "unknown"
      formula_str <- cm$formula %||% ""
      desc_str <- if (!is.null(cm$description) && nzchar(cm$description)) {
        paste0("  \"", cm$description, "\"")
      } else {
        ""
      }
      cat(sprintf("  %d. [%s] %s%s\n", i, type_str, formula_str, desc_str))
    }
  }

  # Raw calls if no metadata
  if (length(x$call_metadata) == 0 && length(x$calls) > 0) {
    cat(cli::style_bold(cli::col_blue(paste0(
      "\n\u2500\u2500 Calls (", length(x$calls), ") \u2500\u2500\n"
    ))))
    for (i in seq_along(x$calls)) {
      cat(sprintf("  %d. %s\n", i, x$calls[[i]]))
    }
  }

  cat("\n")
  invisible(x)
}
