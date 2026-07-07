# RecipeWorkflow R6 class

R6 class representing a publishable workflow that captures statistical
estimations applied to survey data. Workflows reference the recipes they
use and document the estimation calls made.

## Format

An R6 class generator (R6ClassGenerator)

## Value

An object of class `RecipeWorkflow`.

## Methods

- \$new(...):

  Class constructor.

- \$doc():

  Generate documentation for the workflow.

- \$to_list():

  Serialize to a plain list for JSON export.

- \$increment_downloads():

  Increment the download counter.

- \$add_category(category):

  Add a category.

- \$certify(user, level):

  Certify the workflow.

## See also

[`save_workflow`](https://metasurveyr.github.io/metasurvey/reference/save_workflow.md),
[`read_workflow`](https://metasurveyr.github.io/metasurvey/reference/read_workflow.md),
[`workflow`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)

Other workflows:
[`evaluate_cv()`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md),
[`print.RecipeWorkflow()`](https://metasurveyr.github.io/metasurvey/reference/print.RecipeWorkflow.md),
[`publish_workflow()`](https://metasurveyr.github.io/metasurvey/reference/publish_workflow.md),
[`read_workflow()`](https://metasurveyr.github.io/metasurvey/reference/read_workflow.md),
[`reproduce_workflow()`](https://metasurveyr.github.io/metasurvey/reference/reproduce_workflow.md),
[`save_workflow()`](https://metasurveyr.github.io/metasurvey/reference/save_workflow.md),
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md),
[`workflow_from_list()`](https://metasurveyr.github.io/metasurvey/reference/workflow_from_list.md),
[`workflow_table()`](https://metasurveyr.github.io/metasurvey/reference/workflow_table.md)

## Public fields

- `id`:

  Unique identifier (character).

- `name`:

  Descriptive name (character).

- `description`:

  Workflow description (character).

- `user`:

  Author/owner (character).

- `user_info`:

  RecipeUser object or NULL.

- `survey_type`:

  Survey type (character).

- `edition`:

  Survey edition (character).

- `estimation_type`:

  Character vector of estimation types used.

- `recipe_ids`:

  Character vector of recipe IDs referenced.

- `calls`:

  List of deparsed call strings.

- `call_metadata`:

  List of lists with type, formula, by, description fields.

- `categories`:

  List of RecipeCategory objects.

- `downloads`:

  Integer download count.

- `certification`:

  RecipeCertification object.

- `version`:

  Version string.

- `doi`:

  DOI or external identifier (character\|NULL).

- `created_at`:

  Creation timestamp (character).

- `weight_spec`:

  Named list with weight configuration per periodicity (list\|NULL).

## Methods

### Public methods

- [`RecipeWorkflow$new()`](#method-RecipeWorkflow-initialize)

- [`RecipeWorkflow$doc()`](#method-RecipeWorkflow-doc)

- [`RecipeWorkflow$to_list()`](#method-RecipeWorkflow-to_list)

- [`RecipeWorkflow$increment_downloads()`](#method-RecipeWorkflow-increment_downloads)

- [`RecipeWorkflow$certify()`](#method-RecipeWorkflow-certify)

- [`RecipeWorkflow$add_category()`](#method-RecipeWorkflow-add_category)

- [`RecipeWorkflow$remove_category()`](#method-RecipeWorkflow-remove_category)

- [`RecipeWorkflow$clone()`](#method-RecipeWorkflow-clone)

------------------------------------------------------------------------

### `RecipeWorkflow$new()`

Create a RecipeWorkflow object

#### Usage

    RecipeWorkflow$new(
      id = NULL,
      name,
      description = "",
      user = "Unknown",
      user_info = NULL,
      survey_type = "Unknown",
      edition = "Unknown",
      estimation_type = character(0),
      recipe_ids = character(0),
      calls = list(),
      call_metadata = list(),
      categories = list(),
      downloads = 0L,
      certification = NULL,
      version = "1.0.0",
      doi = NULL,
      created_at = NULL,
      weight_spec = NULL
    )

#### Arguments

- `id`:

  Unique identifier

- `name`:

  Descriptive name

- `description`:

  Workflow description

- `user`:

  Author name

- `user_info`:

  RecipeUser object or NULL

- `survey_type`:

  Survey type

- `edition`:

  Survey edition

- `estimation_type`:

  Character vector of estimation types

- `recipe_ids`:

  Character vector of recipe IDs

- `calls`:

  List of deparsed call strings

- `call_metadata`:

  List of call metadata lists

- `categories`:

  List of RecipeCategory objects

- `downloads`:

  Integer download count

- `certification`:

  RecipeCertification or NULL

- `version`:

  Version string

- `doi`:

  DOI or NULL

- `created_at`:

  Timestamp string or NULL (auto-generated)

- `weight_spec`:

  Named list with weight configuration per periodicity

------------------------------------------------------------------------

### `RecipeWorkflow$doc()`

Generate documentation for this workflow

#### Usage

    RecipeWorkflow$doc()

#### Returns

List with meta, recipe_ids, estimations, and estimation_types

------------------------------------------------------------------------

### `RecipeWorkflow$to_list()`

Serialize to a plain list for JSON export

#### Usage

    RecipeWorkflow$to_list()

#### Returns

A list suitable for jsonlite::write_json

------------------------------------------------------------------------

### `RecipeWorkflow$increment_downloads()`

Increment the download counter

#### Usage

    RecipeWorkflow$increment_downloads()

------------------------------------------------------------------------

### `RecipeWorkflow$certify()`

Certify the workflow at a given level

#### Usage

    RecipeWorkflow$certify(user, level)

#### Arguments

- `user`:

  RecipeUser who is certifying

- `level`:

  Character certification level

------------------------------------------------------------------------

### `RecipeWorkflow$add_category()`

Add a category to the workflow

#### Usage

    RecipeWorkflow$add_category(category)

#### Arguments

- `category`:

  RecipeCategory to add

------------------------------------------------------------------------

### `RecipeWorkflow$remove_category()`

Remove a category by name

#### Usage

    RecipeWorkflow$remove_category(name)

#### Arguments

- `name`:

  Character category name to remove

------------------------------------------------------------------------

### `RecipeWorkflow$clone()`

The objects of this class are cloneable with this method.

#### Usage

    RecipeWorkflow$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
wf <- RecipeWorkflow$new(
  name = "Labor workflow", description = "Unemployment rate",
  user = "test", survey_type = "ech", edition = "2023",
  estimation_type = "annual", recipe_ids = "r_001",
  calls = list("svymean(~desocupado, na.rm = TRUE)")
)
```
