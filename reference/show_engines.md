# List available survey data engines

Returns a character vector of available engines that can be used for
loading surveys.

## Usage

``` r
show_engines()
```

## Value

Character vector with the names of the available engines.

## See also

Other options:
[`get_engine()`](https://metasurveyr.github.io/metasurvey/reference/get_engine.md),
[`lazy_default()`](https://metasurveyr.github.io/metasurvey/reference/lazy_default.md),
[`set_engine()`](https://metasurveyr.github.io/metasurvey/reference/set_engine.md),
[`set_lazy_processing()`](https://metasurveyr.github.io/metasurvey/reference/set_lazy_processing.md),
[`set_use_copy()`](https://metasurveyr.github.io/metasurvey/reference/set_use_copy.md),
[`use_copy_default()`](https://metasurveyr.github.io/metasurvey/reference/use_copy_default.md)

## Examples

``` r
show_engines()
#> [1] "data.table" "tidyverse"  "dplyr"     
```
