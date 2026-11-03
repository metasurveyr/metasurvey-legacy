# Survey Weighting with weightflow

## Introduction

The [weightflow](https://jpferreira33.github.io/weightflow/) package by
Juan Pablo Ferreira provides a declarative, pipeable API for survey
weight construction: nonresponse adjustment, calibration (raking,
post-stratification, GREG), trimming, and bootstrap replicate weights.

metasurvey’s
[`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md)
integrates weightflow into the step pipeline so that weight construction
becomes a lazy, reproducible step — just like
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md)
or
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md).
Weights are computed when
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
is called.

## Setup

We simulate a household survey with design weights, demographic
variables, and known population margins.

``` r

library(metasurvey)
library(weightflow)
library(data.table)

set.seed(2026)
n <- 500

microdata <- data.table(
  id = seq_len(n),
  sex = sample(c("M", "F"), n, replace = TRUE),
  age_grp = sample(c("18-34", "35-54", "55+"), n,
    replace = TRUE,
    prob = c(0.35, 0.40, 0.25)
  ),
  region = sample(c("North", "South", "Central"), n, replace = TRUE),
  income = round(rlnorm(n, log(30000), 0.6)),
  employed = sample(0:1, n, replace = TRUE, prob = c(0.3, 0.7)),
  dw = runif(n, 0.8, 1.5)
)
```

We also define population totals for calibration:

``` r

pop_sex <- c(M = 120000, F = 125000)
pop_age <- c("18-34" = 80000, "35-54" = 100000, "55+" = 65000)
```

## weightflow standalone

Before integrating with metasurvey, here is the pure weightflow
pipeline:

``` r

spec <- weighting_spec(microdata, base_weights = dw) |>
  step_calibrate(method = "raking", margins = list(
    sex     = pop_sex,
    age_grp = pop_age
  )) |>
  step_trim_weights()

prepped <- prep(spec)
summary(prepped)
#> 
#> == Weighting specification (weightflow) ==
#> Data    : 500 cases
#> Base wts: dw
#> Steps   :
#>   1. calibration (raking)  [calibrate_1]
#>   2. auto weight trimming  [trim_weights_1]
#> Status  : estimated (prep)
#> 
#> Stage summary:
#>                      stage n_active sum_wts cv_wts deff_kish n_eff
#>                       base      500     572  0.175     1.031   485
#>     stage_1_step_calibrate      500  245000  0.178     1.032   485
#>  stage_2_step_trim_weights      500  245000  0.178     1.032   485
#> 
#> deff_kish = 1 + CV^2 (Kish design effect from unequal weighting);
#> n_eff = n_active / deff_kish. Both worsen with each adjustment and
#> improve with trimming.
#> 
#> --- Step 1: calibration (raking) ---
#>  variable category target achieved prev_total   factor   n
#>       sex        M 120000   120000   277.4581 432.4977 241
#>       sex        F 125000   125000   294.8741 423.9098 259
#>   age_grp    18-34  80000    80000   193.4054 413.6390 169
#>   age_grp    35-54 100000   100000   229.8817 435.0063 201
#>   age_grp      55+  65000    65000   149.0451 436.1096 130
#> (converged/iterated in 4 iterations)
#> Kish deff: 1.031 -> 1.032   |   n_eff: 485 -> 485
#> 
#> --- Step 2: auto weight trimming ---
#>  method lower    upper strict n_capped n_raised sum_before sum_after
#>   tukey     1 1017.193   TRUE        0        0     245000    245000
#> (converged/iterated in 1 iterations)
#> Kish deff: 1.032 -> 1.032   |   n_eff: 485 -> 485
```

[`collect_weights()`](https://jpferreira33.github.io/weightflow/reference/collect_weights.html)
returns the data with a `.weight` column:

``` r

weighted_data <- collect_weights(prepped)
head(weighted_data[, .(id, sex, age_grp, dw, .weight)])
#>       id    sex age_grp       dw  .weight
#>    <int> <char>  <char>    <num>    <num>
#> 1:     1      M   35-54 1.009007 442.2656
#> 2:     2      M   18-34 1.168091 487.8854
#> 3:     3      M     55+ 1.147288 505.3351
#> 4:     4      F   35-54 1.357180 584.6296
#> 5:     5      M   35-54 1.112800 487.7600
#> 6:     6      M   35-54 1.411763 618.8007
```

## Integration with metasurvey

[`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md)
wraps the entire weightflow pipeline into a single lazy step. The
weighting specification is stored and executed at
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
time.

``` r

svy <- Survey$new(
  data    = microdata,
  edition = "2023",
  type    = "household",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "dw")
)

spec <- weighting_spec(microdata, base_weights = dw) |>
  step_calibrate(method = "raking", margins = list(
    sex     = pop_sex,
    age_grp = pop_age
  )) |>
  step_trim_weights()

svy <- svy |>
  step_weight(spec) |>
  step_compute(high_income = as.integer(income > 50000)) |>
  bake_steps()
```

After baking, the `.weight` column exists and the survey design uses the
calibrated weights:

``` r

head(get_data(svy)[, .(id, dw, .weight, high_income)])
#>       id       dw  .weight high_income
#>    <int>    <num>    <num>       <int>
#> 1:     1 1.009007 442.2656           0
#> 2:     2 1.168091 487.8854           0
#> 3:     3 1.147288 505.3351           1
#> 4:     4 1.357180 584.6296           0
#> 5:     5 1.112800 487.7600           1
#> 6:     6 1.411763 618.8007           0
svy$weight
#> $annual
#> [1] ".weight"
```

## Running estimations

With calibrated weights in place,
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
produces design-consistent estimates:

``` r

results <- workflow(
  list(svy),
  survey::svymean(~income, na.rm = TRUE),
  survey::svymean(~employed, na.rm = TRUE),
  survey::svytotal(~high_income, na.rm = TRUE),
  estimation_type = "annual"
)
print(results)
#>                             stat    variable        value           se
#>                           <char>      <char>        <num>        <num>
#> 1:       survey::svymean: income      income 3.507788e+04 1.026228e+03
#> 2:     survey::svymean: employed    employed 7.049188e-01 2.067803e-02
#> 3: survey::svytotal: high_income high_income 4.692795e+04 4.371043e+03
#>            cv confint_lower confint_upper  evaluate
#>         <num>         <num>         <num>    <char>
#> 1: 0.02925569  3.306651e+04  37089.247569 Excellent
#> 2: 0.02933392  6.643906e-01      0.745447 Excellent
#> 3: 0.09314371  3.836086e+04  55495.036040 Very good
```

## Custom weight column name

Use `weight_var` to control the output column name:

``` r

svy2 <- Survey$new(
  data    = microdata,
  edition = "2023",
  type    = "household",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "dw")
)

svy2 <- svy2 |>
  step_weight(spec, weight_var = "calibrated_w") |>
  bake_steps()

"calibrated_w" %in% names(get_data(svy2))
#> [1] TRUE
svy2$weight
#> $annual
#> [1] "calibrated_w"
```

## When to use step_weight

| Scenario | Approach |
|----|----|
| Weights already in the microdata | Use [`add_weight()`](https://metasurveyr.github.io/metasurvey/reference/add_weight.md) directly |
| Need calibration / nonresponse adjustment | Use [`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md) with a weightflow spec |
| Multiple weighting strategies to compare | Create separate specs and surveys |
| Bootstrap replicate weights | Use [`weightflow::bootstrap_weights()`](https://jpferreira33.github.io/weightflow/reference/bootstrap_weights.html) then [`add_weight()`](https://metasurveyr.github.io/metasurvey/reference/add_weight.md) with replicate spec |
