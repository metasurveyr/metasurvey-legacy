#' Load survey from file and create Survey object
#'
#' This function reads survey files in multiple formats and creates a Survey
#' object with all necessary metadata for subsequent analysis. Supports various
#' survey types with specific configurations for each one.
#'
#' @param path Path to the survey file. Supports multiple formats: csv, xlsx,
#'   dta (Stata), sav (SPSS), rds (R). If NULL, survey arguments must be
#'   specified to create an empty object
#' @param svy_type Survey type as string. Supported types:
#'   \itemize{
#'     \item "ech": Encuesta Continua de Hogares (Uruguay)
#'     \item "eph": Encuesta Permanente de Hogares (Argentina)
#'     \item "eai": Encuesta de Actividades de Innovación (Uruguay)
#'     \item "eaii": Encuesta de Actividades de Innovación e I+D (Uruguay)
#'   }
#' @param svy_edition Survey edition as string. Supports different temporal
#'   patterns:
#'   \itemize{
#'     \item "YYYY": Year (e.g., "2023")
#'     \item "YYYYMM" or "MMYYYY": Year-month (e.g., "202301" or "012023")
#'     \item "YYYY-YYYY": Year range (e.g., "2020-2022")
#'   }
#' @param svy_weight List with weight information specifying periodicity and
#'   weight variable name. Use helper function \code{\link{add_weight}}
#' @param svy_psu Primary sampling unit (PSU) variable as string
#' @param svy_strata Stratification variable name as string (optional).
#'   Used in [survey::svydesign()] for stratified sampling designs.
#' @param ... Additional arguments passed to specific reading functions
#' @param bake Logical indicating whether recipes are processed automatically
#'   when loading data. Defaults to FALSE
#' @param recipes Recipe object obtained with \code{\link{get_recipe}}.
#'   If bake=TRUE, these recipes are applied automatically
#'
#' @return `Survey` object with structure:
#'   \itemize{
#'     \item \code{data}: Survey data
#'     \item \code{metadata}: Information about type, edition, weights
#'     \item \code{steps}: History of applied transformations
#'     \item \code{recipes}: Available recipes
#'     \item \code{design}: Sample design information
#'   }
#'
#' @details
#' The function automatically detects file format and uses the appropriate
#' reader. For each survey type, it applies specific configurations such as
#' standard variables, data types, and validations.
#'
#' When \code{bake=TRUE} is specified, recipes are applied immediately after
#' loading the data, creating an analysis-ready object.
#'
#' If no \code{path} is provided, an empty Survey object is created that can
#' be used to build step pipelines without initial data.
#'
#' @examples
#' \dontrun{
#' # Load ECH 2023 with recipes
#' ech_2023 <- load_survey(
#'   path = "data/ech_2023.csv",
#'   svy_type = "ech",
#'   svy_edition = "2023",
#'   svy_weight = add_weight(annual = "pesoano"),
#'   recipes = get_recipe("ech", "2023"),
#'   bake = TRUE
#' )
#'
#' # Load monthly survey
#' ech_january <- load_survey(
#'   path = "data/ech_202301.dta",
#'   svy_type = "ech",
#'   svy_edition = "202301",
#'   svy_weight = add_weight(monthly = "pesomes")
#' )
#'
#' # Create empty object for pipeline
#' pipeline <- load_survey(
#'   svy_type = "ech",
#'   svy_edition = "2023"
#' ) %>%
#'   step_compute(new_var = operation)
#'
#' # With included example data
#' ech_example <- load_survey(
#'   path = load_survey_example("ech", "ech_2022"),
#'   svy_type = "ech",
#'   svy_edition = "2022",
#'   svy_weight = add_weight(annual = "pesoano")
#' )
#' }
#'
#' @seealso
#' \code{\link{add_weight}} to specify weights
#' \code{\link{get_recipe}} to get available recipes
#' \code{\link{load_survey_example}} to load example data
#' \code{\link{load_panel_survey}} for panel surveys
#'
#' @keywords preprocessing
#' @family survey-loading
#' @export
load_survey <- function(
  path = NULL,
  svy_type = NULL,
  svy_edition = NULL,
  svy_weight = NULL,
  svy_psu = NULL,
  svy_strata = NULL,
  ..., bake = FALSE,
  recipes = NULL
) {
  path_null <- missing(path)

  svy_args_null <- missing(svy_type) ||
    missing(svy_edition) || missing(svy_weight)


  if (
    path_null && svy_args_null
  ) {
    stop(
      "Must provide either a file path or a survey type with edition",
      call. = FALSE
    )
  }

  .engine <- getOption("metasurvey.engine")

  .namespace <- ls(
    envir = asNamespace("metasurvey"),
    pattern = "load_survey"
  )

  .args <- list(
    file = path,
    svy_type = svy_type,
    svy_edition = svy_edition,
    svy_weight = svy_weight,
    svy_psu = svy_psu,
    svy_strata = svy_strata,
    .engine_name = .engine,
    bake = bake,
    recipes = recipes,
    ...
  )


  .call_engine <- paste0(
    "load_survey.",
    .engine
  )


  do.call(
    .call_engine,
    args = .args
  )
}


