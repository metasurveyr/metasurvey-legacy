#' @importFrom data.table copy
#' @importFrom methods is
NULL

compute <- function(svy, ..., .by = NULL,
                    .copy = use_copy_default(),
                    lazy = lazy_default()) {
  .dots <- substitute(...)


  if (!lazy) {
    if (!.copy) {
      .data <- get_data(svy)
    } else {
      .clone <- svy$shallow_clone()
      .data <- get_data(.clone)
    }

    is_simple_type <- !is(.dots, "call") && !is(.dots, "name") &&
      !is(.dots, "numeric") && !is(.dots, "logical")
    if (is_simple_type) {
      .exprs <- list()
      for (i in seq.int(2L, length(.dots))) {
        .exprs <- c(.exprs, .dots[[i]])
      }
    } else {
      .exprs <- substitute(list(...))
    }

    if (!is.null(.by)) {
      .agg <- .data[, j, by = .by, env = list(j = .exprs)]

      # Remove existing target columns before merge to avoid .x/.y suffixes
      agg_cols <- setdiff(names(.agg), .by)
      existing <- intersect(agg_cols, names(.data))
      if (length(existing) > 0) {
        .data[, (existing) := NULL]
      }

      .data <- merge(.data, .agg, by = .by, all.x = TRUE)
    } else {
      .exprs <- eval(.exprs, .data)
      .data[
        ,
        (names(.exprs)) := .exprs,
        by = .by
      ]
    }


    if (!.copy) {
      return(set_data(svy, .data))
    } else {
      return(set_data(.clone, .data))
    }
  } else {
    if (!.copy) {
      return(svy)
    } else {
      return(svy$shallow_clone())
    }
  }
}


#' @importFrom data.table copy

recode <- function(svy, new_var, ...,
                   .default = NA_character_,
                   ordered = FALSE,
                   .copy = use_copy_default(),
                   .to_factor = FALSE,
                   lazy = lazy_default()) {
  if (!lazy) {
    if (!.copy) {
      .data <- svy$get_data()
    } else {
      .clone <- svy$shallow_clone()
      .data <- get_data(.clone)
    }

    .exprs <- substitute(list(...))
    .exprs <- eval(.exprs, .data, parent.frame())

    if (!is(.exprs[[1]], "formula")) {
      .exprs <- .exprs[[1]]
    }

    .labels <- c(
      .default,
      unique(
        vapply(
          X = seq_along(.exprs),
          FUN = function(x) {
            .exprs[[x]][[3]]
          },
          FUN.VALUE = character(1)
        )
      )
    )





    if (.to_factor) {
      .data[
        ,
        (new_var) := factor(
          .default,
          levels = .labels,
          ordered = ordered
        )
      ]
    } else {
      .data[
        ,
        (new_var) := .default
      ]
    }

    lapply(
      FUN = function(.expr) {
        .filter <- .exprs[[.expr]][[2]]
        .label <- .exprs[[.expr]][[3]]

        .data[
          eval(
            .filter,
            .data,
            parent.frame()
          ),
          (new_var) := .label
        ]
        invisible(NULL)
      },
      X = seq_along(.exprs)
    )

    if (!.copy) {
      return(set_data(svy, .data))
    } else {
      return(set_data(.clone, .data))
    }
  } else {
    if (!.copy) {
      return(svy)
    } else {
      return(svy$shallow_clone())
    }
  }
}


filter_rows <- function(svy, ..., .by = NULL,
                        .copy = use_copy_default(),
                        lazy = lazy_default()) {
  if (!lazy) {
    if (!.copy) {
      .data <- get_data(svy)
    } else {
      .clone <- svy$shallow_clone()
      .data <- get_data(.clone)
    }

    .conditions <- substitute(list(...))

    # Build combined AND condition from all expressions
    combined <- NULL
    for (i in seq.int(2L, length(.conditions))) {
      cond <- .conditions[[i]]
      if (is.null(combined)) {
        combined <- cond
      } else {
        combined <- substitute(a & b, list(a = combined, b = cond))
      }
    }

    if (!is.null(.by)) {
      .data <- .data[, .SD[eval(combined, .SD)], by = .by]
    } else {
      .data <- .data[eval(combined, .data, parent.frame())]
    }

    if (!.copy) {
      return(set_data(svy, .data))
    } else {
      return(set_data(.clone, .data))
    }
  } else {
    if (!.copy) {
      return(svy)
    } else {
      return(svy$shallow_clone())
    }
  }
}


#' Create computation steps for survey variables
#'
#' This function uses optimized expression evaluation
#' with automatic dependency detection and error
#' prevention. All computations are validated before
#' execution.
#'
#' @param svy A `Survey` or `RotativePanelSurvey` object.
#'   If NULL, creates a step that can be applied later
#'   using the pipe operator (%>%)
#' @param ... Computation expressions with automatic
#'   optimization. Names are assigned using
#'   `new_var = expression`
#' @param .by Vector of variables to group computations
#'   by. The system automatically validates these
#'   variables exist before execution
#' @param .copy Logical indicating whether to create
#'   a copy of the object before applying
#'   transformations. Defaults to `use_copy_default()`
#' @param use_copy `r lifecycle::badge("deprecated")` Use `.copy` instead.
#' @param comment Descriptive text for the step for
#'   documentation and traceability. Compatible with
#'   Markdown syntax. Defaults to "Compute step"
#' @param .level For RotativePanelSurvey objects (default `"auto"`),
#'   specifies the level where computations are
#'   applied: `"implantation"`, `"follow_up"`, `"quarter"`,
#'   `"month"`, or `"auto"`
#'
#' @return Same type of input object (`Survey` or `RotativePanelSurvey`)
#'   with new computed variables and the step added to the history
#'
#' @details
#' **Lazy evaluation (default):** By default, steps are recorded but
#' **not executed** until [bake_steps()] is called. This allows building
#' a full pipeline before materializing any changes. Set
#' `options(metasurvey.lazy_processing = FALSE)` to apply steps immediately.
#'
#' **Expression processing:**
#' Expressions are evaluated using data.table's `:=` operator.
#' Variable dependencies are detected automatically via `all.vars()`.
#' Missing variables are caught before execution.
#'
#' **Grouped computations:** Use `.by` to compute aggregated values
#' (e.g., group means) that are automatically joined back to the data.
#'
#' For RotativePanelSurvey objects, `.level` controls where computations
#' are applied:
#' - `"auto"` (default): applies to both implantation and follow-ups
#' - `"implantation"`: household/dwelling level only
#' - `"follow_up"`: individual/person level only
#'
#' @examples
#' # Basic computation
#' dt <- data.table::data.table(
#'   id = 1:5, age = c(25, 30, 45, 50, 60), w = 1
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "test",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' svy <- svy |> step_compute(age_squared = age^2, comment = "Age squared")
#' svy <- bake_steps(svy)
#' get_data(svy)
#'
#' \donttest{
#' # ECH example: labor indicator
#' # ech <- ech |>
#' #   step_compute(
#' #     unemployed = ifelse(POBPCOAC %in% 3:5, 1, 0),
#' #     comment = "Unemployment indicator")
#' }
#' @seealso
#' \code{\link{step_recode}} for categorical recodings
#' \code{\link{bake_steps}} to execute all pending steps
#'
#' @keywords step
#' @family steps
#' @export

