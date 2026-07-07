# Create a recipe certification

Creates a
[`RecipeCertification`](https://metasurveyr.github.io/metasurvey/reference/RecipeCertification.md)
object. Typically you would use
[`certify_recipe`](https://metasurveyr.github.io/metasurvey/reference/certify_recipe.md)
to certify a recipe in a pipeline instead.

## Usage

``` r
recipe_certification(level = "community", certified_by = NULL, notes = NULL)
```

## Arguments

- level:

  Character. One of `"community"` (default), `"reviewed"`, or
  `"official"`.

- certified_by:

  RecipeUser or `NULL` (default `NULL`). Required for reviewed/official.

- notes:

  Character or `NULL` (default `NULL`). Additional notes.

## Value

A
[`RecipeCertification`](https://metasurveyr.github.io/metasurvey/reference/RecipeCertification.md)
object.

## See also

[`RecipeCertification`](https://metasurveyr.github.io/metasurvey/reference/RecipeCertification.md),
[`certify_recipe`](https://metasurveyr.github.io/metasurvey/reference/certify_recipe.md)

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
[`rank_recipes()`](https://metasurveyr.github.io/metasurvey/reference/rank_recipes.md),
[`rank_workflows()`](https://metasurveyr.github.io/metasurvey/reference/rank_workflows.md),
[`recipe_category()`](https://metasurveyr.github.io/metasurvey/reference/recipe_category.md),
[`recipe_user()`](https://metasurveyr.github.io/metasurvey/reference/recipe_user.md),
[`remove_category()`](https://metasurveyr.github.io/metasurvey/reference/remove_category.md),
[`search_recipes()`](https://metasurveyr.github.io/metasurvey/reference/search_recipes.md),
[`search_workflows()`](https://metasurveyr.github.io/metasurvey/reference/search_workflows.md),
[`set_user_info()`](https://metasurveyr.github.io/metasurvey/reference/set_user_info.md),
[`set_version()`](https://metasurveyr.github.io/metasurvey/reference/set_version.md)

## Examples

``` r
# Default community certification
cert <- recipe_certification()

# Official certification
inst <- recipe_user("IECON", type = "institution")
cert <- recipe_certification("official", certified_by = inst)
```
