#' Step Class
#' Represents a step in a survey workflow.
#' @description The `Step` class is used to define and manage
#' individual steps in a survey workflow. Each step can
#' include operations such as recoding variables, computing
#' new variables, or validating dependencies.
#' @field name The name of the step.
#' @field edition The edition of the survey associated with the step.
#' @field survey_type The type of survey associated with the step.
#' @field type The type of operation performed by the step
#'   (e.g., "compute", "recode").
#' @field new_var The name of the new variable created by
#'   the step, if applicable.
#' @field exprs A list of expressions defining the step's
#'   operations.
#' @field call The function call associated with the step.
#' @field svy_before Deprecated. Always NULL to prevent memory
#'   retention chains. Kept for backwards compatibility.
#' @field default_engine The default engine used for
#'   processing the step.
#' @field depends_on A list of variables that the step
#'   depends on.
#' @field comment Comments or notes about the step.
#' @field bake A logical value indicating whether the step
#'   has been executed.
#' @details The `Step` class is part of the survey workflow
#' system and is designed to encapsulate all the information
#' and operations required for a single step in the
#' workflow. Steps can be chained together to form a
#' complete workflow.
#' @keywords internal
#' @param name The name of the step.
#' @param edition The edition of the survey associated with the step.
#' @param survey_type The type of survey associated with the step.
#' @param type The type of operation performed by the step
#'   (e.g., "compute", "recode").
#' @param new_var The name of the new variable created by
#'   the step, if applicable.
#' @param exprs A list of expressions defining the step's
#'   operations.
#' @param call The function call associated with the step.
#' @param svy_before Deprecated. Ignored (always set to NULL)
#'   to prevent memory retention chains.
#' @param default_engine The default engine used for
#'   processing the step.
#' @param depends_on A list of variables that the step
#'   depends on.
#' @param comment Comments or notes about the step.
#' @param comments `r lifecycle::badge("deprecated")` Use `comment` instead.
#' @param bake A logical value indicating whether the step
#'   has been executed.
#' @param by_vars Character vector of grouping variables for
#'   grouped computations, or NULL.
Step <- R6Class("Step",
  public = list(
    name = NULL,
    edition = NULL,
    survey_type = NULL,
    type = NULL,
    new_var = NULL,
    exprs = NULL,
    call = NULL,
    svy_before = NULL,
    default_engine = NULL,
    depends_on = list(),
    comment = NULL,
    bake = NULL,
    #' @field by_vars Character vector of grouping variables or NULL.
    by_vars = NULL,
    #' @description Create a new Step object
    #' @param name The name of the step.
    #' @param edition The edition of the survey associated with the step.
    #' @param survey_type The type of survey associated with the step.
    #' @param type The type of operation performed by the
    #'   step (e.g., "compute" or "recode").
    #' @param new_var The name of the new variable created
    #'   by the step, if applicable.
    #' @param exprs A list of expressions defining the
    #'   step's operations.
    #' @param call The function call associated with the
    #'   step.
    #' @param svy_before Deprecated. Ignored (always set to
    #'   NULL) to prevent memory retention chains.
    #' @param default_engine The default engine used for
    #'   processing the step.
    #' @param depends_on A list of variables that the step
    #'   depends on.
    #' @param comment Comments or notes about the step.
    #' @param comments `r lifecycle::badge("deprecated")` Use `comment` instead.
    #' @param bake A logical value indicating whether the
    #'   step has been executed.

    initialize = function(name, edition, survey_type,
                          type, new_var, exprs, call,
                          svy_before, default_engine,
                          depends_on, comment = NULL,
                          bake = !lazy_default(),
                          comments = NULL,
                          by_vars = NULL) {
      self$name <- name
      self$edition <- edition
      self$survey_type <- survey_type
      self$type <- type
      self$new_var <- new_var
      self$exprs <- exprs
      self$call <- call
      self$svy_before <- NULL
      self$default_engine <- default_engine
      self$depends_on <- depends_on
      self$comment <- comment %||% comments
      self$bake <- bake
      self$by_vars <- by_vars
    }
  )
)

#' Validate step
#' @param svy A Survey object
#' @param step A Step object
#' @keywords survey
#' @keywords step
#' @keywords Validate
#' @noRd
#' @keywords internal

