# Create a survey data transformation recipe

Creates a Recipe object that encapsulates a sequence of data
transformations that can be applied to surveys in a reproducible manner.
Recipes allow documenting, sharing, and reusing data processing
workflows.

## Usage

``` r
recipe(...)
```

## Arguments

- ...:

  Required metadata and optional steps. Required parameters:

  - `name`: Descriptive name for the recipe

  - `user`: User/author creating the recipe

  - `svy`: Base Survey object (use
    [`survey_empty()`](https://metasurveyr.github.io/metasurvey/reference/survey_empty.md)
    for generic recipes)

  - `description`: Detailed description of the recipe's purpose

  Optional parameters include data transformation steps.

## Value

A `Recipe` object containing metadata, transformation steps, dependency
information, and default engine configuration.

## Details

Recipes are essential for:

- Reproducibility: Ensure transformations are applied consistently

- Documentation: Keep a record of what transformations are performed and
  why

- Collaboration: Share workflows between users and teams

- Versioning: Maintain different processing versions for different
  editions

- Automation: Apply complex transformations automatically

Steps included in the recipe can be any combination of `step_compute`,
`step_recode`, or other transformation steps.

Recipes can be saved with
[`save_recipe()`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md),
loaded with
[`read_recipe()`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md),
and applied automatically with
[`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md).

## See also

[`Recipe`](https://metasurveyr.github.io/metasurvey/reference/Recipe-class.md)
for class definition
[`save_recipe`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md)
to save recipes
[`read_recipe`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md)
to load recipes
[`get_recipe`](https://metasurveyr.github.io/metasurvey/reference/get_recipe.md)
to retrieve recipes from repository
[`bake_recipes`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md)
to apply recipes to data

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
[`save_recipe()`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md),
[`steps_to_recipe()`](https://metasurveyr.github.io/metasurvey/reference/steps_to_recipe.md)

## Examples

``` r
# Basic recipe without steps
r <- recipe(
  name = "Basic ECH Indicators",
  user = "Analyst",
  svy = survey_empty(type = "ech", edition = "2023"),
  description = "Basic labor indicators for ECH 2023"
)
r
#> 
#> ── Recipe: Basic ECH Indicators ──
#> Author:  Analyst
#> Survey:  ech / 2023
#> Version: 1.0.0
#> Description: Basic labor indicators for ECH 2023
#> Certification: community
#> 

# \donttest{
# Recipe with steps using local data
dt <- data.table::data.table(
  id = 1:50, age = sample(18:65, 50, TRUE),
  income = runif(50, 1000, 5000), w = runif(50, 0.5, 2)
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "demo",
  psu = NULL, engine = "data.table",
  weight = add_weight(annual = "w")
)
svy <- svy |>
  step_compute(income_cat = ifelse(income > 3000, "high", "low")) |>
  step_recode(age_group, age < 30 ~ "young", .default = "adult")
r2 <- recipe(
  name = "Demo", user = "test", svy = svy,
  description = "Demo recipe", steps = get_steps(svy)
)
r2
#> 
#> ── Recipe: Demo ──
#> Author:  test
#> Survey:  demo / 2023
#> Version: 1.0.0
#> Description: Demo recipe
#> Certification: community
#> 
#> ── Requires (2 variables) ──
#>   income, age
#> 
#> ── Pipeline (2 steps) ──
#>   1. [compute] -> income_cat  "Compute step"
#>   2. [recode] -> age_group  "Recode step"
#> 
#> ── Produces (2 variables) ──
#>   age_group [categorical], income_cat [numeric]
#> 
# }
```
