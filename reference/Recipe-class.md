# Recipe R6 class

Recipe R6 class

Recipe R6 class

## Format

An R6 class generator (R6ClassGenerator)

## Value

An object of class `Recipe`.

## Details

R6 class representing a reproducible data transformation recipe for
surveys. It encapsulates metadata, declared dependencies, and a list of
transformation steps to be applied to a Survey object.

## Methods

- \$new(name, edition, survey_type, default_engine, depends_on, user,
  description, steps, id, doi, topic):

  Class constructor.

- \$doc():

  Auto-generate documentation from recipe steps. Returns a list with
  metadata, input_variables, output_variables, and pipeline information.

- \$validate(svy):

  Validate that a survey object has all required input variables.

## See also

[`recipe`](https://metasurveyr.github.io/metasurvey/reference/recipe.md),
[`save_recipe`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md),
[`read_recipe`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md),
[`bake_recipes`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md)

Other recipes:
[`add_recipe()`](https://metasurveyr.github.io/metasurvey/reference/add_recipe.md),
[`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md),
[`explore_recipes()`](https://metasurveyr.github.io/metasurvey/reference/explore_recipes.md),
[`get_recipe()`](https://metasurveyr.github.io/metasurvey/reference/get_recipe.md),
[`harmonize()`](https://metasurveyr.github.io/metasurvey/reference/harmonize.md),
[`print.Recipe()`](https://metasurveyr.github.io/metasurvey/reference/print.Recipe.md),
[`publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/publish_recipe.md),
[`read_recipe()`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md),
[`recipe()`](https://metasurveyr.github.io/metasurvey/reference/recipe.md),
[`save_recipe()`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md),
[`steps_to_recipe()`](https://metasurveyr.github.io/metasurvey/reference/steps_to_recipe.md)

## Public fields

- `name`:

  Descriptive name of the recipe (character).

- `edition`:

  Target edition/period (character or Date).

- `survey_type`:

  Survey type (character), e.g., "ech", "eaii".

- `default_engine`:

  Default evaluation engine (character).

- `depends_on`:

  Vector/list of dependencies declared by the steps.

- `user`:

  Author/owner (character).

- `description`:

  Recipe description (character).

- `id`:

  Unique identifier (character/numeric).

- `steps`:

  List of step calls that make up the workflow.

- `doi`:

  DOI or external identifier (character\|NULL).

- `bake`:

  Logical flag indicating whether it has been applied.

- `topic`:

  Recipe topic (character\|NULL).

- `step_objects`:

  List of Step R6 objects (list\|NULL), used for documentation
  generation.

- `categories`:

  List of RecipeCategory objects for classification.

- `downloads`:

  Integer download/usage count.

- `certification`:

  RecipeCertification object (default community).

- `user_info`:

  RecipeUser object or NULL.

- `version`:

  Recipe version string.

- `depends_on_recipes`:

  List of recipe IDs that must be applied before this one.

- `data_source`:

  List with S3 bucket info (s3_bucket, s3_prefix, file_pattern,
  provider) or NULL.

- `labels`:

  List with variable and value labels (var_labels, val_labels) or NULL.

## Methods

### Public methods

- [`Recipe$new()`](#method-Recipe-new)

- [`Recipe$increment_downloads()`](#method-Recipe-increment_downloads)

- [`Recipe$certify()`](#method-Recipe-certify)

- [`Recipe$add_category()`](#method-Recipe-add_category)

- [`Recipe$remove_category()`](#method-Recipe-remove_category)

- [`Recipe$to_list()`](#method-Recipe-to_list)

- [`Recipe$doc()`](#method-Recipe-doc)

- [`Recipe$validate()`](#method-Recipe-validate)

- [`Recipe$clone()`](#method-Recipe-clone)

------------------------------------------------------------------------

### Method `new()`

Create a Recipe object

#### Usage

    Recipe$new(
      name,
      edition,
      survey_type,
      default_engine,
      depends_on,
      user,
      description,
      steps,
      id,
      doi = NULL,
      topic = NULL,
      step_objects = NULL,
      cached_doc = NULL,
      categories = list(),
      downloads = 0L,
      certification = NULL,
      user_info = NULL,
      version = "1.0.0",
      depends_on_recipes = list(),
      data_source = NULL,
      labels = NULL
    )

#### Arguments

- `name`:

  Descriptive name of the recipe (character)

- `edition`:

  Target edition/period (character or Date)

- `survey_type`:

  Survey type (character), e.g., "ech", "eaii"

- `default_engine`:

  Default evaluation engine (character)

- `depends_on`:

  Vector or list of declared dependencies

- `user`:

  Author or owner of the recipe (character)

- `description`:

  Detailed description of the recipe (character)

- `steps`:

  List of step calls that make up the workflow

- `id`:

  Unique identifier (character or numeric)

- `doi`:

  DOI or external identifier (character or NULL)

- `topic`:

  Recipe topic (character or NULL)

- `step_objects`:

  List of Step R6 objects (optional, used for doc generation)

- `cached_doc`:

  Pre-computed documentation (optional, used when loading from JSON)

- `categories`:

  List of RecipeCategory objects (optional)

- `downloads`:

  Integer download count (default 0)

- `certification`:

  RecipeCertification object (optional, default community)

- `user_info`:

  RecipeUser object (optional)

- `version`:

  Recipe version string (default "1.0.0")

- `depends_on_recipes`:

  List of recipe IDs that must be applied before this one (optional)

- `data_source`:

  List with S3 bucket info (optional)

- `labels`:

  List with var_labels and val_labels (optional)

------------------------------------------------------------------------

### Method `increment_downloads()`

Increment the download counter

#### Usage

    Recipe$increment_downloads()

------------------------------------------------------------------------

### Method `certify()`

Certify the recipe at a given level

#### Usage

    Recipe$certify(user, level)

#### Arguments

- `user`:

  RecipeUser who is certifying

- `level`:

  Character certification level ("reviewed" or "official")

------------------------------------------------------------------------

### Method [`add_category()`](https://metasurveyr.github.io/metasurvey/reference/add_category.md)

Add a category to the recipe

#### Usage

    Recipe$add_category(category)

#### Arguments

- `category`:

  RecipeCategory to add

------------------------------------------------------------------------

### Method [`remove_category()`](https://metasurveyr.github.io/metasurvey/reference/remove_category.md)

Remove a category by name

#### Usage

    Recipe$remove_category(name)

#### Arguments

- `name`:

  Character category name to remove

------------------------------------------------------------------------

### Method `to_list()`

Serialize Recipe to a plain list suitable for JSON/API publishing. Steps
are encoded as character strings via deparse().

#### Usage

    Recipe$to_list()

#### Returns

A named list with all recipe fields.

------------------------------------------------------------------------

### Method `doc()`

Auto-generate documentation from recipe steps

#### Usage

    Recipe$doc()

#### Returns

A list with metadata, input_variables, output_variables, and pipeline
information

------------------------------------------------------------------------

### Method `validate()`

Validate that a survey has all required input variables

#### Usage

    Recipe$validate(svy)

#### Arguments

- `svy`:

  A Survey object

#### Returns

TRUE if valid, otherwise stops with error listing missing variables

------------------------------------------------------------------------

### Method `clone()`

The objects of this class are cloneable with this method.

#### Usage

    Recipe$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
# Use the recipe() constructor:
svy <- survey_empty(type = "ech", edition = "2023")
r <- recipe(
  name = "Example", user = "Test", svy = svy,
  description = "Example recipe"
)
```
