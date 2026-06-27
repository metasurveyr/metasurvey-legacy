# Rotating Panels and PoolSurvey

## Introduction

Many national household surveys use **rotating panel designs**, where a
sample of respondents is interviewed in an initial wave (*implantation*)
and then followed up over successive periods. Uruguay’s ECH, for
example, interviews each household once and then conducts monthly
follow-ups for the rest of the year.

metasurvey provides two classes for this type of design:

- `RotativePanelSurvey` – a panel with an implantation survey and a list
  of follow-up surveys
- `PoolSurvey` – a collection of surveys grouped together for combined
  estimation across periods

## Creating a RotativePanelSurvey

A `RotativePanelSurvey` requires an implantation `Survey` and one or
more follow-up `Survey` objects.

``` r

library(metasurvey)
library(data.table)
set_use_copy(TRUE)

set.seed(42)
n <- 100

make_survey <- function(edition) {
  dt <- data.table(
    id       = 1:n,
    age      = sample(18:80, n, replace = TRUE),
    income   = round(runif(n, 5000, 80000)),
    employed = sample(0:1, n, replace = TRUE),
    w        = round(runif(n, 0.5, 3.0), 4)
  )
  Survey$new(
    data = dt, edition = edition, type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )
}

# Implantation: 2023 wave 1
impl <- make_survey("2023")

# Follow-ups: waves 2 through 4
fu_2 <- make_survey("2023")
fu_3 <- make_survey("2023")
fu_4 <- make_survey("2023")

panel <- RotativePanelSurvey$new(
  implantation   = impl,
  follow_up      = list(fu_2, fu_3, fu_4),
  type           = "ech",
  default_engine = "data.table",
  steps          = list(),
  recipes        = list(),
  workflows      = list(),
  design         = NULL
)
```

## Accessing panel components

