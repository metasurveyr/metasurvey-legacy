is_blank <- function(x) {
  return(
    is.null(x) || length(x) == 0 || is.na(x) || x == ""
  )
}

#' Generate a unique ID
#'
#' Creates a human-readable unique identifier with an optional prefix,
#' a Unix timestamp, and a random suffix.
#'
#' @param prefix Character prefix (e.g., "r" for recipes,
#'   "w" for workflows).
#' @return Character string ID like "r_1739654400_742".
#' @keywords internal
#' @noRd
generate_id <- function(prefix = "r") {
  ts <- as.integer(Sys.time())
  rand <- sample.int(999, 1)
  paste0(prefix, "_", ts, "_", rand)
}


"%||%" <- function(x, y) if (is.null(x)) y else x

"%@%" <- function(x, y) {
  if (is_blank(x)) {
    y
  } else {
    x
  }
}

#' Validate weight
#' @param svy Survey
#' @param weight Weight
#' @return Weight
#' @keywords utils
#' @keywords internal
#' @noRd

validate_weight <- function(svy, weight) {
  if (is.null(svy)) {
    return(NULL)
  }

  if (!is.character(weight)) {
    stop("Weight must be a character", call. = FALSE)
  }

  if (!weight %in% colnames(svy)) {
    stop(
      glue::glue(
        "Weight column '{weight}' not found in survey data. ",
        "Available columns: {paste(head(colnames(svy), 10), collapse = ', ')}"
      ),
      call. = FALSE
    )
  } else {
    weight
  }
}

#' Validate Replicate
#' @param svy Survey
#' @param replicate Replicate
#' @return Replicate
#' @keywords internal
#' @noRd

validate_replicate <- function(svy, replicate) {
  if (is.null(svy)) {
    return(NULL)
  }

  if (!is.null(replicate$replicate_id)) {
    if (!is.character(replicate$replicate_id)) {
      stop("Replicate ID must be a character", call. = FALSE)
    }

    if (!all(names(replicate$replicate_id) %in% colnames(svy))) {
      missing <- setdiff(names(replicate$replicate_id), colnames(svy))
      stop(
        glue::glue(
          "Replicate ID column(s) not found in survey: ",
          "{paste(missing, collapse = ', ')}"
        ),
        call. = FALSE
      )
    }
  }


  replicate_file <- read_file(replicate$replicate_path)

  if (!is.null(replicate$replicate_pattern)) {
    if (!is.character(replicate$replicate_pattern)) {
      stop("Replicate pattern must be a character", call. = FALSE)
    }

    column_names <- names(replicate_file)

    if (!any(grepl(replicate$replicate_pattern, column_names))) {
      stop("Replicate pattern not found in replicate file", call. = FALSE)
    }
  }

  replicate[["replicate_file"]] <- replicate_file

  return(
    replicate
  )
}

#' Validate Weight time pattern
#' @param svy Survey
#' @param weight_time_pattern Weight time pattern
#' @return Weight time pattern
#' @keywords utils
#' @keywords internal
#' @noRd

validate_weight_time_pattern <- function(svy, weight_list) {
  if (is.null(svy) || is.null(weight_list)) {
    return(NULL)
  }

  if (!is.list(weight_list)) {
    stop("Weight time pattern must be a list", call. = FALSE)
  }

  Map(
    f = function(x) {
      if (is.character(x = x)) {
        validate_weight(svy = svy, weight = x)
      } else {
        if (is.list(x)) {
          validate_replicate(svy = svy, replicate = x)
        }
      }
    },
    weight_list
  )
}


#' Load survey example data
#'
#' Downloads and loads example survey data from the
#' metasurvey data repository. This function provides access
#' to sample datasets for testing and demonstration purposes,
#' including ECH (Continuous Household Survey) and other
#' survey types.
#'
#' @param svy_type Character string specifying the survey
#'   type (e.g., "ech")
#' @param svy_edition Character string specifying the survey
#'   edition/year (e.g., "2023")
#'
#' @return Character string with the path to the downloaded
#'   CSV file containing the example survey data
#'
#' @details
#' This function downloads example data from the official
#' metasurvey data repository on GitHub. The data is cached
#' locally in a temporary file to avoid repeated downloads
#' in the same session.
#'
#' Available survey types and editions can be found at:
#' \url{https://github.com/metasurveyr/metasurvey_data}
#'
#' @examples
#' \dontrun{
#' # Load ECH 2023 example data
#' ech_path <- load_survey_example("ech", "2023")
#'
#' # Use with load_survey
#' ech_data <- load_survey(
#'   path = load_survey_example("ech", "2023"),
#'   svy_type = "ech",
#'   svy_edition = "2023"
#' )
#' }
#'
#' @seealso \code{\link{load_survey}} for loading the downloaded data
#' @keywords utils
#' @family survey-loading
#' @export

