# Poverty and Inequality with convey

## Introduction

The [convey](https://www.convey-r.org/) package by Guilherme Jacob,
Anthony Damico, and Djalma Pessoa implements poverty and inequality
indicators for complex survey data. It works with
[`survey::svydesign`](https://rdrr.io/pkg/survey/man/svydesign.html)
objects — the same objects that metasurvey wraps inside `Survey`
objects.

This vignette shows how to use `convey` functions inside
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
to compute Gini coefficients, at-risk-of-poverty rates, FGT indices, and
other distributional measures, all with proper standard errors and CVs.

For the full reference on every measure, see the [convey
book](https://www.convey-r.org/).

## Setup

We use the `api` dataset from the `survey` package. The `api00` variable
(Academic Performance Index score in 2000) serves as our continuous
variable for inequality measures, and `meals` (percent of students
eligible for subsidized meals) works as an income-like proxy.

``` r

library(metasurvey)
library(survey)
library(convey)
library(data.table)

data(api, package = "survey")
dt <- data.table(apistrat)

svy <- Survey$new(
  data    = dt,
  edition = "2000",
  type    = "api",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "pw")
)
```

### Preparing the design for convey

Before using any `convey` function, the underlying design must be
prepared with
[`convey_prep()`](https://rdrr.io/pkg/convey/man/convey_prep.html).
Build the design with `ensure_design()` and then replace the
estimation-type entry:

``` r

svy$ensure_design()
svy$design[["annual"]] <- convey_prep(svy$design[["annual"]])
```

## Inequality Measures

### Gini coefficient

The Gini index measures overall inequality on a 0–1 scale:

``` r

gini <- workflow(
  list(svy),
  convey::svygini(~api00, na.rm = TRUE),
  estimation_type = "annual"
)

gini
#>                     stat variable     value          se         cv
#>                   <char>   <char>     <num>       <num>      <num>
#> 1: convey::svygini: gini     gini 0.1123906 0.004824568 0.04292681
#>    confint_lower confint_upper  evaluate
#>            <num>         <num>    <char>
#> 1:     0.1029346     0.1218465 Excellent
```

### Atkinson index

The Atkinson index uses an inequality aversion parameter `epsilon`.
Higher epsilon gives more weight to the lower tail:

``` r

atk_05 <- workflow(
  list(svy),
  convey::svyatk(~api00, epsilon = 0.5),
  estimation_type = "annual"
)

atk_1 <- workflow(
  list(svy),
  convey::svyatk(~api00, epsilon = 1),
  estimation_type = "annual"
)

rbind(atk_05, atk_1)
#>                        stat variable       value           se         cv
#>                      <char>   <char>       <num>        <num>      <num>
#> 1: convey::svyatk: atkinson atkinson 0.008841101 0.0007781485 0.08801488
#> 2: convey::svyatk: atkinson atkinson 0.017852866 0.0015768947 0.08832726
#>    confint_lower confint_upper  evaluate
#>            <num>         <num>    <char>
#> 1:   0.007315958    0.01036624 Very good
#> 2:   0.014762210    0.02094352 Very good
```

### Quintile share ratio (QSR)

The QSR compares income at the top 20% with the bottom 20%:

``` r

qsr <- workflow(
  list(svy),
  convey::svyqsr(~api00, na.rm = TRUE),
  estimation_type = "annual"
)

qsr
#>                   stat variable    value        se         cv confint_lower
#>                 <char>   <char>    <num>     <num>      <num>         <num>
#> 1: convey::svyqsr: qsr      qsr 1.565964 0.0355218 0.02268367      1.496342
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:      1.635585 Excellent
```

### Generalized entropy index

The GEI family includes the Theil index (`alpha = 1`) and the mean log
deviation (`alpha = 0`):

``` r

theil <- workflow(
  list(svy),
  convey::svygei(~api00, epsilon = 1),
  estimation_type = "annual"
)

mld <- workflow(
  list(svy),
  convey::svygei(~api00, epsilon = 0),
  estimation_type = "annual"
)

rbind(theil, mld)
#>                   stat variable      value          se         cv confint_lower
#>                 <char>   <char>      <num>       <num>      <num>         <num>
#> 1: convey::svygei: gei      gei 0.01749577 0.001533703 0.08766137    0.01448977
#> 2: convey::svygei: gei      gei 0.01801415 0.001605559 0.08912763    0.01486731
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:    0.02050177 Very good
#> 2:    0.02116099 Very good
```

## Poverty Measures

For poverty measures we use `meals` (percent of students receiving
subsidized meals) as an income-like variable. We define a poverty
threshold at 50%.

### At-risk-of-poverty threshold

[`svyarpt()`](https://rdrr.io/pkg/convey/man/svyarpt.html) computes the
at-risk-of-poverty threshold (60% of the median by default):

``` r

arpt <- workflow(
  list(svy),
  convey::svyarpt(~meals, na.rm = TRUE),
  estimation_type = "annual"
)

arpt
#>                     stat variable value       se         cv confint_lower
#>                   <char>   <char> <num>    <num>      <num>         <num>
#> 1: convey::svyarpt: arpt     arpt    27 2.051721 0.07598967       22.9787
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:       31.0213 Very good
```

### At-risk-of-poverty rate

[`svyarpr()`](https://rdrr.io/pkg/convey/man/svyarpr.html) computes the
proportion of units below the ARPT:

``` r

arpr <- workflow(
  list(svy),
  convey::svyarpr(~meals, na.rm = TRUE),
  estimation_type = "annual"
)

arpr
#>                     stat variable     value         se         cv confint_lower
#>                   <char>   <char>     <num>      <num>      <num>         <num>
#> 1: convey::svyarpr: arpr     arpr 0.2974169 0.02696583 0.09066677     0.2445648
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:     0.3502689 Very good
```

### FGT poverty indices

The Foster-Greer-Thorbecke (FGT) family provides:

- **FGT(0)**: headcount ratio (proportion below the line)
- **FGT(1)**: poverty gap (average depth of poverty)
- **FGT(2)**: severity (squared poverty gap, penalizes extreme poverty)

``` r

threshold <- 50

fgt0 <- workflow(
  list(svy),
  convey::svyfgt(~meals, g = 0, abs_thresh = threshold, na.rm = TRUE),
  estimation_type = "annual"
)

fgt1 <- workflow(
  list(svy),
  convey::svyfgt(~meals, g = 1, abs_thresh = threshold, na.rm = TRUE),
  estimation_type = "annual"
)

fgt2 <- workflow(
  list(svy),
  convey::svyfgt(~meals, g = 2, abs_thresh = threshold, na.rm = TRUE),
  estimation_type = "annual"
)

rbind(fgt0, fgt1, fgt2)
#>                    stat variable     value         se         cv confint_lower
#>                  <char>   <char>     <num>      <num>      <num>         <num>
#> 1: convey::svyfgt: fgt0     fgt0 0.5590055 0.03854638 0.06895528     0.4834560
#> 2: convey::svyfgt: fgt1     fgt1 0.2733427 0.02456407 0.08986547     0.2251980
#> 3: convey::svyfgt: fgt2     fgt2 0.1795022 0.02043659 0.11385149     0.1394472
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:     0.6345550 Very good
#> 2:     0.3214874 Very good
#> 3:     0.2195572      Good
```

## Full Pipeline: Steps + Convey

A complete pipeline with data transformations followed by inequality
estimation:

``` r

dt_full <- data.table(apistrat)

svy_full <- Survey$new(
  data    = dt_full,
  edition = "2000",
  type    = "api",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "pw")
)

# Transform: compute a derived variable
svy_full <- step_compute(svy_full,
  api_growth = api00 - api99,
  comment = "API score growth"
)

# Bake the steps
svy_full <- bake_steps(svy_full)

# Prepare for convey
svy_full$ensure_design()
svy_full$design[["annual"]] <- convey_prep(svy_full$design[["annual"]])

# Inequality: Gini on derived variable, Atkinson on api00 (must be positive)
results <- workflow(
  list(svy_full),
  convey::svygini(~api_growth, na.rm = TRUE),
  convey::svyatk(~api00, epsilon = 1),
  estimation_type = "annual"
)

results
#>                        stat variable      value          se         cv
#>                      <char>   <char>      <num>       <num>      <num>
#> 1:    convey::svygini: gini     gini 0.48220882 0.033233109 0.06891850
#> 2: convey::svyatk: atkinson atkinson 0.01785287 0.001576895 0.08832726
#>    confint_lower confint_upper  evaluate
#>            <num>         <num>    <char>
#> 1:    0.41707312    0.54734451 Very good
#> 2:    0.01476221    0.02094352 Very good
```

### Quality assessment

``` r

for (i in seq_len(nrow(results))) {
  cv_val <- results$cv[i] * 100
  cat(
    results$stat[i], ":",
    round(cv_val, 1), "% CV -",
    evaluate_cv(cv_val), "\n"
  )
}
#> convey::svygini: gini : 6.9 % CV - Very good 
#> convey::svyatk: atkinson : 8.8 % CV - Very good
```

### Publication table

``` r

workflow_table(
  results,
  title = "Inequality of API Score Growth",
  subtitle = "California Schools, 2000"
)
```

| Inequality of API Score Growth |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|
| California Schools, 2000 |  |  |  |  |  |  |  |
| Statistic | variable | Estimate | SE | CI Lower | CI Upper | CV (%) | Quality |
| :svygini: gini | gini | 0.48 | 0.033 | 0.42 | 0.55 | 6.9 | Very good |
| :svyatk: atkinson | atkinson | 0.02 | 0.002 | 0.01 | 0.02 | 8.8 | Very good |
| metasurvey 0.0.24 \| CI: 95% \| 2026-06-27 |  |  |  |  |  |  |  |

## Provenance

Provenance is tracked automatically. The full lineage — steps applied,
convey estimates computed, and package versions — is available:

``` r

prov <- provenance(results)
prov
#> ── Data Provenance ─────────────────────────────────────────────────────────────
#> Loaded: 2026-06-27T21:06:22 
#> Initial rows: 200 
#> 
#> Pipeline:
#>   1. step_1 Compute: api_growth  N=200 [1.0ms]
#> 
#> Estimation:
#>   Type: annual 
#>   Timestamp: 2026-06-27T21:06:22 
#> 
#> Environment:
#>   metasurvey: 0.0.24 
#>   R: 4.6.1 
#>   survey: 4.5
cat("metasurvey version:", prov$environment$metasurvey_version, "\n")
#> metasurvey version: 0.0.24
cat("Steps applied:", length(prov$steps), "\n")
#> Steps applied: 1
```

## References

- Jacob, G., Damico, A., & Pessoa, D. (2024). *Poverty and Inequality
  with Complex Survey Data*. <https://www.convey-r.org/>
- Lumley, T. (2010). *Complex Surveys: A Guide to Analysis Using R*.
  Wiley.