Use
[`get_implantation()`](https://metasurveyr.github.io/metasurvey/reference/get_implantation.md)
and
[`get_follow_up()`](https://metasurveyr.github.io/metasurvey/reference/get_follow_up.md)
to retrieve the individual surveys:

``` r

# Implantation survey
imp <- get_implantation(panel)
class(imp)
#> [1] "Survey" "R6"
head(get_data(imp), 3)
#>       id   age income employed      w
#>    <int> <int>  <num>    <int>  <num>
#> 1:     1    66  21287        1 1.6114
#> 2:     2    54  21243        0 0.6510
#> 3:     3    18  34171        1 1.3188
```

``` r

# Follow-up surveys
follow_ups <- get_follow_up(panel)
cat("Number of follow-ups:", length(follow_ups), "\n")
#> Number of follow-ups: 3
```

## Applying steps to panel components

Apply transformations to individual panel components. The same step
functions work on both the implantation and follow-up surveys:

``` r

# Transform the implantation survey
panel$implantation <- step_compute(panel$implantation,
  income_k = income / 1000,
  comment = "Income in thousands"
)

# Apply the same step to each follow-up
panel$follow_up <- lapply(panel$follow_up, function(svy) {
  step_compute(svy, income_k = income / 1000, comment = "Income in thousands")
})
```

## Estimation on panel components

Use
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
on individual panel components to perform cross-sectional or time-series
analysis.

### Cross-sectional analysis (Implantation)

``` r

result_impl <- workflow(
  list(panel$implantation),
  survey::svymean(~income, na.rm = TRUE),
  estimation_type = "annual"
)

result_impl
#>                       stat variable    value       se         cv confint_lower
#>                     <char>   <char>    <num>    <num>      <num>         <num>
#> 1: survey::svymean: income   income 43742.45 2420.706 0.05533997      38997.96
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:      48486.95 Very good
```

### Comparison across follow-ups

``` r

results <- rbindlist(lapply(seq_along(panel$follow_up), function(i) {
  r <- workflow(
    list(panel$follow_up[[i]]),
    survey::svymean(~income, na.rm = TRUE),
    estimation_type = "annual"
  )
  r$period <- panel$follow_up[[i]]$edition
  r
}))

results[, .(period, stat, value, se, cv)]
#>    period                    stat    value       se         cv
#>     <num>                  <char>    <num>    <num>      <num>
#> 1:   2023 survey::svymean: income 41537.99 2328.715 0.05606230
#> 2:   2023 survey::svymean: income 42809.39 2383.860 0.05568546
#> 3:   2023 survey::svymean: income 41314.46 2232.803 0.05404409
```

## PoolSurvey: Combined estimation

A `PoolSurvey` groups multiple surveys for combined estimation. This is
useful when you want to aggregate monthly data into quarterly or annual
estimates, or when combining surveys reduces sampling variability.

The constructor takes a nested list:
`list(estimation_type = list(group = list(surveys)))`.

``` r

s1 <- make_survey("2023")
s2 <- make_survey("2023")
s3 <- make_survey("2023")

pool <- PoolSurvey$new(
  list(annual = list("q1" = list(s1, s2, s3)))
)

class(pool)
#> [1] "PoolSurvey" "R6"
```

### Pooled estimation

``` r

pool_result <- workflow(
  pool,
  survey::svymean(~income, na.rm = TRUE),
  estimation_type = "annual"
)

pool_result
#>                       stat variable    value       se         cv confint_lower
#>                     <char>   <char>    <num>    <num>      <num>         <num>
#> 1: survey::svymean: income   income 44574.23 2226.844 0.04995811      40209.69
#> 2: survey::svymean: income   income 44341.53 2407.912 0.05430377      39622.10
#> 3: survey::svymean: income   income 41293.92 2239.968 0.05424451      36903.66
#>    confint_upper  evaluate period   type variance
#>            <num>    <char>  <num> <char>    <num>
#> 1:      48938.76 Excellent   2023     q1  4958836
#> 2:      49060.95 Very good   2023     q1  5798041
#> 3:      45684.18 Very good   2023     q1  5017458
```

### Multiple groups

Surveys can be organized into multiple groups:

``` r

s4 <- make_survey("2023")
s5 <- make_survey("2023")
s6 <- make_survey("2023")

pool_semester <- PoolSurvey$new(
  list(annual = list(
    "q1" = list(s1, s2, s3),
    "q2" = list(s4, s5, s6)
  ))
)

result_semester <- workflow(
  pool_semester,
  survey::svymean(~income, na.rm = TRUE),
  estimation_type = "annual"
)

result_semester
#>                       stat variable    value       se         cv confint_lower
#>                     <char>   <char>    <num>    <num>      <num>         <num>
#> 1: survey::svymean: income   income 44574.23 2226.844 0.04995811      40209.69
#> 2: survey::svymean: income   income 44341.53 2407.912 0.05430377      39622.10
#> 3: survey::svymean: income   income 41293.92 2239.968 0.05424451      36903.66
#> 4: survey::svymean: income   income 41760.06 2296.170 0.05498485      37259.64
#> 5: survey::svymean: income   income 48051.67 2374.145 0.04940816      43398.43
#> 6: survey::svymean: income   income 42721.21 2276.767 0.05329359      38258.83
#>    confint_upper  evaluate period   type variance
#>            <num>    <char>  <num> <char>    <num>
#> 1:      48938.76 Excellent   2023     q1  4958836
#> 2:      49060.95 Very good   2023     q1  5798041
#> 3:      45684.18 Very good   2023     q1  5017458
#> 4:      46260.47 Very good   2023     q2  5272399
#> 5:      52704.90 Excellent   2023     q2  5636562
#> 6:      47183.59 Very good   2023     q2  5183666
```

## Extracting surveys from panels

Use
[`extract_surveys()`](https://metasurveyr.github.io/metasurvey/reference/extract_surveys.md)
to select specific periods from a `RotativePanelSurvey`:

``` r

# Extract specific follow-ups by index
first_two <- extract_surveys(panel, index = 1:2)
class(first_two)
#> [1] "list"
```

``` r

# Extract by month (requires Date-format editions)
march_data <- extract_surveys(panel, monthly = 3)
```

## Time patterns

metasurvey provides utilities for working with survey edition dates:

``` r

# Extract periodicity from edition strings
extract_time_pattern("2023")
#> $year
#> [1] 2023
#> 
#> $periodicity
#> [1] "Annual"
extract_time_pattern("2023-06")
#> $year
#> [1] 2023
#> 
#> $month
#> [1] 6
#> 
#> $periodicity
#> [1] "Monthly"
```

``` r

# Validate edition format
validate_time_pattern(svy_type = "ech", svy_edition = "2023")
#> $svy_type
#> [1] "ech"
#> 
#> $svy_edition
#> [1] 2023
#> 
#> $svy_periodicity
#> [1] "Annual"
```

``` r

# Group dates by period
dates <- as.Date(c(
  "2023-01-15", "2023-03-20", "2023-06-10",
  "2023-09-05", "2023-11-30"
))
group_dates(dates, type = "quarterly")
#> 2023-01-15 2023-03-20 2023-06-10 2023-09-05 2023-11-30 
#>          1          1          2          3          4
group_dates(dates, type = "biannual")
#> 2023-01-15 2023-03-20 2023-06-10 2023-09-05 2023-11-30 
#>          1          1          1          2          2
```

## Loading panel data from files

In practice, panel data is loaded from files using
[`load_panel_survey()`](https://metasurveyr.github.io/metasurvey/reference/load_panel_survey.md):

``` r

panel <- load_panel_survey(
  path_implantation = "data/ECH_implantacion_2023.csv",
  path_follow_up = "data/seguimiento/",
  svy_type = "ech",
  svy_weight_implantation = add_weight(annual = "pesoano"),
  svy_weight_follow_up = add_weight(monthly = "pesomes")
)

# Access components
imp <- get_implantation(panel)
fups <- get_follow_up(panel)
```

## Bootstrap replicate weights

For surveys that provide bootstrap replicate weights (such as the ECH),
use
[`add_replicate()`](https://metasurveyr.github.io/metasurvey/reference/add_replicate.md)
inside
[`add_weight()`](https://metasurveyr.github.io/metasurvey/reference/add_weight.md)
to configure robust variance estimation:

``` r

panel <- load_panel_survey(
  path_implantation = "data/ECH_implantacion_2023.csv",
  path_follow_up = "data/seguimiento/",
  svy_type = "ech",
  svy_weight_implantation = add_weight(
    annual = add_replicate(
      weight = "pesoano",
      replicate_pattern = "wr\\d+",
      replicate_path = "data/pesos_replicados_anual.csv",
      replicate_id = c("numero" = "numero"),
      replicate_type = "bootstrap"
    )
  ),
  svy_weight_follow_up = add_weight(monthly = "pesomes")
)
```

When replicate weights are configured,
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
automatically uses
[`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html)
for variance estimation instead of the standard Taylor linearization
approach.

## Best practices

1.  **Set the periodicity** on each component survey before building the
    panel
2.  **Apply transformations uniformly** – ensure that the same steps are
    applied to both implantation and follow-up surveys to guarantee
    comparability
3.  **Use PoolSurvey** when combining surveys to reduce variance or for
    quarterly/annual aggregations
4.  **Validate results** – compare pooled estimates with direct
    estimates to verify consistency
5.  **Use bootstrap replicate weights** when available for more robust
    variance estimation

## Next steps

- **[Survey designs and
  validation](https://metasurveyr.github.io/metasurvey/articles/complex-designs.md)**
  – Stratification, clustering, and pipeline validation
- **[ECH case
  study](https://metasurveyr.github.io/metasurvey/articles/ech-case-study.md)**
  – Complete labor market analysis with the ECH rotating panel
- **[Estimation
  workflows](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.md)**
  –
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  and `RecipeWorkflow`
