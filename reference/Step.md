# Step Class Represents a step in a survey workflow.

The `Step` class is used to define and manage individual steps in a
survey workflow. Each step can include operations such as recoding
variables, computing new variables, or validating dependencies.

## Details

The `Step` class is part of the survey workflow system and is designed
to encapsulate all the information and operations required for a single
step in the workflow. Steps can be chained together to form a complete
workflow.

## Public fields

- `name`:

  The name of the step.

- `edition`:

  The edition of the survey associated with the step.

- `survey_type`:

  The type of survey associated with the step.

- `type`:

  The type of operation performed by the step (e.g., "compute",
  "recode").

- `new_var`:

  The name of the new variable created by the step, if applicable.

- `exprs`:

  A list of expressions defining the step's operations.

- `call`:

  The function call associated with the step.

- `svy_before`:

  Deprecated. Always NULL to prevent memory retention chains. Kept for
  backwards compatibility.

- `default_engine`:

  The default engine used for processing the step.

- `depends_on`:

  A list of variables that the step depends on.

- `comment`:

  Comments or notes about the step.

- `bake`:

  A logical value indicating whether the step has been executed.

- `by_vars`:

  Character vector of grouping variables or NULL.

- `recode_opts`:

  Named list of evaluated recode options (`.default`, `ordered`,
  `.to_factor`) or NULL.

## Methods

### Public methods

- [`Step$new()`](#method-Step-initialize)

- [`Step$clone()`](#method-Step-clone)

------------------------------------------------------------------------

### `Step$new()`

Create a new Step object

#### Usage

    Step$new(
      name,
      edition,
      survey_type,
      type,
      new_var,
      exprs,
      call,
      svy_before,
      default_engine,
      depends_on,
      comment = NULL,
      bake = !lazy_default(),
      comments = NULL,
      by_vars = NULL,
      recode_opts = NULL
    )

#### Arguments

- `name`:

  The name of the step.

- `edition`:

  The edition of the survey associated with the step.

- `survey_type`:

  The type of survey associated with the step.

- `type`:

  The type of operation performed by the step (e.g., "compute" or
  "recode").

- `new_var`:

  The name of the new variable created by the step, if applicable.

- `exprs`:

  A list of expressions defining the step's operations.

- `call`:

  The function call associated with the step.

- `svy_before`:

  Deprecated. Ignored (always set to NULL) to prevent memory retention
  chains.

- `default_engine`:

  The default engine used for processing the step.

- `depends_on`:

  A list of variables that the step depends on.

- `comment`:

  Comments or notes about the step.

- `bake`:

  A logical value indicating whether the step has been executed.

- `comments`:

  **\[deprecated\]** Use `comment` instead.

- `by_vars`:

  Character vector of grouping variables for grouped computations, or
  NULL.

- `recode_opts`:

  Named list of evaluated recode options (`.default`, `ordered`,
  `.to_factor`), or NULL for non-recode steps.

------------------------------------------------------------------------

### `Step$clone()`

The objects of this class are cloneable with this method.

#### Usage

    Step$clone(deep = FALSE)

#### Arguments

- `deep`:

  Whether to make a deep clone.
