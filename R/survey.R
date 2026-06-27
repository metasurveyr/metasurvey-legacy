#' Survey R6 class
#'
#' R6 class that encapsulates survey data, metadata (type, edition,
#' periodicity), sampling design (simple/replicate), steps/recipes/workflows,
#' and utilities to manage them.
#'
#' @seealso \code{\link{survey_empty}}, \code{\link{bake_recipes}},
#'   \code{\link{cat_design}}, \code{\link{cat_recipes}}
#' @keywords survey
#'
#' @name Survey
#' @docType class
#' @format An R6 class generator (R6ClassGenerator)
#'
#' @field data Survey data (data.frame/data.table).
#' @field edition Reference edition or period.
#' @field type Survey type, e.g., "ech" (character).
#' @field periodicity Periodicity detected by validate_time_pattern.
#' @field default_engine Default engine (character).
#' @field weight List with weight specifications per estimation type.
#' @field steps List of steps applied to the survey.
#' @field recipes List of \link{Recipe} objects associated.
#' @field workflows List of workflows.
#' @field design List of survey design objects (survey/surveyrep).
#' @field psu Primary Sampling Unit specification (formula or character).
#' @field strata Stratification variable name (character or NULL).
#' @field design_initialized Logical flag for lazy design initialization.
#' @field provenance Data lineage metadata (see [provenance()]).
#'
#' @section Main methods:
#' \describe{
#'   \item{$new(data, edition, type, psu, strata, engine,
#'     weight, design = NULL, steps = NULL,
#'     recipes = list())}{Constructor.}
#'   \item{$set_data(data)}{Set data.}
#'   \item{$set_edition(edition)}{Set edition.}
#'   \item{$set_type(type)}{Set type.}
#'   \item{$set_weight(weight)}{Set weight specification.}
#'   \item{$print()}{Print summarized metadata.}
#'   \item{$add_step(step)}{Add a step and invalidate design.}
#'   \item{$add_recipe(recipe)}{Add a recipe (validates type and dependencies).}
#'   \item{$add_workflow(workflow)}{Add a workflow.}
#'   \item{$bake()}{Apply recipes and return updated Survey.}
#'   \item{$ensure_design()}{Lazily initialize the sampling design.}
#'   \item{$update_design()}{Update design variables with current data.}
#'   \item{$shallow_clone()}{Efficient copy (shares design, copies data).}
#' }
#'
#' @param data Survey data.
#' @param edition Edition or period.
#' @param type Survey type (character).
#' @param psu PSU variable or formula (optional).
#' @param strata Stratification variable name (optional). Passed to
#'   [survey::svydesign()] as the `strata` argument.
#' @param engine Default engine.
#' @param weight Weight specification(s) per estimation type.
#' @param design Pre-built design (optional).
#' @param steps Initial steps list (optional).
#' @param recipes List of \link{Recipe} (optional).
#'
#' @return R6 class generator for Survey.
#' @examples
#' dt <- data.table::data.table(id = 1:5, x = rnorm(5), w = rep(1, 5))
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "test",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' svy
#' @family survey-objects
#' @export
Survey <- R6Class(
  "Survey",
  public = list(
    data = NULL,
    edition = NULL,
    type = NULL,
    periodicity = NULL,
    default_engine = NULL,
    weight = NULL,
    steps = list(),
    recipes = list(),
    workflows = list(),
    design = NULL,
    psu = NULL,
    strata = NULL,
    design_initialized = FALSE,
    provenance = NULL,

    #' @description Create a Survey object
    #' @param data Survey data
    #' @param edition Edition or period
    #' @param type Survey type (character)
    #' @param psu PSU variable or formula (optional)
    #' @param strata Stratification variable name (optional)
    #' @param engine Default engine
    #' @param weight Weight specification(s) per estimation type
    #' @param design Pre-built design (optional)
    #' @param steps Initial steps list (optional)
    #' @param recipes List of Recipe (optional)
    initialize = function(data, edition, type,
                          psu = NULL, strata = NULL,
                          engine, weight,
                          design = NULL, steps = NULL,
                          recipes = list()) {
      self$data <- data

      time_pattern <- validate_time_pattern(
        svy_type = type,
        svy_edition = edition
      )

      weight_list <- validate_weight_time_pattern(data, weight)

      # LAZY DESIGN: Store PSU for later, don't create design yet
      self$psu <- psu
      self$strata <- strata
      self$edition <- time_pattern$svy_edition
      self$type <- time_pattern$svy_type
      self$default_engine <- engine
      self$weight <- weight_list
      self$periodicity <- time_pattern$svy_periodicity

      # Mark design as not initialized
      self$design <- NULL
      self$design_initialized <- FALSE

      if (length(recipes) == 1) {
        recipes <- list(recipes)
      }

      self$recipes <- if (is.null(recipes)) list() else recipes
      self$workflows <- list()
      self$steps <- if (is.null(steps)) list() else steps

      # Initialize provenance
      self$provenance <- structure(
        list(
          source = list(
            path = NULL,
            timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
            initial_n = if (!is.null(data)) nrow(data) else NULL,
            hash = NULL
          ),
          steps = list(),
          environment = list(
            metasurvey_version = as.character(
              utils::packageVersion("metasurvey")
            ),
            r_version = paste(R.version$major, R.version$minor, sep = "."),
            survey_version = as.character(
              utils::packageVersion("survey")
            )
          )
        ),
        class = "metasurvey_provenance"
      )
    },

    #' @description Return the underlying data
    get_data = function() {
      return(self$data)
    },

    #' @description Return the survey edition/period
    get_edition = function() {
      return(self$edition)
    },

    #' @description Return the survey type identifier
    get_type = function() {
      return(self$type)
    },

    #' @description Set the underlying data
    #' @param data New survey data
    set_data = function(data) {
      self$data <- data
    },

    #' @description Set the survey edition/period
    #' @param edition New edition or period
    set_edition = function(edition) {
      self$edition <- edition
    },

    #' @description Set the survey type
    #' @param type New type identifier
    set_type = function(type) {
      self$type <- type
    },

    #' @description Set weight specification(s) per estimation type
    #' @param weight Weight specification list or character
    set_weight = function(weight) {
      data <- self$data
      weight_list <- validate_weight_time_pattern(data, weight)
      self$weight <- weight_list
    },

    #' @description Print summarized metadata to console
    print = function() {
      get_metadata(self)
    },

    #' @description Add a step and invalidate design
    #' @param step Step object
    add_step = function(step) {
      name_index <- length(self$steps) + 1
      name_index <- paste0("step_", name_index, " ", step$name)
      step$name <- name_index
      self$steps[[name_index]] <- step
      self$design_initialized <- FALSE
    },

    #' @description Add a recipe
    #' @param recipe Recipe object
    #' @param bake Whether to bake lazily (internal flag)
    add_recipe = function(recipe, bake = lazy_default()) {
      # Validate survey_type match (if both are set)
      both_set <- !is.null(self$type) && !is.null(recipe$survey_type) &&
        nzchar(self$type) && nzchar(recipe$survey_type)
      if (both_set && tolower(self$type) != tolower(recipe$survey_type)) {
        stop(
          "Recipe survey type mismatch: survey is '", self$type,
          "' but recipe '", recipe$name, "' targets '", recipe$survey_type, "'",
          call. = FALSE
        )
      }

      # Validate depends_on: check that required variables
      # exist in the data (case-insensitive)
      if (length(recipe$depends_on) > 0 && !is.null(self$data)) {
        deps <- unlist(recipe$depends_on)
        survey_vars <- names(self$data)
        missing_vars <- deps[!tolower(deps) %in% tolower(survey_vars)]
        if (length(missing_vars) > 0) {
          warning(
            "Recipe '", recipe$name,
            "' depends on variables not present in survey: ",
            paste(missing_vars, collapse = ", "),
            ". Recipe added but bake_recipes() may fail.",
            call. = FALSE
          )
        }
      }

      index_recipe <- length(self$recipes) + 1
      self$recipes[[index_recipe]] <- recipe
    },

    #' @description Add a workflow to the survey
    #' @param workflow Workflow object
    add_workflow = function(workflow) {
      self$workflows[[workflow$name]] <- workflow
    },

    #' @description Apply recipes and return updated Survey
    bake = function() {
      bake_recipes(self)
    },

    #' @description Return the head of the underlying data
    head = function() {
      head(self$data)
    },

    #' @description Display the structure of the underlying data
    str = function() {
      str(self$data)
    },

    #' @description Set the survey design object
    #' @param design Survey design object or list
    set_design = function(design) {
      self$design <- design
      self$design_initialized <- TRUE
    },

    #' @description Ensure survey design is initialized (lazy initialization)
    #' @return Invisibly returns self
    ensure_design = function() {
      if (!self$design_initialized) {
        weight_list <- self$weight
        psu <- self$psu
        strata_var <- self$strata
        data <- self$data

        if (!is.null(strata_var) && !is.null(data)) {
          if (!strata_var %in% names(data)) {
            stop(
              "Strata variable '", strata_var,
              "' not found in survey data",
              call. = FALSE
            )
          }
        }

        design_list <- lapply(
          weight_list,
          function(x) {
            if (is.character(x)) {
              if (is.null(psu)) {
                psu <- ~1
              } else {
                psu <- as.formula(paste("~", psu))
              }

              strata_fml <- if (!is.null(strata_var)) {
                as.formula(paste("~", strata_var))
              } else {
                NULL
              }

              survey::svydesign(
                id = psu,
                strata = strata_fml,
                weights = as.formula(paste("~", x)),
                data = data,
                calibrate.formula = ~1
              )
            } else {
              aux_vars <- c(x$weight, x$replicate_id)
              data_aux <- data[, aux_vars, with = FALSE]
              data_aux <- merge(
                data_aux,
                x$replicate_file[, 1:11],
                by.x = names(x$replicate_id),
                by.y = x$replicate_id
              )

              design <- survey::svrepdesign(
                id = psu,
                weights = as.formula(paste("~", x$weight)),
                data = data_aux,
                repweights = x$replicate_pattern,
                type = x$replicate_type
              )

              data <- merge(
                data, x$replicate_file,
                by.x = names(x$replicate_id),
                by.y = x$replicate_id
              )
              design$variables <- data
              vars <- grepl(x$replicate_pattern, names(data))
              rep_weights <- data[, vars, with = FALSE]
              design$repweights <- data.table(rep_weights)
              return(design)
            }
          }
        )

        names(design_list) <- names(weight_list)
        self$design <- design_list
        self$design_initialized <- TRUE
      }

      return(invisible(self))
    },

    #' @description Update design variables using current data and weight
    update_design = function() {
      self$ensure_design()

      weight_list <- self$weight
      data_now <- self$get_data()

      if (length(self$design) != length(weight_list)) {
        warning("Design length mismatch, reinitializing design", call. = FALSE)
        self$design_initialized <- FALSE
        self$ensure_design()
      }

      for (i in seq_along(weight_list)) {
        if (is.character(weight_list[[i]])) {
          self$design[[i]]$variables <- self$data
        } else {
          self$design[[i]]$variables <- merge(
            data_now,
            weight_list[[i]]$replicate_file,
            by.x = names(weight_list[[i]]$replicate_id),
            by.y = weight_list[[i]]$replicate_id
          )
        }
      }
    },

    #' @description Create a shallow copy of the Survey
    #' (optimized for performance)
    #' @details Only copies the data; reuses design objects and other metadata.
    #'   Much faster than clone(deep=TRUE) but design objects are shared.
    #' @return New Survey object with copied data but shared design
    shallow_clone = function() {
      new_svy <- self$clone(deep = FALSE)
      new_svy$data <- data.table::copy(self$data)
      return(new_svy)
    }
  ),
  active = list(
    #' @field design_active Deprecated. Use \code{ensure_design()} instead.
    design_active = function() {
      self$ensure_design()
      self$design
    }
  )
)