load_survey_example <- function(svy_type, svy_edition) {
  baseUrl <- paste0(
    "https://raw.githubusercontent.com/",
    "metasurveyr/metasurvey_data/main/"
  )
  f <- tempfile(fileext = ".csv")
  tryCatch(
    utils::download.file(
      paste0(
        baseUrl,
        glue::glue("{svy_type}/{svy_edition}.csv")
      ),
      f,
      method = "auto",
      quiet = TRUE
    ),
    error = function(e) {
      stop(
        sprintf(
          "Failed to download example data for '%s/%s': %s",
          svy_type, svy_edition, conditionMessage(e)
        ),
        call. = FALSE
      )
    }
  )
  f
}

#' Get data copy option
#'
#' Retrieves the current setting for the use_copy option,
#' which controls whether survey operations create copies of
#' the data or modify in place.
#'
#' @return Logical value indicating whether to use data copies (TRUE) or
#'   modify data in place (FALSE). Default is TRUE.
#'
#' @details
#' The use_copy option affects memory usage and performance:
#' \itemize{
#'   \item TRUE: Creates copies, safer but uses more memory
#'   \item FALSE: Modifies in place, more efficient but requires caution
#' }
#'
#' @examples
#' # Check current setting
#' current_setting <- use_copy_default()
#' print(current_setting)
#'
#' @seealso \code{\link{set_use_copy}} to change the setting
#' @family options
#' @export

use_copy_default <- function() {
  getOption("metasurvey.use_copy", default = TRUE)
}

#' Set data copy option
#'
#' Configures whether survey operations should create copies
#' of the data or modify existing data in place. This setting
#' affects memory usage and performance across the metasurvey
#' package.
#'
#' @param use_copy Logical value: TRUE to create data copies (safer),
#'   FALSE to modify data in place (more efficient)
#'
#' @details
#' Setting use_copy affects all subsequent survey operations:
#' \itemize{
#'   \item TRUE (default): Operations create data copies,
#'     preserving original data
#'   \item FALSE: Operations modify data in place, reducing
#'     memory usage
#' }
#'
#' Use FALSE for large datasets where memory is a concern,
#' but ensure you don't need the original data after
#' operations.
#'
#' @examples
#' # Set to use copies (default behavior)
#' set_use_copy(TRUE)
#' use_copy_default()
#'
#' # Set to modify in place for better performance
#' set_use_copy(FALSE)
#' use_copy_default()
#'
#' # Reset to default
#' set_use_copy(TRUE)
#'
#' @return Invisibly, the previous value (for restoring).
#' @seealso \code{\link{use_copy_default}} to check current setting
#' @family options
#' @export
#' @keywords utils
set_use_copy <- function(use_copy) {
  if (!is.logical(use_copy) || length(use_copy) != 1L) {
    stop("use_copy must be a single logical value", call. = FALSE)
  }

  old <- getOption("metasurvey.use_copy")
  options(metasurvey.use_copy = use_copy)
  invisible(old)
}


#' Get User
#' @return User
#' @keywords utils
#' @keywords internal
#' @noRd

get_user <- function() {
  user_key <- NULL

  api_key <- getOption("metasurvey.api_key", default = NULL)

  if (!is.null(api_key)) {
    user_key <- "apiKey"
  }

  getOption(
    "metasurvey.user",
    default = NULL
  ) %||% user_key %||% "public"
}


# Legacy Atlas direct-access functions were removed.
# All API access now goes through api_client.R → plumber API.
# See configure_api(), api_login(), api_list_recipes(), etc.


#' Lazy processing
#' @return Logical indicating the current lazy processing setting.
#' @keywords utils
#' @examples
#' # Check current lazy processing default
#' lazy_default()
#' @family options
#' @export