step_compute <- function(
    svy = NULL, ..., .by = NULL,
    .copy = use_copy_default(),
    comment = "Compute step",
    .level = "auto",
    use_copy = deprecated()) {
  if (lifecycle::is_present(use_copy)) {
    lifecycle::deprecate_warn("0.0.12", "step_compute(use_copy)", "step_compute(.copy)")
    .copy <- use_copy
  }
  .call <- match.call()

  # Capture and prepare expressions
  exprs <- as.list(substitute(list(...))[-1])
  expr_names <- names(exprs)

  # Collect dependencies using simple variable detection
  dependencies <- unique(unlist(lapply(exprs, function(expr) {
    all.vars(expr)
  })))

  if (is(svy, "RotativePanelSurvey")) {
    return(step_compute_rotative(svy, ...,
      .by = .by, .copy = .copy,
      comment = comment, .level = .level, .call = .call
    ))
  }

  # Store dependencies
  depends_on <- if (length(dependencies) > 0) dependencies else NULL

  if (.copy) {
    # Direct evaluation with compute function
    # (force lazy=FALSE to execute immediately)
    .svy_after <- compute(
      svy, ...,
      .by = .by,
      .copy = .copy, lazy = FALSE
    )

    .new_vars <- expr_names

    if (length(.new_vars) > 0) {
      step <- Step$new(
        name = paste("Compute:", paste(.new_vars, collapse = ", ")),
        edition = get_edition(.svy_after),
        survey_type = get_type(.svy_after),
        type = "compute",
        new_var = paste(.new_vars, collapse = ", "),
        exprs = substitute(list(...)),
        call = .call,
        svy_before = NULL,
        default_engine = get_engine(),
        depends_on = depends_on,
        comment = comment,
        by_vars = .by
      )

      if (validate_step(svy, step)) {
        .svy_after$add_step(step)
      } else {
        stop(
          sprintf(
            "Step validation failed for compute step creating: %s",
            paste(.new_vars, collapse = ", ")
          ),
          call. = FALSE
        )
      }
      return(.svy_after)
    } else {
      metasurvey_msg("No new variable created: ", substitute(list(...)))
      return(svy)
    }
  } else {
    names_vars <- names(get_data(svy))
    compute(svy, ..., .by = .by, .copy = .copy, lazy = FALSE)
    .new_vars <- names(substitute(list(...)))[-1]
    not_in_data <- !(.new_vars %in% names_vars)
    .new_vars <- .new_vars[not_in_data]

    step <- Step$new(
      name = paste("New variable:", paste(.new_vars, collapse = ", ")),
      edition = get_edition(svy),
      survey_type = get_type(svy),
      type = "compute",
      new_var = paste(.new_vars, collapse = ", "),
      exprs = substitute(list(...)),
      call = .call,
      svy_before = NULL,
      default_engine = get_engine(),
      comment = comment,
      depends_on = depends_on,
      by_vars = .by
    )

    svy$add_step(step)
    invisible(svy)
  }
}

#' Step compute rotative
#' @param svy Survey object
#' @param ... Expressions to compute
#' @param .copy Copy
#' @param .by By
#' @param comment Comment
#' @return Survey object
#' @keywords step
#' @noRd
#' @keywords internal


step_compute_rotative <- function(
    svy, ..., .by = NULL,
    .copy = use_copy_default(),
    comment = "Compute step",
    .level = "auto", .call) {
  follow_up_processed <- svy$follow_up
  implantation_processed <- svy$implantation


  if (.level == "auto" || .level == "follow_up") {
    follow_up_processed <- lapply(svy$follow_up, function(sub_svy) {
      step_compute(
        sub_svy, ...,
        .by = .by,
        .copy = .copy,
        comment = comment
      )
    })
  }

  if (.level == "auto" || .level == "implantation") {
    implantation_processed <- step_compute(
      svy$implantation, ...,
      .by = .by,
      .copy = .copy,
      comment = comment
    )
  }



  if (length(implantation_processed$steps) > 0) {
    steps <- implantation_processed$steps
  } else {
    steps <- follow_up_processed[[1]]$steps
  }




  result <- RotativePanelSurvey$new(
    implantation = implantation_processed,
    follow_up = follow_up_processed,
    type = svy$type,
    default_engine = "data.table",
    steps = NULL,
    recipes = NULL,
    workflows = NULL,
    design = NULL
  )

  result$steps <- steps

  if (.copy) {
    return(result)
  } else {
    svy$implantation <- implantation_processed
    svy$follow_up <- follow_up_processed
    svy$steps <- steps
    return(svy)
  }
}

#' Create recoding steps for categorical variables
#'
#' This function uses optimized expression evaluation
#' for all recoding conditions. All conditional
#' expressions are validated and optimized for
#' efficient execution.
#'
#' @param svy A `Survey` or `RotativePanelSurvey`
#'   object. If NULL, creates a step that can be
#'   applied later using the pipe operator (%>%)
#' @param new_var Name of the new variable to create
#'   (unquoted)
#' @param ... Sequence of two-sided formulas defining
#'   recoding rules. Left-hand side (LHS) is a
#'   conditional expression, right-hand side (RHS)
#'   defines the replacement value.
#'   Format: `condition ~ value`
#' @param .default Default value assigned when no
#'   condition is met. Defaults to `NA_character_`
#' @param .name_step `r lifecycle::badge("deprecated")`
#'   Custom name for the step in the history. Now
#'   auto-generated from the variable name. Use `comment`
#'   for user-facing documentation instead.
#' @param ordered Logical indicating whether the new
#'   variable should be an ordered factor.
#'   Defaults to FALSE
#' @param .copy Logical indicating whether to
#'   create a copy of the object before applying
#'   transformations. Defaults to `use_copy_default()`
#' @param use_copy `r lifecycle::badge("deprecated")` Use `.copy` instead.
#' @param comment Descriptive text for the step for
#'   documentation and traceability. Compatible with
#'   Markdown syntax. Defaults to "Recode step"
#' @param .to_factor Logical indicating whether the
#'   new variable should be converted to a factor.
#'   Defaults to FALSE
#' @param .level For RotativePanelSurvey objects (default `"auto"`),
#'   specifies the level where recoding is applied:
#'   `"implantation"`, `"follow_up"`, `"quarter"`,
#'   `"month"`, or `"auto"`
#'
#' @return Same type of input object (`Survey` or `RotativePanelSurvey`)
#'   with the new recoded variable and the step added to the history
#'
#' @details
#' **Lazy evaluation (default):** By default, steps are recorded but
#' **not executed** until [bake_steps()] is called. This allows building
#' a full pipeline before materializing any changes.
#'
#' **Condition evaluation:** Conditions are two-sided formulas evaluated
#' in order. The first matching condition determines the assigned value.
#' If no condition matches, `.default` is used.
#'
#' Condition examples:
#' - Simple: `variable == 1 ~ "Yes"`
#' - Complex: `age >= 18 & income > 12000 ~ "High"`
#' - Vectorized: `variable %in% c(1,2,3) ~ "Group A"`
#' - Logical: `!is.na(education) ~ "Has education"`
#'
#' @examples
#' # Basic recode: categorize ages
#' dt <- data.table::data.table(
#'   id = 1:6, age = c(10, 25, 45, 60, 70, 80), w = 1
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "test",
#'   psu = NULL, engine = "data.table",
#'   weight = add_weight(annual = "w")
#' )
#' svy <- svy |>
#'   step_recode(
#'     age_group,
#'     age < 18 ~ "Under 18",
#'     age >= 18 & age < 65 ~ "Working age",
#'     age >= 65 ~ "Senior",
#'     .default = "Unknown"
#'   )
#' svy <- bake_steps(svy)
#' get_data(svy)
#'
#' \donttest{
#' # ECH example: labor force status
#' # ech <- ech |>
#' #   step_recode(labor_status,
#' #     POBPCOAC == 2 ~ "Employed",
#' #     POBPCOAC %in% 3:5 ~ "Unemployed",
#' #     .default = "Missing")
#' }
#'
#' @seealso
#' \code{\link{step_compute}} for more complex calculations
#' \code{\link{bake_steps}} to execute all pending steps
#' \code{\link{get_steps}} to view step history
#'
#' @keywords step
#' @family steps
#' @export

