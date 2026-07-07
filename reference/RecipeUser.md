# RecipeUser

User identity for the recipe ecosystem. Supports three account types:
individual, institutional_member, and institution.

## Value

An object of class `RecipeUser`.

## See also

Other tidy-api:
[`RecipeCategory-from_list`](https://metasurveyr.github.io/metasurvey/reference/RecipeCategory-from_list.md),
[`RecipeCertification`](https://metasurveyr.github.io/metasurvey/reference/RecipeCertification.md),
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
[`recipe_user()`](https://metasurveyr.github.io/metasurvey/reference/recipe_user.md),
[`remove_category()`](https://metasurveyr.github.io/metasurvey/reference/remove_category.md),
[`search_recipes()`](https://metasurveyr.github.io/metasurvey/reference/search_recipes.md),
[`search_workflows()`](https://metasurveyr.github.io/metasurvey/reference/search_workflows.md),
[`set_user_info()`](https://metasurveyr.github.io/metasurvey/reference/set_user_info.md),
[`set_version()`](https://metasurveyr.github.io/metasurvey/reference/set_version.md)

## Public fields

- `name`:

  Character. User or institution name.

- `email`:

  Character or NULL. Email address.

- `user_type`:

  Character. One of "individual", "institutional_member", "institution".

- `affiliation`:

  Character or NULL. Organizational affiliation.

- `institution`:

  RecipeUser or NULL. Parent institution (for institutional_member).

- `url`:

  Character or NULL. Institution URL.

- `verified`:

  Logical. Whether the account is verified.

- `review_status`:

  Character. One of "approved", "pending", "rejected".

## Methods

### Public methods

- [`RecipeUser$new()`](#method-RecipeUser-initialize)

- [`RecipeUser$trust_level()`](#method-RecipeUser-trust_level)

- [`RecipeUser$can_certify()`](#method-RecipeUser-can_certify)

- [`RecipeUser$to_list()`](#method-RecipeUser-to_list)

- [`RecipeUser$print()`](#method-RecipeUser-print)

- [`RecipeUser$clone()`](#method-RecipeUser-clone)

------------------------------------------------------------------------

### `RecipeUser$new()`

Create a new RecipeUser

#### Usage

    RecipeUser$new(
      name,
      user_type,
      email = NULL,
      affiliation = NULL,
      institution = NULL,
      url = NULL,
      verified = FALSE,
      review_status = "approved"
    )

#### Arguments

- `name`:

  Character. User or institution name.

- `user_type`:

  Character. One of "individual", "institutional_member", "institution".

- `email`:

  Character or NULL. Email address.

- `affiliation`:

  Character or NULL. Organizational affiliation.

- `institution`:

  RecipeUser or NULL. Parent institution for institutional_member.

- `url`:

  Character or NULL. Institution URL.

- `verified`:

  Logical. Whether account is verified.

- `review_status`:

  Character. "approved", "pending", or "rejected".

------------------------------------------------------------------------

### `RecipeUser$trust_level()`

Get trust level (1=individual, 2=member, 3=institution)

#### Usage

    RecipeUser$trust_level()

#### Returns

Integer trust level

------------------------------------------------------------------------

### `RecipeUser$can_certify()`

Check if user can certify at a given level

#### Usage

    RecipeUser$can_certify(level)

#### Arguments

- `level`:

  Character. Certification level ("reviewed" or "official").

#### Returns

Logical

------------------------------------------------------------------------

### `RecipeUser$to_list()`

Serialize to list for JSON

#### Usage

    RecipeUser$to_list()

#### Returns

List representation

------------------------------------------------------------------------

### `RecipeUser$print()`

Print user card

#### Usage

    RecipeUser$print(...)

#### Arguments

- `...`:

  Additional arguments (not used)

------------------------------------------------------------------------

### `RecipeUser$clone()`

The objects of this class are cloneable with this method.

#### Usage

    RecipeUser$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
# Use recipe_user() for the public API:
user <- recipe_user("Juan Perez", email = "juan@example.com")
inst <- recipe_user("IECON", type = "institution")
member <- recipe_user(
  "Maria",
  type = "institutional_member",
  institution = inst
)
```