#' @title survey_to_data_frame
#' @description Convert survey to data.frame
#' @keywords survey
#' @param svy Survey object
#' @examples
#' dt <- data.table::data.table(
#'   id = 1:5, age = c(25, 30, 45, 50, 60),
#'   w = rep(1, 5)
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "ech",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' df <- survey_to_data_frame(svy)
#' class(df) # "data.frame"
#' @family survey-objects
#' @export
#' @return data.frame
survey_to_data_frame <- function(svy) {
  data.frame(svy$get_data())
}

#' @title survey_to_tibble
#' @keywords survey
#' @description Convert survey to tibble
#' @param svy Survey object
#' @examplesIf requireNamespace("tibble", quietly = TRUE)
#' dt <- data.table::data.table(
#'   id = 1:5, age = c(25, 30, 45, 50, 60),
#'   w = rep(1, 5)
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "ech",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' tbl <- survey_to_tibble(svy)
#' class(tbl)
#' @family survey-objects
#' @export
#' @return A tibble ([tbl_df][tibble::tbl_df]) containing the survey data.

survey_to_tibble <- function(svy) {
  if (!requireNamespace("tibble", quietly = TRUE)) {
    stop("Package 'tibble' required. Install with: install.packages('tibble')",
      call. = FALSE
    )
  }
  tibble::as_tibble(svy$get_data())
}

