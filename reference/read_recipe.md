# Read Recipe

Reads a Recipe object from a JSON file.

## Usage

``` r
read_recipe(file)
```

## Arguments

- file:

  A character string specifying the file path.

## Value

A Recipe object.

## Details

This function reads a JSON file and decodes it into a Recipe object.

## See also

Other recipes:
[`Recipe-class`](https://metasurveyr.github.io/metasurvey/reference/Recipe-class.md),
[`add_recipe()`](https://metasurveyr.github.io/metasurvey/reference/add_recipe.md),
[`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md),
[`explore_recipes()`](https://metasurveyr.github.io/metasurvey/reference/explore_recipes.md),
[`get_recipe()`](https://metasurveyr.github.io/metasurvey/reference/get_recipe.md),
[`harmonize()`](https://metasurveyr.github.io/metasurvey/reference/harmonize.md),
[`print.Recipe()`](https://metasurveyr.github.io/metasurvey/reference/print.Recipe.md),
[`publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/publish_recipe.md),
[`recipe()`](https://metasurveyr.github.io/metasurvey/reference/recipe.md),
[`save_recipe()`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md),
[`steps_to_recipe()`](https://metasurveyr.github.io/metasurvey/reference/steps_to_recipe.md)

## Examples

``` r
r <- recipe(
  name = "Example", user = "Test",
  svy = survey_empty(type = "ech", edition = "2023"),
  description = "Example recipe"
)
f <- tempfile(fileext = ".json")
save_recipe(r, f)
#> The recipe has been saved in /tmp/Rtmp2csiyN/file1dd55568f59e.json
r2 <- read_recipe(f)
#> Warning: Failed to parse recipe steps: invalid length 0 argument. Using raw strings as fallback.
r2
#> 
#> ── Recipe: Example ──
#> Author:  Test
#> Survey:  ech / 2023
#> Version: 1.0.0
#> Topic:   
#> DOI:     
#> Description: Example recipe
#> Certification: community
#> 
```
