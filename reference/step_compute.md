# Create computation steps for survey variables

This function uses optimized expression evaluation with automatic
dependency detection and error prevention. All computations are
validated before execution.

## Usage

``` r
step_compute(
  svy = NULL,
  ...,
  .by = NULL,
  .copy = use_copy_default(),
  comment = "Compute step",
  .level = "auto",
  use_copy = deprecated()
)
```

## Arguments

- svy:

  A `Survey` or `RotativePanelSurvey` object. If NULL, creates a step
  that can be applied later using the pipe operator (%\>%)

- ...:

  Computation expressions with automatic optimization. Names are
  assigned using `new_var = expression`

- .by:

  Vector of variables to group computations by. The system automatically
  validates these variables exist before execution

- .copy:

  Logical indicating whether to create a copy of the object before
  applying transformations. Defaults to
  [`use_copy_default()`](https://metasurveyr.github.io/metasurvey/reference/use_copy_default.md)

- comment:

  Descriptive text for the step for documentation and traceability.
  Compatible with Markdown syntax. Defaults to "Compute step"

- .level:

  For RotativePanelSurvey objects (default `"auto"`), specifies the
  level where computations are applied: `"auto"` (both),
  `"implantation"`, or `"follow_up"`

- use_copy:

  **\[deprecated\]** Use `.copy` instead.

## Value

Same type of input object (`Survey` or `RotativePanelSurvey`) with new
computed variables and the step added to the history

## Details

**Execution model:** The computation is applied immediately when the
step is created and the step is recorded as already executed
(`bake = TRUE`). Calling
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
afterwards is safe: executed steps are skipped, so expressions are never
applied twice.

**Expression processing:** Expressions are evaluated using data.table's
`:=` operator. Within a single call, expressions are evaluated
sequentially, so a later expression can reference variables created by
earlier ones (mutate semantics):
`step_compute(svy, horamen = f85 * 4.3, yhora = pt4 / horamen)`.
Variable dependencies are detected automatically via
[`all.vars()`](https://rdrr.io/r/base/allnames.html); names created by
earlier expressions of the same call are not reported as dependencies.
Missing variables are caught before execution.

**Grouped computations:** Use `.by` to compute aggregated values (e.g.,
group means) broadcast to all rows of each group. Row order is
preserved.

For RotativePanelSurvey objects, `.level` controls where computations
are applied:

- `"auto"` (default): applies to both implantation and follow-ups

- `"implantation"`: household/dwelling level only

- `"follow_up"`: individual/person level only

## See also

[`step_recode`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md)
for categorical recodings
[`bake_steps`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
to execute all pending steps

Other steps:
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
[`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md),
[`step_collapse()`](https://metasurveyr.github.io/metasurvey/reference/step_collapse.md),
[`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md),
[`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md),
[`step_quantile()`](https://metasurveyr.github.io/metasurvey/reference/step_quantile.md),
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md),
[`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md),
[`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md),
[`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md),
[`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md),
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)

## Examples

``` r
# Basic computation
dt <- data.table::data.table(
  id = 1:5, age = c(25, 30, 45, 50, 60), w = 1
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "test",
  psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
)
svy <- svy |> step_compute(age_squared = age^2, comment = "Age squared")
svy <- bake_steps(svy)
get_data(svy)
#>       id   age     w age_squared
#>    <int> <num> <num>       <num>
#> 1:     1    25     1         625
#> 2:     2    30     1         900
#> 3:     3    45     1        2025
#> 4:     4    50     1        2500
#> 5:     5    60     1        3600

# \donttest{
# ECH example: labor indicator
# ech <- ech |>
#   step_compute(
#     unemployed = ifelse(POBPCOAC %in% 3:5, 1, 0),
#     comment = "Unemployment indicator")
# }
```
