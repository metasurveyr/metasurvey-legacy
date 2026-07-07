# Add a category to a recipe

Pipe-friendly function to add a category to a Recipe object. Accepts
either a category name (string) or a
[`RecipeCategory`](https://metasurveyr.github.io/metasurvey/reference/RecipeCategory-from_list.md)
object.

## Usage

``` r
add_category(recipe, category, description = "")
```

## Arguments

- recipe:

  A Recipe object.

- category:

  Character category name or RecipeCategory object.

- description:

  Character. Description for the category (used when `category` is a
  string). Defaults to empty.

## Value

The modified Recipe object (invisibly for piping).

## See also

[`remove_category`](https://metasurveyr.github.io/metasurvey/reference/remove_category.md),
[`recipe_category`](https://metasurveyr.github.io/metasurvey/reference/recipe_category.md),
[`default_categories`](https://metasurveyr.github.io/metasurvey/reference/default_categories.md)

Other tidy-api:
[`RecipeCategory-from_list`](https://metasurveyr.github.io/metasurvey/reference/RecipeCategory-from_list.md),
[`RecipeCertification`](https://metasurveyr.github.io/metasurvey/reference/RecipeCertification.md),
[`RecipeUser`](https://metasurveyr.github.io/metasurvey/reference/RecipeUser.md),
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
[`recipe_certification()`](https://metasurveyr.github.io/metasurvey/reference/recipe_certification.md),
[`recipe_user()`](https://metasurveyr.github.io/metasurvey/reference/recipe_user.md),
[`remove_category()`](https://metasurveyr.github.io/metasurvey/reference/remove_category.md),
[`search_recipes()`](https://metasurveyr.github.io/metasurvey/reference/search_recipes.md),
[`search_workflows()`](https://metasurveyr.github.io/metasurvey/reference/search_workflows.md),
[`set_user_info()`](https://metasurveyr.github.io/metasurvey/reference/set_user_info.md),
[`set_version()`](https://metasurveyr.github.io/metasurvey/reference/set_version.md)

## Examples

``` r
r <- recipe(
  name = "Example", user = "Test",
  svy = survey_empty(type = "ech", edition = "2023"),
  description = "Example recipe"
)
r <- r |>
  add_category("labor_market", "Labor market indicators") |>
  add_category("income")
```
