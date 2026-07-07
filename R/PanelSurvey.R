#' @title RotativePanelSurvey Class
#' @description This class represents a rotative panel survey,
#' which includes implantation and follow-up surveys.
#' It provides methods to access and manipulate survey data,
#' steps, recipes, workflows, and designs.
#' @field implantation A survey object representing the implantation survey.
#' @field follow_up A list of survey objects representing the follow-up surveys.
#' @field type A string indicating the type of the survey.
#' @field default_engine A string specifying the default
#' engine used for processing.
#' @field steps A list of steps applied to the survey.
#' @field recipes A list of recipes associated with the survey.
#' @field workflows A list of workflows associated with the survey.
#' @field design A design object for the survey.
#' @field periodicity A list containing the periodicity of
#' the implantation and follow-up surveys.
#' @return An object of class \code{RotativePanelSurvey}.
#' @keywords panel-survey
#'
#' @examples
#' impl <- Survey$new(
#'   data = data.table::data.table(id = 1:5, w = 1),
#'   edition = "2023", type = "ech", psu = NULL,
#'   engine = "data.table", weight = add_weight(annual = "w")
#' )
#' fu1 <- Survey$new(
#'   data = data.table::data.table(id = 1:5, w = 1),
#'   edition = "2023_01", type = "ech", psu = NULL,
#'   engine = "data.table", weight = add_weight(annual = "w")
#' )
#' panel <- RotativePanelSurvey$new(
#'   implantation = impl, follow_up = list(fu1),
#'   type = "ech", default_engine = "data.table",
#'   steps = list(), recipes = list(), workflows = list(), design = NULL
#' )
#'
#' @family panel-surveys
#' @export
RotativePanelSurvey <- R6Class(
  "RotativePanelSurvey",
  public = list(
    implantation = NULL,
    follow_up = NULL,
    type = NULL,
    default_engine = NULL,
    steps = NULL,
    recipes = NULL,
    workflows = NULL,
    design = NULL,
    periodicity = NULL,

    #' @description Initializes a new instance of the
    #' RotativePanelSurvey class.
    #' @param implantation A survey object representing the implantation survey.
    #' @param follow_up A list of survey objects representing
    #' the follow-up surveys.
    #' @param type A string indicating the type of the survey.
    #' @param default_engine A string specifying the default
    #' engine used for processing.
    #' @param steps A list of steps applied to the survey.
    #' @param recipes A list of recipes associated with the survey.
    #' @param workflows A list of workflows associated with the survey.
    #' @param design A design object for the survey.
    initialize = function(implantation, follow_up, type,
                          default_engine, steps, recipes,
                          workflows, design) {
      self$implantation <- implantation
      self$follow_up <- follow_up
      self$type <- type
      self$default_engine <- default_engine
      self$steps <- steps
      self$recipes <- recipes
      self$workflows <- workflows
      self$design <- design

      follow_up_types <- vapply(
        self$follow_up,
        function(f) f$periodicity,
        character(1)
      )

      if (length(unique(follow_up_types)) > 1) {
        stop("All follow-up surveys must have the same type", call. = FALSE)
      }

      self$periodicity <- list(
        implantation = self$implantation$periodicity,
        follow_up = unique(follow_up_types)
      )
    },

    #' @description Retrieves the implantation survey.
    #' @return A survey object representing the implantation survey.
    get_implantation = function() {
      return(self$implantation)
    },

    #' @description Retrieves the follow-up surveys.
    #' @param index An integer specifying the index of the
    #' follow-up survey to retrieve.
    #' @param monthly A vector of integers specifying monthly intervals.
    #' @param quarterly A vector of integers specifying quarterly intervals.
    #' @param semiannual A vector of integers specifying semiannual intervals.
    #' @param annual A vector of integers specifying annual intervals.
    #' @return A list of follow-up surveys matching the specified criteria.
    get_follow_up = function(index = length(self$follow_up),
                             monthly = NULL,
                             quarterly = NULL,
                             semiannual = NULL,
                             annual = NULL) {
      return(self$follow_up[index])
    },

    #' @description Retrieves the type of the survey.
    #' @return A string indicating the type of the survey.
    get_type = function() {
      return(self$type)
    },

    #' @description Retrieves the default engine used for processing.
    #' @return A string specifying the default engine.
    get_default_engine = function() {
      return(self$default_engine)
    },

    #' @description Retrieves the steps applied to the survey.
    #' @return A list containing the steps for the
    #' implantation and follow-up surveys.
    get_steps = function() {
      steps_implantation <- self$implantation$steps
      steps_follow_up <- lapply(self$follow_up, function(f) f$steps)

      return(list(
        implantation = steps_implantation,
        follow_up = steps_follow_up
      ))
    },

    #' @description Retrieves the recipes associated with the survey.
    #' @return A list of recipes.
    get_recipes = function() {
      return(self$recipes)
    },

    #' @description Retrieves the workflows associated with the survey.
    #' @return A list of workflows.
    get_workflows = function() {
      return(self$workflows)
    },

    #' @description Retrieves the design object for the survey.
    #' @return A design object.
    get_design = function() {
      return(self$design)
    },

    #' @description Prints metadata about the RotativePanelSurvey object.
    print = function() {
      get_metadata(self = self)
    }
  )
)

