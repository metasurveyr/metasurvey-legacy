# Collapse survey data to one row per group (step)

Creates a step that collapses the survey data to a single row per group,
typically one row per household, so that estimations can be run at the
group level with the group's weight (e.g. share of households receiving
a transfer).

## Usage

``` r
step_collapse(
  svy,
  by,
  rule = c("first", "max", "min"),
  .copy = use_copy_default(),
  comment = "Collapse step",
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

- by:

  Character vector of grouping variables that identify the group (e.g.
  the household id).

- rule:

  How to build the collapsed row (default `"first"`):

  - `"first"`: keep the first row of each group as-is.

  - `"max"` / `"min"`: aggregate every numeric/logical column with
    [`max()`](https://rdrr.io/r/base/Extremes.html)/[`min()`](https://rdrr.io/r/base/Extremes.html)
    (`na.rm = TRUE`); non-numeric columns keep the first value of the
    group.

- .copy:

  Whether to operate on a copy (default:
  [`use_copy_default()`](https://metasurveyr.github.io/metasurvey/reference/use_copy_default.md)).

- comment:

  Descriptive text for the step (default `"Collapse step"`).

- lazy:

  Internal. Currently ignored: the collapse is always applied
  immediately and the step is recorded as executed.

- record:

  Internal. Whether to record the step (default `TRUE`).

## Value

The survey object with one row per `by` group and the step recorded.

## Details

**Execution model:** The collapse is applied immediately when the step
is created and the step is recorded as already executed (`bake = TRUE`).
Calling
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
afterwards is safe: executed steps are skipped, so the data is never
collapsed twice.

**Interaction with the sampling design:** After collapsing, each row
represents one group (household), so the weight column now acts as the
*group* weight and subsequent estimations are at the group level. The
design is invalidated and rebuilt from the collapsed data on the next
estimation. In household surveys the person weight is constant within
the household, so the collapsed weight is the household weight; if the
weight varies within a group, a warning is issued because the collapsed
weight is ambiguous (it is taken with `rule` like any other column).

`rule = "max"` reproduces the person-to-household propagation pattern
("order decreasing + distinct by household id"): a dummy that is 1 for
any household member becomes 1 in the collapsed household row.

## See also

[`step_quantile()`](https://metasurveyr.github.io/metasurvey/reference/step_quantile.md)
for weighted quantile groups (e.g. household income quintiles after
collapsing).

Other steps:
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
[`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md),
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md),
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
dt <- data.table::data.table(
  hh = c(1, 1, 2, 2, 3), person = 1:5,
  receives = c(0, 1, 0, 0, 1), w = c(2, 2, 3, 3, 1)
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "test",
  psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
)
hh_svy <- step_collapse(svy, by = "hh", rule = "max")
get_data(hh_svy) # one row per household, receives = max over members
#>       hh person receives     w
#>    <num>  <int>    <num> <num>
#> 1:     1      2        1     2
#> 2:     2      4        0     3
#> 3:     3      5        1     1
```