lazy_default <- function() {
  getOption("metasurvey.lazy_processing", default = TRUE)
}

#' Set lazy processing
#' @param lazy Logical. If TRUE, steps are deferred until
#'   bake_steps() is called.
#' @return Invisibly, the previous value.
#' @keywords utils
#' @examples
#' old <- lazy_default()
#' set_lazy_processing(FALSE)
#' lazy_default() # now FALSE
#' set_lazy_processing(old) # restore
#' @family options
#' @export

set_lazy_processing <- function(lazy) {
  if (!is.logical(lazy) || length(lazy) != 1L) {
    stop("lazy must be a single logical value", call. = FALSE)
  }

  old <- getOption("metasurvey.lazy_processing")
  options(metasurvey.lazy_processing = lazy)
  invisible(old)
}


# Validate month and return monthly result or invalid format
# @noRd
validate_monthly <- function(year, month) {
  if (month >= 1 && month <= 12) {
    list(year = year, month = month, periodicity = "Monthly")
  } else {
    list(year = year, month = NA, periodicity = "Invalid format")
  }
}

# Parse two-digit short date (YY_MM or MM_YY)
# @noRd
parse_short_date <- function(svy_edition) {
  patterns <- c("^(\\d{2})[_-](\\d{2})$", "^(\\d{2})(\\d{2})$")
  for (pat in patterns) {
    if (!grepl(pat, svy_edition)) next
    p1 <- as.numeric(sub(pat, "\\1", svy_edition))
    p2 <- as.numeric(sub(pat, "\\2", svy_edition))
    if (p1 >= 1 && p1 <= 12) {
      return(list(
        year = 2000 + p2, month = p1,
        periodicity = "Monthly"
      ))
    }
    if (p2 >= 1 && p2 <= 12) {
      return(list(
        year = 2000 + p1, month = p2,
        periodicity = "Monthly"
      ))
    }
  }
  NULL
}

