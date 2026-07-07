# Validate data during the step pipeline

Creates a non-mutating step that checks data invariants when
[`bake_steps`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
is called. Each check is a logical expression evaluated row-wise against
the survey data. If any row fails a check, the pipeline stops (or
warns).

## Usage

``` r
step_validate(
  svy,
  ...,
  .action = c("stop", "warn"),
  .min_n = NULL,
  .copy = use_copy_default(),
  comment = "Validate step"
)
```

## Arguments

- svy:

  A Survey or RotativePanelSurvey object

- ...:

  Logical expressions evaluated against the data. Each must return a
  logical vector with one value per row. Named expressions use the name
  in error messages; unnamed expressions use the deparsed code.
  Examples: `income > 0`, `!is.na(age)`, `sex %in% c(1, 2)`.

- .action:

  What to do when a check fails: `"stop"` (default) raises an error,
  `"warn"` issues a warning and continues.

- .min_n:

  Minimum number of rows required. Checked before row-level expressions.

- .copy:

  Whether to operate on a copy (default:
  [`use_copy_default()`](https://metasurveyr.github.io/metasurvey/reference/use_copy_default.md))

- comment:

  Descriptive text for the step for documentation and traceability
  (default `"Validate step"`).

## Value

The survey object with a validate step recorded (no data mutation).

## Details

**Lazy evaluation (default):** Like all steps, validation checks are
recorded but **not executed** until
[`bake_steps`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
is called. This means `step_validate` can reference variables created by
preceding
[`step_compute`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md)
calls.

The validate step does **not** modify the data in any way. It only
inspects the current state of the data.table and raises an error or
warning if any check fails.

## See also

Other steps:
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
[`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md),
[`step_collapse()`](https://metasurveyr.github.io/metasurvey/reference/step_collapse.md),
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md),
[`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md),
[`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md),
[`step_quantile()`](https://metasurveyr.github.io/metasurvey/reference/step_quantile.md),
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md),
[`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md),
[`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md),
[`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md),
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)

## Examples

``` r
dt <- data.table::data.table(
  id = 1:5, age = c(25, 30, 45, 50, 60),
  income = c(1000, 2000, 3000, 4000, 5000), w = 1
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "test",
  psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
)

# Validate that all ages are positive and income is not NA
svy <- svy |>
  step_validate(age > 0, !is.na(income), .min_n = 3) |>
  bake_steps()
```
