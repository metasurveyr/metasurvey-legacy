# RecipeCertification

Quality certification for recipes with three tiers: community (default),
reviewed (peer-reviewed by institutional member), and official
(certified by institution).

## Value

An object of class `RecipeCertification`.

## See also

Other tidy-api:
[`RecipeCategory-from_list`](https://metasurveyr.github.io/metasurvey/reference/RecipeCategory-from_list.md),
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
[`recipe_user()`](https://metasurveyr.github.io/metasurvey/reference/recipe_user.md),
[`remove_category()`](https://metasurveyr.github.io/metasurvey/reference/remove_category.md),
[`search_recipes()`](https://metasurveyr.github.io/metasurvey/reference/search_recipes.md),
[`search_workflows()`](https://metasurveyr.github.io/metasurvey/reference/search_workflows.md),
[`set_user_info()`](https://metasurveyr.github.io/metasurvey/reference/set_user_info.md),
[`set_version()`](https://metasurveyr.github.io/metasurvey/reference/set_version.md)

## Public fields

- `level`:

  Character. Certification level.

- `certified_by`:

  RecipeUser or NULL. The certifying user.

- `certified_at`:

  POSIXct. Timestamp of certification.

- `notes`:

  Character or NULL. Additional notes.

## Methods

### Public methods

- [`RecipeCertification$new()`](#method-RecipeCertification-initialize)

- [`RecipeCertification$numeric_level()`](#method-RecipeCertification-numeric_level)

- [`RecipeCertification$is_at_least()`](#method-RecipeCertification-is_at_least)

- [`RecipeCertification$to_list()`](#method-RecipeCertification-to_list)

- [`RecipeCertification$print()`](#method-RecipeCertification-print)

- [`RecipeCertification$clone()`](#method-RecipeCertification-clone)

------------------------------------------------------------------------

### `RecipeCertification$new()`

Create a new RecipeCertification

#### Usage

    RecipeCertification$new(
      level,
      certified_by = NULL,
      notes = NULL,
      certified_at = NULL
    )

#### Arguments

- `level`:

  Character. One of "community", "reviewed", "official".

- `certified_by`:

  RecipeUser or NULL. Required for reviewed/official.

- `notes`:

  Character or NULL. Additional notes.

- `certified_at`:

  POSIXct or NULL. Auto-set if NULL.

------------------------------------------------------------------------

### `RecipeCertification$numeric_level()`

Get numeric level for ordering (1=community, 2=reviewed, 3=official)

#### Usage

    RecipeCertification$numeric_level()

#### Returns

Integer

------------------------------------------------------------------------

### `RecipeCertification$is_at_least()`

Check if certification is at least a given level

#### Usage

    RecipeCertification$is_at_least(level)

#### Arguments

- `level`:

  Character. Level to compare against.

#### Returns

Logical

------------------------------------------------------------------------

### `RecipeCertification$to_list()`

Serialize to list for JSON

#### Usage

    RecipeCertification$to_list()

#### Returns

List representation

------------------------------------------------------------------------

### `RecipeCertification$print()`

Print certification badge

#### Usage

    RecipeCertification$print(...)

#### Arguments

- `...`:

  Additional arguments (not used)

------------------------------------------------------------------------

### `RecipeCertification$clone()`

The objects of this class are cloneable with this method.

#### Usage

    RecipeCertification$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
# Use recipe_certification() for the public API:
cert <- recipe_certification()
inst <- recipe_user("IECON", type = "institution")
official <- recipe_certification("official", certified_by = inst)
```
