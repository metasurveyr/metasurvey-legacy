# Analyze transpilation coverage for STATA do-files

**\[experimental\]**

Reports what percentage of commands in a .do file (or directory of
files) can be automatically transpiled vs require manual review.

## Usage

``` r
transpile_coverage(path, recursive = TRUE)
```

## Arguments

- path:

  Path to a .do file or directory of .do files

- recursive:

  If TRUE and path is a directory, search subdirectories

## Value

A data.frame with columns: file, total_commands, translated, skipped,
manual_review, coverage_pct

## See also

Other transpiler:
[`parse_do_file()`](https://metasurveyr.github.io/metasurvey/reference/parse_do_file.md),
[`parse_stata_labels()`](https://metasurveyr.github.io/metasurvey/reference/parse_stata_labels.md),
[`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md),
[`transpile_stata_module()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata_module.md)

## Examples

``` r
# \donttest{
tf <- tempfile(fileext = ".do")
writeLines(c("gen x = 1", "replace x = 2 if y == 3", "drop z"), tf)
transpile_coverage(tf)
#>                 file                               path total_commands
#> 1 file1e9baeb02eb.do /tmp/Rtmpguwdvz/file1e9baeb02eb.do              2
#> 2              TOTAL /tmp/Rtmpguwdvz/file1e9baeb02eb.do              2
#>   translated skipped manual_review coverage_pct
#> 1          2       0             0          100
#> 2          2       0             0          100
# }
```
