# RecipeBackend

Backend-agnostic factory for recipe storage and retrieval. Supports
"local" (JSON-backed RecipeRegistry) and "api" (remote plumber API)
backends.

## Public fields

- `type`:

  Character backend type ("local" or "api").

## Methods

### Public methods

- [`RecipeBackend$new()`](#method-RecipeBackend-initialize)

- [`RecipeBackend$publish()`](#method-RecipeBackend-publish)

- [`RecipeBackend$search()`](#method-RecipeBackend-search)

- [`RecipeBackend$get()`](#method-RecipeBackend-get)

- [`RecipeBackend$increment_downloads()`](#method-RecipeBackend-increment_downloads)

- [`RecipeBackend$rank()`](#method-RecipeBackend-rank)

- [`RecipeBackend$filter()`](#method-RecipeBackend-filter)

- [`RecipeBackend$list_all()`](#method-RecipeBackend-list_all)

- [`RecipeBackend$save()`](#method-RecipeBackend-save)

- [`RecipeBackend$load()`](#method-RecipeBackend-load)

- [`RecipeBackend$clone()`](#method-RecipeBackend-clone)

------------------------------------------------------------------------

### `RecipeBackend$new()`

Create a new RecipeBackend

#### Usage

    RecipeBackend$new(type, path = NULL)

#### Arguments

- `type`:

  Character. "local" or "api".

- `path`:

  Character. File path for local backend (optional).

------------------------------------------------------------------------

### `RecipeBackend$publish()`

Publish a recipe to the backend

#### Usage

    RecipeBackend$publish(recipe)

#### Arguments

- `recipe`:

  Recipe object

------------------------------------------------------------------------

### `RecipeBackend$search()`

Search recipes

#### Usage

    RecipeBackend$search(query)

#### Arguments

- `query`:

  Character search string

#### Returns

List of matching Recipe objects

------------------------------------------------------------------------

### `RecipeBackend$get()`

Get a recipe by id

#### Usage

    RecipeBackend$get(id)

#### Arguments

- `id`:

  Recipe id

#### Returns

Recipe object or NULL

------------------------------------------------------------------------

### `RecipeBackend$increment_downloads()`

Increment download count for a recipe

#### Usage

    RecipeBackend$increment_downloads(id)

#### Arguments

- `id`:

  Recipe id

------------------------------------------------------------------------

### `RecipeBackend$rank()`

Rank recipes by downloads

#### Usage

    RecipeBackend$rank(n = NULL)

#### Arguments

- `n`:

  Integer max to return

#### Returns

List of Recipe objects

------------------------------------------------------------------------

### `RecipeBackend$filter()`

Filter recipes by criteria

#### Usage

    RecipeBackend$filter(
      survey_type = NULL,
      edition = NULL,
      category = NULL,
      certification_level = NULL,
      topic = NULL
    )

#### Arguments

- `survey_type`:

  Character or NULL

- `edition`:

  Character or NULL

- `category`:

  Character or NULL

- `certification_level`:

  Character or NULL

- `topic`:

  Character or NULL

#### Returns

List of matching Recipe objects

------------------------------------------------------------------------

### `RecipeBackend$list_all()`

List all recipes

#### Usage

    RecipeBackend$list_all()

#### Returns

List of Recipe objects

------------------------------------------------------------------------

### `RecipeBackend$save()`

Save local backend to disk

#### Usage

    RecipeBackend$save()

------------------------------------------------------------------------

### `RecipeBackend$load()`

Load local backend from disk

#### Usage

    RecipeBackend$load()

------------------------------------------------------------------------

### `RecipeBackend$clone()`

The objects of this class are cloneable with this method.

#### Usage

    RecipeBackend$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
