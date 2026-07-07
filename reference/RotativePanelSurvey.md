# RotativePanelSurvey Class

This class represents a rotative panel survey, which includes
implantation and follow-up surveys. It provides methods to access and
manipulate survey data, steps, recipes, workflows, and designs.

## Value

An object of class `RotativePanelSurvey`.

## See also

Other panel-surveys:
[`PoolSurvey`](https://metasurveyr.github.io/metasurvey/reference/PoolSurvey.md),
[`extract_surveys()`](https://metasurveyr.github.io/metasurvey/reference/extract_surveys.md),
[`get_follow_up()`](https://metasurveyr.github.io/metasurvey/reference/get_follow_up.md),
[`get_implantation()`](https://metasurveyr.github.io/metasurvey/reference/get_implantation.md)

## Public fields

- `implantation`:

  A survey object representing the implantation survey.

- `follow_up`:

  A list of survey objects representing the follow-up surveys.

- `type`:

  A string indicating the type of the survey.

- `default_engine`:

  A string specifying the default engine used for processing.

- `steps`:

  A list of steps applied to the survey.

- `recipes`:

  A list of recipes associated with the survey.

- `workflows`:

  A list of workflows associated with the survey.

- `design`:

  A design object for the survey.

- `periodicity`:

  A list containing the periodicity of the implantation and follow-up
  surveys.

## Methods

### Public methods

- [`RotativePanelSurvey$new()`](#method-RotativePanelSurvey-initialize)

- [`RotativePanelSurvey$get_implantation()`](#method-RotativePanelSurvey-get_implantation)

- [`RotativePanelSurvey$get_follow_up()`](#method-RotativePanelSurvey-get_follow_up)

- [`RotativePanelSurvey$get_type()`](#method-RotativePanelSurvey-get_type)

- [`RotativePanelSurvey$get_default_engine()`](#method-RotativePanelSurvey-get_default_engine)

- [`RotativePanelSurvey$get_steps()`](#method-RotativePanelSurvey-get_steps)

- [`RotativePanelSurvey$get_recipes()`](#method-RotativePanelSurvey-get_recipes)

- [`RotativePanelSurvey$get_workflows()`](#method-RotativePanelSurvey-get_workflows)

- [`RotativePanelSurvey$get_design()`](#method-RotativePanelSurvey-get_design)

- [`RotativePanelSurvey$print()`](#method-RotativePanelSurvey-print)

- [`RotativePanelSurvey$clone()`](#method-RotativePanelSurvey-clone)

------------------------------------------------------------------------

### `RotativePanelSurvey$new()`

Initializes a new instance of the RotativePanelSurvey class.

#### Usage

    RotativePanelSurvey$new(
      implantation,
      follow_up,
      type,
      default_engine,
      steps,
      recipes,
      workflows,
      design
    )

#### Arguments

- `implantation`:

  A survey object representing the implantation survey.

- `follow_up`:

  A list of survey objects representing the follow-up surveys.

- `type`:

  A string indicating the type of the survey.

- `default_engine`:

  A string specifying the default engine used for processing.

- `steps`:

  A list of steps applied to the survey.

- `recipes`:

  A list of recipes associated with the survey.

- `workflows`:

  A list of workflows associated with the survey.

- `design`:

  A design object for the survey.

------------------------------------------------------------------------

### `RotativePanelSurvey$get_implantation()`

Retrieves the implantation survey.

#### Usage

    RotativePanelSurvey$get_implantation()

#### Returns

A survey object representing the implantation survey.

------------------------------------------------------------------------

### `RotativePanelSurvey$get_follow_up()`

Retrieves the follow-up surveys.

#### Usage

    RotativePanelSurvey$get_follow_up(
      index = length(self$follow_up),
      monthly = NULL,
      quarterly = NULL,
      semiannual = NULL,
      annual = NULL
    )

#### Arguments

- `index`:

  An integer specifying the index of the follow-up survey to retrieve.

- `monthly`:

  A vector of integers specifying monthly intervals.

- `quarterly`:

  A vector of integers specifying quarterly intervals.

- `semiannual`:

  A vector of integers specifying semiannual intervals.

- `annual`:

  A vector of integers specifying annual intervals.

#### Returns

A list of follow-up surveys matching the specified criteria.

------------------------------------------------------------------------

### `RotativePanelSurvey$get_type()`

Retrieves the type of the survey.

#### Usage

    RotativePanelSurvey$get_type()

#### Returns

A string indicating the type of the survey.

------------------------------------------------------------------------

### `RotativePanelSurvey$get_default_engine()`

Retrieves the default engine used for processing.

#### Usage

    RotativePanelSurvey$get_default_engine()

#### Returns

A string specifying the default engine.

------------------------------------------------------------------------

### `RotativePanelSurvey$get_steps()`

Retrieves the steps applied to the survey.

#### Usage

    RotativePanelSurvey$get_steps()

#### Returns

A list containing the steps for the implantation and follow-up surveys.

------------------------------------------------------------------------

### `RotativePanelSurvey$get_recipes()`

Retrieves the recipes associated with the survey.

#### Usage

    RotativePanelSurvey$get_recipes()

#### Returns

A list of recipes.

------------------------------------------------------------------------

### `RotativePanelSurvey$get_workflows()`

Retrieves the workflows associated with the survey.

#### Usage

    RotativePanelSurvey$get_workflows()

#### Returns

A list of workflows.

------------------------------------------------------------------------

### `RotativePanelSurvey$get_design()`

Retrieves the design object for the survey.

#### Usage

    RotativePanelSurvey$get_design()

#### Returns

A design object.

------------------------------------------------------------------------

### `RotativePanelSurvey$print()`

Prints metadata about the RotativePanelSurvey object.

#### Usage

    RotativePanelSurvey$print()

------------------------------------------------------------------------

### `RotativePanelSurvey$clone()`

The objects of this class are cloneable with this method.

#### Usage

    RotativePanelSurvey$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.

## Examples

``` r
impl <- Survey$new(
  data = data.table::data.table(id = 1:5, w = 1),
  edition = "2023", type = "ech", psu = NULL,
  engine = "data.table", weight = add_weight(annual = "w")
)
fu1 <- Survey$new(
  data = data.table::data.table(id = 1:5, w = 1),
  edition = "2023_01", type = "ech", psu = NULL,
  engine = "data.table", weight = add_weight(annual = "w")
)
panel <- RotativePanelSurvey$new(
  implantation = impl, follow_up = list(fu1),
  type = "ech", default_engine = "data.table",
  steps = list(), recipes = list(), workflows = list(), design = NULL
)
```
