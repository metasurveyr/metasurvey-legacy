# Weighted quantile groups (step)

Creates a step that assigns each row to a weighted quantile group
(quintiles, deciles, ...) of a numeric variable, e.g. income quintiles
at the household level. Quantiles are computed directly on the weighted
ECDF, without expanding the data by the weights.

## Usage

``` r
step_quantile(
  svy,
  new_var,
  x,
  n = 5,
  weight = NULL,
  .by = NULL,
  .copy = use_copy_default(),
  comment = "Quantile step",
  lazy = lazy_default(),
  record = TRUE
)
```

## Arguments

- svy:

  A
  [Survey](https://metasurveyr.github.io/metasurvey/reference/Survey.md)
  or
  [RotativePanelSurvey](https://metasurveyr.github.io/metasurvey/reference/RotativePanelSurvey.md)
  object.

- new_var:

  Name of the new group variable (unquoted or character).

- x:

  Name of the numeric variable to split into quantile groups (unquoted
  or character). Must be an existing column.

- n:

  Number of groups (default `5`, i.e. quintiles). Use `10` for deciles,
  `4` for quartiles, etc.

- weight:

  Name of the weight column (unquoted or character). Defaults to the
  survey's own weight.

- .by:

  Optional character vector of grouping variables: quantile breaks are
  computed independently within each group.

- .copy:

  Whether to operate on a copy (default:
  [`use_copy_default()`](https://metasurveyr.github.io/metasurvey/reference/use_copy_default.md)).

- comment:

  Descriptive text for the step (default `"Quantile step"`).

- lazy:

  Internal. Currently ignored: the groups are always computed
  immediately and the step is recorded as executed.

- record:

  Internal. Whether to record the step (default `TRUE`).

## Value

The survey object with `new_var` added (integer codes `1..n`) and the
step recorded.

## Details

**Execution model:** The quantile groups are computed immediately when
the step is created and the step is recorded as already executed
(`bake = TRUE`). Calling
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
afterwards is safe: executed steps are skipped.

**Algorithm:** The break for probability `p` is the right-continuous
inverse of the weighted ECDF, `inf{x : F_w(x) >= p}`. This matches
`survey::svyquantile(qrule = "math")` and, for integer weights,
`quantile(rep(x, w), type = 1)`, but runs in `O(n log n)` instead of
`O(sum(w))` memory. Rows are then assigned with intervals
`(q[k-1], q[k]]`; rows with `NA` in `x` get `NA`. If breaks are tied
(heavily discrete `x`), fewer than `n` groups can result.

For household-level quantiles (one observation per household), collapse
first with
[`step_collapse()`](https://metasurveyr.github.io/metasurvey/reference/step_collapse.md)
or compute on a household-level survey.

## See also

[`step_collapse()`](https://metasurveyr.github.io/metasurvey/reference/step_collapse.md)
to collapse to household level before computing household quantiles.

Other steps:
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
[`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md),
[`step_collapse()`](https://metasurveyr.github.io/metasurvey/reference/step_collapse.md),
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md),
[`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md),
[`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md),
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md),
[`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md),
[`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md),
[`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md),
[`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md),
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)

## Examples

``` r
dt <- data.table::data.table(
  id = 1:10, income = c(1:10) * 100, w = rep(1, 10)
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "test",
  psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
)
svy <- step_quantile(svy, income_q, income, n = 5)
get_data(svy)$income_q
#>  [1] 1 1 2 2 3 3 4 4 5 5
```
