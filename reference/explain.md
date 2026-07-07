# Explain the execution plan of the pending steps

Builds the `metatable` logical plan for the pending (not yet baked)
steps of a survey and returns it without executing anything. The print
method shows the classification of each node
(narrow/wide/filter/fence/meta), the segments cut at fence nodes, and
the number of passes over the data of the current engine versus the plan
(identical for now: no optimization rule is active yet).

## Usage

``` r
explain(svy)

# S3 method for class 'meta_plan'
print(x, ...)
```

## Arguments

- svy:

  A `Survey` object.

- x:

  A `meta_plan` object.

- ...:

  Ignored.

## Value

A `meta_plan` object (invisibly printable). With no pending steps the
plan is empty and the print method says so.

## Details

`explain()` never touches the data: it only inspects the step metadata,
regardless of the configured engine.

## Functions

- `print(meta_plan)`: Print method for the plan returned by `explain()`.

## See also

[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
to execute the pending steps.

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
[`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md),
[`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md),
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)

## Examples

``` r
dt <- data.table::data.table(
  id = 1:6, age = c(15, 25, 35, 45, 55, 65), w = 1
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "test",
  psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
)
svy <- svy |>
  step_rename(edad = age) |>
  step_filter(edad >= 18) |>
  step_validate(edad > 0)
explain(svy)
#> <metatable plan> 3 pending steps
#> -- segment 1
#>   [1] meta   step_rename  produces: edad | consumes: age
#>   [2] filter filter       produces: - | consumes: age
#>   [3] fence  validate     produces: - | consumes: age
#> Passes over the data: 2 (current engine) -> 2 (planned, no optimization rules yet)
```
