# Create a recipe user

Creates a
[`RecipeUser`](https://metasurveyr.github.io/metasurvey/reference/RecipeUser.md)
object with a simple functional interface.

## Usage

``` r
recipe_user(
  name,
  type = "individual",
  email = NULL,
  affiliation = NULL,
  institution = NULL,
  url = NULL,
  verified = FALSE
)
```

## Arguments

- name:

  Character. User or institution name.

- type:

  Character. One of `"individual"` (default), `"institutional_member"`,
  or `"institution"`.

- email:

  Character or `NULL` (default `NULL`). Email address.

- affiliation:

  Character or `NULL` (default `NULL`). Organizational affiliation.

- institution:

  RecipeUser object or character institution name. Required for
  `"institutional_member"` type. If a string is provided, it creates an
  institution user with that name automatically.

- url:

  Character or `NULL` (default `NULL`). Institution URL.

- verified:

  Logical (default `FALSE`). Whether the account is verified.

## Value

A
[`RecipeUser`](https://metasurveyr.github.io/metasurvey/reference/RecipeUser.md)
object.

## See also

[`RecipeUser`](https://metasurveyr.github.io/metasurvey/reference/RecipeUser.md),
[`set_user_info`](https://metasurveyr.github.io/metasurvey/reference/set_user_info.md),
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
[`recipe_certification()`](https://metasurveyr.github.io/metasurvey/reference/recipe_certification.md),
[`remove_category()`](https://metasurveyr.github.io/metasurvey/reference/remove_category.md),
[`search_recipes()`](https://metasurveyr.github.io/metasurvey/reference/search_recipes.md),
[`search_workflows()`](https://metasurveyr.github.io/metasurvey/reference/search_workflows.md),
[`set_user_info()`](https://metasurveyr.github.io/metasurvey/reference/set_user_info.md),
[`set_version()`](https://metasurveyr.github.io/metasurvey/reference/set_version.md)

## Examples

``` r
# Individual user
user <- recipe_user("Juan Perez", email = "juan@example.com")

# Institution
inst <- recipe_user(
  "Instituto de Economia",
  type = "institution", verified = TRUE
)

# Member linked to institution
member <- recipe_user(
  "Maria",
  type = "institutional_member",
  institution = inst
)

# Member with institution name shortcut
member2 <- recipe_user(
  "Pedro",
  type = "institutional_member",
  institution = "IECON"
)
```
