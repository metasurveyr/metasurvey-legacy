# Convert a list of steps to a recipe

Convert a list of steps to a recipe

## Usage

``` r
steps_to_recipe(
  name,
  user,
  svy = survey_empty(type = "eaii", edition = "2019-2021"),
  description,
  steps,
  doi = NULL,
  topic = NULL
)
```

## Arguments

- name:

  A character string with the name of the recipe

- user:

  A character string with the user of the recipe

- svy:

  A Survey object

- description:

  A character string with the description of the recipe

- steps:

  A list with the steps of the recipe

- doi:

  A character string with the DOI of the recipe

- topic:

  A character string with the topic of the recipe

## Value

A Recipe object

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
[`read_recipe()`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md),
[`recipe()`](https://metasurveyr.github.io/metasurvey/reference/recipe.md),
[`save_recipe()`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md)

## Examples

``` r
# \donttest{
dt <- data.table::data.table(
  id = 1:20, age = sample(18:65, 20, TRUE),
  w = runif(20, 0.5, 2)
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "demo",
  psu = NULL, engine = "data.table",
  weight = add_weight(annual = "w")
)
svy <- step_compute(svy, age2 = age^2)
my_recipe <- steps_to_recipe(
  name = "age_vars", user = "analyst",
  svy = svy, description = "Age-derived variables",
  steps = get_steps(svy)
)
my_recipe
#> 
#> ── Recipe: age_vars ──
#> Author:  analyst
#> Survey:  demo / 2023
#> Version: 1.0.0
#> Description: Age-derived variables
#> Certification: community
#> 
#> ── Requires (1 variables) ──
#>   age
#> 
#> ── Pipeline (1 steps) ──
#>   1. [compute] -> age2  "Compute step"
#> 
#> ── Produces (1 variables) ──
#>   age2 [numeric]
#> 
# }
```