#' Extract time pattern
#' @param svy_edition Survey edition string
#'   (e.g. "2023", "2023-06", "2023_Q1").
#' @return List with components: periodicity, year,
#'   month (when applicable).
#' @keywords utils
#' @examples
#' # Annual edition
#' extract_time_pattern("2023")
#'
#' # Monthly edition
#' extract_time_pattern("2023-06")
#' @family survey-loading
#' @export
extract_time_pattern <- function(svy_edition) {
  svy_edition <- gsub("[\\s\\-\\/]+", "_", svy_edition, perl = TRUE)
  svy_edition <- gsub("[_*]+", "_", svy_edition, perl = TRUE)
  svy_edition <- trimws(svy_edition, which = "both")

  type <- NA
  year <- NA
  year_start <- NA
  year_end <- NA
  month <- NA
  periodicity <- NA

  # Extract type prefix if text precedes digits
  if (grepl("^[^0-9]", svy_edition)) {
    type <- sub("[0-9_]*$", "", svy_edition, perl = TRUE)
    svy_edition <- gsub("[^0-9_]*", "", svy_edition, perl = TRUE)
    svy_edition <- gsub("^_+|_+$", "", svy_edition)
  }

  # Quarter/Trimester: YYYY_T\d, YYYY_Q\d (e.g., "2023_T3", "2023_Q1")
  qmatch <- regmatches(svy_edition, regexec(
    "^(\\d{4})[_]?([TtQq])(\\d)$", svy_edition
  ))[[1]]
  if (length(qmatch) == 4) {
    year <- as.numeric(qmatch[2])
    quarter <- as.integer(qmatch[4])
    month <- (quarter - 1L) * 3L + 1L
    periodicity <- "Quarterly"
    result <- list(
      type = type, year = year, month = month,
      year_start = NA, year_end = NA,
      periodicity = periodicity
    )
    return(result[!vapply(result, is.na, logical(1))])
  }

  # YYYYMM (e.g., "202312")
  if (
    grepl("^(\\d{4})(\\d{2})$", svy_edition) &&
      as.numeric(sub("^\\d{4}(\\d{2})$", "\\1", svy_edition)) <= 12
  ) {
    yr <- as.numeric(sub("^(\\d{4})\\d{2}$", "\\1", svy_edition))
    mo <- as.numeric(sub("^\\d{4}(\\d{2})$", "\\1", svy_edition))
    res <- validate_monthly(yr, mo)
    year <- res$year
    month <- res$month
    periodicity <- res$periodicity

    # MMYYYY (e.g., "122023")
  } else if (
    grepl("^(\\d{2})(\\d{4})$", svy_edition) &&
      as.numeric(sub("^(\\d{2})\\d{4}$", "\\1", svy_edition)) <= 12
  ) {
    mo <- as.numeric(sub("^(\\d{2})\\d{4}$", "\\1", svy_edition))
    yr <- as.numeric(sub("^\\d{2}(\\d{4})$", "\\1", svy_edition))
    res <- validate_monthly(yr, mo)
    year <- res$year
    month <- res$month
    periodicity <- res$periodicity

    # MM_YYYY (e.g., "01_2023")
  } else if (
    grepl("^(\\d{2})[_-](\\d{4})$", svy_edition) &&
      as.numeric(
        sub("^(\\d{2})[_-]\\d{4}$", "\\1", svy_edition)
      ) <= 12
  ) {
    mo <- as.numeric(sub("^(\\d{2})[_-]\\d{4}$", "\\1", svy_edition))
    yr <- as.numeric(sub("^\\d{2}[_-](\\d{4})$", "\\1", svy_edition))
    res <- validate_monthly(yr, mo)
    year <- res$year
    month <- res$month
    periodicity <- res$periodicity

    # YYYY_MM (e.g., "2023_12")
  } else if (
    grepl("^(\\d{4})[_-](\\d{2})$", svy_edition) &&
      as.numeric(
        sub("^\\d{4}[_-](\\d{2})$", "\\1", svy_edition)
      ) <= 12
  ) {
    yr <- as.numeric(sub("^(\\d{4})[_-]\\d{2}$", "\\1", svy_edition))
    mo <- as.numeric(sub("^\\d{4}[_-](\\d{2})$", "\\1", svy_edition))
    res <- validate_monthly(yr, mo)
    year <- res$year
    month <- res$month
    periodicity <- res$periodicity

    # Year range (e.g., "2019_2021")
  } else if (grepl("^(\\d{4})[_]?(\\d{4})$", svy_edition)) {
    years <- as.numeric(unlist(regmatches(
      svy_edition, gregexpr("\\d{4}", svy_edition)
    )))
    year_start <- min(years)
    year_end <- max(years)
    span <- year_end - year_start + 1
    periodicity <- if (span == 3) "Triennial" else "Multi-year"

    # Annual (e.g., "2023")
  } else if (
    grepl("^\\d{4}$", svy_edition) &&
      as.numeric(svy_edition) >= 1900
  ) {
    year <- as.numeric(svy_edition)
    periodicity <- "Annual"

    # Short date YY_MM or MM_YY (e.g., "23_05")
  } else if (grepl("^\\d{2}[_-]?\\d{2}$", svy_edition)) {
    res <- parse_short_date(svy_edition)
    if (!is.null(res)) {
      year <- res$year
      month <- res$month
      periodicity <- res$periodicity
    }
  } else {
    periodicity <- "Unknown format"
  }

  result <- list(
    type = type, year = year, month = month,
    year_start = year_start, year_end = year_end,
    periodicity = periodicity
  )
  result[!vapply(result, is.na, logical(1))]
}










#' Validate time pattern
#' @param svy_type Survey type (e.g. "ech").
#' @param svy_edition Survey edition string
#'   (e.g. "2023", "2023-06").
#' @return List with components: svy_type, svy_edition
#'   (parsed), svy_periodicity.
#' @keywords utils
#' @examples
#' validate_time_pattern(svy_type = "ech", svy_edition = "2023")
#' validate_time_pattern(
#'   svy_type = "ech", svy_edition = "2023-06"
#' )
#' @family survey-loading
#' @export