step_recode <- function(
    svy,
    new_var, ...,
    .default = NA_character_,
    .name_step = NULL,
    ordered = FALSE,
    .copy = use_copy_default(),
    comment = "Recode step",
    .to_factor = FALSE,
    .level = "auto",
    use_copy = deprecated()) {
  if (lifecycle::is_present(use_copy)) {
    lifecycle::deprecate_warn("0.0.12", "step_recode(use_copy)", "step_recode(.copy)")
    .copy <- use_copy
  }
  .call <- match.call()

  if (is(svy, "RotativePanelSurvey")) {
    return(step_recode_rotative(svy, as.character(substitute(new_var)), ...,
      .default = .default, .name_step = .name_step,
      ordered = ordered, .copy = .copy,
      comment = comment, .to_factor = .to_factor,
      .level = .level, .call = .call
    ))
  }

  if (is(svy, "Survey")) {
    return(step_recode_survey(svy, as.character(substitute(new_var)), ...,
      .default = .default, .name_step = .name_step,
      ordered = ordered, .copy = .copy,
      comment = comment, .to_factor = .to_factor,
      .call = .call
    ))
  }

  # Create standalone step
  standalone_step <- list(
    type = "recode",
    new_var = as.character(substitute(new_var)),
    conditions = substitute(...),
    default = .default,
    name_step = .name_step,
    comment = comment,
    call = .call
  )
  class(standalone_step) <- c("metasurvey_step", "list")

  return(standalone_step)
}

#' Step recode survey
#' @param svy Survey object
#' @param new_var New variable
#' @param ... Expressions to recode
#' @param .default Default value
#' @param .name_step Name of the step
#' @param ordered Ordered
#' @param .copy Copy
#' @param comment Comment
#' @keywords step
#' @noRd
#' @keywords internal

step_recode_survey <- function(
    svy, new_var, ...,
    .default = NA_character_,
    .name_step = NULL,
    ordered = FALSE,
    .copy = use_copy_default(),
    comment = "Recode step",
    .to_factor = FALSE,
    .call = .call) {
  new_var <- as.character(new_var)
  check_svy <- is.null(get_data(svy))
  if (check_svy) {
    return(.call)
  }

  if (is.null(.name_step)) {
    .name_step <- paste0("Recode: ", new_var)
  }

  # Extract dependencies using simple variable detection
  conditions <- list(...)
  dependencies <- character()

  for (i in seq_along(conditions)) {
    condition_formula <- conditions[[i]]
    if (inherits(condition_formula, "formula")) {
      lhs_expr <- condition_formula[[2]]
      # Use all.vars() for fast dependency detection
      deps <- all.vars(lhs_expr)
      dependencies <- unique(c(dependencies, deps))
    }
  }

  depends_on <- if (length(dependencies) > 0) dependencies else NULL

  if (.copy) {
    # Direct recode evaluation (force lazy=FALSE to execute immediately)
    .svy_after <- recode(
      svy = svy, new_var = new_var, ...,
      .default = .default,
      .copy = .copy,
      .to_factor = .to_factor,
      lazy = FALSE
    )

    step <- Step$new(
      name = .name_step,
      edition = get_edition(.svy_after),
      survey_type = get_type(.svy_after),
      type = "recode",
      new_var = new_var,
      exprs = list(...),
      call = .call,
      svy_before = NULL,
      default_engine = get_engine(),
      depends_on = depends_on,
      comment = comment
    )
    .svy_after$add_step(step)
    return(.svy_after)
  } else {
    recode(
      svy = svy, new_var = new_var, ...,
      .default = .default,
      .copy = .copy,
      .to_factor = .to_factor,
      lazy = FALSE
    )
    step <- Step$new(
      name = .name_step,
      edition = get_edition(svy),
      survey_type = get_type(svy),
      type = "recode",
      new_var = new_var,
      exprs = list(...),
      call = .call,
      svy_before = NULL,
      default_engine = get_engine(),
      depends_on = depends_on,
      comment = comment
    )
    svy$add_step(step)
    invisible(svy)
  }
}

#' Step recode rotative
#' @param svy Survey object
#' @param new_var New variable
#' @param ... Expressions to recode
#' @param .default Default value
#' @param .name_step Name of the step
#' @param ordered Ordered
#' @param .copy Copy
#' @param comment Comment
#' @param .to_factor To factor
#' @return Survey object
#' @keywords step
#' @noRd
#' @keywords internal

step_recode_rotative <- function(
    svy, new_var, ...,
    .default = NA_character_,
    .name_step = NULL,
    ordered = FALSE,
    .copy = use_copy_default(),
    comment = "Recode step",
    .to_factor = FALSE,
    .level = "auto", .call) {
  follow_up_processed <- svy$follow_up
  implantation_processed <- svy$implantation

  if (.level == "auto" || .level == "follow_up") {
    follow_up_processed <- lapply(svy$follow_up, function(sub_svy) {
      step_recode_survey(
        sub_svy, new_var, ...,
        .default = .default,
        .name_step = .name_step,
        ordered = ordered,
        .copy = .copy,
        comment = comment,
        .to_factor = .to_factor,
        .call = .call
      )
    })
  }

  if (.level == "auto" || .level == "implantation") {
    implantation_processed <- step_recode_survey(
      svy$implantation, new_var, ...,
      .default = .default,
      .name_step = .name_step,
      ordered = ordered,
      .copy = .copy,
      comment = comment,
      .to_factor = .to_factor,
      .call = .call
    )
  }

  result <- RotativePanelSurvey$new(
    implantation = implantation_processed,
    follow_up = follow_up_processed,
    type = svy$type,
    default_engine = "data.table",
    steps = NULL,
    recipes = NULL,
    workflows = NULL,
    design = NULL
  )

  if (.copy) {
    return(result)
  } else {
    svy$implantation <- implantation_processed
    svy$follow_up <- follow_up_processed
    return(svy)
  }
}


#' Get formulas
#' @param steps List of steps
#' @return List of formulas
#' @noRd

get_formulas <- function(steps) {
  if (length(steps) > 0) {
    vapply(
      X = seq_along(steps),
      FUN = function(x) {
        step <- steps[[x]]
        exprs <- step$exprs
        if (step$type == "recode") {
          paste0(
            step$new_var,
            ": ",
            paste(
              deparse1(
                step$exprs
              ),
              collapse = "\n"
            )
          )
        } else {
          deparse1(exprs)
        }
      },
      FUN.VALUE = character(1)
    )
  } else {
    NULL
  }
}

#' Get comments
#' @param steps List of steps
#' @return List of comments
#' @noRd

get_comments <- function(steps) {
  if (length(steps) > 0) {
    vapply(
      X = seq_along(steps),
      FUN = function(x) {
        step <- steps[[x]]
        step$comment
      },
      FUN.VALUE = character(1)
    )
  } else {
    NULL
  }
}