#' Convert survey to data.table
#'
#' Extracts the survey microdata as a `data.table`.
#'
#' @param svy Survey object.
#' @return A `data.table`.
#' @examples
#' dt <- data.table::data.table(
#'   id = 1:5, age = c(25, 30, 45, 50, 60),
#'   w = rep(1, 5)
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "ech",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' result <- survey_to_datatable(svy)
#' data.table::is.data.table(result) # TRUE
#' @family survey-objects
#' @keywords survey
#' @export
#' @importFrom data.table data.table
survey_to_datatable <- function(svy) {
  data.table::data.table(svy$get_data())
}

#' @rdname survey_to_datatable
#' @export
survey_to_data.table <- function(svy) {
  lifecycle::deprecate_warn(
    "0.0.20", "survey_to_data.table()", "survey_to_datatable()"
  )
  survey_to_datatable(svy)
}

#' @title get_data
#' @description Get data from survey
#' @param svy Survey object
#' @keywords survey
#' @examples
#' dt <- data.table::data.table(
#'   id = 1:5, age = c(25, 30, 45, 50, 60),
#'   w = rep(1, 5)
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "ech",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' head(get_data(svy))
#' @family survey-objects
#' @export
#' @return A `data.table` (or `data.frame`) containing the survey microdata.

get_data <- function(svy) {
  svy$get_data()
}

