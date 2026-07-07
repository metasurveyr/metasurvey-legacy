# Print provenance information

Print provenance information

## Usage

``` r
# S3 method for class 'metasurvey_provenance'
print(x, ...)
```

## Arguments

- x:

  A `metasurvey_provenance` list.

- ...:

  Additional arguments (unused).

## Value

Invisibly returns `x`.

## See also

Other provenance:
[`print.metasurvey_provenance_diff()`](https://metasurveyr.github.io/metasurvey/reference/print.metasurvey_provenance_diff.md),
[`provenance()`](https://metasurveyr.github.io/metasurvey/reference/provenance.md),
[`provenance_diff()`](https://metasurveyr.github.io/metasurvey/reference/provenance_diff.md),
[`provenance_to_json()`](https://metasurveyr.github.io/metasurvey/reference/provenance_to_json.md)

## Examples

``` r
s <- survey_empty("ech", "2023")
#> Type does not match. Please provide a valid type in the survey edition or as an argument
s <- set_data(s, data.table::data.table(age = 18:65))
s <- step_compute(s, age2 = age * 2)
s <- bake_steps(s)
print(provenance(s))
#> ── Data Provenance ─────────────────────────────────────────────────────────────
#> Loaded: 2026-07-07T20:52:11 
#> 
#> Pipeline:
#>   1. step_1 Compute: age2  N=48 [0.0ms]
#> 
#> Environment:
#>   metasurvey: 0.2.0 
#>   R: 4.6.1 
#>   survey: 4.5 
```