#' Extract surveys by periodicity from a rotating panel
#'
#' Extracts subsets of surveys from a RotativePanelSurvey object based on
#' temporal criteria. Allows obtaining surveys for different types of analysis
#' (monthly, quarterly, annual) respecting the rotating panel's temporal
#' structure.
#'
#' @param RotativePanelSurvey A \code{RotativePanelSurvey} object containing
#'   the rotating panel surveys organized temporally
#' @param index Integer vector specifying survey indices to extract. If a single
#'   value, returns that survey; if a vector, returns a list
#' @param monthly Integer vector specifying which months to extract for
#'   monthly analysis (1-12)
#' @param annual Integer vector specifying which years to extract for
#'   annual analysis
#' @param quarterly Integer vector specifying which quarters to extract
#'   for quarterly analysis (1-4)
#' @param biannual Integer vector specifying which semesters to extract
#'   for biannual analysis (1-2)
#' @param use.parallel Logical indicating whether to use parallel processing
#'   for intensive operations. Default FALSE
#'
#' @return A list of \code{Survey} objects matching the specified criteria,
#'   or a single \code{Survey} object if a single index is specified
#'
#' @details
#' This function is essential for working with rotating panels because:
#' \itemize{
#'   \item Enables periodicity-based analysis: Extract data for different
#'     types of temporal estimations
#'   \item Preserves temporal structure: Respects temporal relationships
#'     between different panel waves
#'   \item Optimizes memory: Only loads surveys needed for the analysis
#'   \item Facilitates comparisons: Extract specific periods for
#'     comparative analysis
#'   \item Supports parallelization: For operations with large data volumes
#' }
#'
#' Extraction criteria are interpreted according to survey frequency:
#' - For monthly ECH: monthly=c(1,3,6) extracts January, March and June
#' - For annual analysis: annual=1 typically extracts the first available year
#' - For quarterly analysis: quarterly=c(1,4) extracts Q1 and Q4
#'
#' If no criteria are specified, the function returns the implantation survey
#' with a warning.
#'
#' @examples
#' \dontrun{
#' # Load rotating panel
#' panel_ech <- load_panel_survey(
#'   path = "ech_panel_2023.dta",
#'   svy_type = "ech_panel",
#'   svy_edition = "2023"
#' )
#'
#' # Extract specific monthly surveys
#' ech_q1 <- extract_surveys(
#'   panel_ech,
#'   monthly = c(1, 2, 3) # January, February, March
#' )
#'
#' # Extract by index
#' ech_first <- extract_surveys(panel_ech, index = 1)
#' ech_several <- extract_surveys(panel_ech, index = c(1, 3, 6))
#'
#' # Quarterly analysis
#' ech_Q1_Q4 <- extract_surveys(
#'   panel_ech,
#'   quarterly = c(1, 4)
#' )
#'
#' # Annual analysis (typically all surveys for the year)
#' ech_annual <- extract_surveys(
#'   panel_ech,
#'   annual = 1
#' )
#'
#' # With parallel processing for large volumes
#' ech_full <- extract_surveys(
#'   panel_ech,
#'   monthly = 1:12,
#'   use.parallel = TRUE
#' )
#'
#' # Use in workflow
#' results <- workflow(
#'   survey = extract_surveys(panel_ech, quarterly = c(1, 2)),
#'   svymean(~unemployed, na.rm = TRUE),
#'   estimation_type = "quarterly"
#' )
#' }
#'
#' @seealso
#' \code{\link{load_panel_survey}} for loading rotating panels
#' \code{\link{get_implantation}} for obtaining implantation data
#' \code{\link{get_follow_up}} for obtaining follow-up data
#' \code{\link{workflow}} for using extracted surveys in analysis
#'
#' @keywords panel-survey
#' @family panel-surveys
#' @export