#' Join external data into survey (step)
#'
#' Creates a step that joins additional data into a
#' Survey or RotativePanelSurvey.
#'
#' @details
#' **Lazy evaluation (default):** By default, steps are recorded but
#' **not executed** until [bake_steps()] is called.
#'
#' Supports left, inner, right, and full joins. Allows named `by`
#' mapping (e.g., `c("id" = "code")`) or a simple character vector.
#' Conflicting column names are resolved by appending `suffixes`
#' to the right-hand side columns.
#'
#' @param svy A Survey or RotativePanelSurvey object.
#'   If NULL, returns a step call
#' @param x A data.frame/data.table or a Survey to join into `svy`
#' @param by Character vector of join keys. Named vector for different names
#'   between `svy` and `x` (names are keys in `svy`,
#'   values are keys in `x`).
#'   If NULL, tries to infer common column names
#' @param type Join type: "left" (default), "inner", "right", or "full"
#' @param suffixes Length-2 character vector of suffixes
#'   for conflicting columns
#'   from `svy` and `x` respectively. Defaults to c("", ".y")
#' @param .copy Whether to operate on a copy (default: use_copy_default())
#' @param use_copy `r lifecycle::badge("deprecated")` Use `.copy` instead.
#' @param comment Optional description for the step (default `"Join step"`).
#' @param lazy Internal. Whether to delay execution (default `lazy_default()`).
#' @param record Internal. Whether to record the step (default `TRUE`).
#'
#' @return Modified survey object with the join
#'   recorded as a step (and applied immediately
#'   when baked). For RotativePanelSurvey, the join is applied to
#'   implantation and every follow_up survey.
#'
#' @examples
#' # With data.frame
#' s <- Survey$new(
#'   data = data.table::data.table(id = 1:3, w = 1, a = c("x", "y", "z")),
#'   edition = "2023", type = "ech", psu = NULL, engine = "data.table",
#'   weight = add_weight(annual = "w")
#' )
#' info <- data.frame(id = c(1, 2), b = c(10, 20))
#' s2 <- step_join(s, info, by = "id", type = "left")
#' s2 <- bake_steps(s2)
#'
#' # With another Survey
#' s_right <- Survey$new(
#'   data = data.table::data.table(id = c(2, 3), b = c(200, 300), w2 = 1),
#'   edition = "2023", type = "ech", psu = NULL, engine = "data.table",
#'   weight = add_weight(annual = "w2")
#' )
#' s3 <- step_join(s, s_right, by = c("id" = "id"), type = "inner")
#' s3 <- bake_steps(s3)
#'
#' @keywords step
#' @family steps
#' @export
step_join <- function(
    svy,
    x,
    by = NULL,
    type = c("left", "inner", "right", "full"),
    suffixes = c("", ".y"),
    .copy = use_copy_default(),
    comment = "Join step",
    use_copy = deprecated(),
    lazy = lazy_default(),
    record = TRUE) {
  if (lifecycle::is_present(use_copy)) {
    lifecycle::deprecate_warn("0.0.12", "step_join(use_copy)", "step_join(.copy)")
    .copy <- use_copy
  }
  .call <- match.call()
  type <- match.arg(type)

  # Normalize RHS data source
  rhs_data <- if (methods::is(x, "Survey")) get_data(x) else x
  if (!is.data.frame(rhs_data)) {
    stop("x must be a data.frame/data.table or a Survey", call. = FALSE)
  }

  # RotativePanelSurvey: apply to implantation and each follow_up
  if (methods::is(svy, "RotativePanelSurvey")) {
    svy$implantation <- step_join(
      svy = svy$implantation, x = x, by = by, type = type,
      suffixes = suffixes, .copy = .copy, comment = comment
    )
    svy$follow_up <- lapply(
      svy$follow_up,
      function(fu) {
        step_join(
          fu,
          x = x, by = by,
          type = type,
          suffixes = suffixes,
          .copy = .copy,
          comment = comment
        )
      }
    )
    return(svy)
  }

  # If no data yet, return the call (pipeline build)
  if (is.null(get_data(svy))) {
    return(.call)
  }

  lhs_data <- get_data(svy)

  # Derive by mapping
  if (is.null(by)) {
    common <- intersect(names(lhs_data), names(rhs_data))
    if (length(common) == 0) {
      stop("Cannot infer join keys: no common columns", call. = FALSE)
    }
    by.x <- by.y <- common
  } else {
    if (is.null(names(by))) {
      by.x <- by
      by.y <- by
    } else {
      by.x <- names(by)
      by.y <- unname(by)
    }
  }

  # Check keys exist
  miss_x <- setdiff(by.x, names(lhs_data))
  miss_y <- setdiff(by.y, names(rhs_data))
  if (length(miss_x) > 0) {
    stop(sprintf(
      "Join keys not found in survey: %s",
      paste(miss_x, collapse = ", ")
    ), call. = FALSE)
  }
  if (length(miss_y) > 0) {
    stop(sprintf(
      "Join keys not found in x: %s",
      paste(miss_y, collapse = ", ")
    ), call. = FALSE)
  }

  # Prepare RHS: resolve name conflicts (excluding join keys)
  overlap <- intersect(
    setdiff(names(lhs_data), by.x),
    setdiff(names(rhs_data), by.y)
  )
  if (length(overlap) > 0 && (suffixes[2] %in% c("", NA))) {
    suffixes[2] <- ".y"
  }
  if (length(overlap) > 0) {
    new_rhs_names <- names(rhs_data)
    idx <- match(overlap, names(rhs_data))
    # only rename true overlaps not part of by.y
    for (nm in overlap) {
      if (!nm %in% by.y) {
        new_rhs_names[names(rhs_data) == nm] <- paste0(nm, suffixes[2])
      }
    }
    names(rhs_data) <- new_rhs_names
  }

  # Compute merge flags
  all.x <- (type %in% c("left", "full"))
  all.y <- (type %in% c("right", "full"))

  # Perform merge using data.table merge
  merged <- merge(
    data.table::as.data.table(lhs_data),
    data.table::as.data.table(rhs_data),
    by.x = by.x,
    by.y = by.y,
    all.x = all.x,
    all.y = all.y,
    sort = FALSE
  )

  # Fill NA weights introduced by full/right joins
  # Get weight column names from the survey
  if (!is.null(svy$weight) && length(svy$weight) > 0) {
    weight_cols <- character(0)
    for (w in svy$weight) {
      if (is.character(w)) {
        weight_cols <- c(weight_cols, w)
      } else if (is.list(w) && !is.null(w$weight)) {
        weight_cols <- c(weight_cols, w$weight)
      }
    }
    # Fill NA values in weight columns with 1
    for (wcol in weight_cols) {
      if (wcol %in% names(merged)) {
        set_na_idx <- which(is.na(merged[[wcol]]))
        if (length(set_na_idx) > 0) {
          data.table::set(merged, i = set_na_idx, j = wcol, value = 1)
        }
      }
    }
  }

  # Assign data to copy or in-place
  if (.copy) {
    out <- svy$shallow_clone()
    out$set_data(merged)
  } else {
    svy$set_data(merged)
    out <- svy
  }

  # Build depends_on from join keys
  if (isTRUE(record)) {
    depends_on <- unique(by.x)
    step <- Step$new(
      name = paste0("Join (", type, "): ", paste(by.x, collapse = ", ")),
      edition = get_edition(out),
      survey_type = get_type(out),
      type = "step_join",
      new_var = NULL,
      exprs = list(x = x, by = by, type = type, suffixes = suffixes),
      call = .call,
      svy_before = NULL,
      default_engine = get_engine(),
      depends_on = depends_on,
      comment = comment,
      bake = FALSE
    )
    out$add_step(step)
  }
  invisible(out)
}