validate_time_pattern <- function(svy_type = NULL, svy_edition = NULL) {
  # Validate that svy_edition is not NULL or empty
  if (
    is.null(svy_edition) ||
      length(svy_edition) == 0 ||
      isTRUE(is.na(svy_edition)) ||
      identical(svy_edition, "")
  ) {
    if (is.null(svy_type)) {
      stop(
        "Both svy_edition and svy_type are NULL. ",
        "Please provide at least one.",
        call. = FALSE
      )
    }
    # If no edition but type exists, return type only
    return(list(
      svy_type = svy_type,
      svy_edition = NA,
      svy_periodicity = NA
    ))
  }

  time_pattern <- extract_time_pattern(svy_edition)

  if (is.null(time_pattern$type) && is.null(svy_type)) {
    stop(
      "Type not found. Please provide a valid type ",
      "in the survey edition or as an argument",
      call. = FALSE
    )
  }

  time_pattern$type <- time_pattern$type %@% svy_type

  if (
    !is.null(time_pattern$type) &&
      toupper(time_pattern$type) != toupper(svy_type)
  ) {
    metasurvey_msg(
      "Type does not match. Please provide a valid ",
      "type in the survey edition or as an argument"
    )
  }


  names_time <- names(time_pattern)

  remove_attributes <- c("type", "periodicity")


  svy_editions <- ""

  if (
    !is.null(time_pattern$month) &&
      !is.na(time_pattern$month) &&
      !is.null(time_pattern$year) &&
      !is.na(time_pattern$year)
  ) {
    date_string <- sprintf(
      "%04d-%02d-01",
      time_pattern$year, time_pattern$month
    )
    svy_edition <- as.Date(date_string)
  } else {
    svy_edition <- Reduce(
      time_pattern[names_time[!names_time %in% remove_attributes]],
      f = function(x, y) {
        paste(x, y, sep = "_")
      }
    )
  }



  return(
    list(
      svy_type = svy_type %@% time_pattern$type,
      svy_edition = svy_edition,
      svy_periodicity = time_pattern$periodicity %||% "Annual"
    )
  )
}


#' Group dates
#' @param dates Vector of Date objects.
#' @param type Grouping type: "monthly", "quarterly", or "biannual".
#' @return Integer vector of group indices (e.g. 1-12 for
#'   monthly, 1-4 for quarterly).
#' @keywords utils
#' @examples
#' dates <- as.Date(c(
#'   "2023-01-15", "2023-04-20",
#'   "2023-07-10", "2023-11-05"
#' ))
#' group_dates(dates, "quarterly")
#' group_dates(dates, "biannual")
#' @family survey-loading
#' @export

group_dates <- function(dates, type = c("monthly", "quarterly", "biannual")) {
  type <- match.arg(type)
  dates_lt <- as.POSIXlt(dates)

  group <- integer(length(dates))

  if (type == "monthly") {
    group <- dates_lt$mon + 1
  } else if (type == "quarterly") {
    group <- (dates_lt$mon %/% 3) + 1
  } else if (type == "biannual") {
    group <- (dates_lt$mon %/% 6) + 1
  }

  names(group) <- dates

  return(group)
}


