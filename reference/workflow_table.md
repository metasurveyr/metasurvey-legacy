# Create publication-quality table from workflow results

Formats a
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
result as a gt table with confidence intervals, CV quality
classification, and provenance-based source notes.

## Usage

``` r
workflow_table(
  result,
  ci = 0.95,
  digits = 2,
  compare_by = NULL,
  show_cv = TRUE,
  show_se = TRUE,
  title = NULL,
  subtitle = NULL,
  source_note = TRUE,
  locale = "en",
  theme = "publication"
)
```

## Arguments

- result:

  A `data.table` from
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md).

- ci:

  Confidence level for intervals (default 0.95). Set to `NULL` to hide
  confidence intervals.

- digits:

  Number of decimal places (default 2).

- compare_by:

  Column name to pivot for side-by-side comparison (e.g.,
  `"survey_edition"`).

- show_cv:

  Logical; show CV column with quality classification.

- show_se:

  Logical; show SE column.

- title:

  Table title. Auto-generated if `NULL`.

- subtitle:

  Table subtitle. Auto-generated if `NULL`.

- source_note:

  Logical; show provenance footer.

- locale:

  Locale for number formatting (`"en"` or `"es"`).

- theme:

  Table theme: `"publication"` (clean) or `"minimal"`.

## Value

A `gt_tbl` object. Export via
[`gt::gtsave()`](https://gt.rstudio.com/reference/gtsave.html) to .html,
.docx, .pdf, .png, or .rtx. Falls back to
[`knitr::kable()`](https://rdrr.io/pkg/knitr/man/kable.html) if gt is
not installed.

## Details

CV quality classification follows INE/CEPAL standards:

- Excellent: CV \< 5\\

- Very good: 5-10\\

- Good: 10-15\\

- Acceptable: 15-25\\

- Use with caution: 25-35\\

- Do not publish: \>= 35\\

## See also

Other workflows:
[`RecipeWorkflow-class`](https://metasurveyr.github.io/metasurvey/reference/RecipeWorkflow-class.md),
[`evaluate_cv()`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md),
[`print.RecipeWorkflow()`](https://metasurveyr.github.io/metasurvey/reference/print.RecipeWorkflow.md),
[`publish_workflow()`](https://metasurveyr.github.io/metasurvey/reference/publish_workflow.md),
[`read_workflow()`](https://metasurveyr.github.io/metasurvey/reference/read_workflow.md),
[`reproduce_workflow()`](https://metasurveyr.github.io/metasurvey/reference/reproduce_workflow.md),
[`save_workflow()`](https://metasurveyr.github.io/metasurvey/reference/save_workflow.md),
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md),
[`workflow_from_list()`](https://metasurveyr.github.io/metasurvey/reference/workflow_from_list.md)

## Examples

``` r
svy <- Survey$new(
  data = data.table::data.table(
    x = rnorm(100), g = sample(c("a", "b"), 100, TRUE), w = rep(1, 100)
  ),
  edition = "2023", type = "test", psu = NULL,
  engine = "data.table", weight = add_weight(annual = "w")
)
result <- workflow(
  list(svy), survey::svymean(~x, na.rm = TRUE),
  estimation_type = "annual"
)
#> Warning: CV may not be useful for negative statistics
# \donttest{
if (requireNamespace("gt", quietly = TRUE)) {
  workflow_table(result)
}


  


Survey Estimation Results
```
