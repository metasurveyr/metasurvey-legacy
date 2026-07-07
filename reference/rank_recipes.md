# Rank recipes by downloads

Get the top recipes ranked by download count from the active backend.

## Usage

``` r
rank_recipes(n = NULL)
```

## Arguments

- n:

  Integer. Maximum number of recipes to return, or NULL for all.

## Value

List of Recipe objects sorted by downloads (descending).

## See also

[`search_recipes`](https://metasurveyr.github.io/metasurvey/reference/search_recipes.md),
[`filter_recipes`](https://metasurveyr.github.io/metasurvey/reference/filter_recipes.md)

Other tidy-api:
[`RecipeCategory-from_list`](https://metasurveyr.github.io/metasurvey/reference/RecipeCategory-from_list.md),
[`RecipeCertification`](https://metasurveyr.github.io/metasurvey/reference/RecipeCertification.md),
[`RecipeUser`](https://metasurveyr.github.io/metasurvey/reference/RecipeUser.md),
[`add_category()`](https://metasurveyr.github.io/metasurvey/reference/add_category.md),
[`certify_recipe()`](https://metasurveyr.github.io/metasurvey/reference/certify_recipe.md),
[`default_categories()`](https://metasurveyr.github.io/metasurvey/reference/default_categories.md),
[`filter_recipes()`](https://metasurveyr.github.io/metasurvey/reference/filter_recipes.md),
[`filter_workflows()`](https://metasurveyr.github.io/metasurvey/reference/filter_workflows.md),
[`find_workflows_for_recipe()`](https://metasurveyr.github.io/metasurvey/reference/find_workflows_for_recipe.md),
[`list_recipes()`](https://metasurveyr.github.io/metasurvey/reference/list_recipes.md),
[`list_workflows()`](https://metasurveyr.github.io/metasurvey/reference/list_workflows.md),
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
set_backend("local", path = tempfile(fileext = ".json"))
top10 <- rank_recipes(n = 10)
```
