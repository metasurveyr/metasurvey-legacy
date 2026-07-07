# Default recipe categories

Returns a list of standard built-in categories for recipe
classification.

## Usage

``` r
default_categories()
```

## Value

List of RecipeCategory objects

## See also

Other tidy-api:
[`RecipeCategory-from_list`](https://metasurveyr.github.io/metasurvey/reference/RecipeCategory-from_list.md),
[`RecipeCertification`](https://metasurveyr.github.io/metasurvey/reference/RecipeCertification.md),
[`RecipeUser`](https://metasurveyr.github.io/metasurvey/reference/RecipeUser.md),
[`add_category()`](https://metasurveyr.github.io/metasurvey/reference/add_category.md),
[`certify_recipe()`](https://metasurveyr.github.io/metasurvey/reference/certify_recipe.md),
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
cats <- default_categories()
vapply(cats, function(c) c$name, character(1))
#> [1] "labor_market" "income"       "education"    "health"       "demographics"
#> [6] "housing"     
```
