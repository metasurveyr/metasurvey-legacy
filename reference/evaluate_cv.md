# Evaluate estimation with Coefficient of Variation

Evaluate estimation with Coefficient of Variation

## Usage

``` r
evaluate_cv(cv)
```

## Arguments

- cv:

  Numeric coefficient of variation value.

## Value

Character string with the quality category (e.g. "Excellent", "Good"),
or `NA` when the CV is not defined (e.g. a zero estimate, where CV =
0/0).

## See also

Other workflows:
[`RecipeWorkflow-class`](https://metasurveyr.github.io/metasurvey/reference/RecipeWorkflow-class.md),
[`print.RecipeWorkflow()`](https://metasurveyr.github.io/metasurvey/reference/print.RecipeWorkflow.md),
[`publish_workflow()`](https://metasurveyr.github.io/metasurvey/reference/publish_workflow.md),
[`read_workflow()`](https://metasurveyr.github.io/metasurvey/reference/read_workflow.md),
[`reproduce_workflow()`](https://metasurveyr.github.io/metasurvey/reference/reproduce_workflow.md),
[`save_workflow()`](https://metasurveyr.github.io/metasurvey/reference/save_workflow.md),
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md),
[`workflow_from_list()`](https://metasurveyr.github.io/metasurvey/reference/workflow_from_list.md),
[`workflow_table()`](https://metasurveyr.github.io/metasurvey/reference/workflow_table.md)

## Examples

``` r
evaluate_cv(3) # "Excellent"
#> [1] "Excellent"
evaluate_cv(12) # "Good"
#> [1] "Good"
evaluate_cv(30) # "Use with caution"
#> [1] "Use with caution"
evaluate_cv(NaN) # NA
#> [1] NA
```
