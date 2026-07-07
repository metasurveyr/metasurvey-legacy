# Execute estimation workflow for surveys

This function executes a sequence of statistical estimations on Survey
objects, applying functions from the R survey package with appropriate
metadata. Automatically handles different survey types and
periodicities.

## Usage

``` r
workflow(svy, ..., estimation_type = "monthly", level = 0.95)
```

## Arguments

- svy:

  A **list** of Survey objects, or a PoolSurvey. Even for a single
  survey, wrap it in [`list()`](https://rdrr.io/r/base/list.html):
  `workflow(svy = list(my_survey), ...)`. Must contain properly
  configured sample design.

- ...:

  Calls to survey package functions (such as `svymean`, `svytotal`,
  `svyratio`, etc.) that will be executed sequentially

- estimation_type:

  Type of estimation (default `"monthly"`) that determines which weight
  to use. Options: `"monthly"`, `"quarterly"`, `"annual"`, or vector
  with multiple types

- level:

  Confidence level for the interval (default `0.95`). Passed to
  [`confint`](https://rdrr.io/r/stats/confint.html). Can also be set
  per-call inside the estimation function (e.g.,
  `svymean(~x, na.rm = TRUE, level = 0.90)`), which overrides the
  `workflow()` default for that estimation.

## Value

`data.table` with results from all estimations, including columns:

- `stat`: Estimation call and variable name

- `variable`: Variable name (for filtering)

- `value`: Point estimate

- `se`: Standard error

- `cv`: Coefficient of variation (proportion)

- `confint_lower`: Lower bound of confidence interval

- `confint_upper`: Upper bound of confidence interval

- `evaluate`: CV quality label from
  [`evaluate_cv`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md)
  (e.g. "Excellent", "Good", "Use with caution")

For `svyby` estimations, grouping variables (e.g. `region`, `sexo`)
appear as additional columns.

## Details

The function automatically selects the appropriate sample design
according to the specified `estimation_type`. For each Survey in the
input list, it executes all functions specified in `...` and combines
the results.

Supported estimation types:

- "monthly": Monthly estimations

- "quarterly": Quarterly estimations

- "annual": Annual estimations

For PoolSurvey objects, it uses a specialized methodology that handles
pooling of multiple surveys. When a compound `estimation_type` is used
(e.g. `"annual:monthly"`), point estimates are averaged across the `k`
pooled surveys and the standard error is computed as
`sqrt(mean(variance) * (1 + rho * (k - 1)) / k)`, where `rho` (default
`0`, passed as a named argument through `...`) is the correlation
between waves of a rotating panel. The former `R` argument is deprecated
and ignored.

## See also

[`svymean`](https://rdrr.io/pkg/survey/man/surveysummary.html) for
population means
[`svytotal`](https://rdrr.io/pkg/survey/man/surveysummary.html) for
population totals
[`svyratio`](https://rdrr.io/pkg/survey/man/svyratio.html) for ratios
[`svyby`](https://rdrr.io/pkg/survey/man/svyby.html) for domain
estimations
[`PoolSurvey`](https://metasurveyr.github.io/metasurvey/reference/PoolSurvey.md)
for survey pooling

Other workflows:
[`RecipeWorkflow-class`](https://metasurveyr.github.io/metasurvey/reference/RecipeWorkflow-class.md),
[`evaluate_cv()`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md),
[`print.RecipeWorkflow()`](https://metasurveyr.github.io/metasurvey/reference/print.RecipeWorkflow.md),
[`publish_workflow()`](https://metasurveyr.github.io/metasurvey/reference/publish_workflow.md),
[`read_workflow()`](https://metasurveyr.github.io/metasurvey/reference/read_workflow.md),
[`reproduce_workflow()`](https://metasurveyr.github.io/metasurvey/reference/reproduce_workflow.md),
[`save_workflow()`](https://metasurveyr.github.io/metasurvey/reference/save_workflow.md),
[`workflow_from_list()`](https://metasurveyr.github.io/metasurvey/reference/workflow_from_list.md),
[`workflow_table()`](https://metasurveyr.github.io/metasurvey/reference/workflow_table.md)

## Examples

``` r
# Simple estimation
dt <- data.table::data.table(
  x = rnorm(100), g = sample(c("a", "b"), 100, TRUE),
  w = rep(1, 100)
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "test",
  psu = NULL, engine = "data.table",
  weight = add_weight(annual = "w")
)
result <- workflow(
  svy = list(svy),
  survey::svymean(~x, na.rm = TRUE),
  estimation_type = "annual"
)

# Domain estimation with svyby
result_by <- workflow(
  svy = list(svy),
  survey::svyby(~x, ~g, survey::svymean, na.rm = TRUE),
  estimation_type = "annual"
)

# Custom confidence level (90%) for all estimations
result_90 <- workflow(
  svy = list(svy),
  survey::svymean(~x, na.rm = TRUE),
  estimation_type = "annual",
  level = 0.90
)

# Per-call confidence level (overrides workflow default)
result_mixed <- workflow(
  svy = list(svy),
  survey::svymean(~x, na.rm = TRUE, level = 0.80),
  estimation_type = "annual"
)
```
