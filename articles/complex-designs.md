# Survey Designs and Validation

## Introduction

Complex sampling designs require special treatment for correct variance
estimation. metasurvey manages the sampling design automatically through
the `Survey` object, so that users can focus on the analysis rather than
technical details.

This vignette covers the following topics:

1.  Creating surveys with different design types
2.  Configuring weights and data engines
3.  Validating the processing pipeline
4.  Cross-checking results with the `survey` package

## Initial Setup

We use the Academic Performance Index (API) dataset from the `survey`
package. It includes stratified, cluster, and simple random sampling
versions.

``` r

library(metasurvey)
library(survey)
library(data.table)

data(api, package = "survey")
dt_strat <- data.table(apistrat)
```

## Sampling Design Types

### Simple Weighted Design

The simplest design uses probability weights without clusters or
stratification:

``` r

svy_simple <- Survey$new(
  data = dt_strat,
  edition = "2000",
  type = "api",
  psu = NULL,
  engine = "data.table",
  weight = add_weight(annual = "pw")
)

cat_design(svy_simple)
#> [1] "\n  Design: Not initialized (lazy initialization - will be created when needed)\n"
```

### Stratified Cluster Design

Many national surveys use stratified multi-stage sampling. Pass `strata`
and `psu` to `Survey$new()`:

``` r

dt_clus <- data.table(apiclus1)

svy_strat_clus <- Survey$new(
  data    = dt_strat,
  edition = "2000",
  type    = "api",
  psu     = NULL,
  strata  = "stype",
  engine  = "data.table",
  weight  = add_weight(annual = "pw")
)

cat_design(svy_strat_clus)
#> [1] "\n  Design: Not initialized (lazy initialization - will be created when needed)\n"
```

Cross-validate with the `survey` package:

``` r

design_strat <- svydesign(
  id = ~1, strata = ~stype, weights = ~pw,
  data = dt_strat
)
direct_strat <- svymean(~api00, design_strat)

wf_strat <- workflow(
  list(svy_strat_clus),
  survey::svymean(~api00, na.rm = TRUE),
  estimation_type = "annual"
)

cat("Direct estimate:", round(coef(direct_strat), 2), "\n")
#> Direct estimate: 662.29
cat("Workflow estimate:", round(wf_strat$value, 2), "\n")
#> Workflow estimate: 662.29
cat("Match:", all.equal(
  as.numeric(coef(direct_strat)),
  wf_strat$value,
  tolerance = 1e-6
), "\n")
#> Match: TRUE
```