get_edition <- function(svy) {
  svy$get_edition()
}

get_weight <- function(svy, estimation_type = seq_along(svy$weight)) {
  svy$weight[[estimation_type]]
}

get_info_weight <- function(svy) {
  info_weight <- c("")

  for (i in seq_along(svy$weight)) {
    if (is.character(svy$weight[[i]]) == 1) {
      info_weight[i] <- glue::glue(
        "Weight {names(svy$weight)[[i]]}: {svy$weight[[i]]} (Simple design)"
      )
    } else {
      rep_name <- basename(svy$weight[[i]]$replicate_path)
      rep_n <- ncol(svy$weight[[i]]$replicate_file) - 1
      info_weight[i] <- glue::glue(
        "

         {names(svy$weight)[[i]]}: {svy$weight[[i]]$weight} (Replicate design)
         Type: {svy$weight[[i]]$replicate_type}
         Pattern: {svy$weight[[i]]$replicate_pattern}
         Replicate file: {rep_name} with {rep_n} replicates"
      )
    }
  }

  glue::glue(
    Reduce(
      f = function(x, y) {
        paste0(x, "\n", y)
      },
      x = info_weight
    )
  )
}

get_type <- function(svy) {
  svy$get_type()
}

get_design <- function(self) {
  self$ensure_design()
  self$design
}

set_edition <- function(svy, new_edition, .copy = use_copy_default()) {
  if (.copy) {
    clone <- svy$clone()
    clone$set_edition(new_edition)
    return(clone)
  } else {
    svy$set_edition(new_edition)
    return(svy)
  }
}

set_type <- function(svy, new_type, .copy = use_copy_default()) {
  if (.copy) {
    clone <- svy$clone()
    clone$set_type(new_type)
    return(clone)
  } else {
    svy$set_type(new_type)
    return(svy)
  }
}

set_weight <- function(svy, new_weight, .copy = use_copy_default()) {
  if (.copy) {
    clone <- svy$clone()
    clone$set_weight(new_weight)
    return(clone)
  } else {
    if (svy$weight == new_weight) {
      return(svy)
    }

    svy$set_weight(new_weight)
    return(svy)
  }
}

#' Check if survey has steps
#'
#' @param svy A Survey or RotativePanelSurvey object.
#' @return Logical.
#' @examples
#' svy <- survey_empty(type = "test", edition = "2023")
#' has_steps(svy) # FALSE
#' @family survey-objects
#' @export
has_steps <- function(svy) {
  length(svy$steps) > 0
}

#' Check if survey has recipes
#'
#' @param svy A Survey or RotativePanelSurvey object.
#' @return Logical.
#' @examples
#' svy <- survey_empty(type = "test", edition = "2023")
#' has_recipes(svy) # FALSE
#' @family survey-objects
#' @export
has_recipes <- function(svy) {
  length(svy$recipes) > 0
}

