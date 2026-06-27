# Get provenance from a survey or workflow result

Returns the provenance metadata recording the full data lineage: source
file, step history with row counts, and environment info.

## Usage

``` r
provenance(x, ...)

# S3 method for class 'Survey'
provenance(x, ...)

# S3 method for class 'data.table'
provenance(x, ...)

# Default S3 method
provenance(x, ...)
```

## Arguments

- x:

  A
  [Survey](https://metasurveyr.github.io/metasurvey/reference/Survey.md)
  object or a `data.table` from
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md).

- ...:

  Additional arguments (unused).

## Value

A `metasurvey_provenance` list, or `NULL` if no provenance is available.

## See also

Other provenance:
[`print.metasurvey_provenance()`](https://metasurveyr.github.io/metasurvey/reference/print.metasurvey_provenance.md),
[`print.metasurvey_provenance_diff()`](https://metasurveyr.github.io/metasurvey/reference/print.metasurvey_provenance_diff.md),
[`provenance_diff()`](https://metasurveyr.github.io/metasurvey/reference/provenance_diff.md),
[`provenance_to_json()`](https://metasurveyr.github.io/metasurvey/reference/provenance_to_json.md)

## Examples

``` r
svy <- Survey$new(
  data = data.table::data.table(id = 1:10, age = 20:29, w = 1),
  edition = "2023", type = "test", psu = NULL,
  engine = "data.table", weight = add_weight(annual = "w")
)
provenance(svy)
#> ── Data Provenance ─────────────────────────────────────────────────────────────
#> Loaded: 2026-06-27T16:03:28 
#> Initial rows: 10 
#> 
#> Environment:
#>   metasurvey: 0.0.24 
#>   R: 4.6.1 
#>   survey: 4.5 
```
