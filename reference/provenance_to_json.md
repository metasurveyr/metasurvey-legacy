# Export provenance to JSON

Serializes a provenance object to JSON format, optionally writing to a
file.

## Usage

``` r
provenance_to_json(prov, path = NULL)
```

## Arguments

- prov:

  A `metasurvey_provenance` list.

- path:

  File path to write JSON. If `NULL`, returns the JSON string.

## Value

JSON string (invisibly if `path` is provided).

## See also

Other provenance:
[`print.metasurvey_provenance()`](https://metasurveyr.github.io/metasurvey/reference/print.metasurvey_provenance.md),
[`print.metasurvey_provenance_diff()`](https://metasurveyr.github.io/metasurvey/reference/print.metasurvey_provenance_diff.md),
[`provenance()`](https://metasurveyr.github.io/metasurvey/reference/provenance.md),
[`provenance_diff()`](https://metasurveyr.github.io/metasurvey/reference/provenance_diff.md)

## Examples

``` r
svy <- Survey$new(
  data = data.table::data.table(id = 1:5, w = rep(1, 5)),
  edition = "2023", type = "test",
  engine = "data.table", weight = add_weight(annual = "w")
)
prov <- provenance(svy)
provenance_to_json(prov)
#> {
#>   "source": {
#>     "path": null,
#>     "timestamp": "2026-07-07T14:44:37",
#>     "initial_n": 5,
#>     "hash": null
#>   },
#>   "steps": [],
#>   "environment": {
#>     "metasurvey_version": "0.1.0",
#>     "r_version": "4.6.1",
#>     "survey_version": "4.5"
#>   }
#> } 
```