#' Configure weights by periodicity for Survey objects
#'
#' This function creates a weight structure that allows specifying different
#' weight variables according to estimation periodicity. It is essential for
#' proper functioning of workflows with multiple temporal estimation types.
#'
#' @param monthly String with monthly weight variable name, or replicate list
#'   created with \code{\link{add_replicate}} for monthly weights
#' @param annual String with annual weight variable name, or replicate list
#'   for annual weights
#' @param quarterly String with quarterly weight variable name, or replicate
#'   list for quarterly weights
#' @param biannual String with biannual weight variable name, or replicate
#'   list for biannual weights
#'
#' @return Named list with weight configuration by periodicity, which will be
#'   used by \code{\link{load_survey}} and \code{\link{workflow}} to
#'   automatically select the appropriate weight
#'
#' @details
#' This function is fundamental for surveys that require different weights
#' according to temporal estimation type. For example, Uruguay's ECH has
#' specific weights for monthly, quarterly, and annual estimations.
#'
#' Each parameter can be:
#' \itemize{
#'   \item A simple string with the weight variable name
#'   \item A replicate structure created with \code{add_replicate()}
#'     for bootstrap or jackknife estimations
#' }
#'
#' Weights are automatically selected in \code{workflow()} according to the
#' specified \code{estimation_type} parameter.
#'
#' @examples
#' # Basic configuration with simple weight variables
#' ech_weights <- add_weight(
#'   monthly = "pesomes",
#'   quarterly = "pesotri",
#'   annual = "pesoano"
#' )
#'
#' # With bootstrap replicates for variance estimation
#' weights_with_replicates <- add_weight(
#'   monthly = add_replicate(
#'     weight = "pesomes",
#'     replicate_pattern = "wr\\d+",
#'     replicate_path = "monthly_replicate_weights.xlsx",
#'     replicate_id = c("ID_HOGAR" = "ID"),
#'     replicate_type = "bootstrap"
#'   ),
#'   annual = "pesoano"
#' )
#'
#' @seealso
#' \code{\link{add_replicate}} to configure bootstrap/jackknife replicates
#' \code{\link{load_survey}} where this configuration is used
#' \code{\link{workflow}} that automatically selects weights
#'
#' @keywords utils
#' @family weights
#' @export
#'
add_weight <- function(
    monthly = NULL,
    annual = NULL,
    quarterly = NULL,
    biannual = NULL) {
  weight_list <- list(
    monthly = monthly,
    annual = annual,
    quarterly = quarterly,
    biannual = biannual
  )

  weight_list_clean <- weight_list[!vapply(weight_list, is.null, logical(1))]

  for (nm in names(weight_list_clean)) {
    w <- weight_list_clean[[nm]]
    valid <- (is.character(w) && length(w) == 1L && nzchar(w)) || is.list(w)
    if (!valid) {
      stop_input(
        "add_weight", nm,
        paste0(
          "must be a weight variable name (single string) ",
          "or an add_replicate() specification"
        ),
        got = describe_class(w)
      )
    }
  }

  return(weight_list_clean)
}

#' Configure replicate weights for variance estimation
#'
#' This function configures replicate weights (bootstrap, jackknife, etc.) that
#' allow estimation of variance for complex statistics in surveys with complex
#' sampling designs. It is essential for obtaining correct standard errors in
#' population estimates.
#'
#' @param weight String with the name of the main weight variable in the
#'   survey (e.g., "pesoano", "pesomes")
#' @param replicate_pattern String with regex pattern to identify replicate
#'   weight columns. Examples: "wr\\d+" for columns wr1, wr2, etc.
#' @param replicate_path Path to the file containing replicate weights.
#'   If NULL, assumes they are in the same main dataset
#' @param replicate_id Named vector specifying how to join between the main
#'   dataset and replicate file. Format: c("main_var" = "replicate_var")
#' @param replicate_type Type of replication used. Options:
#'   "bootstrap", "jackknife", "BRR" (Balanced Repeated Replication)
#'
#' @return List with replicate configuration that will be used by the
#'   sampling design for variance estimation
#'
#' @details
#' Replicate weights are essential for:
#' \itemize{
#'   \item Correctly estimating variance in complex designs
#'   \item Calculating appropriate confidence intervals
#'   \item Obtaining reliable coefficients of variation
#'   \item Performing valid statistical tests
#' }
#'
#' The regex pattern must exactly match the replicate weight column names
#' in the file. For example, if columns are named "wr001", "wr002", etc.,
#' use the pattern "wr\\\\d+".
#'
#' This function is typically used within \code{add_weight()} for more
#' complex weight configurations.
#'
#' @examples
#' # Basic configuration with external file
#' annual_replicates <- add_replicate(
#'   weight = "pesoano",
#'   replicate_pattern = "wr\\d+",
#'   replicate_path = "bootstrap_weights_2023.xlsx",
#'   replicate_id = c("ID_HOGAR" = "ID"),
#'   replicate_type = "bootstrap"
#' )
#'
#' # With replicates in same dataset
#' integrated_replicates <- add_replicate(
#'   weight = "main_weight",
#'   replicate_pattern = "rep_\\d{3}",
#'   replicate_type = "jackknife"
#' )
#'
#' # Use within add_weight
#' weight_config <- add_weight(
#'   annual = add_replicate(
#'     weight = "pesoano",
#'     replicate_pattern = "wr\\d+",
#'     replicate_path = "bootstrap_annual.xlsx",
#'     replicate_id = c("numero" = "ID_HOGAR"),
#'     replicate_type = "bootstrap"
#'   ),
#'   monthly = "pesomes"
#' )
#'
#' @seealso
#' \code{\link{add_weight}} for complete weight configuration
#' \code{\link[survey]{svrepdesign}} for replicate design in survey package
#' \code{\link{load_survey}} where this configuration is used
#'
#' @keywords utils
#' @family weights
#' @export

