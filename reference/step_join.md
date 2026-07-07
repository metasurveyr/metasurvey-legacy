# Join external data into survey (step)

Creates a step that joins additional data into a Survey or
RotativePanelSurvey.

## Usage

``` r
step_join(
  svy,
  x,
  by = NULL,
  type = c("left", "inner", "right", "full"),
  suffixes = c("", ".y"),
  .copy = use_copy_default(),
  comment = "Join step",
  use_copy = deprecated(),
  lazy = lazy_default(),
  record = TRUE
)
```

## Arguments

- svy:

  A Survey or RotativePanelSurvey object. If NULL, returns a step call

- x:

  A data.frame/data.table or a Survey to join into `svy`

- by:

  Character vector of join keys. Named vector for different names
  between `svy` and `x` (names are keys in `svy`, values are keys in
  `x`). If NULL, tries to infer common column names

- type:

  Join type: "left" (default), "inner", "right", or "full"

- suffixes:

  Length-2 character vector of suffixes for conflicting columns from
  `svy` and `x` respectively. Defaults to c("", ".y")

- .copy:

  Whether to operate on a copy (default: use_copy_default())

- comment:

  Optional description for the step (default `"Join step"`).

- use_copy:

  **\[deprecated\]** Use `.copy` instead.

- lazy:

  Internal. Currently ignored: the join always executes immediately and
  the step is recorded as executed.

- record:

  Internal. Whether to record the step (default `TRUE`).

## Value

Modified survey object with the join recorded as a step (and applied
immediately when baked). For RotativePanelSurvey, the join is applied to
implantation and every follow_up survey.

## Details

**Execution model:** The join is applied immediately when the step is
created and the step is recorded as already executed (`bake = TRUE`).
Calling
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
afterwards is safe: executed steps are skipped, so the join is never
applied twice (which would duplicate overlapping columns with the `.y`
suffix).

Supports left, inner, right, and full joins. Allows named `by` mapping
(e.g., `c("id" = "code")`) or a simple character vector. Conflicting
column names are resolved by appending `suffixes` to the right-hand side
columns.

## See also

Other steps:
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
[`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md),
[`step_collapse()`](https://metasurveyr.github.io/metasurvey/reference/step_collapse.md),
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md),
[`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md),
[`step_quantile()`](https://metasurveyr.github.io/metasurvey/reference/step_quantile.md),
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md),
[`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md),
[`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md),
[`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md),
[`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md),
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)

## Examples

``` r
# With data.frame
s <- Survey$new(
  data = data.table::data.table(id = 1:3, w = 1, a = c("x", "y", "z")),
  edition = "2023", type = "ech", psu = NULL, engine = "data.table",
  weight = add_weight(annual = "w")
)
info <- data.frame(id = c(1, 2), b = c(10, 20))
s2 <- step_join(s, info, by = "id", type = "left")
s2 <- bake_steps(s2)

# With another Survey
s_right <- Survey$new(
  data = data.table::data.table(id = c(2, 3), b = c(200, 300), w2 = 1),
  edition = "2023", type = "ech", psu = NULL, engine = "data.table",
  weight = add_weight(annual = "w2")
)
s3 <- step_join(s, s_right, by = c("id" = "id"), type = "inner")
s3 <- bake_steps(s3)
```