#' Remove variables from survey data (step)
#'
#' Creates a step that removes one or more variables
#' from the survey data when baked.
#'
#' @param svy A Survey or RotativePanelSurvey object
#' @param ... Unquoted variable names to remove, or a character vector
#' @param vars Character vector of variable names to remove.
#'   Alternative to `...` for programmatic use.
#' @param .copy Whether to operate on a copy (default: `use_copy_default()`)
#' @param comment Descriptive text for the step for
#'   documentation and traceability (default `"Remove variables"`).
#' @param use_copy `r lifecycle::badge("deprecated")` Use `.copy` instead.
#' @param lazy Internal. Whether to delay execution (default `lazy_default()`).
#' @param record Internal. Whether to record the step (default `TRUE`).
#' @return Survey object with the specified variables
#'   removed (or queued for removal).
#'
#' @details
#' **Lazy evaluation (default):** By default, steps are recorded but
#' **not executed** until [bake_steps()] is called.
#'
#' Variables can be specified in two ways:
#' - **Unquoted names:** `step_remove(svy, age, income)`
#' - **Character vector:** `step_remove(svy, vars = c("age", "income"))`
#'
#' Variables that don't exist in the data produce a warning
#' (not an error), allowing pipelines to be robust to missing columns.
#' @examples
#' dt <- data.table::data.table(
#'   id = 1:5, age = c(25, 30, 45, 50, 60),
#'   w = rep(1, 5)
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "ech",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' svy2 <- step_remove(svy, age)
#' svy2 <- bake_steps(svy2)
#' "age" %in% names(get_data(svy2)) # FALSE
#' @family steps
#' @export
step_remove <- function(
    svy, ...,
    vars = NULL,
    .copy = use_copy_default(),
    comment = "Remove variables",
    use_copy = deprecated(),
    lazy = lazy_default(),
    record = TRUE) {
  if (lifecycle::is_present(use_copy)) {
    lifecycle::deprecate_warn("0.0.12", "step_remove(use_copy)", "step_remove(.copy)")
    .copy <- use_copy
  }
  .call <- match.call()
  var_names <- NULL
  # Prefer explicit vars argument when provided
  if (!is.null(vars)) {
    if (is.character(vars)) {
      var_names <- vars
    } else {
      stop("'vars' must be a character vector of variable names", call. = FALSE)
    }
  } else {
    dots_list <- as.list(substitute(list(...)))[-1]
    # Allow character vector passed via ...
    if (length(dots_list) == 1) {
      evald <- try(
        eval(dots_list[[1]], parent.frame()),
        silent = TRUE
      )
      if (!inherits(evald, "try-error") && is.character(evald)) {
        var_names <- as.character(evald)
      }
    }
    if (is.null(var_names)) {
      var_names <- vapply(dots_list, deparse1, character(1))
    }
  }

  if (is(svy, "RotativePanelSurvey")) {
    svy$implantation <- step_remove(
      svy$implantation,
      vars = var_names,
      .copy = .copy,
      comment = comment,
      record = record,
      lazy = lazy
    )
    svy$follow_up <- lapply(
      svy$follow_up,
      function(x) {
        step_remove(
          x,
          vars = var_names,
          .copy = .copy,
          comment = comment,
          record = record,
          lazy = lazy
        )
      }
    )
    return(svy)
  }

  if (is.null(get_data(svy))) {
    return(.call)
  }

  out <- if (.copy) svy$shallow_clone() else svy

  data <- get_data(svy) # Check against original data
  missing <- setdiff(var_names, names(data))
  if (length(missing) > 0) {
    warning(sprintf(
      "Variables not found and cannot be removed: %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }

  # Apply change only if not lazy
  if (!lazy) {
    cols_to_remove <- intersect(var_names, names(out$data))
    if (length(cols_to_remove) > 0) {
      if (data.table::is.data.table(out$data)) {
        data.table::set(out$data, j = cols_to_remove, value = NULL)
      } else {
        out$data <- out$data[,
          !names(out$data) %in% cols_to_remove,
          drop = FALSE
        ]
      }
    }
  }

  if (isTRUE(record)) {
    step <- Step$new(
      name = paste0("Remove: ", paste(var_names, collapse = ", ")),
      edition = get_edition(out),
      survey_type = get_type(out),
      type = "step_remove",
      new_var = NULL,
      exprs = list(vars = var_names),
      call = .call,
      svy_before = NULL,
      default_engine = get_engine(),
      depends_on = NULL,
      comment = comment,
      bake = FALSE
    )
    out$add_step(step)
  }
  invisible(out)
}

#' Rename variables in survey data (step)
#'
#' Creates a step that renames variables in the survey data when baked.
#'
#' @param svy A Survey or RotativePanelSurvey object
#' @param ... Pairs in the form `new_name = old_name` (unquoted).
#' @param mapping A named character vector of the form
#'   `c(new_name = "old_name")`. Alternative to `...` for
#'   programmatic use.
#' @param .copy Whether to operate on a copy (default: `use_copy_default()`)
#' @param comment Descriptive text for the step for
#'   documentation and traceability (default `"Rename variables"`).
#' @param use_copy `r lifecycle::badge("deprecated")` Use `.copy` instead.
#' @param lazy Internal. Whether to delay execution (default `lazy_default()`).
#' @param record Internal. Whether to record the step (default `TRUE`).
#' @return Survey object with the specified variables
#'   renamed (or queued for renaming).
#'
#' @details
#' **Lazy evaluation (default):** By default, steps are recorded but
#' **not executed** until [bake_steps()] is called.
#'
#' Variables can be renamed in two ways:
#' - **Unquoted pairs:** `step_rename(svy, new_name = old_name)`
#' - **Named character vector:** `step_rename(svy, mapping = c(new_name = "old_name"))`
#'
#' Variables that don't exist in the data cause an error, unlike
#' [step_remove()] which issues a warning.
#' @examples
#' dt <- data.table::data.table(
#'   id = 1:5, age = c(25, 30, 45, 50, 60),
#'   w = rep(1, 5)
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "ech",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#' svy2 <- step_rename(svy, edad = age)
#' svy2 <- bake_steps(svy2)
#' "edad" %in% names(get_data(svy2)) # TRUE
#' @family steps
#' @export
step_rename <- function(
    svy, ...,
    mapping = NULL,
    .copy = use_copy_default(),
    comment = "Rename variables",
    use_copy = deprecated(),
    lazy = lazy_default(),
    record = TRUE) {
  if (lifecycle::is_present(use_copy)) {
    lifecycle::deprecate_warn("0.0.12", "step_rename(use_copy)", "step_rename(.copy)")
    .copy <- use_copy
  }
  .call <- match.call()
  # Build mapping new -> old
  if (!is.null(mapping)) {
    if (is.null(names(mapping)) || !is.character(mapping)) {
      stop("'mapping' must be a named character vector: new_name = old_name",
        call. = FALSE
      )
    }
    map <- mapping
  } else {
    pairs <- as.list(substitute(list(...)))[-1]
    if (length(pairs) == 0) {
      return(svy)
    }
    new_names <- names(pairs)
    old_names <- vapply(
      pairs,
      function(x) {
        if (is.symbol(x)) {
          deparse1(x)
        } else {
          as.character(x)
        }
      },
      character(1)
    )
    map <- stats::setNames(old_names, new_names)
  }

  if (is(svy, "RotativePanelSurvey")) {
    # Propagate as explicit mapping to avoid ambiguity
    svy$implantation <- step_rename(
      svy = svy$implantation,
      mapping = map,
      .copy = .copy,
      comment = comment,
      lazy = lazy,
      record = record
    )
    svy$follow_up <- lapply(
      svy$follow_up,
      function(x) {
        step_rename(
          svy = x,
          mapping = map,
          .copy = .copy,
          comment = comment,
          lazy = lazy,
          record = record
        )
      }
    )
    return(svy)
  }

  if (is.null(get_data(svy))) {
    return(.call)
  }

  out <- if (.copy) svy$shallow_clone() else svy

  data <- get_data(svy) # Check against original data
  missing <- setdiff(unname(map), names(data))
  if (length(missing) > 0) {
    stop(sprintf(
      "Variables to rename not found: %s",
      paste(missing, collapse = ", ")
    ), call. = FALSE)
  }

  # Apply change only if not lazy
  if (!lazy) {
    data.table::setnames(out$data, old = unname(map), new = names(map))
  }

  if (isTRUE(record)) {
    step <- Step$new(
      name = paste0(
        "Rename: ",
        paste(
          sprintf("%s=%s", names(map), unname(map)),
          collapse = ", "
        )
      ),
      edition = get_edition(out),
      survey_type = get_type(out),
      type = "step_rename",
      new_var = NULL,
      exprs = list(mapping = map),
      call = .call,
      svy_before = NULL,
      default_engine = get_engine(),
      depends_on = NULL,
      comment = comment,
      bake = FALSE
    )
    out$add_step(step)
  }
  invisible(out)
}

#' Get type of step
#' @param steps List of steps
#' @return List of types
#' @noRd

get_type_step <- function(steps) {
  if (length(steps) > 0) {
    vapply(
      X = seq_along(steps),
      FUN = function(x) {
        step <- steps[[x]]
        step$type
      },
      FUN.VALUE = character(1)
    )
  } else {
    NULL
  }
}

#' Validate data during the step pipeline
#'
#' Creates a non-mutating step that checks data invariants when
#' \code{\link{bake_steps}} is called. Each check is a logical expression
#' evaluated row-wise against the survey data. If any row fails a check,
#' the pipeline stops (or warns).
#'
#' @param svy A Survey or RotativePanelSurvey object
#' @param ... Logical expressions evaluated against the data. Each must
#'   return a logical vector with one value per row. Named expressions
#'   use the name in error messages; unnamed expressions use the deparsed
#'   code. Examples: \code{income > 0}, \code{!is.na(age)},
#'   \code{sex \%in\% c(1, 2)}.
#' @param .action What to do when a check fails: \code{"stop"} (default)
#'   raises an error, \code{"warn"} issues a warning and continues.
#' @param .min_n Minimum number of rows required. Checked before
#'   row-level expressions.
#' @param .copy Whether to operate on a copy (default:
#'   \code{use_copy_default()})
#' @param comment Descriptive text for the step for documentation
#'   and traceability (default `"Validate step"`).
#' @return The survey object with a validate step recorded (no data
#'   mutation).
#'
#' @details
#' **Lazy evaluation (default):** Like all steps, validation checks are
#' recorded but **not executed** until \code{\link{bake_steps}} is called.
#' This means \code{step_validate} can reference variables created by
#' preceding \code{\link{step_compute}} calls.
#'
#' The validate step does **not** modify the data in any way. It only
#' inspects the current state of the data.table and raises an error
#' or warning if any check fails.
#'
#' @examples
#' dt <- data.table::data.table(
#'   id = 1:5, age = c(25, 30, 45, 50, 60),
#'   income = c(1000, 2000, 3000, 4000, 5000), w = 1
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "test",
#'   psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
#' )
#'
#' # Validate that all ages are positive and income is not NA
#' svy <- svy |>
#'   step_validate(age > 0, !is.na(income), .min_n = 3) |>
#'   bake_steps()
#'
#' @family steps
#' @export
step_validate <- function(
    svy, ...,
    .action = c("stop", "warn"),
    .min_n = NULL,
    .copy = use_copy_default(),
    comment = "Validate step") {
  .action <- match.arg(.action)
  .call <- match.call()

  # Capture check expressions
  checks <- as.list(substitute(list(...))[-1])

  if (length(checks) == 0 && is.null(.min_n)) {
    stop("step_validate requires at least one check expression or .min_n",
      call. = FALSE
    )
  }

  # Collect dependencies from all check expressions
  dependencies <- unique(unlist(lapply(checks, all.vars)))

  if (is(svy, "RotativePanelSurvey")) {
    svy$implantation <- step_validate(
      svy$implantation, ...,
      .action = .action, .min_n = .min_n,
      .copy = .copy, comment = comment
    )
    svy$follow_up <- lapply(svy$follow_up, function(fu) {
      step_validate(fu, ...,
        .action = .action, .min_n = .min_n,
        .copy = .copy, comment = comment
      )
    })
    return(svy)
  }

  out <- if (.copy) svy$shallow_clone() else svy

  check_labels <- if (!is.null(names(checks))) {
    ifelse(
      nzchar(names(checks)),
      names(checks),
      vapply(checks, deparse1, character(1))
    )
  } else {
    vapply(checks, deparse1, character(1))
  }

  step <- Step$new(
    name = paste0("Validate: ", paste(check_labels, collapse = ", ")),
    edition = get_edition(out),
    survey_type = get_type(out),
    type = "validate",
    new_var = NULL,
    exprs = list(
      checks = checks,
      .action = .action,
      .min_n = .min_n
    ),
    call = .call,
    svy_before = NULL,
    default_engine = get_engine(),
    depends_on = dependencies,
    comment = comment,
    bake = FALSE
  )

  out$add_step(step)
  invisible(out)
}


#' Filter rows from survey data
#'
#' Creates a step that filters (subsets) rows from the survey data based
#' on logical conditions. Multiple conditions are combined with AND.
#'
#' @param svy A [Survey] or [RotativePanelSurvey] object.
#' @param ... Logical expressions evaluated against the data. Each must
#'   return a logical vector. Multiple conditions are combined with AND.
#' @param .by Optional grouping variable(s) for within-group filtering.
#' @param .copy Whether to operate on a copy (default: [use_copy_default()]).
#' @param comment Descriptive text for the step (default `"Filter step"`).
#' @param .level For [RotativePanelSurvey], the level to apply
#'   (default `"auto"`): `"implantation"`, `"follow_up"`, or `"auto"` (both).
#'
#' @return The survey object with rows filtered and the step recorded.
#'
#' @details
#' **Lazy evaluation (default):** Like all steps, filter is recorded but
#' **not executed** until [bake_steps()] is called.
#'
#' @examples
#' svy <- Survey$new(
#'   data = data.table::data.table(
#'     id = 1:10, age = c(15, 25, 35, 45, 55, 65, 75, 20, 30, 40), w = 1
#'   ),
#'   edition = "2023", type = "test", psu = NULL,
#'   engine = "data.table", weight = add_weight(annual = "w")
#' )
#' svy <- svy |>
#'   step_filter(age >= 18) |>
#'   bake_steps()
#' nrow(get_data(svy))
#'
#' @family steps
#' @export
step_filter <- function(
    svy, ...,
    .by = NULL,
    .copy = use_copy_default(),
    comment = "Filter step",
    .level = "auto") {
  .call <- match.call()

  # Capture filter expressions
  exprs <- as.list(substitute(list(...))[-1])

  if (length(exprs) == 0) {
    stop("step_filter requires at least one filter expression", call. = FALSE)
  }

  # Collect dependencies
  dependencies <- unique(unlist(lapply(exprs, all.vars)))

  if (is(svy, "RotativePanelSurvey")) {
    return(step_filter_rotative(svy, ...,
      .by = .by, .copy = .copy,
      comment = comment, .level = .level, .call = .call
    ))
  }

  out <- if (.copy) svy$shallow_clone() else svy

  filter_labels <- vapply(exprs, deparse1, character(1))

  step <- Step$new(
    name = paste0("Filter: ", paste(filter_labels, collapse = " & ")),
    edition = get_edition(out),
    survey_type = get_type(out),
    type = "filter",
    new_var = NULL,
    exprs = substitute(list(...)),
    call = .call,
    svy_before = NULL,
    default_engine = get_engine(),
    depends_on = dependencies,
    comment = comment,
    bake = FALSE
  )

  out$add_step(step)
  invisible(out)
}


#' @keywords internal
#' @noRd
step_filter_rotative <- function(
    svy, ...,
    .by = NULL,
    .copy = use_copy_default(),
    comment = "Filter step",
    .level = "auto", .call) {
  follow_up_processed <- svy$follow_up
  implantation_processed <- svy$implantation

  if (.level == "auto" || .level == "follow_up") {
    follow_up_processed <- lapply(svy$follow_up, function(sub_svy) {
      step_filter(sub_svy, ...,
        .by = .by, .copy = .copy, comment = comment
      )
    })
  }

  if (.level == "auto" || .level == "implantation") {
    implantation_processed <- step_filter(
      svy$implantation, ...,
      .by = .by, .copy = .copy, comment = comment
    )
  }

  if (length(implantation_processed$steps) > 0) {
    steps <- implantation_processed$steps
  } else if (length(follow_up_processed) > 0) {
    steps <- follow_up_processed[[1]]$steps
  } else {
    steps <- list()
  }

  if (.copy) {
    result <- RotativePanelSurvey$new(
      implantation = implantation_processed,
      follow_up = follow_up_processed,
      type = svy$type,
      default_engine = "data.table",
      steps = NULL, recipes = NULL,
      workflows = NULL, design = NULL
    )
    result$steps <- steps
    return(result)
  } else {
    svy$implantation <- implantation_processed
    svy$follow_up <- follow_up_processed
    svy$steps <- steps
    return(svy)
  }
}


#' View graph
#' @param svy Survey object
#' @param init_step Initial step label (default: "Load survey")
#' @return A visNetwork interactive graph of the survey processing steps.
#' @keywords survey
#' @keywords step
#' @examples
#' \donttest{
#' dt <- data.table::data.table(
#'   id = 1:5, age = c(25, 30, 45, 50, 60),
#'   w = rep(1, 5)
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "ech",
#'   psu = NULL, engine = "data.table",
#'   weight = add_weight(annual = "w")
#' )
#' svy <- step_compute(svy, age2 = age * 2)
#' view_graph(svy)
#' }
#' @family steps
#' @export
view_graph <- function(svy, init_step = "Load survey") {
  steps <- get_steps(svy)
  steps_type <- get_type_step(steps)
  formulas <- get_formulas(steps)
  comments <- get_comments(steps)

  if (!requireNamespace("visNetwork", quietly = TRUE)) {
    stop(
      "Package 'visNetwork' is required. ",
      "Install it with: install.packages('visNetwork')",
      call. = FALSE
    )
  }
  if (!requireNamespace("htmltools", quietly = TRUE)) {
    stop(
      "Package 'htmltools' is required. ",
      "Install it with: install.packages('htmltools')",
      call. = FALSE
    )
  }

  # ── Color palette (aligned with Shiny Recipe Explorer) ──
  palette <- list(
    primary    = "#2C3E50",
    compute    = "#3498db",
    recode     = "#9b59b6",
    join       = "#1abc9c",
    remove     = "#e74c3c",
    rename     = "#e67e22",
    validate   = "#27ae60",
    filter     = "#f39c12",
    dataframe  = "#95a5a6",
    background = "#f8f9fa",
    edge       = "#bdc3c7",
    edge_join  = "#1abc9c"
  )

  # ── Tooltip builder ──
  create_title <- function(comment, formula) {
    mapply(function(c, f) {
      paste0(
        "<div style='font-family: ",
        "system-ui, -apple-system, sans-serif; ",
        "padding: 10px 14px; ",
        "max-width: 340px;'>",
        "<div style='font-weight: 700; ",
        "font-size: 13px; color: ",
        palette$primary, "; ",
        "margin-bottom: 6px; ",
        "border-bottom: 2px solid #eee; ",
        "padding-bottom: 6px;'>",
        htmltools::htmlEscape(c), "</div>",
        "<div style='font-family: ",
        "SFMono-Regular, Consolas, monospace; ",
        "font-size: 11px; ",
        "color: #6c757d; background: ",
        palette$background,
        "; padding: 8px 10px; ",
        "border-radius: 6px; ",
        "line-height: 1.5; ",
        "white-space: pre-wrap;'>",
        htmltools::htmlEscape(f),
        "</div></div>"
      )
    }, comment, formula, USE.NAMES = FALSE)
  }

  # ── Survey info tooltip ──
  survey_tooltip <- function(svy_obj, label_prefix = "") {
    svy_type <- get_type(svy_obj)
    svy_edition <- get_edition(svy_obj)
    svy_weight <- get_info_weight(svy_obj)
    paste0(
      "<div style='font-family: ",
      "system-ui, -apple-system, sans-serif; ",
      "padding: 12px 16px; ",
      "max-width: 300px;'>",
      "<div style='font-weight: 800; ",
      "font-size: 14px; color: ",
      palette$primary, "; ",
      "margin-bottom: 8px;'>",
      label_prefix, "Survey</div>",
      "<table style='font-size: 12px; ",
      "color: #555; ",
      "border-collapse: collapse;'>",
      "<tr><td style='font-weight:600; ",
      "padding: 3px 12px 3px 0; color:",
      palette$primary, ";'>Type</td>",
      "<td style='padding:3px 0;'>",
      htmltools::htmlEscape(svy_type),
      "</td></tr>",
      "<tr><td style='font-weight:600; ",
      "padding: 3px 12px 3px 0; color:",
      palette$primary, ";'>Edition</td>",
      "<td style='padding:3px 0;'>",
      htmltools::htmlEscape(svy_edition),
      "</td></tr>",
      "<tr><td style='font-weight:600; ",
      "padding: 3px 12px 3px 0; color:",
      palette$primary, ";'>Weight</td>",
      "<td style='padding:3px 0;'>",
      htmltools::htmlEscape(svy_weight),
      "</td></tr>",
      "</table></div>"
    )
  }

  # ── Group color helper ──
  step_color <- function(type) {
    switch(type,
      "compute"     = palette$compute,
      "recode"      = palette$recode,
      "step_join"   = palette$join,
      "step_remove" = palette$remove,
      "step_rename" = palette$rename,
      "validate"    = palette$validate,
      "filter"      = palette$filter,
      "dataframe"   = palette$dataframe,
      "Load survey" = palette$primary,
      palette$primary
    )
  }

  # ── Initial node ──
  if (init_step == "Load survey") {
    init_label <- "Load survey"
    init_title <- survey_tooltip(svy)
  } else {
    init_label <- init_step
    init_title <- init_step
  }

  nodes <- data.frame(
    id = 1,
    label = init_label,
    title = init_title,
    group = "Load survey",
    stringsAsFactors = FALSE
  )
  edges <- data.frame(
    from = integer(),
    to = integer(),
    stringsAsFactors = FALSE
  )

  if (length(steps) > 0) {
    node_ids <- 2:(length(steps) + 1)
    nodes <- rbind(
      nodes,
      data.frame(
        id = node_ids,
        label = names(steps),
        title = create_title(comments, formulas),
        group = steps_type,
        stringsAsFactors = FALSE
      )
    )
    edges <- rbind(
      edges,
      data.frame(from = seq_along(steps), to = seq_along(steps) + 1L)
    )
  }

  # ── Process joins ──
  extra_nodes_list <- list()
  extra_edges_list <- list()
  node_id_counter <- nrow(nodes)

  if (length(steps) > 0) {
    for (i in seq_along(steps)) {
      step <- steps[[i]]
      current_step_node_id <- i + 1

      if (step$type == "step_join") {
        rhs <- step$exprs$x

        if (methods::is(rhs, "Survey")) {
          rhs_steps <- get_steps(rhs)
          rhs_steps_type <- get_type_step(rhs_steps)
          rhs_formulas <- get_formulas(rhs_steps)
          rhs_comments <- get_comments(rhs_steps)

          node_id_counter <- node_id_counter + 1
          rhs_init_node_id <- node_id_counter

          extra_nodes_list[[
            length(extra_nodes_list) + 1
          ]] <- data.frame(
            id = rhs_init_node_id,
            label = "Load survey (join)",
            title = survey_tooltip(
              rhs, "Join "
            ),
            group = "Load survey",
            stringsAsFactors = FALSE
          )

          prev_rhs_node_id <- rhs_init_node_id

          if (length(rhs_steps) > 0) {
            for (j in seq_along(rhs_steps)) {
              node_id_counter <- node_id_counter + 1

              extra_nodes_list[[
                length(extra_nodes_list) + 1
              ]] <- data.frame(
                id = node_id_counter,
                label = names(rhs_steps)[j],
                title = create_title(
                  rhs_comments[j],
                  rhs_formulas[j]
                ),
                group = rhs_steps_type[j],
                stringsAsFactors = FALSE
              )

              extra_edges_list[[
                length(extra_edges_list) + 1
              ]] <- data.frame(
                from = prev_rhs_node_id,
                to = node_id_counter
              )
              prev_rhs_node_id <- node_id_counter
            }
          }

          extra_edges_list[[
            length(extra_edges_list) + 1
          ]] <- data.frame(
            from = prev_rhs_node_id,
            to = current_step_node_id
          )
        } else if (is.data.frame(rhs)) {
          node_id_counter <- node_id_counter + 1
          df_node_id <- node_id_counter
          df_name <- deparse(step$call$x)

          extra_nodes_list[[
            length(extra_nodes_list) + 1
          ]] <- data.frame(
            id = df_node_id,
            label = paste("Data:", df_name),
            title = paste0(
              "<div style='font-family: ",
              "system-ui, sans-serif; ",
              "padding: 10px 14px;'>",
              "<div style='font-weight: 700; ",
              "color: ",
              palette$primary,
              ";'>External data.frame</div>",
              "<div style='font-size: 12px; ",
              "color: #6c757d; ",
              "margin-top: 4px;'>",
              htmltools::htmlEscape(df_name),
              "</div></div>"
            ),
            group = "dataframe",
            stringsAsFactors = FALSE
          )

          extra_edges_list[[
            length(extra_edges_list) + 1
          ]] <- data.frame(
            from = df_node_id,
            to = current_step_node_id
          )
        }
      }
    }
  }

  if (length(extra_nodes_list) > 0) {
    nodes <- rbind(nodes, do.call(rbind, extra_nodes_list))
  }
  if (length(extra_edges_list) > 0) {
    edges <- rbind(edges, do.call(rbind, extra_edges_list))
  }

  edges <- edges[!is.na(edges$to), ]

  # ── Build visNetwork ──
  visNetwork::visNetwork(
    nodes = nodes,
    edges = edges,
    height = "600px",
    width = "100%",
    background = palette$background
  ) |>
    # ── Node groups ──
    visNetwork::visGroups(
      groupname = "Load survey",
      shape = "icon",
      icon = list(
        code = "f1c0", size = 60,
        color = palette$primary
      ),
      font = list(
        size = 16, color = palette$primary,
        face = "bold", multi = TRUE
      ),
      shadow = list(
        enabled = TRUE, size = 8,
        x = 2, y = 2,
        color = "rgba(44,62,80,.15)"
      )
    ) |>
    visNetwork::visGroups(
      groupname = "compute",
      shape = "icon",
      icon = list(
        code = "f1ec", size = 50,
        color = palette$compute
      ),
      font = list(
        size = 14, color = "#2c3e50",
        face = "bold"
      ),
      shadow = list(
        enabled = TRUE, size = 6,
        x = 2, y = 2,
        color = "rgba(52,152,219,.2)"
      )
    ) |>
    visNetwork::visGroups(
      groupname = "recode",
      shape = "icon",
      icon = list(
        code = "f0e8", size = 50,
        color = palette$recode
      ),
      font = list(
        size = 14, color = "#2c3e50",
        face = "bold"
      ),
      shadow = list(
        enabled = TRUE, size = 6,
        x = 2, y = 2,
        color = "rgba(155,89,182,.2)"
      )
    ) |>
    visNetwork::visGroups(
      groupname = "step_join",
      shape = "icon",
      icon = list(
        code = "f0c1", size = 50,
        color = palette$join
      ),
      font = list(
        size = 14, color = "#2c3e50",
        face = "bold"
      ),
      shadow = list(
        enabled = TRUE, size = 6,
        x = 2, y = 2,
        color = "rgba(26,188,156,.2)"
      )
    ) |>
    visNetwork::visGroups(
      groupname = "step_remove",
      shape = "icon",
      icon = list(
        code = "f1f8", size = 50,
        color = palette$remove
      ),
      font = list(
        size = 14, color = "#2c3e50",
        face = "bold"
      ),
      shadow = list(
        enabled = TRUE, size = 6,
        x = 2, y = 2,
        color = "rgba(231,76,60,.2)"
      )
    ) |>
    visNetwork::visGroups(
      groupname = "step_rename",
      shape = "icon",
      icon = list(
        code = "f044", size = 50,
        color = palette$rename
      ),
      font = list(
        size = 14, color = "#2c3e50",
        face = "bold"
      ),
      shadow = list(
        enabled = TRUE, size = 6,
        x = 2, y = 2,
        color = "rgba(230,126,34,.2)"
      )
    ) |>
    visNetwork::visGroups(
      groupname = "validate",
      shape = "icon",
      icon = list(
        code = "f058", size = 50,
        color = palette$validate
      ),
      font = list(
        size = 14, color = "#2c3e50",
        face = "bold"
      ),
      shadow = list(
        enabled = TRUE, size = 6,
        x = 2, y = 2,
        color = "rgba(39,174,96,.2)"
      )
    ) |>
    visNetwork::visGroups(
      groupname = "dataframe",
      shape = "icon",
      icon = list(
        code = "f0ce", size = 50,
        color = palette$dataframe
      ),
      font = list(
        size = 14, color = "#2c3e50"
      ),
      shadow = list(
        enabled = TRUE, size = 6,
        x = 2, y = 2,
        color = "rgba(149,165,166,.2)"
      )
    ) |>
    visNetwork::addFontAwesome() |>
    visNetwork::visEdges(
      arrows = list(
        to = list(
          enabled = TRUE,
          scaleFactor = 0.7,
          type = "arrow"
        )
      ),
      color = list(
        color = palette$edge,
        highlight = palette$compute,
        hover = palette$compute
      ),
      width = 2,
      smooth = list(
        enabled = TRUE,
        type = "curvedCW",
        roundness = 0.1
      )
    ) |>
    visNetwork::visHierarchicalLayout(
      direction = "LR",
      levelSeparation = 220,
      nodeSpacing = 140,
      sortMethod = "directed"
    ) |>
    visNetwork::visInteraction(
      hover = TRUE,
      tooltipDelay = 100,
      tooltipStyle = paste0(
        "position: fixed; visibility: hidden; padding: 0; ",
        "background: #fff; border-radius: 10px; ",
        "box-shadow: 0 4px 20px rgba(0,0,0,.12); ",
        "border: 1px solid #eee; ",
        "pointer-events: none; z-index: 9999;"
      ),
      navigationButtons = TRUE,
      keyboard = TRUE
    ) |>
    visNetwork::visOptions(
      nodesIdSelection = list(
        enabled = TRUE,
        style = paste0(
          "font-family: system-ui, ",
          "sans-serif; font-size: 13px; ",
          "padding: 6px 12px; ",
          "border-radius: 8px; ",
          "border: 1px solid #dee2e6; ",
          "background: #fff; color: ",
          palette$primary, ";"
        )
      ),
      highlightNearest = list(
        enabled = TRUE, degree = 1,
        hover = TRUE
      ),
      clickToUse = FALSE
    ) |>
    visNetwork::visLegend(
      width = 0.15,
      position = "right",
      main = list(
        text = "Step types",
        style = paste0(
          "font-family: system-ui, ",
          "sans-serif; font-weight: 700; ",
          "font-size: 14px; color: ",
          palette$primary, ";"
        )
      ),
      zoom = FALSE
    )
}


new_step <- function(id = 1, name, description,
                     depends = NULL, type,
                     new_var = NULL, ...) {
  if (type == "recode") {
    if (is.null(new_var)) {
      stop("new_var is required for recode", call. = FALSE)
    }
  }

  call <- do.call(
    paste0(
      "step_",
      type
    ),
    args = list(
      svy = survey_empty(),
      new_var = new_var,
      ...
    )
  )

  list(
    id = id,
    name = name,
    description = description,
    depends = depends,
    type = type,
    new_var = new_var,
    call = call
  )
}

#' @title Find dependencies
#' @description Find dependencies
#' @param call_expr Call expression
#' @param survey Survey
#' @keywords internal
#' @return List of dependencies
#' @noRd
#'
find_dependencies <- function(call_expr, survey) {
  dependencies <- character()

  if (is.call(call_expr)) {
    for (i in seq_along(call_expr)) {
      result <- find_dependencies(call_expr[[i]], survey)
      if (!is.null(result)) {
        dependencies <- unique(c(dependencies, result))
      }
    }
  } else if (is.name(call_expr)) {
    expr_chr <- as.character(call_expr)
    if (expr_chr %in% names(survey)) {
      dependencies <- unique(c(dependencies, expr_chr))
    }
  }

  return(unique(dependencies))
}
