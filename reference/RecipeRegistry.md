# RecipeRegistry

Local JSON-backed catalog for recipe discovery, ranking, and filtering.

## Methods

### Public methods

- [`RecipeRegistry$new()`](#method-RecipeRegistry-new)

- [`RecipeRegistry$register()`](#method-RecipeRegistry-register)

- [`RecipeRegistry$unregister()`](#method-RecipeRegistry-unregister)

- [`RecipeRegistry$search()`](#method-RecipeRegistry-search)

- [`RecipeRegistry$filter()`](#method-RecipeRegistry-filter)

- [`RecipeRegistry$rank_by_downloads()`](#method-RecipeRegistry-rank_by_downloads)

- [`RecipeRegistry$rank_by_certification()`](#method-RecipeRegistry-rank_by_certification)

- [`RecipeRegistry$get()`](#method-RecipeRegistry-get)

- [`RecipeRegistry$list_all()`](#method-RecipeRegistry-list_all)

- [`RecipeRegistry$save()`](#method-RecipeRegistry-save)

- [`RecipeRegistry$load()`](#method-RecipeRegistry-load)

- [`RecipeRegistry$list_by_user()`](#method-RecipeRegistry-list_by_user)

- [`RecipeRegistry$list_by_institution()`](#method-RecipeRegistry-list_by_institution)

- [`RecipeRegistry$stats()`](#method-RecipeRegistry-stats)

- [`RecipeRegistry$print()`](#method-RecipeRegistry-print)

- [`RecipeRegistry$clone()`](#method-RecipeRegistry-clone)

------------------------------------------------------------------------

### Method `new()`

Create a new empty RecipeRegistry

#### Usage

    RecipeRegistry$new()

------------------------------------------------------------------------

### Method `register()`

Register a recipe in the catalog

#### Usage

    RecipeRegistry$register(recipe)

#### Arguments

- `recipe`:

  Recipe object to register

------------------------------------------------------------------------

### Method `unregister()`

Remove a recipe from the catalog by id

#### Usage

    RecipeRegistry$unregister(recipe_id)

#### Arguments

- `recipe_id`:

  Recipe id to remove

------------------------------------------------------------------------

### Method [`search()`](https://rdrr.io/r/base/search.html)

Search recipes by name or description (case-insensitive)

#### Usage

    RecipeRegistry$search(query)

#### Arguments

- `query`:

  Character search query

#### Returns

List of matching Recipe objects

------------------------------------------------------------------------

### Method [`filter()`](https://rdrr.io/r/stats/filter.html)

Filter recipes by criteria

#### Usage

    RecipeRegistry$filter(
      survey_type = NULL,
      edition = NULL,
      category = NULL,
      certification_level = NULL,
      topic = NULL
    )

#### Arguments

- `survey_type`:

  Character survey type or NULL

- `edition`:

  Character edition or NULL

- `category`:

  Character category name or NULL

- `certification_level`:

  Character certification level or NULL

- `topic`:

  Character topic name or NULL

#### Returns

List of matching Recipe objects

------------------------------------------------------------------------

### Method `rank_by_downloads()`

Rank recipes by download count (descending)

#### Usage

    RecipeRegistry$rank_by_downloads(n = NULL)

#### Arguments

- `n`:

  Integer max number to return, or NULL for all

#### Returns

List of Recipe objects sorted by downloads

------------------------------------------------------------------------

### Method `rank_by_certification()`

Rank recipes by certification level then downloads

#### Usage

    RecipeRegistry$rank_by_certification(n = NULL)

#### Arguments

- `n`:

  Integer max number to return, or NULL for all

#### Returns

List of Recipe objects sorted by cert level then downloads

------------------------------------------------------------------------

### Method [`get()`](https://rdrr.io/r/base/get.html)

Get a single recipe by id

#### Usage

    RecipeRegistry$get(recipe_id)

#### Arguments

- `recipe_id`:

  Recipe id

#### Returns

Recipe object or NULL

------------------------------------------------------------------------

### Method `list_all()`

List all registered recipes

#### Usage

    RecipeRegistry$list_all()

#### Returns

List of all Recipe objects

------------------------------------------------------------------------

### Method [`save()`](https://rdrr.io/r/base/save.html)

Save the registry catalog to a JSON file

#### Usage

    RecipeRegistry$save(path)

#### Arguments

- `path`:

  Character file path

------------------------------------------------------------------------

### Method [`load()`](https://rdrr.io/r/base/load.html)

Load a registry catalog from a JSON file

#### Usage

    RecipeRegistry$load(path)

#### Arguments

- `path`:

  Character file path

------------------------------------------------------------------------

### Method `list_by_user()`

List recipes by author user name

#### Usage

    RecipeRegistry$list_by_user(user_name)

#### Arguments

- `user_name`:

  Character user name

#### Returns

List of matching Recipe objects

------------------------------------------------------------------------

### Method `list_by_institution()`

List recipes by institution (including members)

#### Usage

    RecipeRegistry$list_by_institution(institution_name)

#### Arguments

- `institution_name`:

  Character institution name

#### Returns

List of matching Recipe objects

------------------------------------------------------------------------

### Method `stats()`

Get registry statistics

#### Usage

    RecipeRegistry$stats()

#### Returns

List with total, by_category, by_certification counts

------------------------------------------------------------------------

### Method [`print()`](https://rdrr.io/r/base/print.html)

Print registry summary

#### Usage

    RecipeRegistry$print(...)

#### Arguments

- `...`:

  Additional arguments (not used)

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    RecipeRegistry$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
