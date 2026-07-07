# Create a recipe category

Creates a
[`RecipeCategory`](https://metasurveyr.github.io/metasurvey/reference/RecipeCategory-from_list.md)
object for classifying recipes.

## Usage

``` r
recipe_category(name, description = "", parent = NULL)
```

## Arguments

- name:

  Character. Category identifier (e.g. `"labor_market"`).

- description:

  Character. Human-readable description. Defaults to empty.

- parent:

  RecipeCategory object or character parent category name (default
  `NULL`). If a string is provided, it creates a parent category with
  that name.

## Value

A
[`RecipeCategory`](https://metasurveyr.github.io/metasurvey/reference/RecipeCategory-from_list.md)
object.

## See also

[`RecipeCategory`](https://metasurveyr.github.io/metasurvey/reference/RecipeCategory-from_list.md),
[`add_category`](https://metasurveyr.github.io/metasurvey/reference/add_category.md),
[`default_categories`](https://metasurveyr.github.io/metasurvey/reference/default_categories.md)

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
[`recipe_certification()`](https://metasurveyr.github.io/metasurvey/reference/recipe_certification.md),
[`recipe_user()`](https://metasurveyr.github.io/metasurvey/reference/recipe_user.md),
[`remove_category()`](https://metasurveyr.github.io/metasurvey/reference/remove_category.md),
[`search_recipes()`](https://metasurveyr.github.io/metasurvey/reference/search_recipes.md),
[`search_workflows()`](https://metasurveyr.github.io/metasurvey/reference/search_workflows.md),
[`set_user_info()`](https://metasurveyr.github.io/metasurvey/reference/set_user_info.md),
[`set_version()`](https://metasurveyr.github.io/metasurvey/reference/set_version.md)

## Examples

``` r
cat <- recipe_category("labor_market", "Labor market indicators")

# With parent hierarchy
sub <- recipe_category(
  "employment", "Employment stats",
  parent = "labor_market"
)
```
