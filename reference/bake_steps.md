# Execute all pending steps

Iterates over all pending (lazy) steps attached to a Survey or
RotativePanelSurvey and executes them sequentially, mutating the
underlying data.table. Each step is validated before execution (checks
that required variables exist).

## Usage

``` r
bake_steps(svy)
```

## Arguments

- svy:

  A `Survey` or `RotativePanelSurvey` object with pending steps

## Value

The same object with all steps materialized in the data and each step
marked as `bake = TRUE`.

## Details

Steps are executed in the order they were added. Each step's expressions
can reference variables created by previous steps.

For RotativePanelSurvey objects, steps are applied to both the
implantation and all follow-up surveys.

## See also

Other steps:
[`explain()`](https://metasurveyr.github.io/metasurvey/reference/explain.md),
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
dt <- data.table::data.table(id = 1:5, age = c(15, 30, 45, 50, 70), w = 1)
svy <- Survey$new(
  data = dt, edition = "2023", type = "test",
  psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
)
svy <- step_compute(svy, age2 = age * 2)
svy <- bake_steps(svy)
get_data(svy)
#>       id   age     w  age2
#>    <int> <num> <num> <num>
#> 1:     1    15     1    30
#> 2:     2    30     1    60
#> 3:     3    45     1    90
#> 4:     4    50     1   100
#> 5:     5    70     1   140
```