#' @title Read panel survey files from different formats
#'   and create a RotativePanelSurvey object
#' @param path_implantation Survey implantation path, file
#'   can be in different formats, csv, xtsx, dta, sav and
#'   rds
#' @param path_follow_up Path with all the needed files
#'   with only survey valid files but also can be character
#'   vector with path files.
#' @param svy_type String with the survey type, supported
#'   types; "ech" (Encuensta Continua de Hogares, Uruguay),
#'   "eph" (Encuesta Permanente de Hogares, Argentina),
#'   "eai" (Encuesta de Actividades de Innovacion, Uruguay)
#' @param svy_weight_implantation List with survey
#'   implantation weights information specifing periodicity
#'   and the name of the weight variable. Recomended to use
#'   the helper function add_weight().
#' @param svy_weight_follow_up List with survey follow_up
#'   weights information specifing periodicity and the name
#'   of the weight variable. Recomended to use the helper
#'   function add_weight().
#' @param svy_strata Stratification variable name (character or NULL).
#'   Passed to Survey$new(strata = ...).
#' @param ... Further arguments to be passed to
#'   load_panel_survey
#' @return RotativePanelSurvey object
#' @examples
#' \dontrun{
#' # example code
#' path_dir <- here::here("example-data", "ech", "ech_2023")
#' ech_2023 <- load_panel_survey(
#'   path_implantation = file.path(
#'     path_dir,
#'     "ECH_implantacion_2023.csv"
#'   ),
#'   path_follow_up = file.path(
#'     path_dir,
#'     "seguimiento"
#'   ),
#'   svy_type = "ECH_2023",
#'   svy_weight_implantation = add_weight(
#'     annual = "W_ANO"
#'   ),
#'   svy_weight_follow_up = add_weight(
#'     monthly = add_replicate(
#'       "W",
#'       replicate_path = file.path(
#'         path_dir,
#'         c(
#'           "Pesos replicados Bootstrap mensuales enero_junio 2023",
#'           "Pesos replicados Bootstrap mensuales julio_diciembre 2023"
#'         ),
#'         c(
#'           "Pesos replicados mensuales enero_junio 2023",
#'           "Pesos replicados mensuales Julio_diciembre 2023"
#'         )
#'       ),
#'       replicate_id = c("ID" = "ID"),
#'       replicate_pattern = "wr[0-9]+",
#'       replicate_type = "bootstrap"
#'     )
#'   )
#' )
#' }
#' \dontrun{
#' # Example of loading a panel survey
#' panel_survey <- load_panel_survey(
#'   path_implantation = "path/to/implantation.csv",
#'   path_follow_up = "path/to/follow_up",
#'   svy_type = "ech",
#'   svy_weight_implantation = add_weight(annual = "w_ano"),
#'   svy_weight_follow_up = add_weight(monthly = "w_monthly")
#' )
#' print(panel_survey)
#' }
#' @keywords preprocessing
#' @family survey-loading
#' @export

