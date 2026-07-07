# Survey R6 class

R6 class that encapsulates survey data, metadata (type, edition,
periodicity), sampling design (simple/replicate),
steps/recipes/workflows, and utilities to manage them.

Only copies the data; reuses design objects and other metadata. Much
faster than clone(deep=TRUE) but design objects are shared.

## Format

An R6 class generator (R6ClassGenerator)

## Value

R6 class generator for Survey.

## Main methods

- \$new(data, edition, type, psu, strata, engine, weight, design = NULL,
  steps = NULL, recipes = list()):

  Constructor.

- \$set_data(data):

  Set data.

- \$set_edition(edition):

  Set edition.

- \$set_type(type):

  Set type.

- \$set_weight(weight):

  Set weight specification.

- \$print():

  Print summarized metadata.

- \$add_step(step):

  Add a step and invalidate design.

- \$add_recipe(recipe):

  Add a recipe (validates type and dependencies).

- \$add_workflow(workflow):

  Add a workflow.

- \$bake():

  Apply recipes and return updated Survey.

- \$ensure_design():

  Lazily initialize the sampling design.

- \$update_design():

  Update design variables with current data.

- \$shallow_clone():

  Efficient copy (shares design, copies data).

## See also

[`survey_empty`](https://metasurveyr.github.io/metasurvey/reference/survey_empty.md),
[`bake_recipes`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md),
[`cat_design`](https://metasurveyr.github.io/metasurvey/reference/cat_design.md),
[`cat_recipes`](https://metasurveyr.github.io/metasurvey/reference/cat_recipes.md)

Other survey-objects:
[`cat_design()`](https://metasurveyr.github.io/metasurvey/reference/cat_design.md),
[`cat_design_type()`](https://metasurveyr.github.io/metasurvey/reference/cat_design_type.md),
[`get_data()`](https://metasurveyr.github.io/metasurvey/reference/get_data.md),
[`get_metadata()`](https://metasurveyr.github.io/metasurvey/reference/get_metadata.md),
[`has_design()`](https://metasurveyr.github.io/metasurvey/reference/has_design.md),
[`has_recipes()`](https://metasurveyr.github.io/metasurvey/reference/has_recipes.md),
[`has_steps()`](https://metasurveyr.github.io/metasurvey/reference/has_steps.md),
[`is_baked()`](https://metasurveyr.github.io/metasurvey/reference/is_baked.md),
[`set_data()`](https://metasurveyr.github.io/metasurvey/reference/set_data.md),
[`survey_empty()`](https://metasurveyr.github.io/metasurvey/reference/survey_empty.md),
[`survey_to_data_frame()`](https://metasurveyr.github.io/metasurvey/reference/survey_to_data_frame.md),
[`survey_to_datatable()`](https://metasurveyr.github.io/metasurvey/reference/survey_to_datatable.md),
[`survey_to_tibble()`](https://metasurveyr.github.io/metasurvey/reference/survey_to_tibble.md)

## Public fields

- `data`:

  Survey data (data.frame/data.table).

- `edition`:

  Reference edition or period.

- `type`:

  Survey type, e.g., "ech" (character).

- `periodicity`:

  Periodicity detected by validate_time_pattern.

- `default_engine`:

  Default engine (character).

- `weight`:

  List with weight specifications per estimation type.

- `steps`:

  List of steps applied to the survey.

- `recipes`:

  List of
  [Recipe](https://metasurveyr.github.io/metasurvey/reference/Recipe-class.md)
  objects associated.

- `workflows`:

  List of workflows.

- `design`:

  List of survey design objects (survey/surveyrep).

- `psu`:

  Primary Sampling Unit specification (formula or character).

- `strata`:

  Stratification variable name (character or NULL).

- `design_initialized`:

  Logical flag for lazy design initialization.

- `provenance`:

  Data lineage metadata (see
  [`provenance()`](https://metasurveyr.github.io/metasurvey/reference/provenance.md)).

## Active bindings

- `design_active`:

  Deprecated. Use `ensure_design()` instead.

## Methods

### Public methods

- [`Survey$new()`](#method-Survey-initialize)

- [`Survey$get_data()`](#method-Survey-get_data)

- [`Survey$get_edition()`](#method-Survey-get_edition)

- [`Survey$get_type()`](#method-Survey-get_type)

- [`Survey$set_data()`](#method-Survey-set_data)

- [`Survey$set_edition()`](#method-Survey-set_edition)

- [`Survey$set_type()`](#method-Survey-set_type)

- [`Survey$set_weight()`](#method-Survey-set_weight)

- [`Survey$print()`](#method-Survey-print)

- [`Survey$add_step()`](#method-Survey-add_step)

- [`Survey$add_recipe()`](#method-Survey-add_recipe)

- [`Survey$add_workflow()`](#method-Survey-add_workflow)

- [`Survey$bake()`](#method-Survey-bake)

- [`Survey$head()`](#method-Survey-head)

- [`Survey$str()`](#method-Survey-str)

- [`Survey$set_design()`](#method-Survey-set_design)

- [`Survey$ensure_design()`](#method-Survey-ensure_design)

- [`Survey$update_design()`](#method-Survey-update_design)

- [`Survey$shallow_clone()`](#method-Survey-shallow_clone)

- [`Survey$clone()`](#method-Survey-clone)

------------------------------------------------------------------------

### `Survey$new()`

Create a Survey object

#### Usage

    Survey$new(
      data,
      edition,
      type,
      psu = NULL,
      strata = NULL,
      engine,
      weight,
      design = NULL,
      steps = NULL,
      recipes = list()
    )

#### Arguments

- `data`:

  Survey data

- `edition`:

  Edition or period

- `type`:

  Survey type (character)

- `psu`:

  PSU variable or formula (optional)

- `strata`:

  Stratification variable name (optional)

- `engine`:

  Default engine

- `weight`:

  Weight specification(s) per estimation type

- `design`:

  Pre-built design (optional)

- `steps`:

  Initial steps list (optional)

- `recipes`:

  List of Recipe (optional)

------------------------------------------------------------------------

### `Survey$get_data()`

Return the underlying data

#### Usage

    Survey$get_data()

------------------------------------------------------------------------

### `Survey$get_edition()`

Return the survey edition/period

#### Usage

    Survey$get_edition()

------------------------------------------------------------------------

### `Survey$get_type()`

Return the survey type identifier

#### Usage

    Survey$get_type()

------------------------------------------------------------------------

### `Survey$set_data()`

Set the underlying data

#### Usage

    Survey$set_data(data)

#### Arguments

- `data`:

  New survey data

------------------------------------------------------------------------

### `Survey$set_edition()`

Set the survey edition/period

#### Usage

    Survey$set_edition(edition)

#### Arguments

- `edition`:

  New edition or period

------------------------------------------------------------------------

### `Survey$set_type()`

Set the survey type

#### Usage

    Survey$set_type(type)

#### Arguments

- `type`:

  New type identifier

------------------------------------------------------------------------

### `Survey$set_weight()`

Set weight specification(s) per estimation type

#### Usage

    Survey$set_weight(weight)

#### Arguments

- `weight`:

  Weight specification list or character

------------------------------------------------------------------------

### `Survey$print()`

Print summarized metadata to console

#### Usage

    Survey$print()

------------------------------------------------------------------------

### `Survey$add_step()`

Add a step and invalidate design

#### Usage

    Survey$add_step(step)

#### Arguments

- `step`:

  Step object

------------------------------------------------------------------------

### `Survey$add_recipe()`

Add a recipe

#### Usage

    Survey$add_recipe(recipe, bake = lazy_default())

#### Arguments

- `recipe`:

  Recipe object

- `bake`:

  Whether to bake lazily (internal flag)

------------------------------------------------------------------------

### `Survey$add_workflow()`

Add a workflow to the survey

#### Usage

    Survey$add_workflow(workflow)

#### Arguments

- `workflow`:

  Workflow object

------------------------------------------------------------------------

### `Survey$bake()`

Apply recipes and return updated Survey

#### Usage

    Survey$bake()

------------------------------------------------------------------------

### `Survey$head()`

Return the head of the underlying data

#### Usage

    Survey$head()

------------------------------------------------------------------------

### `Survey$str()`

Display the structure of the underlying data

#### Usage

    Survey$str()

------------------------------------------------------------------------

### `Survey$set_design()`

Set the survey design object

#### Usage

    Survey$set_design(design)

#### Arguments

- `design`:

  Survey design object or list

------------------------------------------------------------------------

### `Survey$ensure_design()`

Ensure survey design is initialized (lazy initialization)

#### Usage

    Survey$ensure_design()

#### Returns

Invisibly returns self

------------------------------------------------------------------------

### `Survey$update_design()`

Update design variables using current data and weight

#### Usage

    Survey$update_design()

------------------------------------------------------------------------

### `Survey$shallow_clone()`

Create a shallow copy of the Survey (optimized for performance)

#### Usage

    Survey$shallow_clone()

#### Returns

New Survey object with copied data but shared design

------------------------------------------------------------------------

### `Survey$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Survey$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
dt <- data.table::data.table(id = 1:5, x = rnorm(5), w = rep(1, 5))
svy <- Survey$new(
  data = dt, edition = "2023", type = "test",
  psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
)
svy
#> Type: TEST
#> Edition: 2023
#> Periodicity: Annual
#> Engine: data.table
#> Design: 
#>   Design: Not initialized (lazy initialization - will be created when needed)
#> 
#> Steps: None
#> Recipes: None 
```