extract_surveys <- function(RotativePanelSurvey,
                            index = NULL,
                            monthly = NULL,
                            annual = NULL,
                            quarterly = NULL,
                            biannual = NULL,
                            use.parallel = FALSE) {
  if (is.null(monthly) && is.null(annual) && is.null(quarterly) && is.null(biannual) && is.null(index)) {
    warning(paste0(
      "At least one interval argument must be ",
      "different from NULL. ",
      "Returning the implantation survey."
    ), call. = FALSE)
    annual <- 1
  }

  if (!inherits(
    RotativePanelSurvey,
    "RotativePanelSurvey"
  )) {
    stop(paste0(
      "The `RotativeSurvey` argument must be an ",
      "object of class `RotativePanelSurvey`"
    ), call. = FALSE)
  }

  follow_up <- RotativePanelSurvey$follow_up

  if (!is.null(index)) {
    if (length(index) > 1) {
      return(follow_up[index])
    }
    return(follow_up[[index]])
  }

  dates <- as.Date(vapply(
    unname(follow_up),
    function(x) as.character(x$edition),
    character(1)
  ))

  ts_series <- stats::ts(
    seq_along(follow_up),
    start = c(
      as.numeric(format(min(dates), "%Y")),
      as.numeric(format(min(dates), "%m"))
    ),
    frequency = 12
  )

  apply_interval <- function(ts_series, start_year,
                             start_month, end_year,
                             end_month) {
    as.vector(stats::window(
      ts_series,
      start = c(start_year, start_month),
      end = c(end_year, end_month)
    ))
  }

  apply_func <- if (use.parallel) {
    if (!requireNamespace("parallel", quietly = TRUE)) {
      stop(
        "Package 'parallel' is required. ",
        "Install it with: install.packages('parallel')",
        call. = FALSE
      )
    }
    parallel::mclapply
  } else {
    base::lapply
  }

  results <- list()

  # Create only the specified intervals and avoid empty lists
  month_names <- c(
    "January", "February", "March", "April",
    "May", "June", "July", "August",
    "September", "October", "November",
    "December"
  )
  if (!is.null(monthly)) {
    results$monthly <- list()
    for (month in monthly) {
      indices <- apply_interval(
        ts_series,
        as.numeric(format(min(dates), "%Y")),
        month,
        as.numeric(format(max(dates), "%Y")),
        month
      )
      results$monthly[[month_names[month]]] <-
        follow_up[indices]
    }
  }

  if (!is.null(annual)) {
    results$annual <- list()
    for (year in annual) {
      indices <- apply_interval(ts_series, year, 1, year, 12)
      results$annual[[as.character(year)]] <- follow_up[indices]
    }
  }

  quarter_names <- c("Q1", "Q2", "Q3", "Q4")
  if (!is.null(quarterly)) {
    results$quarterly <- list()
    for (quarter in quarterly) {
      start_month <- (quarter - 1) * 3 + 1
      end_month <- start_month + 2
      indices <- apply_interval(
        ts_series,
        as.numeric(format(min(dates), "%Y")),
        start_month,
        as.numeric(format(max(dates), "%Y")),
        end_month
      )
      results$quarterly[[quarter_names[quarter]]] <-
        follow_up[indices]
    }
  }

  biannual_names <- c("H1", "H2")
  if (!is.null(biannual)) {
    results$biannual <- list()
    for (semester in biannual) {
      start_month <- ifelse(semester == 1, 1, 7)
      end_month <- ifelse(semester == 1, 6, 12)
      indices <- apply_interval(
        ts_series,
        as.numeric(format(min(dates), "%Y")),
        start_month,
        as.numeric(format(max(dates), "%Y")),
        end_month
      )
      results$biannual[[biannual_names[semester]]] <-
        follow_up[indices]
    }
  }

  return(PoolSurvey$new(results))
}