validate_step <- function(svy, step) {
  names_svy <- names(svy$data)
  depends_on <- step$depends_on


  missing_vars <- depends_on[!depends_on %in% names_svy]

  if (length(missing_vars) > 0) {
    stop(
      paste0(
        "The following variables are not in the survey: ",
        paste(missing_vars, collapse = ", ")
      ),
      call. = FALSE
    )
  } else {
    return(TRUE)
  }
}


#' Bake step
#' @param svy A Survey object
#' @param step A Step object
#' @return A Survey object
#' @keywords survey
#' @keywords step
#' @keywords Bake
#' @keywords Survey
#' @noRd
#' @keywords internal

bake_step <- function(svy, step, .copy = use_copy_default()) {
  if (step$bake) {
    return(svy)
  }

  validate_step(svy, step)

  args <- list()
  args$svy <- svy
  args$lazy <- FALSE
  args$.copy <- .copy

  is_list_call <- is.call(step$exprs) &&
    identical(step$exprs[[1]], as.name("list"))
  if (is_list_call) {
    args <- c(args, as.list(step$exprs)[-1])
  } else if (is.list(step$exprs)) {
    args <- c(args, step$exprs)
  }

  if (step$type == "recode") {
    args$new_var <- step$new_var
  }

  valid_types <- c(
    "compute", "recode", "step_join",
    "step_remove", "step_rename", "validate", "filter"
  )
  if (!step$type %in% valid_types) {
    stop("Invalid step type: '", step$type, "'. Must be one of: ",
      paste(valid_types, collapse = ", "),
      call. = FALSE
    )
  }

  if (step$type == "validate") {
    bake_validate(svy, step)
    return(svy)
  }

  if (step$type == "filter") {
    filter_args <- list(svy = svy, lazy = FALSE, .copy = .copy)
    is_filter_list_call <- is.call(step$exprs) &&
      identical(step$exprs[[1]], as.name("list"))
    if (is_filter_list_call) {
      filter_args <- c(filter_args, as.list(step$exprs)[-1])
    } else if (is.list(step$exprs)) {
      filter_args <- c(filter_args, step$exprs)
    }
    updated_svy <- do.call(filter_rows, filter_args)
    return(updated_svy)
  }

  if (step$type %in% c("step_join", "step_remove", "step_rename")) {
    args$record <- FALSE
  }

  if (!is.null(step$by_vars) && step$type == "compute") {
    args$.by <- step$by_vars
  }

  updated_svy <- do.call(step$type, args)

  return(updated_svy)
}

#' Execute validation checks from a validate step
#' @param svy A Survey object
#' @param step A Step object with type "validate"
#' @noRd
#' @keywords internal
bake_validate <- function(svy, step) {
  .data <- get_data(svy)
  checks <- step$exprs$checks
  action <- step$exprs$.action %||% "stop"
  min_n <- step$exprs$.min_n

  # Check minimum number of rows
  if (!is.null(min_n)) {
    if (nrow(.data) < min_n) {
      msg <- sprintf(
        "Validation failed [min_n]: expected at least %d rows, got %d",
        min_n, nrow(.data)
      )
      if (action == "warn") {
        warning(msg, call. = FALSE)
      } else {
        stop(msg, call. = FALSE)
      }
    }
  }

  # Evaluate each row-level check
  check_names <- names(checks)
  for (i in seq_along(checks)) {
    result <- eval(checks[[i]], .data, baseenv())
    if (!is.logical(result)) {
      stop(sprintf(
        "Validation check '%s' did not return a logical vector",
        deparse1(checks[[i]])
      ), call. = FALSE)
    }
    n_fail <- sum(!result, na.rm = TRUE)
    # NA counts as failure
    n_na <- sum(is.na(result))
    n_fail <- n_fail + n_na

    if (n_fail > 0) {
      label <- if (!is.null(check_names) && nzchar(check_names[[i]])) {
        check_names[[i]]
      } else {
        deparse1(checks[[i]])
      }
      msg <- sprintf(
        "Validation failed [%s]: %d row%s did not pass",
        label, n_fail, if (n_fail == 1) "" else "s"
      )
      if (action == "warn") {
        warning(msg, call. = FALSE)
      } else {
        stop(msg, call. = FALSE)
      }
    }
  }

  invisible(NULL)
}

