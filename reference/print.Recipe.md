# Print method for Recipe objects

Displays a formatted recipe card showing metadata, required variables,
pipeline steps, and produced variables.

## Usage

``` r
# S3 method for class 'Recipe'
print(x, ...)
```

## Arguments

- x:

  A Recipe object

- ...:

  Additional arguments (currently unused)

## Value

Invisibly returns the Recipe object

## See also

Other recipes:
[`Recipe-class`](https://metasurveyr.github.io/metasurvey/reference/Recipe-class.md),
[`add_recipe()`](https://metasurveyr.github.io/metasurvey/reference/add_recipe.md),
[`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md),
[`explore_recipes()`](https://metasurveyr.github.io/metasurvey/reference/explore_recipes.md),
[`get_recipe()`](https://metasurveyr.github.io/metasurvey/reference/get_recipe.md),
[`harmonize()`](https://metasurveyr.github.io/metasurvey/reference/harmonize.md),
[`publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/publish_recipe.md),
[`read_recipe()`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md),
[`recipe()`](https://metasurveyr.github.io/metasurvey/reference/recipe.md),
[`save_recipe()`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md),
[`steps_to_recipe()`](https://metasurveyr.github.io/metasurvey/reference/steps_to_recipe.md)

## Examples

``` r
rec <- Recipe$new(
  id = "r1", name = "Example", user = "tester",
  edition = "2023", survey_type = "test",
  default_engine = "data.table", depends_on = list(),
  description = "Demo recipe", steps = list()
)
print(rec)
#> 
#> ── Recipe: Example ──
#> Author:  tester
#> Survey:  test / 2023
#> Version: 1.0.0
#> Description: Demo recipe
#> Certification: community
#> 
```
