#' @title metasurvey: Survey Processing with Meta-Programming
#'
#' @description
#' The metasurvey package provides a comprehensive
#' framework for processing complex survey data using
#' meta-programming techniques. It integrates seamlessly
#' with the survey package while adding powerful features
#' for reproducible survey analysis workflows.
#'
#' @section Key Features:
#'
#' **Survey Objects and Classes:**
#' \itemize{
#'   \item \code{\link{Survey}}: Basic survey object for cross-sectional data
#'   \item \code{\link{RotativePanelSurvey}}: Panel survey
#'     with implantation and follow-up
#'   \item \code{\link{PoolSurvey}}: Pool of multiple
#'     surveys for time series analysis
#' }
#'
#' **Steps and Workflows:**
#' \itemize{
#'   \item \code{\link{step_compute}}: Create computed variables
#'   \item \code{\link{step_recode}}: Recode variables
#'     with multiple conditions
#'   \item \code{\link{workflow}}: Execute estimation
#'     workflows with variance adjustment
#' }
#'
#' **Recipes and Reproducibility:**
#' \itemize{
#'   \item \code{\link{recipe}}: Create reusable recipe objects
#'   \item \code{\link{bake_recipes}}: Apply recipes to survey data
#'   \item \code{\link{get_recipe}}: Retrieve recipes from repository
#' }
#'
#' **Data Loading and Weights:**
#' \itemize{
#'   \item \code{\link{load_survey}}: Load single survey data
#'   \item \code{\link{load_panel_survey}}: Load panel survey data
#'   \item \code{\link{add_weight}}: Add survey weights
#'   \item \code{\link{add_replicate}}: Add bootstrap/jackknife replicates
#' }
#'
#' **Quality Assessment:**
#' \itemize{
#'   \item \code{\link{evaluate_cv}}: Evaluate coefficient
#'     of variation quality
#'   \item Built-in variance estimation with multiple engines
#' }
#'
#' @section Supported Survey Types:
#'
#' The package includes built-in support for several survey types:
#' \itemize{
#'   \item **ECH**: Encuesta Continua de Hogares (Uruguay)
#'   \item **EAII**: Encuesta de Actividad, Innovación e I+D
#'   \item **EAI**: Encuesta de Actividades de Innovación
#'   \item Generic survey types with flexible configuration
#' }
#'
#' @section Workflow Example:
#'
#' \preformatted{
#' library(metasurvey)
#' # Note: examples use base R pipe (|>) to avoid extra dependencies
#'
#' # Load survey data
#' survey_data <- load_survey(
#'   data_path = "path/to/data.csv",
#'   svy_edition = "2023",
#'   svy_type = "ech",
#'   svy_weight = add_weight(annual = "weight_var")
#' )
#'
#' # Add processing steps
#' processed_survey <- survey_data |>
#'   step_recode("employed", status == 1 ~ 1, .default = 0) |>
#'   step_compute(unemployment_rate = unemployed / labor_force)
#'
#' # Apply steps and run workflow
#' final_survey <- bake_steps(processed_survey)
#'
#' results <- workflow(
#'   survey = list(final_survey),
#'   survey::svytotal(~employed),
#'   survey::svymean(~unemployment_rate),
#'   estimation_type = "annual"
#' )
#' }
#'
#' @section Meta-Programming Features:
#'
#' The package leverages R's meta-programming capabilities to:
#' \itemize{
#'   \item Generate survey code dynamically based on metadata
#'   \item Create reusable workflows that adapt to different survey structures
#'   \item Validate and harmonize variable definitions across time periods
#'   \item Automatically handle complex variance estimation procedures
#' }
#'
#' @author
#' Mauro Loprete \email{mauro.loprete@@icloud.com},
#' Natalia da Silva \email{natalia.dasilva@@fcea.edu.uy},
#' Fabricio Machado \email{fabricio.mch.slv@@gmail.com}
#'
#' @references
#' Lumley, T. (2020). "survey: analysis of complex survey
#' samples". R package version 4.0.
#'
#' @seealso
#' \itemize{
#'   \item \url{https://CRAN.R-project.org/package=survey}
#'     for the survey package
#'   \item Package website:
#'     \url{https://github.com/metasurveyr/metasurvey}
#'   \item Vignettes: \code{vignette(package = "metasurvey")}
#' }
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom data.table .BY
#' @importFrom data.table .EACHI
#' @importFrom data.table .GRP
#' @importFrom data.table .I
#' @importFrom data.table .N
#' @importFrom data.table .NGRP
#' @importFrom data.table .SD
#' @importFrom data.table :=
#' @importFrom data.table data.table
#' @importFrom lifecycle deprecated
#' @importFrom glue glue
#' @importFrom R6 R6Class
## usethis namespace: end
NULL


utils::globalVariables(c(
  "j", "se", "stat", "period", "type", "evaluate",
  # Added to silence R CMD check NOTES from NSE/data.table usage
  "variance", "value", "new_category", ".pool_k",
  "confint_lower", "confint_upper"
))

#' @importFrom stats as.formula confint
NULL