#' Check if all steps are baked
#'
#' Returns TRUE when every step attached to the survey has been
#' executed (bake == TRUE), or when there are no steps.
#'
#' @param svy A Survey or RotativePanelSurvey object.
#' @return Logical.
#' @examples
#' svy <- survey_empty(type = "test", edition = "2023")
#' is_baked(svy) # TRUE (no steps)
#' @family survey-objects
#' @export
is_baked <- function(svy) {
  steps <- svy$steps
  if (length(steps) == 0) {
    return(TRUE)
  }
  all(vapply(steps, function(s) isTRUE(s$bake), logical(1)))
}

#' Check if survey has a design
#'
#' @param svy A Survey object.
#' @return Logical.
#' @examples
#' svy <- survey_empty(type = "test", edition = "2023")
#' has_design(svy) # FALSE
#' @family survey-objects
#' @export
has_design <- function(svy) {
  !is.null(svy$design) || isTRUE(svy$design_initialized)
}

#' @title get_metadata
#' @description Get metadata from survey
#' @keywords survey
#' @importFrom glue glue
#' @param self Object of class Survey
#' @return NULL (called for side effect: prints metadata to console).
#' @examples
#' dt <- data.table::data.table(
#'   id = 1:5, age = c(25, 30, 45, 50, 60),
#'   w = rep(1, 5)
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "ech",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' get_metadata(svy)
#' @family survey-objects
#' @export

get_metadata <- function(self) {
  if (is(self, "Survey")) {
    type <- toupper(self$type)
    edition <- if (is.null(self$edition) || identical(self$edition, NA)) {
      "Unknown"
    } else if (is(self$edition, "character") || is(self$edition, "numeric")) {
      self$edition
    } else {
      format(self$edition, "%Y-%m")
    }
    default_engine <- self$default_engine
    design <- cat_design(self)
    steps <- ifelse(
      length(self$steps) == 0,
      "None",
      paste0(
        "\n  - ",
        paste0(names(self$steps), collapse = "\n  - ")
      )
    )
    periodicity <- self$periodicity
    names_recipes <- cat_recipes(self)
    cat(glue::glue(
      "\n{cli::col_blue('Type:')} {type}",
      "\n{cli::col_blue('Edition:')} {edition}",
      "\n{cli::col_blue('Periodicity:')} {periodicity}",
      "\n{cli::col_blue('Engine:')} {default_engine}",
      "\n{cli::col_blue('Design:')} {design}",
      "\n{cli::col_blue('Steps:')} {steps}",
      "\n{cli::col_blue('Recipes:')} {names_recipes}"
    ), "\n")

    invisible(
      list(
        type = self$type,
        edition = self$edition,
        default_engine = self$default_engine,
        weight = self$weight,
        steps = names(self$steps)
      )
    )
  }

  if (is(self, "RotativePanelSurvey")) {
    type <- toupper(self$type)
    edition <- ifelse(
      is(self$implantation$edition, "character") ||
        is(self$implantation$edition, "numeric"),
      self$implantation$edition,
      format(self$implantation$edition, "%Y-%m")
    )
    default_engine <- self$default_engine
    steps <- sub(
      "\n$",
      "",
      paste0(
        if (length(self$get_steps()$implantation) > 0) {
          paste0(
            "implantation: (",
            paste(
              names(self$get_steps()$implantation),
              collapse = ", "
            ),
            ")\n"
          )
        } else {
          ""
        },
        if (length(self$get_steps()$follow_up) > 0 &&
          !is.null(row.names(
            self$get_steps()$follow_up
          ))) {
          paste0(
            "follow_up: (",
            paste(
              row.names(
                self$get_steps()$follow_up
              ),
              collapse = ", "
            ),
            ")\n"
          )
        } else {
          ""
        }
      )
    )
    imp_per <- self$periodicity$implantation
    fu_per <- self$periodicity$follow_up
    names_recipes <- cat_recipes(self)
    cat(glue::glue(
      "\n{cli::col_blue('Type:')} {type} (Rotative Panel)",
      "\n{cli::col_blue('Edition:')} {edition}",
      "\n{cli::col_blue('Periodicity:')} Implantation: {imp_per}, Follow-up: {fu_per}",
      "\n{cli::col_blue('Engine:')} {default_engine}",
      "\n{cli::col_blue('Steps:')} {steps}",
      "\n{cli::col_blue('Recipes:')} {names_recipes}"
    ), "\n")

    invisible(
      list(
        type = self$type,
        edition = self$edition,
        default_engine = self$default_engine,
        weight = self$weight,
        steps = names(self$steps)
      )
    )
  }

  if (is(self, "PoolSurvey")) {
    type <- toupper(
      unique(
        vapply(
          self$surveys[[1]],
          function(x) x[[1]]$type,
          character(1)
        )
      )
    )
    steps <- unique(
      vapply(
        self$surveys[[1]],
        function(x) {
          ifelse(
            length(x[[1]]$steps) == 0,
            "None",
            paste0(
              "\n  - ",
              paste0(names(x[[1]]$steps), collapse = "\n  - ")
            )
          )
        },
        character(1)
      )
    )
    periodicity <- names(self$surveys)
    p_each <- tolower(
      unique(vapply(
        self$surveys[[1]],
        function(x) x[[1]]$periodicity,
        character(1)
      ))
    )
    names_recipes <- unique(
      vapply(
        self$surveys[[1]],
        function(x) cat_recipes(x[[1]]),
        character(1)
      )
    )
    groups <- Reduce(
      f = function(x, y) {
        paste0(x, ", ", y)
      },
      names(self$surveys[[1]])
    )
    cat(glue::glue(
      "\n{cli::col_blue('Type:')} {type}",
      "\n{cli::col_blue('Periodicity:')} {cli::col_red('Periodicity of pool')} ",
      "{periodicity} {cli::col_red('each survey')} {p_each}",
      "\n{cli::col_blue('Steps:')} {steps}",
      "\n{cli::col_blue('Recipes:')} {names_recipes}",
      "\n{cli::col_blue('Group:')} {groups}"
    ), "\n")

    invisible(
      list(
        type = self$type,
        edition = self$edition,
        default_engine = self$default_engine,
        weight = self$weight,
        steps = names(self$steps)
      )
    )
  }
}