#' Execute all pending steps
#'
#' Iterates over all pending (lazy) steps attached to a Survey or
#' RotativePanelSurvey and executes them sequentially, mutating
#' the underlying data.table. Each step is validated before execution
#' (checks that required variables exist).
#'
#' @param svy A `Survey` or `RotativePanelSurvey` object with pending steps
#'
#' @return The same object with all steps materialized in the data
#'   and each step marked as `bake = TRUE`.
#'
#' @details
#' Steps are executed in the order they were added. Each step's expressions
#' can reference variables created by previous steps.
#'
#' For RotativePanelSurvey objects, steps are applied to both the
#' implantation and all follow-up surveys.
#'
#' @examples
#' dt <- data.table::data.table(id = 1:5, age = c(15, 30, 45, 50, 70), w = 1)
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "test",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' svy <- step_compute(svy, age2 = age * 2)
#' svy <- bake_steps(svy)
#' get_data(svy)
#' @family steps
#' @export
bake_steps <- function(svy) {
  if (is(svy, "Survey")) {
    return(bake_steps_survey(svy))
  }

  if (is(svy, "RotativePanelSurvey")) {
    return(bake_steps_rotative(svy))
  }

  stop("The object is not a Survey or RotativePanelSurvey object", call. = FALSE)
}

#' Bake steps survey rotative
#' @param svy A Survey object
#' @return A Survey object
#' @keywords survey
#' @keywords step
#' @keywords Bake
#' @keywords Survey
#' @noRd
#' @keywords internal


bake_steps_rotative <- function(svy) {
  if (use_copy_default()) {
    svy_copy <- svy$clone(deep = FALSE)
    svy_copy$implantation <- bake_steps_survey(svy$implantation)
    svy_copy$follow_up <- lapply(svy$follow_up, bake_steps_survey)
    return(svy_copy)
  } else {
    svy$implantation <- bake_steps_survey(svy$implantation)
    for (i in seq_along(svy$follow_up)) {
      svy$follow_up[[i]] <- bake_steps_survey(svy$follow_up[[i]])
    }
    return(svy)
  }
}

#' Bake steps survey
#' @param svy A Survey object
#' @return A Survey object
#' @keywords survey
#' @keywords step
#' @keywords Bake
#' @keywords Survey
#' @noRd
#' @keywords internal

bake_steps_survey <- function(svy) {
  if (use_copy_default()) {
    svy_copy <- svy$shallow_clone()
    svy_copy$steps <- lapply(svy$steps, function(s) s$clone())
    # Ensure provenance exists (backward compat)
    if (is.null(svy_copy$provenance)) {
      svy_copy$provenance <- structure(
        list(source = list(), steps = list(), environment = list()),
        class = "metasurvey_provenance"
      )
    }
    for (i in seq_along(svy_copy$steps)) {
      n_before <- nrow(get_data(svy_copy))
      t_start <- proc.time()[["elapsed"]]
      svy_copy <- bake_step(svy_copy, svy_copy$steps[[i]],
        .copy = FALSE
      )
      svy_copy$steps[[i]]$bake <- TRUE
      t_end <- proc.time()[["elapsed"]]
      svy_copy$provenance$steps[[length(svy_copy$provenance$steps) + 1]] <-
        list(
          type = svy_copy$steps[[i]]$type,
          name = svy_copy$steps[[i]]$name,
          expression = deparse1(svy_copy$steps[[i]]$exprs),
          n_before = n_before,
          n_after = nrow(get_data(svy_copy)),
          timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
          duration_ms = round((t_end - t_start) * 1000, 2)
        )
    }
    svy_copy$update_design()
    return(svy_copy)
  } else {
    # Ensure provenance exists (backward compat)
    if (is.null(svy$provenance)) {
      svy$provenance <- structure(
        list(source = list(), steps = list(), environment = list()),
        class = "metasurvey_provenance"
      )
    }
    for (i in seq_along(svy$steps)) {
      n_before <- nrow(get_data(svy))
      t_start <- proc.time()[["elapsed"]]
      bake_step(svy, svy$steps[[i]], .copy = FALSE)
      svy$steps[[i]]$bake <- TRUE
      t_end <- proc.time()[["elapsed"]]
      svy$provenance$steps[[length(svy$provenance$steps) + 1]] <-
        list(
          type = svy$steps[[i]]$type,
          name = svy$steps[[i]]$name,
          expression = deparse1(svy$steps[[i]]$exprs),
          n_before = n_before,
          n_after = nrow(get_data(svy)),
          timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
          duration_ms = round((t_end - t_start) * 1000, 2)
        )
    }
    svy$update_design()
    return(svy)
  }
}