add_replicate <- function(
    weight,
    replicate_pattern,
    replicate_path = NULL,
    replicate_id = NULL,
    replicate_type) {
  replicate_list <- list(
    weight = weight,
    replicate_pattern = replicate_pattern,
    replicate_path = replicate_path,
    replicate_id = replicate_id,
    replicate_type = replicate_type
  )

  replicate_list_clean <- replicate_list[
    !vapply(replicate_list, is.null, logical(1))
  ]

  return(replicate_list_clean)
}

# --- Weight spec serialization/resolution ---

#' Convert a local replicate path to a portable source reference
#' @param path Local file path (or NULL)
#' @param edition Survey edition
#' @return List with provider/resource/edition, or NULL
#' @keywords internal
#' @noRd
.path_to_source <- function(path, edition = NULL) {
  if (is.null(path)) {
    return(NULL)
  }

  # Use first path if vector
  p <- if (length(path) > 1) path[1] else path
  basename_lower <- tolower(basename(p))

  resource <- NULL
  if (grepl(
    "bootstrap.*anual|anual.*bootstrap|bootstrap.*annual",
    basename_lower
  )) {
    resource <- "bootstrap_annual"
  } else if (grepl(
    "bootstrap.*mensual|mensual.*bootstrap|bootstrap.*monthly",
    basename_lower
  )) {
    resource <- "bootstrap_monthly"
  } else if (grepl(
    "bootstrap.*trimest|trimest.*bootstrap|bootstrap.*quarterly",
    basename_lower
  )) {
    resource <- "bootstrap_quarterly"
  } else if (grepl(
    "bootstrap.*semest|semest.*bootstrap|bootstrap.*semestral",
    basename_lower
  )) {
    resource <- "bootstrap_semestral"
  }

  if (!is.null(resource)) {
    return(list(
      provider = "anda",
      resource = resource,
      edition = as.character(edition)
    ))
  }

  list(
    provider = "local",
    path_hint = basename(p),
    edition = as.character(edition)
  )
}

#' Serialize a Survey weight list into portable weight_spec format
#'
#' Converts the in-memory weight list (output of add_weight()) into a
#' portable JSON-friendly format. Local replicate paths are replaced with
#' provider references.
#'
#' @param weight_list Named list from Survey$weight
#' @param edition Survey edition (used for replicate_source)
#' @return Named list suitable for JSON serialization
#' @keywords internal
#' @noRd
.serialize_weight_spec <- function(weight_list, edition = NULL) {
  if (is.null(weight_list) || length(weight_list) == 0) {
    return(NULL)
  }

  lapply(weight_list, function(w) {
    if (is.character(w)) {
      list(type = "simple", variable = w)
    } else if (is.list(w)) {
      spec <- list(
        type = "replicate",
        variable = w$weight,
        replicate_pattern = w$replicate_pattern,
        replicate_type = w$replicate_type
      )
      if (!is.null(w$replicate_id)) {
        spec$replicate_id <- list(
          survey_key = names(w$replicate_id)[1],
          replicate_key = unname(w$replicate_id)[1]
        )
      }
      spec$replicate_source <- .path_to_source(w$replicate_path, edition)
      spec
    } else {
      list(type = "simple", variable = as.character(w))
    }
  })
}