load_panel_survey <- function(
  path_implantation,
  path_follow_up,
  svy_type,
  svy_weight_implantation,
  svy_weight_follow_up,
  svy_strata = NULL,
  ...
) {
  names_survey <- gsub(
    "\\..*",
    "",
    list.files(path_follow_up, full.names = FALSE, pattern = ".csv")
  )

  if (length(names(svy_weight_follow_up)) > 1) {
    stop(
      "The follow-up survey must have a single weight time pattern",
      call. = FALSE
    )
  }

  time_pattern_follow_up <- names(svy_weight_follow_up)

  if (is(svy_weight_follow_up[[1]], "list")) {
    svy_weight_follow_up <- svy_weight_follow_up[[1]]
  }

  path_survey <- list.files(path_follow_up, full.names = TRUE, pattern = ".csv")

  names(path_survey) <- names_survey


  implantation <- load_survey(
    path_implantation,
    svy_type = svy_type,
    svy_edition = basename(path_implantation),
    svy_weight = svy_weight_implantation,
    svy_strata = svy_strata
  )

  if (!is.null(svy_weight_follow_up$replicate_path)) {
    path_file <- svy_weight_follow_up$replicate_path
    path_file_final <- c()

    for (i in path_file) {
      if (file.info(i)$isdir) {
        path_file_final <- c(
          path_file_final,
          list.files(i, full.names = TRUE, pattern = ".csv")
        )
      } else {
        path_file_final <- c(path_file_final, i)
      }
    }


    names_year_month <- vapply(
      X = basename(path_file_final),
      FUN = function(x) {
        time_pattern <- extract_time_pattern(x)
        if (time_pattern$periodicity != "Monthly") {
          stop(
            "The periodicity of the file is not monthly",
            call. = FALSE
          )
        } else {
          return(
            time_pattern$year * 100 + time_pattern$month
          )
        }
      },
      FUN.VALUE = numeric(1),
      USE.NAMES = FALSE
    )

    names(path_file_final) <- names_year_month


    svy_weight_follow_up <- lapply(
      X = as.character(names_year_month),
      FUN = function(x) {
        replicate <- list(
          add_replicate(
            "W",
            replicate_path = unname(path_file_final[x]),
            replicate_id = c("ID" = "ID"),
            replicate_pattern = "wr[0-9]+",
            replicate_type = "bootstrap"
          )
        )

        names(replicate) <- time_pattern_follow_up

        return(replicate)
      }
    )

    names(svy_weight_follow_up) <- names_year_month

    names_path_survey_year_month <- vapply(
      X = names(path_survey),
      FUN = function(x) {
        time_pattern <- extract_time_pattern(x)
        if (time_pattern$periodicity != "Monthly") {
          stop(
            "The periodicity of the file is not monthly",
            call. = FALSE
          )
        } else {
          return(
            time_pattern$year * 100 + time_pattern$month
          )
        }
      },
      FUN.VALUE = numeric(1),
      USE.NAMES = FALSE
    )

    names(path_survey) <- names_path_survey_year_month

    follow_up <- lapply(
      X = seq_along(path_survey),
      FUN = function(x) {
        y <- path_survey[[x]]
        z <- names(path_survey)[x]
        svy_weight <- unname(svy_weight_follow_up[z])[[1]]

        load_survey(
          y,
          svy_type = svy_type,
          svy_edition = basename(y),
          svy_weight = svy_weight,
          svy_strata = svy_strata
        )
      }
    )

    names(follow_up) <- names_survey
  } else {
    follow_up <- lapply(
      X = names(path_survey),
      FUN = function(x) {
        load_survey(
          path_survey[[x]],
          svy_type = svy_type,
          svy_edition = x,
          svy_weight = svy_weight_follow_up,
          svy_strata = svy_strata
        )
      }
    )

    names(follow_up) <- names_survey
  }

  return(
    RotativePanelSurvey$new(
      implantation = implantation,
      follow_up = follow_up,
      type = svy_type,
      default_engine = "data.table",
      steps = NULL,
      recipes = NULL,
      workflows = NULL,
      design = NULL
    )
  )
}

#' Read file with data.table
#' @param file Path to the file
#' @param .args Additional arguments
#' @keywords internal
#' @noRd
#' @return data.table

