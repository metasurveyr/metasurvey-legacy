# Rename variables in survey data (step)

Creates a step that renames variables in the survey data when baked.

## Usage

``` r
step_rename(
  svy,
  ...,
  mapping = NULL,
  .copy = use_copy_default(),
  comment = "Rename variables",
  use_copy = deprecated(),
  lazy = lazy_default(),
  record = TRUE
)
```

## Arguments

- svy:

  A Survey or RotativePanelSurvey object

- ...:

  Pairs in the form `new_name = old_name` (unquoted).

- mapping:

  A named character vector of the form `c(new_name = "old_name")`.
  Alternative to `...` for programmatic use.

- .copy:

  Whether to operate on a copy (default:
  [`use_copy_default()`](https://metasurveyr.github.io/metasurvey/reference/use_copy_default.md))

- comment:

  Descriptive text for the step for documentation and traceability
  (default `"Rename variables"`).

- use_copy:

  **\[deprecated\]** Use `.copy` instead.

- lazy:

  Internal. Whether to delay execution (default
  [`lazy_default()`](https://metasurveyr.github.io/metasurvey/reference/lazy_default.md)).

- record:

  Internal. Whether to record the step (default `TRUE`).

## Value

Survey object with the specified variables renamed (or queued for
renaming).

## Details

**Lazy evaluation (default):** By default, steps are recorded but **not
executed** until
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
is called.

Variables can be renamed in two ways:

- **Unquoted pairs:** `step_rename(svy, new_name = old_name)`

- **Named character vector:**
  `step_rename(svy, mapping = c(new_name = "old_name"))`

Variables that don't exist in the data cause an error, unlike
[`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md)
which issues a warning.

## See also

Other steps:
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
[`explain()`](https://metasurveyr.github.io/metasurvey/reference/explain.md),
[`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md),
[`step_collapse()`](https://metasurveyr.github.io/metasurvey/reference/step_collapse.md),
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md),
[`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md),
[`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md),
[`step_quantile()`](https://metasurveyr.github.io/metasurvey/reference/step_quantile.md),
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md),
[`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md),
[`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md),
[`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md),
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)

## Examples

``` r
dt <- data.table::data.table(
  id = 1:5, age = c(25, 30, 45, 50, 60),
  w = rep(1, 5)
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "ech",
  psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
)
svy2 <- step_rename(svy, edad = age)
svy2 <- bake_steps(svy2)
"edad" %in% names(get_data(svy2)) # TRUE
#> [1] TRUE
```
