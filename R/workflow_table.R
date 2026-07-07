#' Create publication-quality table from workflow results
#'
#' Formats a [workflow()] result as a gt table with confidence intervals,
#' CV quality classification, and provenance-based source notes.
#'
#' @param result A `data.table` from [workflow()].
#' @param ci Confidence level for intervals (default 0.95).
#'   Set to `NULL` to hide confidence intervals.
#' @param digits Number of decimal places (default 2).
#' @param compare_by Column name to pivot for side-by-side comparison
#'   (e.g., `"survey_edition"`).
#' @param show_cv Logical; show CV column with quality classification.
#' @param show_se Logical; show SE column.
#' @param title Table title. Auto-generated if `NULL`.
#' @param subtitle Table subtitle. Auto-generated if `NULL`.
#' @param source_note Logical; show provenance footer.
#' @param locale Locale for number formatting (`"en"` or `"es"`).
#' @param theme Table theme: `"publication"` (clean) or `"minimal"`.
#'
#' @return A `gt_tbl` object. Export via `gt::gtsave()` to .html, .docx,
#'   .pdf, .png, or .rtx. Falls back to [knitr::kable()] if gt is not
#'   installed.
#'
#' @details
#' CV quality classification follows INE/CEPAL standards:
#' - Excellent: CV < 5\%
#' - Very good: 5-10\%
#' - Good: 10-15\%
#' - Acceptable: 15-25\%
#' - Use with caution: 25-35\%
#' - Do not publish: >= 35\%
#'
#' @examples
#' svy <- Survey$new(
#'   data = data.table::data.table(
#'     x = rnorm(100), g = sample(c("a", "b"), 100, TRUE), w = rep(1, 100)
#'   ),
#'   edition = "2023", type = "test", psu = NULL,
#'   engine = "data.table", weight = add_weight(annual = "w")
#' )
#' result <- workflow(
#'   list(svy), survey::svymean(~x, na.rm = TRUE),
#'   estimation_type = "annual"
#' )
#' \donttest{
#' if (requireNamespace("gt", quietly = TRUE)) {
#'   workflow_table(result)
#' }
#' }
#'
#' @family workflows
#' @export
workflow_table <- function(
  result,
  ci = 0.95,
  digits = 2,
  compare_by = NULL,
  show_cv = TRUE,
  show_se = TRUE,
  title = NULL,
  subtitle = NULL,
  source_note = TRUE,
  locale = "en",
  theme = "publication"
) {
  if (!requireNamespace("gt", quietly = TRUE)) {
    warning(
      "Package 'gt' is required for formatted tables. ",
      "Falling back to knitr::kable().",
      call. = FALSE
    )
    return(.workflow_table_kable(result, digits))
  }

  dt <- data.table::copy(result)

  # --- Handle compare_by pivot ---
  if (!is.null(compare_by) && compare_by %in% names(dt)) {
    return(.workflow_table_compare(
      dt,
      compare_by = compare_by,
      ci = ci, digits = digits,
      show_cv = show_cv, show_se = show_se,
      title = title, subtitle = subtitle,
      source_note = source_note,
      locale = locale, theme = theme,
      result = result
    ))
  }

  # --- Normalize CV to percentage ---
  cv_pct <- dt$cv
  if (!is.null(cv_pct) && length(cv_pct) > 0) {
    if (all(abs(cv_pct[!is.na(cv_pct)]) < 1)) {
      cv_pct <- cv_pct * 100
    }
  }

  # --- Build display table ---
  # Detect group columns (from svyby)
  known_cols <- c(
    "stat", "value", "se", "cv",
    "confint_lower", "confint_upper",
    "estimation_type", "survey_edition",
    "period", "type", "variance", "evaluate"
  )
  by_cols <- setdiff(names(dt), known_cols)

  cols <- list(Statistic = .clean_stat_names(dt$stat))
  for (bc in by_cols) {
    cols[[bc]] <- dt[[bc]]
  }
  cols[["Estimate"]] <- dt$value
  if (show_se) {
    cols[["SE"]] <- dt$se
  }
  if (!is.null(ci)) {
    z <- stats::qnorm(1 - (1 - ci) / 2)
    cols[["CI Lower"]] <- dt$value - z * dt$se
    cols[["CI Upper"]] <- dt$value + z * dt$se
  }
  if (show_cv && !is.null(cv_pct)) {
    cols[["CV (%)"]] <- round(cv_pct, 1)
    cols[["Quality"]] <- vapply(cv_pct, evaluate_cv, character(1))
  }

  display <- data.table::as.data.table(cols)

  # --- Auto-generate titles ---
  wf <- attr(result, "workflow")
  if (is.null(title)) {
    title <- if (!is.null(wf) && inherits(wf, "RecipeWorkflow")) {
      wf$name %||% "Survey Estimation Results"
    } else {
      "Survey Estimation Results"
    }
  }
  if (is.null(subtitle)) {
    if (!is.null(wf) && inherits(wf, "RecipeWorkflow")) {
      parts <- character()
      if (!is.null(wf$survey_type)) parts <- c(parts, toupper(wf$survey_type))
      if (!is.null(wf$edition)) parts <- c(parts, as.character(wf$edition))
      subtitle <- if (length(parts) > 0) paste(parts, collapse = " ") else NULL
    }
  }

  # --- Build gt ---
  tbl <- gt::gt(display)

  # Header
  tbl <- tbl |> gt::tab_header(
    title = title,
    subtitle = subtitle
  )

  # Format numeric columns
  tbl <- tbl |> gt::fmt_number(
    columns = "Estimate", decimals = digits, locale = locale
  )
  if (show_se) {
    tbl <- tbl |> gt::fmt_number(
      columns = "SE", decimals = digits + 1, locale = locale
    )
  }
  if (!is.null(ci)) {
    tbl <- tbl |> gt::fmt_number(
      columns = c("CI Lower", "CI Upper"),
      decimals = digits, locale = locale
    )
  }
  if (show_cv && "CV (%)" %in% names(display)) {
    tbl <- tbl |> gt::fmt_number(
      columns = "CV (%)", decimals = 1, locale = locale
    )
  }

  # CV quality coloring
  if (show_cv && "Quality" %in% names(display)) {
    tbl <- tbl |> gt::data_color(
      columns = "Quality",
      fn = .cv_quality_colors
    )
  }

  # Apply theme
  tbl <- .apply_table_theme(tbl, theme)

  # Source note
  if (isTRUE(source_note)) {
    tbl <- tbl |> gt::tab_source_note(.build_source_note(result, ci))
  }

  tbl
}


