# Filter rows from survey data

Creates a step that filters (subsets) rows from the survey data based on
logical conditions. Multiple conditions are combined with AND.

## Usage

``` r
step_filter(
  svy,
  ...,
  .by = NULL,
  .copy = use_copy_default(),
  comment = "Filter step",
  .level = "auto"
)
```

## Arguments

- svy:

  A
  [Survey](https://metasurveyr.github.io/metasurvey/reference/Survey.md)
  or
  [RotativePanelSurvey](https://metasurveyr.github.io/metasurvey/reference/RotativePanelSurvey.md)
  object.

- ...:

  Logical expressions evaluated against the data. Each must return a
  logical vector. Multiple conditions are combined with AND.

- .by:

  Optional grouping variable(s) for within-group filtering.

- .copy:

  Whether to operate on a copy (default:
  [`use_copy_default()`](https://metasurveyr.github.io/metasurvey/reference/use_copy_default.md)).

- comment:

  Descriptive text for the step (default `"Filter step"`).

- .level:

  For
  [RotativePanelSurvey](https://metasurveyr.github.io/metasurvey/reference/RotativePanelSurvey.md),
  the level to apply (default `"auto"`): `"implantation"`,
  `"follow_up"`, or `"auto"` (both).

## Value

The survey object with rows filtered and the step recorded.

## Details

**Lazy evaluation (default):** Like all steps, filter is recorded but
**not executed** until
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
is called.

## See also

Other steps:
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
[`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md),
[`step_collapse()`](https://metasurveyr.github.io/metasurvey/reference/step_collapse.md),
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md),
[`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md),
[`step_quantile()`](https://metasurveyr.github.io/metasurvey/reference/step_quantile.md),
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md),
[`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md),
[`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md),
[`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md),
[`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md),
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)

## Examples

``` r
svy <- Survey$new(
  data = data.table::data.table(
    id = 1:10, age = c(15, 25, 35, 45, 55, 65, 75, 20, 30, 40), w = 1
  ),
  edition = "2023", type = "test", psu = NULL,
  engine = "data.table", weight = add_weight(annual = "w")
)
svy <- svy |>
  step_filter(age >= 18) |>
  bake_steps()
nrow(get_data(svy))
#> [1] 9
```
