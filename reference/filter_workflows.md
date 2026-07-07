# Filter workflows by criteria

Filter workflows in the active backend by survey type, edition, recipe
ID, or certification level.

## Usage

``` r
filter_workflows(
  survey_type = NULL,
  edition = NULL,
  recipe_id = NULL,
  certification_level = NULL
)
```

## Arguments

- survey_type:

  Character survey type or `NULL` (default `NULL`).

- edition:

  Character edition or `NULL` (default `NULL`).

- recipe_id:

  Character recipe ID or `NULL` (default `NULL`). Find workflows using
  this recipe.

- certification_level:

  Character certification level or `NULL` (default `NULL`).

## Value

List of matching RecipeWorkflow objects.

## See also

[`search_workflows`](https://metasurveyr.github.io/metasurvey/reference/search_workflows.md),
[`find_workflows_for_recipe`](https://metasurveyr.github.io/metasurvey/reference/find_workflows_for_recipe.md)

Other tidy-api:
[`RecipeCategory-from_list`](https://metasurveyr.github.io/metasurvey/reference/RecipeCategory-from_list.md),
[`RecipeCertification`](https://metasurveyr.github.io/metasurvey/reference/RecipeCertification.md),
[`RecipeUser`](https://metasurveyr.github.io/metasurvey/reference/RecipeUser.md),
[`add_category()`](https://metasurveyr.github.io/metasurvey/reference/add_category.md),
[`certify_recipe()`](https://metasurveyr.github.io/metasurvey/reference/certify_recipe.md),
[`default_categories()`](https://metasurveyr.github.io/metasurvey/reference/default_categories.md),
[`filter_recipes()`](https://metasurveyr.github.io/metasurvey/reference/filter_recipes.md),
[`find_workflows_for_recipe()`](https://metasurveyr.github.io/metasurvey/reference/find_workflows_for_recipe.md),
[`list_recipes()`](https://metasurveyr.github.io/metasurvey/reference/list_recipes.md),
[`list_workflows()`](https://metasurveyr.github.io/metasurvey/reference/list_workflows.md),
[`rank_recipes()`](https://metasurveyr.github.io/metasurvey/reference/rank_recipes.md),
[`rank_workflows()`](https://metasurveyr.github.io/metasurvey/reference/rank_workflows.md),
[`recipe_category()`](https://metasurveyr.github.io/metasurvey/reference/recipe_category.md),
[`recipe_certification()`](https://metasurveyr.github.io/metasurvey/reference/recipe_certification.md),
[`recipe_user()`](https://metasurveyr.github.io/metasurvey/reference/recipe_user.md),
[`remove_category()`](https://metasurveyr.github.io/metasurvey/reference/remove_category.md),
[`search_recipes()`](https://metasurveyr.github.io/metasurvey/reference/search_recipes.md),
[`search_workflows()`](https://metasurveyr.github.io/metasurvey/reference/search_workflows.md),
[`set_user_info()`](https://metasurveyr.github.io/metasurvey/reference/set_user_info.md),
[`set_version()`](https://metasurveyr.github.io/metasurvey/reference/set_version.md)

## Examples

``` r
set_workflow_backend("local", path = tempfile(fileext = ".json"))
ech_wf <- filter_workflows(survey_type = "ech")
length(ech_wf)
#> [1] 0
```