# --- Internal helpers ---

# Clean stat names: "svymean: age" -> "age"
.clean_stat_names <- function(stat_col) {
  # Remove "svymean: ", "svytotal: ", etc. prefix
  cleaned <- sub("^[^:]+:\\s*", "", stat_col)
  # Remove "[by_var=value]" suffix for cleaner display
  sub("\\s*\\[.*\\]$", "", cleaned)
}


# CV quality -> color mapping
.cv_quality_colors <- function(x) {
  colors <- character(length(x))
  colors[x == "Excellent"] <- "#16a34a"
  colors[x == "Very good"] <- "#22c55e"
  colors[x == "Good"] <- "#3b82f6"
  colors[x == "Acceptable"] <- "#f59e0b"
  colors[x == "Use with caution"] <- "#f97316"
  colors[x == "Do not publish"] <- "#ef4444"
  colors[is.na(x) | colors == ""] <- "#6b7280"
  colors
}


# Build source note from provenance + workflow attributes
.build_source_note <- function(result, ci) {
  note_parts <- character()

  wf <- attr(result, "workflow")
  if (!is.null(wf) && inherits(wf, "RecipeWorkflow")) {
    parts <- character()
    if (!is.null(wf$survey_type)) parts <- c(parts, toupper(wf$survey_type))
    if (!is.null(wf$edition)) parts <- c(parts, as.character(wf$edition))
    if (length(parts) > 0) {
      note_parts <- c(note_parts, paste("Source:", paste(parts, collapse = " ")))
    }
  }

  prov <- attr(result, "provenance")
  if (!is.null(prov) && !is.null(prov$environment$metasurvey_version)) {
    note_parts <- c(
      note_parts,
      paste("metasurvey", prov$environment$metasurvey_version)
    )
  } else {
    note_parts <- c(note_parts, paste(
      "metasurvey", as.character(utils::packageVersion("metasurvey"))
    ))
  }

  if (!is.null(ci)) {
    note_parts <- c(note_parts, sprintf("CI: %g%%", ci * 100))
  }

  note_parts <- c(note_parts, format(Sys.Date(), "%Y-%m-%d"))

  paste(note_parts, collapse = " | ")
}