#' Display survey design information
#'
#' Pretty-prints the sampling design configuration for each estimation type
#' in a Survey object, showing PSU, strata, weights, and other design elements
#' in a color-coded, readable format.
#'
#' @param self Survey object containing design information
#'
#' @return Invisibly returns NULL; called for side
#' effect of printing design info
#'
#' @details
#' This function displays design information including:
#' \itemize{
#'   \item Primary Sampling Units (PSU/clusters)
#'   \item Stratification variables
#'   \item Weight variables for each estimation type
#'   \item Finite Population Correction (FPC) if used
#'   \item Calibration formulas if applied
#'   \item Overall design type classification
#' }
#'
#' Output is color-coded for better readability in supporting terminals.
#'
#' @examples
#' \donttest{
#' dt <- data.table::data.table(id = 1:20, x = rnorm(20), w = runif(20, 0.5, 2))
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "demo",
#'   psu = NULL, engine = "data.table",
#'   weight = add_weight(annual = "w")
#' )
#' cat_design(svy)
#' }
#'
#' @seealso \code{\link{cat_design_type}} for design type classification
#' @family survey-objects
#' @export
#'
#'

cat_design <- function(self) {
  if (!self$design_initialized) {
    return(paste0(
      "\n  Design: Not initialized",
      " (lazy initialization",
      " - will be created when needed)\n"
    ))
  }

  design_list <- self$design


  output_list <- vapply(
    names(design_list),
    function(x) {
      call <- design_list[[x]]$call
      cluster <- deparse(call$id) %||% "None"
      strata <- deparse(call$strata) %||% "None"
      weight <- ifelse(
        is.character(self$weight[[x]]),
        self$weight[[x]] %||% "None",
        self$weight[[x]]$weight %||% "None"
      )
      fpc <- deparse(call$fpc) %||% "None"
      calibrate.formula <- deparse(call$calibrate.formula) %||% "None"
      design_type <- cat_design_type(self, x)

      text <- paste0(
        "\n* ", cli::col_red(paste(toupper(x), "ESTIMATION")), "\n",
        "        ", design_type, "\n",
        "  * ", cli::col_green("PSU:"), " ", cluster, "\n",
        "  * ", cli::col_green("Strata:"), " ", strata, "\n",
        "  * ", cli::col_green("Weight:"), " ", weight, "\n",
        "  * ", cli::col_green("FPC:"), " ", fpc, "\n",
        "  * ", cli::col_green("Calibrate formula:"), " ", calibrate.formula
      )

      return(paste("\n  ", text))
    },
    character(1)
  )

  output <- paste0(output_list, collapse = "")

  return(output)
}







#' @title cat_design_type
#' @description Cast design type from survey
#' @keywords survey
#' @param self Object of class Survey
#' @param design_name Name of design
#' @return Character string describing the design type, or "None".
#' @examples
#' \donttest{
#' dt <- data.table::data.table(id = 1:20, x = rnorm(20), w = runif(20, 0.5, 2))
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "demo",
#'   psu = NULL, engine = "data.table",
#'   weight = add_weight(annual = "w")
#' )
#' svy$ensure_design()
#' cat_design_type(svy, "annual")
#' }
#' @family survey-objects
#' @export