For real-world examples of stratified cluster designs with CASEN, PNADc,
ENIGH, and DHS data, see
[`vignette("international-surveys")`](https://metasurveyr.github.io/metasurvey/articles/international-surveys.md).

### Design Inspection

``` r

# Check design type
cat_design_type(svy_simple, "annual")
#> [1] "None"

# View metadata
get_metadata(svy_simple)
#> Type: API
#> Edition: 2000
#> Periodicity: Annual
#> Engine: data.table
#> Design: 
#>   Design: Not initialized (lazy initialization - will be created when needed)
#> 
#> Steps: None
#> Recipes: None
```

### Multiple Weight Types

Many surveys provide different weights depending on the analysis period
(for example, annual vs. monthly). metasurvey associates periodicity
labels with weight columns:

``` r

set.seed(42)
dt_multi <- copy(dt_strat)
dt_multi[, pw_monthly := pw * runif(.N, 0.9, 1.1)]

svy_multi <- Survey$new(
  data    = dt_multi,
  edition = "2000",
  type    = "api",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "pw", monthly = "pw_monthly")
)

# Use different weight types in workflow()
annual_est <- workflow(
  list(svy_multi),
  survey::svymean(~api00, na.rm = TRUE),
  estimation_type = "annual"
)

monthly_est <- workflow(
  list(svy_multi),
  survey::svymean(~api00, na.rm = TRUE),
  estimation_type = "monthly"
)

cat("Annual estimate:", round(annual_est$value, 1), "\n")
#> Annual estimate: 662.3
cat("Monthly estimate:", round(monthly_est$value, 1), "\n")
#> Monthly estimate: 662.5
```

### Bootstrap Replicate Weights

For surveys that provide bootstrap replicates (such as Uruguay’s ECH),
use
[`add_replicate()`](https://metasurveyr.github.io/metasurvey/reference/add_replicate.md)
inside
[`add_weight()`](https://metasurveyr.github.io/metasurvey/reference/add_weight.md):

``` r

# Requires external bootstrap replicate CSV files
svy_boot <- load_survey(
  path = "data/main_survey.csv",
  svy_type = "ech",
  svy_edition = "2023",
  svy_weight = add_weight(
    annual = add_replicate(
      weight_var = "pesoano",
      replicate_path = "data/bootstrap_replicates.csv",
      replicate_id = c("numero" = "id"),
      replicate_pattern = "bsrep[0-9]+",
      replicate_type = "bootstrap"
    )
  )
)
```

When replicate weights are configured,
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
automatically uses them for variance estimation via
[`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html).

## Engine and Processing Configuration

### Data Engine

metasurvey uses `data.table` by default for fast data manipulation:

``` r

# Current engine
get_engine()
#> [1] "data.table"

# Available engines
show_engines()
#> [1] "data.table" "tidyverse"  "dplyr"      "metatable"
```

### Step Execution and Lazy Processing

[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md),
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md)
and
[`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md)
execute eagerly when created;
[`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md)
and
[`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md)
are always deferred until
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md),
since filtering affects the sampling design. The lazy-processing setting
only controls
[`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md)
and
[`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md)
(deferred by default):

``` r

# Check current setting (applies to rename/remove only)
lazy_default()
#> [1] TRUE

# Change for the session (not recommended for most workflows)
# set_lazy_processing(FALSE)
```

### Copy Behavior

You can control whether step operations modify the data in-place or work
on copies:

``` r

# Current setting
use_copy_default()
#> [1] TRUE

# In-place is faster but modifies the original
# set_use_copy(FALSE)
```

## Variance Estimation

### Design-Based Variance

Standard variance estimation using the sampling design:

``` r

results <- workflow(
  list(svy_simple),
  survey::svymean(~api00, na.rm = TRUE),
  survey::svytotal(~enroll, na.rm = TRUE),
  estimation_type = "annual"
)

results
#>                        stat variable        value           se         cv
#>                      <char>   <char>        <num>        <num>      <num>
#> 1:   survey::svymean: api00    api00     662.2874 9.585429e+00 0.01447322
#> 2: survey::svytotal: enroll   enroll 3687177.5324 1.645323e+05 0.04462283
#>    confint_lower confint_upper  evaluate
#>            <num>         <num>    <char>
#> 1:      643.5003      681.0745 Excellent
#> 2:  3364700.1537  4009654.9112 Excellent
```

### Domain Estimation

Estimates for subpopulations can be computed using
[`survey::svyby()`](https://rdrr.io/pkg/survey/man/svyby.html):

``` r

domain_results <- workflow(
  list(svy_simple),
  survey::svyby(~api00, ~stype, survey::svymean, na.rm = TRUE),
  estimation_type = "annual"
)

domain_results
#>                    stat variable  value       se         cv confint_lower
#>                  <char>   <char>  <num>    <num>      <num>         <num>
#> 1: survey::svyby: api00    api00 674.43 12.49343 0.01852443      649.9433
#> 2: survey::svyby: api00    api00 625.82 15.34078 0.02451309      595.7526
#> 3: survey::svyby: api00    api00 636.60 16.50239 0.02592270      604.2559
#>    confint_upper  evaluate  stype
#>            <num>    <char> <fctr>
#> 1:      698.9167 Excellent      E
#> 2:      655.8874 Excellent      H
#> 3:      668.9441 Excellent      M
```

### Ratios

``` r

ratio_result <- workflow(
  list(svy_simple),
  survey::svyratio(~api00, ~api99),
  estimation_type = "annual"
)

ratio_result
#>                             stat variable denominator    value         se
#>                           <char>   <char>      <char>    <num>      <num>
#> 1: survey::svyratio: api00/api99    api00       api99 1.052261 0.00379243
#>             cv confint_lower confint_upper  evaluate
#>          <num>         <num>         <num>    <char>
#> 1: 0.003604079      1.044828      1.059694 Excellent
```

## Pipeline Validation

### Step-by-Step Verification

When building complex pipelines, it is useful to verify each step
independently:

``` r

# Step 1: Compute new variable
svy_v <- step_compute(svy_simple,
  api_diff = api00 - api99,
  comment = "API score difference"
)

# The compute already executed; the step is recorded in the pipeline
steps <- get_steps(svy_v)
cat("Recorded steps:", length(steps), "\n")
#> Recorded steps: 1
```

### Cross-Validation with the survey Package

You can compare metasurvey
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
results with direct calls to the `survey` package:

``` r

# Method 1: Direct survey package
design <- svydesign(id = ~1, weights = ~pw, data = dt_strat)
direct_mean <- svymean(~api00, design)

# Method 2: metasurvey workflow
wf_result <- workflow(
  list(svy_simple),
  survey::svymean(~api00, na.rm = TRUE),
  estimation_type = "annual"
)

cat("Direct estimate:", round(coef(direct_mean), 2), "\n")
#> Direct estimate: 662.29
cat("Workflow estimate:", round(wf_result$value, 2), "\n")
#> Workflow estimate: 662.29
cat("Match:", all.equal(
  as.numeric(coef(direct_mean)),
  wf_result$value,
  tolerance = 1e-6
), "\n")
#> Match: TRUE
```

### Pipeline Visualization

You can use
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)
to visualize the dependency graph between steps:

``` r

svy_viz <- step_compute(svy_simple,
  api_diff = api00 - api99,
  high_growth = ifelse(api00 - api99 > 50, 1L, 0L)
)
view_graph(svy_viz, init_step = "Load API data")
```

The interactive DAG is not rendered in this vignette to keep the package
size small. Run the code above in your R session to explore it.

### Quality Assessment

You can assess the quality of estimates using the coefficient of
variation:

``` r

results_quality <- workflow(
  list(svy_simple),
  survey::svymean(~api00, na.rm = TRUE),
  survey::svymean(~enroll, na.rm = TRUE),
  estimation_type = "annual"
)

for (i in seq_len(nrow(results_quality))) {
  cv_pct <- results_quality$cv[i] * 100
  cat(
    results_quality$stat[i], ":",
    round(cv_pct, 1), "% CV -",
    evaluate_cv(cv_pct), "\n"
  )
}
#> survey::svymean: api00 : 1.4 % CV - Excellent 
#> survey::svymean: enroll : 4.5 % CV - Excellent
```

### Recipe Validation

You can verify that recipes and their steps are consistent:

``` r

# Create steps and recipe
svy_rt <- step_compute(svy_simple, api_diff = api00 - api99)

my_recipe <- steps_to_recipe(
  name        = "API Test",
  user        = "QA Team",
  svy         = svy_rt,
  description = "Recipe for validation",
  steps       = get_steps(svy_rt)
)

# Check documentation is correct
doc <- my_recipe$doc()
cat("Input variables:", paste(doc$input_variables, collapse = ", "), "\n")
#> Input variables: api00, api99
cat("Output variables:", paste(doc$output_variables, collapse = ", "), "\n")
#> Output variables: api_diff

# Validate against the survey
my_recipe$validate(svy_rt)
#> [1] TRUE
```

## Validation Checklist

Before putting a survey processing pipeline into production, the
following should be verified:

1.  **Data integrity** – row count, column names, and data types after
    each step
2.  **Weight validation** – weight columns exist and are positive
3.  **Design verification** – the sampling design matches the expected
    specification (PSU, strata, weights)
4.  **Recipe reproducibility** – save and reload recipes, verify the
    JSON round-trip
5.  **Cross-validation** – compare key estimates with published values
    or direct calls to the `survey` package
6.  **CV thresholds** – flag estimates with high coefficients of
    variation

``` r

validate_pipeline <- function(svy) {
  data <- get_data(svy)
  checks <- list(
    has_data = !is.null(data),
    has_rows = nrow(data) > 0,
    has_weights = all(
      unlist(svy$weight)[is.character(unlist(svy$weight))] %in% names(data)
    )
  )

  passed <- all(unlist(checks))
  if (passed) {
    message("All validation checks passed")
  } else {
    failed <- names(checks)[!unlist(checks)]
    warning("Failed checks: ", paste(failed, collapse = ", "))
  }
  invisible(checks)
}

validate_pipeline(svy_simple)
```

## Best Practices

1.  **Always use appropriate weights** – never compute unweighted
    statistics from survey data
2.  **Use replicate weights when available** – they provide more robust
    variance estimates
3.  **Check sample sizes by domain** – combine small domains when CVs
    are too high
4.  **Document the design** – include the design specification, weight
    construction, and variance method
5.  **Cross-validate key estimates** – compare with published values or
    alternative methods

## Next Steps

- **[Estimation
  Workflows](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.md)**
  –
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md),
  `RecipeWorkflow`, and publishable estimates
- **[Rotating Panels and
  PoolSurvey](https://metasurveyr.github.io/metasurvey/articles/panel-analysis.md)**
  – Longitudinal analysis with `RotativePanelSurvey` and `PoolSurvey`
- **[Getting
  Started](https://metasurveyr.github.io/metasurvey/articles/getting-started.md)**
  – Review the basics of steps and Survey objects
