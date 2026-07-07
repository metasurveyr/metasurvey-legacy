# Remove variables from survey data (step)

Creates a step that removes one or more variables from the survey data
when baked.

## Usage

``` r
step_remove(
  svy,
  ...,
  vars = NULL,
  .copy = use_copy_default(),
  comment = "Remove variables",
  use_copy = deprecated(),
  lazy = lazy_default(),
  record = TRUE
)
```

## Arguments

- svy:

  A Survey or RotativePanelSurvey object

- ...:

  Unquoted variable names to remove, or a character vector

- vars:

  Character vector of variable names to remove. Alternative to `...` for
  programmatic use.

- .copy:

  Whether to operate on a copy (default:
  [`use_copy_default()`](https://metasurveyr.github.io/metasurvey/reference/use_copy_default.md))

- comment:

  Descriptive text for the step for documentation and traceability
  (default `"Remove variables"`).

- use_copy:

  **\[deprecated\]** Use `.copy` instead.

- lazy:

  Internal. Whether to delay execution (default
  [`lazy_default()`](https://metasurveyr.github.io/metasurvey/reference/lazy_default.md)).

- record:

  Internal. Whether to record the step (default `TRUE`).

## Value

Survey object with the specified variables removed (or queued for
removal).

## Details

**Lazy evaluation (default):** By default, steps are recorded but **not
executed** until
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
is called.

Variables can be specified in two ways:

- **Unquoted names:** `step_remove(svy, age, income)`

- **Character vector:** `step_remove(svy, vars = c("age", "income"))`

**Name resolution:** bare symbols passed via `...` that match a column
name always refer to that column, even if a variable with the same name
exists in the calling environment (column takes precedence). Symbols
that do not match any column are looked up in the calling environment
and, if they hold a character vector, its values are used as column
names. For fully programmatic use prefer `vars = c("age", "income")`,
which skips symbol resolution entirely.

Variables that don't exist in the data produce a warning (not an error),
allowing pipelines to be robust to missing columns.

## See also

Other steps:
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
[`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md),
[`step_collapse()`](https://metasurveyr.github.io/metasurvey/reference/step_collapse.md),
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md),
[`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md),
[`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md),
[`step_quantile()`](https://metasurveyr.github.io/metasurvey/reference/step_quantile.md),
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md),
[`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md),
[`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md),
[`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md),
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)

## Examples

``` r
dt <- data.table::data.table(
  id = 1:5, age = c(25, 30, 45, 50, 60),
  w = rep(1, 5)
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "ech",
  psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
)
svy2 <- step_remove(svy, age)
svy2 <- bake_steps(svy2)
"age" %in% names(get_data(svy2)) # FALSE
#> [1] FALSE
```