read_file <- function(file, .args = NULL, convert = FALSE) {
  .extension <- gsub(".*\\.", "", file)
  .file_name <- basename(file)

  .path_without_extension <- gsub("\\..*", "", .file_name)
  .output_file <- paste0(.path_without_extension, ".csv")
  .output_file <- file.path(
    dirname(file),
    .output_file
  )


  if (convert) {
    if (.extension != ".csv" && !file.exists(.output_file)) {
      if (!requireNamespace("rio", quietly = TRUE)) {
        stop(
          "Package 'rio' is required. ",
          "Install it with: install.packages('rio')",
          call. = FALSE
        )
      }
      rio::convert(
        in_file = file,
        out_file = .output_file
      )
      .extension <- "csv"
    } else {
      .extension <- "csv"
    }
  }

  .read_function <- switch(.extension,
    sav = list(package = "foreign", read_function = "read.spss"),
    dta = list(package = "foreign", read_function = "read.dta"),
    csv = list(package = "data.table", read_function = "fread"),
    xlsx = list(package = "openxlsx", read_function = "read.xlsx"),
    rds = list(package = "base", read_function = "readRDS"),
    stop("Unsupported file type: ", .extension, call. = FALSE)
  )

  if (!requireNamespace(.read_function$package, quietly = TRUE)) {
    stop(
      "Package '", .read_function$package,
      "' is required to read .", .extension, " files. ",
      "Please install it with: install.packages('",
      .read_function$package, "')",
      call. = FALSE
    )
  }

  # Use the original file path (not .output_file) unless convert was used
  .actual_file <- if (convert) .output_file else file

  if (is.null(.args)) {
    .read_fn <- get(.read_function$read_function,
      envir = asNamespace(.read_function$package),
      mode = "function"
    )
    .args <- list(.actual_file)
    names(.args) <- names(formals(.read_fn)[1])
  } else {
    .args$file <- .actual_file
  }

  .names_args <- names(.args)

  .metadata_args <- metadata_args()

  .names_args <- .names_args[!.names_args %in% .metadata_args]


  .fn <- get(.read_function$read_function,
    envir = asNamespace(.read_function$package),
    mode = "function"
  )

  # foreign::read.spss needs to.data.frame = TRUE to return a data.frame
  call_args <- .args[.names_args]
  if (.extension == "sav" && !"to.data.frame" %in% names(call_args)) {
    call_args$to.data.frame <- TRUE
  }

  df <- do.call(.fn, args = call_args)
  return(data.table::data.table(df))
}


#' Load survey with data.table
#' @param ... Additional arguments
#' @inheritDotParams  load_survey
#' @seealso data.table::fread foreign::read.spss openxlsx::loadWorkbook
#' @return Survey object
#' @importFrom data.table fread
#' @noRd
#' @keywords internal

load_survey.data.table <- function(...) {
  .engine_name <- "data.table"

  .args <- list(...)

  .names_args <- names(.args)

  .metadata_args <- metadata_args()

  .names_args <- .names_args[!.names_args %in% .metadata_args]


  svy <- read_file(.args$file, .args[.names_args])

  if (!is.null(.args$recipes)) {
    if (get_distinct_recipes(.args$recipes) > 1) {
      index_valid_recipes <- vapply(
        X = seq_len(get_distinct_recipes(.args$recipes)),
        FUN = function(x) {
          validate_recipe(
            svy_type = .args$svy_type,
            svy_edition = .args$svy_edition,
            recipe_svy_edition = .args$recipes[[x]]$edition,
            recipe_svy_type = .args$recipes[[x]]$survey_type
          )
        },
        FUN.VALUE = logical(1)
      )
    } else {
      # Single recipe: could be an R6 object directly or list(R6_object)
      single_recipe <- if (inherits(.args$recipes, "Recipe")) {
        .args$recipes
      } else {
        .args$recipes[[1]]
      }
      index_valid_recipes <- validate_recipe(
        svy_type = .args$svy_type,
        svy_edition = .args$svy_edition,
        recipe_svy_edition = single_recipe$edition,
        recipe_svy_type = single_recipe$survey_type
      )
      if (!index_valid_recipes) {
        metasurvey_msg(
          "Invalid Recipe: \n",
          single_recipe$name
        )
        .args$recipes <- NULL
      }
    }
  }


  Survey <- Survey$new(
    data = svy,
    edition = .args$svy_edition,
    type = .args$svy_type,
    psu = .args$svy_psu,
    strata = .args$svy_strata,
    engine = .engine_name,
    weight = .args$svy_weight,
    recipes = .args$recipes %||% NULL
  )

  # Record source path in provenance
  if (!is.null(.args$path) && !is.null(Survey$provenance)) {
    Survey$provenance$source$path <- normalizePath(
      .args$path,
      mustWork = FALSE
    )
  }

  if (.args$bake %||% FALSE) {
    return(bake_recipes(Survey))
  } else {
    return(Survey)
  }
}


#' Config survey
#' @inheritDotParams load_survey
#' @noRd
#' @keywords internal

config_survey <- function(...) {
  match.call()[[1]]
}


#' Check valid recipe
#' @param svy_type Type of survey
#' @param svy_edition Edition of the survey
#' @param recipe_svy_edition Edition of the recipe
#' @param recipe_svy_type Type of the recipe
#' @return Logical
#' @keywords internal

validate_recipe <- function(svy_type, svy_edition,
                            recipe_svy_edition,
                            recipe_svy_type) {
  equal_type <- any(
    tolower(svy_type) == tolower(recipe_svy_type)
  )

  equal_edition <- any(svy_edition %in% recipe_svy_edition)

  return(equal_type && equal_edition)
}