#' @title PoolSurvey Class
#' @description This class represents a collection of
#' surveys grouped by specific periods
#' (e.g., monthly, quarterly, annual).
#' It provides methods to access and manipulate the grouped surveys.
#' @field surveys A list containing the grouped surveys.
#' @return An object of class \code{PoolSurvey}.
#' @keywords panel-survey
#'
#' @examples
#' s1 <- Survey$new(
#'   data = data.table::data.table(id = 1:3, w = 1),
#'   edition = "2023", type = "test", psu = NULL,
#'   engine = "data.table", weight = add_weight(annual = "w")
#' )
#' s2 <- Survey$new(
#'   data = data.table::data.table(id = 4:6, w = 1),
#'   edition = "2023", type = "test", psu = NULL,
#'   engine = "data.table", weight = add_weight(annual = "w")
#' )
#' pool <- PoolSurvey$new(list(annual = list("group1" = list(s1, s2))))
#'
#' @family panel-surveys
#' @export
PoolSurvey <- R6Class(
  "PoolSurvey",
  public = list(
    surveys = NULL,

    #' @description Initializes a new instance of the PoolSurvey class.
    #' @param surveys A list containing the grouped surveys.
    initialize = function(surveys) {
      self$surveys <- surveys
    },

    #' @description Retrieves surveys for a specific period.
    #' @param period A string specifying the period to
    #' retrieve (e.g., "monthly", "quarterly").
    #' @return A list of surveys for the specified period.
    get_surveys = function(period = NULL) {
      if (!is.null(period)) {
        return(self$surveys[[1]][[period]])
      } else {
        return(self$surveys)
      }
    },

    #' @description Prints metadata about the PoolSurvey object.
    print = function() {
      get_metadata(self = self)
    }
  )
)

#' Get implantation survey from a rotating panel
#'
#' Extracts the implantation (baseline) survey from a RotativePanelSurvey
#' object. The implantation survey represents the first data collection wave
#' and is essential for establishing the baseline and structural
#' characteristics of the panel.
#'
#' @param RotativePanelSurvey A \code{RotativePanelSurvey} object from which
#'   to extract the implantation survey
#'
#' @return A \code{Survey} object containing the implantation survey with all
#'   its metadata, data, and design configuration
#'
#' @details
#' The implantation survey is special in a rotating panel because:
#' \itemize{
#'   \item Establishes the baseline: Defines initial characteristics of all
#'     panel units
#'   \item Contains the full sample: Includes all units that will participate
#'     in the different panel waves
#'   \item Defines temporal structure: Establishes rotation and follow-up
#'     patterns
#'   \item Configures metadata: Contains information about periodicity,
#'     key variables, and stratification
#'   \item Serves as tracking reference: Basis for unit tracking in
#'     subsequent waves
#' }
#'
#' This function is essential for analysis requiring:
#' - Temporal comparisons from the baseline
#' - Analysis of the complete panel structure
#' - Configuration of longitudinal models
#' - Evaluation of sampling design quality
#'
#' @examples
#' impl <- Survey$new(
#'   data = data.table::data.table(id = 1:5, w = 1),
#'   edition = "2023", type = "test", psu = NULL,
#'   engine = "data.table", weight = add_weight(annual = "w")
#' )
#' fu <- Survey$new(
#'   data = data.table::data.table(id = 1:5, w = 1),
#'   edition = "2023_01", type = "test", psu = NULL,
#'   engine = "data.table", weight = add_weight(annual = "w")
#' )
#' panel <- RotativePanelSurvey$new(
#'   implantation = impl, follow_up = list(fu),
#'   type = "test", default_engine = "data.table",
#'   steps = list(), recipes = list(), workflows = list(), design = NULL
#' )
#' get_implantation(panel)
#'
#' @seealso
#' \code{\link{get_follow_up}} for obtaining follow-up surveys
#' \code{\link{extract_surveys}} for extracting multiple surveys by criteria
#' \code{\link{load_panel_survey}} for loading rotating panels
#' \code{\link{workflow}} for analysis with the implantation survey
#'
#' @keywords panel-survey
#' @family panel-surveys
#' @export