cat_design_type <- function(self, design_name) {
  design_engine <- list(
    "survey.design2" = list(
      package = "survey",
      type = "Weighted design",
      variance_estimation = "Ultimate cluster"
    ),
    "svyrep.design" = list(
      package = "survey",
      type = "Replicated design",
      variance_estimation = list(
        "Jkn" = "Jackknife",
        "bootstrap" = "Bootstrap"
      )
    )
  )

  # Get the specific design class
  design_class <- class(self$design[[design_name]])[1]
  design_details <- design_engine[[design_class]]

  if (is.null(design_details)) {
    return("None")
  } else {
    # Determinar el método de estimación de varianza
    variance_estimation <- ifelse(
      is.list(design_details$variance_estimation),
      design_details$variance_estimation[[self$design[[design_name]]$type]],
      design_details$variance_estimation
    )
    return(
      glue::glue(
        "\n",
        "\n* {cli::col_green('Package:')} {package}",
        "\n* {cli::col_green('Variance estimation:')} {variance_estimation}",
        package = design_details$package,
        variance_estimation = variance_estimation
      )
    )
  }
}


#' @title cat_recipes
#' @description Cast recipes from survey
#' @param self Object of class Survey
#' @return Character string listing recipe names, or "None".
#' @keywords internal

cat_recipes <- function(self) {
  if (is.null(self$recipes) || length(self$recipes) == 0) {
    return("None")
  }

  n_recipes <- get_distinct_recipes(self$recipes)

  string_print <- Reduce(
    f = function(x, y) {
      paste0(x, "\n  - ", y)
    },
    x = vapply(
      X = seq_len(n_recipes),
      FUN = function(x) {
        doi <- ifelse(
          is.null(self$recipes[[x]]$DOI),
          "None",
          self$recipes[[x]]$DOI
        )
        paste0(
          " ", cli::col_green("Name:"), " ", self$recipes[[x]]$name, "\n",
          "                    * ", cli::col_green("User:"), " ", self$recipes[[x]]$user, "\n",
          "                    * ", cli::col_green("Id:"), " ", self$recipes[[x]]$id, "\n",
          "                    * ", cli::col_green("DOI:"), " ", doi, "\n",
          "                    * ", cli::col_green("Bake:"), " ", self$recipes[[x]]$bake
        )
      },
      FUN.VALUE = character(1)
    ),
    init = ""
  )

  return(string_print)
}

#' @title get_steps
#' @description Get steps from survey
#' @param svy Survey object
#' @keywords survey
#' @keywords step
#' @examples
#' dt <- data.table::data.table(
#'   id = 1:5, age = c(25, 30, 45, 50, 60),
#'   w = rep(1, 5)
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "ech",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' svy <- step_compute(svy, age2 = age * 2)
#' get_steps(svy) # list of Step objects
#' @family steps
#' @export
#' @return List of Step objects

get_steps <- function(svy) {
  svy$steps
}

#' @title survey_empty
#' @description Create an empty survey
#' @keywords survey
#' @param edition Edition of survey
#' @param type Type of survey
#' @param weight Weight of survey
#' @param engine Engine of survey
#' @param psu PSU variable or formula (optional)
#' @param strata Stratification variable name (optional)
#' @examples
#' empty <- survey_empty(edition = "2023", type = "test")
#' empty_typed <- survey_empty(edition = "2023", type = "ech")
#' @family survey-objects
#' @export
#' @return Survey object

survey_empty <- function(edition = NULL, type = NULL,
                         weight = NULL, engine = NULL,
                         psu = NULL, strata = NULL) {
  Survey$new(
    data = NULL,
    edition = edition,
    type = type,
    psu = psu,
    strata = strata,
    weight = weight,
    engine = engine
  )
}


