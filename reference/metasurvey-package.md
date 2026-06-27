# metasurvey: Survey Processing with Meta-Programming

The metasurvey package provides a comprehensive framework for processing
complex survey data using meta-programming techniques. It integrates
seamlessly with the survey package while adding powerful features for
reproducible survey analysis workflows.

## Key Features

**Survey Objects and Classes:**

- [`Survey`](https://metasurveyr.github.io/metasurvey/reference/Survey.md):
  Basic survey object for cross-sectional data

- [`RotativePanelSurvey`](https://metasurveyr.github.io/metasurvey/reference/RotativePanelSurvey.md):
  Panel survey with implantation and follow-up

- [`PoolSurvey`](https://metasurveyr.github.io/metasurvey/reference/PoolSurvey.md):
  Pool of multiple surveys for time series analysis

**Steps and Workflows:**

- [`step_compute`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md):
  Create computed variables

- [`step_recode`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md):
  Recode variables with multiple conditions

- [`workflow`](https://metasurveyr.github.io/metasurvey/reference/workflow.md):
  Execute estimation workflows with variance adjustment

**Recipes and Reproducibility:**

- [`recipe`](https://metasurveyr.github.io/metasurvey/reference/recipe.md):
  Create reusable recipe objects

- [`bake_recipes`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md):
  Apply recipes to survey data

- [`get_recipe`](https://metasurveyr.github.io/metasurvey/reference/get_recipe.md):
  Retrieve recipes from repository

**Data Loading and Weights:**

- [`load_survey`](https://metasurveyr.github.io/metasurvey/reference/load_survey.md):
  Load single survey data

- [`load_panel_survey`](https://metasurveyr.github.io/metasurvey/reference/load_panel_survey.md):
  Load panel survey data

- [`add_weight`](https://metasurveyr.github.io/metasurvey/reference/add_weight.md):
  Add survey weights

- [`add_replicate`](https://metasurveyr.github.io/metasurvey/reference/add_replicate.md):
  Add bootstrap/jackknife replicates

**Quality Assessment:**

- [`evaluate_cv`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md):
  Evaluate coefficient of variation quality

- Built-in variance estimation with multiple engines

## Supported Survey Types

The package includes built-in support for several survey types:

- **ECH**: Encuesta Continua de Hogares (Uruguay)

- **EAII**: Encuesta de Actividad, Innovación e I+D

- **EAI**: Encuesta de Actividades de Innovación

- Generic survey types with flexible configuration

## Workflow Example


    library(metasurvey)
    # Note: examples use base R pipe (|>) to avoid extra dependencies

    # Load survey data
    survey_data <- load_survey(
      data_path = "path/to/data.csv",
      svy_edition = "2023",
      svy_type = "ech",
      svy_weight = add_weight(annual = "weight_var")
    )

    # Add processing steps
    processed_survey <- survey_data |>
      step_recode("employed", status == 1 ~ 1, .default = 0) |>
      step_compute(unemployment_rate = unemployed / labor_force)

    # Apply steps and run workflow
    final_survey <- bake_steps(processed_survey)

    results <- workflow(
      survey = list(final_survey),
      survey::svytotal(~employed),
      survey::svymean(~unemployment_rate),
      estimation_type = "annual"
    )

## Meta-Programming Features

The package leverages R's meta-programming capabilities to:

- Generate survey code dynamically based on metadata

- Create reusable workflows that adapt to different survey structures

- Validate and harmonize variable definitions across time periods

- Automatically handle complex variance estimation procedures

## References

Lumley, T. (2020). "survey: analysis of complex survey samples". R
package version 4.0.

## See also

- <https://CRAN.R-project.org/package=survey> for the survey package

- Package website: <https://github.com/metasurveyr/metasurvey>

- Vignettes: `vignette(package = "metasurvey")`

## Author

Mauro Loprete <mauro.loprete@icloud.com>, Natalia da Silva
<natalia.dasilva@fcea.edu.uy>, Fabricio Machado
<fabricio.mch.slv@gmail.com>