get_implantation <- function(RotativePanelSurvey) {
  if (!inherits(
    RotativePanelSurvey,
    "RotativePanelSurvey"
  )) {
    stop(paste0(
      "The `RotativeSurvey` argument must be ",
      "an object of class ",
      "`RotativePanelSurvey`"
    ))
  }

  return(RotativePanelSurvey$implantation)
}

#' Get follow-up surveys from a rotating panel
#'
#' Extracts one or more follow-up surveys (waves after the implantation) from
#' a RotativePanelSurvey object. Follow-up surveys represent subsequent data
#' collections and are essential for longitudinal and temporal change analysis.
#'
#' @param RotativePanelSurvey A \code{RotativePanelSurvey} object from which
#'   to extract the follow-up surveys
#' @param index Integer vector specifying which follow-up surveys to extract.
#'   Defaults to all available (1:length(follow_up)). Can be a single index
#'   or a vector of indices
#'
#' @return A list of \code{Survey} objects corresponding to the specified
#'   follow-up surveys. If a single index is specified, returns a list with
#'   one element
#'
#' @details
#' Follow-up surveys are fundamental in rotating panels because:
#' \itemize{
#'   \item Enable longitudinal analysis: Track the same units over time
#'   \item Capture temporal changes: Evolution of economic, social, and
#'     demographic variables
#'   \item Maintain representativeness: Each wave preserves population
#'     representativeness through controlled rotation
#'   \item Optimize resources: Reuse information from previous waves to
#'     reduce collection costs
#'   \item Facilitate comparisons: Consistent temporal structure for
#'     trend analysis
#' }
#'
#' In rotating panels like ECH:
#' - Each follow-up wave covers a specific period (monthly/quarterly)
#' - Units rotate gradually maintaining temporal overlap
#' - Indices correspond to the chronological collection order
#' - Each follow-up maintains methodological consistency with implantation
#'
#' @examples
#' impl <- Survey$new(
#'   data = data.table::data.table(id = 1:5, w = 1),
#'   edition = "2023", type = "test", psu = NULL,
#'   engine = "data.table", weight = add_weight(annual = "w")
#' )
#' fu1 <- Survey$new(
#'   data = data.table::data.table(id = 1:5, w = 1),
#'   edition = "2023_01", type = "test", psu = NULL,
#'   engine = "data.table", weight = add_weight(annual = "w")
#' )
#' fu2 <- Survey$new(
#'   data = data.table::data.table(id = 1:5, w = 1),
#'   edition = "2023_02", type = "test", psu = NULL,
#'   engine = "data.table", weight = add_weight(annual = "w")
#' )
#' panel <- RotativePanelSurvey$new(
#'   implantation = impl, follow_up = list(fu1, fu2),
#'   type = "test", default_engine = "data.table",
#'   steps = list(), recipes = list(), workflows = list(), design = NULL
#' )
#' get_follow_up(panel, index = 1)
#' get_follow_up(panel)
#'
#' @seealso
#' \code{\link{get_implantation}} for obtaining the implantation survey
#' \code{\link{extract_surveys}} for extracting surveys by temporal criteria
#' \code{\link{load_panel_survey}} for loading rotating panels
#' \code{\link{workflow}} for analysis with follow-up surveys
#'
#' @keywords panel-survey
#' @family panel-surveys
#' @export


get_follow_up <- function(
  RotativePanelSurvey,
  index = seq_along(
    RotativePanelSurvey$follow_up
  )
) {
  if (!inherits(
    RotativePanelSurvey,
    "RotativePanelSurvey"
  )) {
    stop(paste0(
      "The `RotativeSurvey` argument must be ",
      "an object of class ",
      "`RotativePanelSurvey`"
    ))
  }

  return(RotativePanelSurvey$follow_up[index])
}