#' Bake recipes
#' @param svy Survey object
#' @keywords survey
#' @examples
#' \donttest{
#' dt <- data.table::data.table(id = 1:20, x = rnorm(20), w = runif(20, 0.5, 2))
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "demo",
#'   psu = NULL, engine = "data.table",
#'   weight = add_weight(annual = "w")
#' )
#' r <- recipe(
#'   name = "Demo", user = "test", svy = svy,
#'   description = "Demo recipe"
#' )
#' svy <- add_recipe(svy, r)
#' processed <- bake_recipes(svy)
#' }
#' @family recipes
#' @export
#' @return Survey object with all recipes applied
bake_recipes <- function(svy) {
  recipes <- svy$recipes

  if (length(recipes) == 0) {
    return(svy)
  }

  if (is(recipes, "Recipe")) {
    recipes <- list(recipes)
  }

  eval_env <- new.env(parent = parent.frame())
  eval_env$svy <- svy

  old_lazy <- getOption("metasurvey.lazy_processing")
  options(metasurvey.lazy_processing = FALSE)
  on.exit(options(metasurvey.lazy_processing = old_lazy), add = TRUE)

  for (i in seq_along(recipes)) {
    recipe <- recipes[[i]]

    # Validate depends_on before baking each recipe (case-insensitive)
    if (length(recipe$depends_on) > 0 && !is.null(eval_env$svy$data)) {
      deps <- unlist(recipe$depends_on)
      survey_vars <- names(eval_env$svy$data)
      missing_vars <- deps[!tolower(deps) %in% tolower(survey_vars)]
      if (length(missing_vars) > 0) {
        stop(
          "Cannot bake recipe '", recipe$name,
          "': missing required variables: ",
          paste(missing_vars, collapse = ", "),
          call. = FALSE
        )
      }

      # Normalize column names: rename data columns to match recipe case
      # (handles INE inconsistencies like POBPCOAC vs pobpcoac)
      survey_vars_lower <- tolower(survey_vars)
      for (dep in deps) {
        if (!dep %in% survey_vars) {
          match_idx <- which(survey_vars_lower == tolower(dep))
          if (length(match_idx) > 0) {
            data.table::setnames(
              eval_env$svy$data,
              survey_vars[match_idx[1]], dep
            )
            survey_vars <- names(eval_env$svy$data)
            survey_vars_lower <- tolower(survey_vars)
          }
        }
      }
    }

    for (step in seq_along(recipe$steps)) {
      step_call <- recipe$steps[[step]]
      if (is.character(step_call)) {
        step_call <- parse(text = step_call)[[1]]
      }
      # Replace pipe placeholder '.' with 'svy' in call objects
      is_pipe_call <- is.call(step_call) && length(step_call) >= 2 &&
        is.name(step_call[[2]]) && as.character(step_call[[2]]) == "."
      if (is_pipe_call) {
        step_call[[2]] <- as.name("svy")
      }
      eval_env$svy <- eval(step_call, envir = eval_env)
    }
  }
  svy <- eval_env$svy

  svy_after <- svy$clone(deep = TRUE)
  svy_after$recipes <- lapply(
    X = seq_along(recipes),
    FUN = function(x) {
      recipes[[x]]$clone()
    }
  )

  for (i in seq_along(recipes)) {
    svy_after$recipes[[i]]$bake <- TRUE
  }

  return(svy_after)
}

#' Set data on a Survey
#'
#' Tidy wrapper for \code{svy$set_data(data)}.
#'
#' @param svy Survey object
#' @param data A data.frame or data.table with survey microdata
#' @param .copy Logical; if TRUE, clone the Survey before
#' modifying (default FALSE)
#' @return The Survey object (invisibly). If
#' \code{.copy=TRUE}, returns a new clone.
#' @family survey-objects
#' @export
#' @examples
#' dt <- data.table::data.table(id = 1:5, x = rnorm(5), w = rep(1, 5))
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "test",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' new_dt <- data.table::data.table(id = 1:3, x = rnorm(3), w = rep(1, 3))
#' svy <- set_data(svy, new_dt)
set_data <- function(svy, data, .copy = FALSE) {
  if (isTRUE(.copy)) {
    svy <- svy$clone(deep = TRUE)
  }
  svy$set_data(data)
  invisible(svy)
}

#' Add a recipe to a Survey
#'
#' Tidy wrapper for \code{svy$add_recipe(recipe)}.
#'
#' @param svy Survey object
#' @param recipe A Recipe object
#' @param bake Logical; whether to bake immediately (default: lazy_default())
#' @return The Survey object (invisibly), modified in place
#' @family recipes
#' @export
#' @examples
#' svy <- survey_empty(type = "ech", edition = "2023")
#' r <- recipe(
#'   name = "Example", user = "test",
#'   svy = svy, description = "Example"
#' )
#' svy <- add_recipe(svy, r)
add_recipe <- function(svy, recipe, bake = lazy_default()) {
  svy$add_recipe(recipe, bake = bake)
  invisible(svy)
}
