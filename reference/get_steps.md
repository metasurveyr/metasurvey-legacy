# get_steps

Get steps from survey

## Usage

``` r
get_steps(svy)
```

## Arguments

- svy:

  Survey object

## Value

List of Step objects

## See also

Other steps:
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
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
  id = 1:5, age = c(25, 30, 45, 50, 60),
  w = rep(1, 5)
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "ech",
  psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
)
svy <- step_compute(svy, age2 = age * 2)
get_steps(svy) # list of Step objects
#> $`step_1 Compute: age2`
#> <Step>
#>   Public:
#>     bake: TRUE
#>     by_vars: NULL
#>     call: call
#>     clone: function (deep = FALSE) 
#>     comment: Compute step
#>     default_engine: data.table
#>     depends_on: age
#>     edition: 2023
#>     exprs: call
#>     initialize: function (name, edition, survey_type, type, new_var, exprs, call, 
#>     name: step_1 Compute: age2
#>     new_var: age2
#>     recode_opts: NULL
#>     survey_type: ech
#>     svy_before: NULL
#>     type: compute
#> 
```