# Apply publication or minimal theme
.apply_table_theme <- function(tbl, theme) {
  if (theme == "publication") {
    tbl <- tbl |> gt::tab_options(
      table.font.size = gt::px(13),
      heading.title.font.size = gt::px(16),
      heading.subtitle.font.size = gt::px(13),
      column_labels.font.weight = "bold",
      table.border.top.style = "solid",
      table.border.top.width = gt::px(2),
      table.border.top.color = "#1e293b",
      table.border.bottom.style = "solid",
      table.border.bottom.width = gt::px(2),
      table.border.bottom.color = "#1e293b",
      heading.border.bottom.style = "solid",
      heading.border.bottom.width = gt::px(1),
      heading.border.bottom.color = "#94a3b8",
      column_labels.border.bottom.style = "solid",
      column_labels.border.bottom.width = gt::px(1),
      column_labels.border.bottom.color = "#94a3b8",
      table_body.hlines.style = "none",
      source_notes.font.size = gt::px(10),
      source_notes.padding = gt::px(8)
    )
  } else {
    tbl <- tbl |> gt::tab_options(
      table.font.size = gt::px(12),
      column_labels.font.weight = "bold",
      table_body.hlines.style = "none",
      source_notes.font.size = gt::px(10)
    )
  }
  tbl
}


# Compare-by pivot: side-by-side editions
.workflow_table_compare <- function(
  dt, compare_by,
  ci, digits, show_cv, show_se,
  title, subtitle, source_note,
  locale, theme, result
) {
  groups <- unique(dt[[compare_by]])

  # Build base: stat + group cols
  known_cols <- c(
    "stat", "value", "se", "cv",
    "confint_lower", "confint_upper",
    "estimation_type", "survey_edition",
    "period", "type", "variance", "evaluate"
  )
  by_cols <- setdiff(names(dt), c(known_cols, compare_by))

  stat_clean <- .clean_stat_names(dt$stat)
  # Get unique stat names
  unique_stats <- unique(stat_clean)

  display <- data.table::data.table(Statistic = unique_stats)

  for (g in groups) {
    subset_dt <- dt[dt[[compare_by]] == g]
    subset_stat <- .clean_stat_names(subset_dt$stat)
    # Match rows
    idx <- match(unique_stats, subset_stat)
    col_name <- as.character(g)
    display[[col_name]] <- subset_dt$value[idx]
  }

  # Add variation if exactly 2 groups
  if (length(groups) == 2) {
    g1 <- as.character(groups[1])
    g2 <- as.character(groups[2])
    display[["Var. (%)"]] <- round(
      (display[[g2]] - display[[g1]]) / abs(display[[g1]]) * 100, 1
    )
  }

  if (is.null(title)) title <- "Comparison"
  if (is.null(subtitle)) {
    subtitle <- paste(compare_by, ":", paste(groups, collapse = " vs "))
  }

  tbl <- gt::gt(display)
  tbl <- tbl |> gt::tab_header(title = title, subtitle = subtitle)

  # Format all numeric columns
  num_cols <- setdiff(names(display), "Statistic")
  tbl <- tbl |> gt::fmt_number(
    columns = num_cols, decimals = digits, locale = locale
  )

  tbl <- .apply_table_theme(tbl, theme)

  if (isTRUE(source_note)) {
    tbl <- tbl |> gt::tab_source_note(.build_source_note(result, ci))
  }

  tbl
}


# Fallback when gt is not installed
.workflow_table_kable <- function(result, digits) {
  if (!requireNamespace("knitr", quietly = TRUE)) {
    return(result)
  }
  knitr::kable(result, digits = digits, format = "pipe")
}