#' Resolve a portable weight specification to a usable weight configuration
#'
#' Converts the portable weight_spec from a RecipeWorkflow back into the
#' format expected by \code{load_survey()} and \code{add_weight()}.
#' For replicate weights with ANDA sources, automatically downloads the
#' replicate file.
#'
#' @param weight_spec Named list from RecipeWorkflow$weight_spec
#' @param dest_dir Character directory for downloaded files (default: tempdir())
#' @return Named list compatible with add_weight() output
#' @export
#' @examples
#' \dontrun{
#' wf <- api_get_workflow("w_123")
#' weight <- resolve_weight_spec(wf$weight_spec)
#' }
#' @family weights
resolve_weight_spec <- function(weight_spec, dest_dir = tempdir()) {
  if (is.null(weight_spec)) {
    return(NULL)
  }

  resolved <- lapply(weight_spec, function(ws) {
    if (ws$type == "simple") {
      ws$variable
    } else if (ws$type == "replicate") {
      replicate_path <- NULL
      src <- ws$replicate_source

      if (!is.null(src) && src$provider == "anda") {
        replicate_path <- anda_download_microdata(
          edition = src$edition,
          resource = src$resource,
          dest_dir = dest_dir
        )
      } else if (!is.null(src) && src$provider == "local") {
        warning(
          "Replicate source is local-only ('", src$path_hint,
          "'). Please provide the file manually.",
          call. = FALSE
        )
      }

      rep_id <- NULL
      if (!is.null(ws$replicate_id)) {
        rep_id <- stats::setNames(
          ws$replicate_id$replicate_key,
          ws$replicate_id$survey_key
        )
      }

      add_replicate(
        weight = ws$variable,
        replicate_pattern = ws$replicate_pattern,
        replicate_path = replicate_path,
        replicate_id = rep_id,
        replicate_type = ws$replicate_type
      )
    }
  })

  names(resolved) <- names(weight_spec)
  resolved
}

#' Reproduce a workflow from its published specification
#'
#' Given a RecipeWorkflow (typically fetched from the registry), downloads
#' the data, resolves the weight configuration, fetches referenced recipes,
#' and returns a Survey object ready for \code{workflow()} estimation.
#'
#' @param wf RecipeWorkflow object
#' @param data_path Character path to survey microdata. If NULL, attempts to
#'   download from ANDA for ECH surveys.
#' @param dest_dir Character directory for downloaded files
#' @return Survey object with recipes applied and weight configuration set
#' @export
#' @examples
#' \dontrun{
#' wf <- api_get_workflow("w_123")
#' svy <- reproduce_workflow(wf)
#' }
#' @family workflows
reproduce_workflow <- function(wf, data_path = NULL, dest_dir = tempdir()) {
  if (!inherits(wf, "RecipeWorkflow")) {
    stop("wf must be a RecipeWorkflow object", call. = FALSE)
  }

  svy_weight <- resolve_weight_spec(wf$weight_spec, dest_dir = dest_dir)

  if (is.null(data_path) && tolower(wf$survey_type) == "ech") {
    edition <- as.character(wf$edition)
    data_path <- anda_download_microdata(edition,
      resource = "implantation",
      dest_dir = dest_dir
    )
  }

  if (is.null(data_path)) {
    stop("Cannot resolve data source. Please provide data_path.", call. = FALSE)
  }

  recipes <- NULL
  if (length(wf$recipe_ids) > 0) {
    backend <- tryCatch(get_backend(), error = function(e) NULL)
    if (!is.null(backend)) {
      recipe_list <- list()
      for (rid in wf$recipe_ids) {
        r <- tryCatch(backend$get(rid), error = function(e) NULL)
        if (!is.null(r)) recipe_list <- c(recipe_list, list(r))
      }
      if (length(recipe_list) > 0) recipes <- recipe_list
    }
  }

  load_survey(
    path = data_path,
    svy_type = wf$survey_type,
    svy_edition = as.character(wf$edition),
    svy_weight = svy_weight,
    recipes = recipes,
    bake = !is.null(recipes)
  )
}

#' Evaluate estimation with Coefficient of Variation
#' @param cv Numeric coefficient of variation value.
#' @return Character string with the quality category
#'   (e.g. "Excellent", "Good"), or \code{NA} when the CV is not
#'   defined (e.g. a zero estimate, where CV = 0/0).
#' @keywords utils
#' @examples
#' evaluate_cv(3) # "Excellent"
#' evaluate_cv(12) # "Good"
#' evaluate_cv(30) # "Use with caution"
#' evaluate_cv(NaN) # NA
#' @family workflows
#' @export

evaluate_cv <- function(cv) {
  if (!is.finite(cv)) {
    return(NA_character_)
  }
  if (cv < 5) {
    return("Excellent")
  } else if (cv >= 5 && cv < 10) {
    return("Very good")
  } else if (cv >= 10 && cv < 15) {
    return("Good")
  } else if (cv >= 15 && cv < 25) {
    return("Acceptable")
  } else if (cv >= 25 && cv < 35) {
    return("Use with caution")
  } else {
    return("Do not publish")
  }
}
