# RecipeCategory

Standardized taxonomy for classifying recipes by domain. Supports
hierarchical categories with parent-child relationships.

## Value

An object of class `RecipeCategory`.

## Methods

- \$new(name, description, parent):

  Constructor for creating a new category

- \$is_subcategory_of(ancestor_name):

  Check if this category is a subcategory of another

- \$get_path():

  Get full hierarchical path

- \$equals(other):

  Check equality by name

- \$to_list():

  Serialize to list for JSON

- \$print(...):

  Print category information

- \$from_list(lst):

  Class method to reconstruct from list (see details)

## See also

Other tidy-api:
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
[`recipe_user()`](https://metasurveyr.github.io/metasurvey/reference/recipe_user.md),
[`remove_category()`](https://metasurveyr.github.io/metasurvey/reference/remove_category.md),
[`search_recipes()`](https://metasurveyr.github.io/metasurvey/reference/search_recipes.md),
[`search_workflows()`](https://metasurveyr.github.io/metasurvey/reference/search_workflows.md),
[`set_user_info()`](https://metasurveyr.github.io/metasurvey/reference/set_user_info.md),
[`set_version()`](https://metasurveyr.github.io/metasurvey/reference/set_version.md)

## Public fields

- `name`:

  Character. Category identifier.

- `description`:

  Character. Human-readable description.

- `parent`:

  RecipeCategory or NULL. Parent category for hierarchy.

## Methods

### Public methods

- [`RecipeCategory$new()`](#method-RecipeCategory-initialize)

- [`RecipeCategory$is_subcategory_of()`](#method-RecipeCategory-is_subcategory_of)

- [`RecipeCategory$get_path()`](#method-RecipeCategory-get_path)

- [`RecipeCategory$equals()`](#method-RecipeCategory-equals)

- [`RecipeCategory$to_list()`](#method-RecipeCategory-to_list)

- [`RecipeCategory$print()`](#method-RecipeCategory-print)

- [`RecipeCategory$from_list()`](#method-RecipeCategory-from_list)

- [`RecipeCategory$clone()`](#method-RecipeCategory-clone)

------------------------------------------------------------------------

### `RecipeCategory$new()`

Create a new RecipeCategory

#### Usage

    RecipeCategory$new(name, description, parent = NULL)

#### Arguments

- `name`:

  Character. Category identifier (non-empty string).

- `description`:

  Character. Description of the category.

- `parent`:

  RecipeCategory or NULL. Parent category.

------------------------------------------------------------------------

### `RecipeCategory$is_subcategory_of()`

Check if this category is a subcategory of another

#### Usage

    RecipeCategory$is_subcategory_of(ancestor_name)

#### Arguments

- `ancestor_name`:

  Character. Name of the potential ancestor category.

#### Returns

Logical

------------------------------------------------------------------------

### `RecipeCategory$get_path()`

Get full hierarchical path

#### Usage

    RecipeCategory$get_path()

#### Returns

Character string with slash-separated path

------------------------------------------------------------------------

### `RecipeCategory$equals()`

Check equality by name

#### Usage

    RecipeCategory$equals(other)

#### Arguments

- `other`:

  RecipeCategory to compare with.

#### Returns

Logical

------------------------------------------------------------------------

### `RecipeCategory$to_list()`

Serialize to list for JSON

#### Usage

    RecipeCategory$to_list()

#### Returns

List representation

------------------------------------------------------------------------

### `RecipeCategory$print()`

Print category

#### Usage

    RecipeCategory$print(...)

#### Arguments

- `...`:

  Additional arguments (not used)

------------------------------------------------------------------------

### `RecipeCategory$from_list()`

Deserialize a RecipeCategory from a list

Class method to reconstruct a RecipeCategory from its list
representation.

#### Usage

    RecipeCategory$from_list(lst)

#### Arguments

- `lst`:

  List with name, description, parent fields, or NULL

- `lst`:

  List with name, description, parent fields, or NULL.

#### Returns

RecipeCategory object or NULL

------------------------------------------------------------------------

### `RecipeCategory$clone()`

The objects of this class are cloneable with this method.

#### Usage

    RecipeCategory$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
# Use recipe_category() for the public API:
cat <- recipe_category(
  "economics", "Economic indicators"
)
sub <- recipe_category(
  "labor_market", "Labor market",
  parent = "economics"
)
```
