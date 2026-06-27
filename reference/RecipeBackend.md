# RecipeBackend

Backend-agnostic factory for recipe storage and retrieval. Supports
"local" (JSON-backed RecipeRegistry) and "api" (remote plumber API)
backends.

## Public fields

- `type`:

  Character backend type ("local" or "api").

## Methods

### Public methods

- [`RecipeBackend$new()`](#method-RecipeBackend-new)

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

### Method `new()`

Create a new RecipeBackend

#### Usage

    RecipeBackend$new(type, path = NULL)

#### Arguments

- `type`:

  Character. "local" or "api".

- `path`:

  Character. File path for local backend (optional).

------------------------------------------------------------------------

### Method `publish()`

Publish a recipe to the backend

#### Usage

    RecipeBackend$publish(recipe)

#### Arguments

- `recipe`:

  Recipe object

------------------------------------------------------------------------

### Method [`search()`](https://rdrr.io/r/base/search.html)

Search recipes

#### Usage

    RecipeBackend$search(query)

#### Arguments

- `query`:

  Character search string

#### Returns

List of matching Recipe objects

------------------------------------------------------------------------

### Method [`get()`](https://rdrr.io/r/base/get.html)

Get a recipe by id

#### Usage

    RecipeBackend$get(id)

#### Arguments

- `id`:

  Recipe id

#### Returns

Recipe object or NULL

------------------------------------------------------------------------

### Method `increment_downloads()`

Increment download count for a recipe

#### Usage

    RecipeBackend$increment_downloads(id)

#### Arguments

- `id`:

  Recipe id

------------------------------------------------------------------------

### Method [`rank()`](https://rdrr.io/r/base/rank.html)

Rank recipes by downloads

#### Usage

    RecipeBackend$rank(n = NULL)

#### Arguments

- `n`:

  Integer max to return

#### Returns

List of Recipe objects

------------------------------------------------------------------------

### Method [`filter()`](https://rdrr.io/r/stats/filter.html)

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

### Method `list_all()`

List all recipes

#### Usage

    RecipeBackend$list_all()

#### Returns

List of Recipe objects

------------------------------------------------------------------------

### Method [`save()`](https://rdrr.io/r/base/save.html)

Save local backend to disk

#### Usage

    RecipeBackend$save()

------------------------------------------------------------------------

### Method [`load()`](https://rdrr.io/r/base/load.html)

Load local backend from disk

#### Usage

    RecipeBackend$load()

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    RecipeBackend$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
