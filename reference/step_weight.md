# Apply survey weights from a weightflow specification

Integrates the weightflow package into the metasurvey step pipeline.
Accepts a `weighting_spec` object and, at bake time, prepares it and
adds the resulting weight column to the survey data.

## Usage

``` r
step_weight(
  svy,
  spec,
  weight_var = ".weight",
  .copy = use_copy_default(),
  comment = "Weight step (weightflow)",
  lazy = lazy_default(),
  record = TRUE
)
```

## Arguments

- svy:

  A
  [`Survey`](https://metasurveyr.github.io/metasurvey/reference/Survey.md)
  or
  [`RotativePanelSurvey`](https://metasurveyr.github.io/metasurvey/reference/RotativePanelSurvey.md)
  object.

- spec:

  A `weighting_spec` from weightflow.

- weight_var:

  Character. Name for the final weight column (default `".weight"`).

- .copy:

  Logical. If `TRUE`, returns a cloned survey (default
  [`use_copy_default()`](https://metasurveyr.github.io/metasurvey/reference/use_copy_default.md)).

- comment:

  Character. Documentation for the step.

- lazy:

  Logical. Whether to defer execution (default
  [`lazy_default()`](https://metasurveyr.github.io/metasurvey/reference/lazy_default.md)).

- record:

  Logical. Internal; set to `FALSE` during baking to prevent
  double-recording.

## Value

The survey object (invisibly) with the weighting step recorded or
applied.

## Details

By default, `step_weight()` uses lazy evaluation: it records the
weighting specification as a step without executing it. The weights are
computed when
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
is called. Set `options(metasurvey.lazy_processing = FALSE)` to apply
immediately.

The `spec` must be created with the same data that is loaded into the
survey via
[`set_data()`](https://metasurveyr.github.io/metasurvey/reference/set_data.md),
and `step_weight()` should be called before any row-filtering steps to
ensure row alignment.

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
[`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md),
[`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md),
[`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md),
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)
