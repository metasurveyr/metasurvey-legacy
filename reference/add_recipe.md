# Add a recipe to a Survey

Tidy wrapper for `svy$add_recipe(recipe)`.

## Usage

``` r
add_recipe(svy, recipe, bake = lazy_default())
```

## Arguments

- svy:

  Survey object

- recipe:

  A Recipe object

- bake:

  Logical; whether to bake immediately (default: lazy_default())

## Value

The Survey object (invisibly), modified in place

## See also

Other recipes:
[`Recipe-class`](https://metasurveyr.github.io/metasurvey/reference/Recipe-class.md),
[`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md),
[`explore_recipes()`](https://metasurveyr.github.io/metasurvey/reference/explore_recipes.md),
[`get_recipe()`](https://metasurveyr.github.io/metasurvey/reference/get_recipe.md),
[`harmonize()`](https://metasurveyr.github.io/metasurvey/reference/harmonize.md),
[`print.Recipe()`](https://metasurveyr.github.io/metasurvey/reference/print.Recipe.md),
[`publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/publish_recipe.md),
[`read_recipe()`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md),
[`recipe()`](https://metasurveyr.github.io/metasurvey/reference/recipe.md),
[`save_recipe()`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md),
[`steps_to_recipe()`](https://metasurveyr.github.io/metasurvey/reference/steps_to_recipe.md)

## Examples

``` r
svy <- survey_empty(type = "ech", edition = "2023")
r <- recipe(
  name = "Example", user = "test",
  svy = svy, description = "Example"
)
svy <- add_recipe(svy, r)
```
