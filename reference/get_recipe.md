# Get recipe from repository or API

This function retrieves data transformation recipes from the metasurvey
repository or API, based on specific criteria such as survey type,
edition, and topic. It is the primary way to access predefined and
community-validated recipes.

## Usage

``` r
get_recipe(
  svy_type = NULL,
  svy_edition = NULL,
  topic = NULL,
  allowMultiple = TRUE
)
```

## Arguments

- svy_type:

  String specifying the survey type. Examples: "ech", "eaii", "eai",
  "eph"

- svy_edition:

  String specifying the survey edition. Supported formats: "YYYY",
  "YYYYMM", "YYYY-YYYY"

- topic:

  String specifying the recipe topic. Examples: "labor_market",
  "poverty", "income", "demographics"

- allowMultiple:

  Logical indicating whether multiple recipes are allowed. If FALSE and
  multiple matches exist, returns the most recent one

## Value

`Recipe` object or list of `Recipe` objects according to the specified
criteria and the value of `allowMultiple`

## Details

This function is essential for:

- Accessing official recipes: Get validated and maintained recipes by
  specialized teams

- Reproducibility: Ensure different users apply the same standard
  transformations

- Automation: Integrate recipes into automatic pipelines

- Collaboration: Share methodologies between teams and organizations

- Versioning: Access different recipe versions according to edition

The function queries the metasurvey API to retrieve recipes. **Internet
connection is required**. If the API is unavailable or you need to work
offline:

**Working Offline:**

- Don't call `get_recipe()` - work directly with steps

- Set `options(metasurvey.skip_recipes = TRUE)` to disable API calls

- Load recipes from local files using
  [`read_recipe()`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md)

- Create custom recipes with
  [`recipe()`](https://metasurveyr.github.io/metasurvey/reference/recipe.md)

Search criteria are combined with AND operator, so all specified
criteria must match for a recipe to be returned.

## See also

[`recipe`](https://metasurveyr.github.io/metasurvey/reference/recipe.md)
to create custom recipes
[`save_recipe`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md)
to save recipes locally
[`read_recipe`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md)
to read recipes from file
[`publish_recipe`](https://metasurveyr.github.io/metasurvey/reference/publish_recipe.md)
to publish recipes to the repository
[`load_survey`](https://metasurveyr.github.io/metasurvey/reference/load_survey.md)
where recipes are used

Other recipes:
[`Recipe-class`](https://metasurveyr.github.io/metasurvey/reference/Recipe-class.md),
[`add_recipe()`](https://metasurveyr.github.io/metasurvey/reference/add_recipe.md),
[`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md),
[`explore_recipes()`](https://metasurveyr.github.io/metasurvey/reference/explore_recipes.md),
[`harmonize()`](https://metasurveyr.github.io/metasurvey/reference/harmonize.md),
[`print.Recipe()`](https://metasurveyr.github.io/metasurvey/reference/print.Recipe.md),
[`publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/publish_recipe.md),
[`read_recipe()`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md),
[`recipe()`](https://metasurveyr.github.io/metasurvey/reference/recipe.md),
[`save_recipe()`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md),
[`steps_to_recipe()`](https://metasurveyr.github.io/metasurvey/reference/steps_to_recipe.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Get specific recipe for ECH 2023
ech_recipe <- get_recipe(
  svy_type = "ech",
  svy_edition = "2023"
)

# Recipe for specific topic
labor_recipe <- get_recipe(
  svy_type = "ech",
  svy_edition = "2023",
  topic = "labor_market"
)

# Allow multiple recipes
available_recipes <- get_recipe(
  svy_type = "eaii",
  svy_edition = "2019-2021",
  allowMultiple = TRUE
)

# Use recipe in load_survey
ech_with_recipe <- load_survey(
  path = "ech_2023.dta",
  svy_type = "ech",
  svy_edition = "2023",
  recipes = get_recipe("ech", "2023"),
  bake = TRUE
)

# Working offline - don't use recipes
ech_offline <- load_survey(
  path = "ech_2023.dta",
  svy_type = "ech",
  svy_edition = "2023",
  svy_weight = add_weight(annual = "PESOANO")
)

# Disable recipe API globally
options(metasurvey.skip_recipes = TRUE)
# Now get_recipe() will return NULL with a warning

# For year ranges
panel_recipe <- get_recipe(
  svy_type = "ech_panel",
  svy_edition = "2020-2023"
)
} # }
```
