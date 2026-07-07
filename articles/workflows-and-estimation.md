# Estimation Workflows

## What is a Workflow?

After transforming survey data with steps and recipes, the next task is
**estimation**: computing means, totals, ratios, and their standard
errors while accounting for the complex survey design.

The
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
function wraps the estimators from the `survey` package (`svymean`,
`svytotal`, `svyratio`, `svyby`) and returns tidy results as a
`data.table` that include:

- Point estimates and standard errors
- Coefficients of variation (CV)
- Confidence intervals
- Metadata for reproducibility

## Initial Setup

We use the Academic Performance Index (API) dataset from the `survey`
package, which contains real data from stratified schools in California.

``` r

library(metasurvey)
library(survey)
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

## Basic Estimation

### Mean

We estimate the population mean of the API score in the year 2000:

``` r

result <- workflow(
  list(svy),
  survey::svymean(~api00, na.rm = TRUE),
  estimation_type = "annual"
)

result
#>                      stat variable    value       se         cv confint_lower
#>                    <char>   <char>    <num>    <num>      <num>         <num>
#> 1: survey::svymean: api00    api00 662.2874 9.585429 0.01447322      643.5003
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:      681.0745 Excellent
```

### Total

We estimate total enrollment across all schools:

``` r

result_total <- workflow(
  list(svy),
  survey::svytotal(~enroll, na.rm = TRUE),
  estimation_type = "annual"
)

result_total
#>                        stat variable   value       se         cv confint_lower
#>                      <char>   <char>   <num>    <num>      <num>         <num>
#> 1: survey::svytotal: enroll   enroll 3687178 164532.3 0.04462283       3364700
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:       4009655 Excellent
```

### Multiple Estimates at Once

You can pass multiple estimation calls to
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
to compute them in a single step:

``` r

results <- workflow(
  list(svy),
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

## Domain Estimation

We use [`survey::svyby()`](https://rdrr.io/pkg/survey/man/svyby.html) to
compute estimates by subpopulations (domains):

``` r

# Mean API score by school type
api_by_type <- workflow(
  list(svy),
  survey::svyby(~api00, ~stype, survey::svymean, na.rm = TRUE),
  estimation_type = "annual"
)

api_by_type
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

``` r

# Mean enrollment by awards status
enroll_by_award <- workflow(
  list(svy),
  survey::svyby(~enroll, ~awards, survey::svymean, na.rm = TRUE),
  estimation_type = "annual"
)

enroll_by_award
#>                     stat variable    value       se         cv confint_lower
#>                   <char>   <char>    <num>    <num>      <num>         <num>
#> 1: survey::svyby: enroll   enroll 727.5958 57.54094 0.07908366      614.8177
#> 2: survey::svyby: enroll   enroll 520.5114 25.51854 0.04902590      470.4960
#>    confint_upper  evaluate awards
#>            <num>    <char> <fctr>
#> 1:      840.3740 Very good     No
#> 2:      570.5269 Excellent    Yes
```

## Quality Assessment

The **coefficient of variation (CV)** measures the precision of an
estimate. You can use
[`evaluate_cv()`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md)
to classify quality following standard guidelines:

| CV Range | Quality    | Recommendation           |
|----------|------------|--------------------------|
| \< 5%    | Excellent  | Use without restrictions |
| 5-10%    | Very good  | Use with confidence      |
| 10-15%   | Good       | Use for most purposes    |
| 15-25%   | Acceptable | Use with caution         |
| 25-35%   | Poor       | Only for general trends  |
| \>= 35%  | Unreliable | Do not publish           |

``` r

# Evaluate quality of the API score estimate
cv_pct <- results$cv[1] * 100
quality <- evaluate_cv(cv_pct)

cat("CV:", round(cv_pct, 2), "%\n")
#> CV: 1.45 %
cat("Quality:", quality, "\n")
#> Quality: Excellent
```

## RecipeWorkflow: Publishable Estimates

A `RecipeWorkflow` bundles estimation calls with metadata, making the
analysis reproducible and shareable. It records:

- Which recipes were used for data preparation
- Which estimation calls were performed
- Authorship and versioning information

### Creating a RecipeWorkflow

``` r

wf <- RecipeWorkflow$new(
  name = "API Score Analysis 2000",
  description = "Mean API score estimation by school type",
  user = "Research Team",
  survey_type = "api",
  edition = "2000",
  estimation_type = "annual",
  recipe_ids = character(0),
  calls = list(
    "survey::svymean(~api00, na.rm = TRUE)",
    "survey::svyby(~api00, ~stype, survey::svymean, na.rm = TRUE)"
  )
)

wf
#> 
#> ── Workflow: API Score Analysis 2000 ──
#> Author:  Research Team
#> Survey:  api / 2000
#> Version: 1.0.0
#> Description: Mean API score estimation by school type
#> Certification: community
#> Estimation types: annual
#> 
#> ── Calls (2) ──
#>   1. survey::svymean(~api00, na.rm = TRUE)
#>   2. survey::svyby(~api00, ~stype, survey::svymean, na.rm = TRUE)
```

### Publishing to the Registry

We publish the workflow so that others can discover and reuse it:

``` r

# Configure a local backend
wf_path <- tempfile(fileext = ".json")
set_workflow_backend("local", path = wf_path)

# Publish
publish_workflow(wf)

# Discover workflows
all_wf <- list_workflows()
length(all_wf)
#> [1] 1

# Search by text
found <- search_workflows("income")
length(found)
#> [1] 0

# Filter by survey type
ech_wf <- filter_workflows(survey_type = "ech")
length(ech_wf)
#> [1] 0
```

### Finding Workflows Associated with a Recipe

If you have a recipe and want to know which estimates have been
published for it, you can use
[`find_workflows_for_recipe()`](https://metasurveyr.github.io/metasurvey/reference/find_workflows_for_recipe.md):

``` r

# Create a workflow that references a recipe
wf2 <- RecipeWorkflow$new(
  name            = "Labor Market Estimates",
  user            = "Team",
  survey_type     = "ech",
  edition         = "2023",
  estimation_type = "annual",
  recipe_ids      = c("labor_force_recipe_001"),
  calls           = list("survey::svymean(~employed, na.rm = TRUE)")
)

publish_workflow(wf2)

# Find all workflows that use this recipe
related <- find_workflows_for_recipe("labor_force_recipe_001")
length(related)
#> [1] 1
if (length(related) > 0) cat("Found:", related[[1]]$name, "\n")
#> Found: Labor Market Estimates
```

## Sharing via the Remote API

For broader dissemination, you can publish workflows to the metasurvey
API:

``` r

# Requires authentication
api_login("you@example.com", "password")

# Publish
api_publish_workflow(wf)

# Browse
all <- api_list_workflows(survey_type = "ech")
specific <- api_get_workflow("workflow_id_here")
```

## Full Pipeline

Below is a complete pipeline from raw data to publishable estimation,
using the API dataset:

``` r

# 1. Create survey from real data
dt_full <- data.table(apistrat)

svy_full <- Survey$new(
  data    = dt_full,
  edition = "2000",
  type    = "api",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "pw")
)

# 2. Apply steps: compute derived variables
svy_full <- step_compute(svy_full,
  api_growth = api00 - api99,
  high_growth = ifelse(api00 - api99 > 50, 1L, 0L),
  comment = "API score growth indicators"
)

svy_full <- step_recode(svy_full, school_level,
  stype == "E" ~ "Elementary",
  stype == "M" ~ "Middle",
  stype == "H" ~ "High",
  .default = "Other",
  comment = "School level classification"
)

# 3. Estimate means
estimates <- workflow(
  list(svy_full),
  survey::svymean(~api_growth, na.rm = TRUE),
  survey::svymean(~high_growth, na.rm = TRUE),
  estimation_type = "annual"
)

estimates
#>                            stat    variable      value        se         cv
#>                          <char>      <char>      <num>     <num>      <num>
#> 1:  survey::svymean: api_growth  api_growth 32.8925184 2.1583789 0.06561914
#> 2: survey::svymean: high_growth high_growth  0.2938489 0.0363651 0.12375443
#>    confint_lower confint_upper  evaluate
#>            <num>         <num>    <char>
#> 1:    28.6621734    37.1228633 Very good
#> 2:     0.2225746     0.3651232      Good
```

``` r

# 4. Domain estimation (by school type)
by_school <- workflow(
  list(svy_full),
  survey::svyby(~api00, ~stype, survey::svymean, na.rm = TRUE),
  estimation_type = "annual"
)

by_school
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

``` r

# 5. Assess quality
for (i in seq_len(nrow(estimates))) {
  cv_val <- estimates$cv[i] * 100
  cat(
    estimates$stat[i], ":",
    round(cv_val, 1), "% CV -",
    evaluate_cv(cv_val), "\n"
  )
}
#> survey::svymean: api_growth : 6.6 % CV - Very good 
#> survey::svymean: high_growth : 12.4 % CV - Good
```

## Provenance: Data Lineage

Every `Survey` object records **provenance** metadata: where the data
came from, which steps were applied, how many rows survived each step,
and which versions of R and metasurvey were used. This makes it possible
to trace any estimate back to the raw data.

``` r

# Provenance is populated automatically after bake_steps()
prov <- provenance(svy_full)
prov
#> ── Data Provenance ─────────────────────────────────────────────────────────────
#> Loaded: 2026-07-07T14:40:37 
#> Initial rows: 200 
#> 
#> Environment:
#>   metasurvey: 0.0.24 
#>   R: 4.6.1 
#>   survey: 4.5
```

Provenance is also attached to
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
results, so you can always inspect the full lineage of an estimate:

``` r

prov_wf <- provenance(estimates)
cat("metasurvey version:", prov_wf$environment$metasurvey_version, "\n")
#> metasurvey version: 0.0.24
cat("Steps applied:", length(prov_wf$steps), "\n")
#> Steps applied: 0
```

For audit trails, export provenance to JSON:

``` r

provenance_to_json(prov, "audit_trail.json")
```

To compare two runs (e.g., different editions), use
[`provenance_diff()`](https://metasurveyr.github.io/metasurvey/reference/provenance_diff.md):

``` r

diff <- provenance_diff(prov_2022, prov_2023)
diff$steps_changed
diff$n_final_changed
```

## Publication-Quality Tables

[`workflow_table()`](https://metasurveyr.github.io/metasurvey/reference/workflow_table.md)
formats estimation results as publication-ready tables using the `gt`
package. It adds confidence intervals, CV quality classification with
color coding, and provenance-based source notes.

``` r

workflow_table(estimates)
```

| Survey Estimation Results |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|
| Statistic | variable | Estimate | SE | CI Lower | CI Upper | CV (%) | Quality |
| :svymean: api_growth | api_growth | 32.89 | 2.158 | 28.66 | 37.12 | 6.6 | Very good |
| :svymean: high_growth | high_growth | 0.29 | 0.036 | 0.22 | 0.37 | 12.4 | Good |
| metasurvey 0.0.24 \| CI: 95% \| 2026-07-07 |  |  |  |  |  |  |  |

You can customize the output:

``` r

# Spanish locale, hide SE, custom title
workflow_table(
  estimates,
  locale = "es",
  show_se = FALSE,
  title = "API Growth Indicators",
  subtitle = "California Schools, 2000"
)
```

| API Growth Indicators |  |  |  |  |  |  |
|----|----|----|----|----|----|----|
| California Schools, 2000 |  |  |  |  |  |  |
| Statistic | variable | Estimate | CI Lower | CI Upper | CV (%) | Quality |
| :svymean: api_growth | api_growth | 32,89 | 28,66 | 37,12 | 6,6 | Very good |
| :svymean: high_growth | high_growth | 0,29 | 0,22 | 0,37 | 12,4 | Good |
| metasurvey 0.0.24 \| CI: 95% \| 2026-07-07 |  |  |  |  |  |  |

For domain estimates, the table detects group columns automatically:

``` r

workflow_table(by_school)
```

| Survey Estimation Results |  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|----|
| Statistic | variable | stype | Estimate | SE | CI Lower | CI Upper | CV (%) | Quality |
| :svyby: api00 | api00 | E | 674.43 | 12.493 | 649.94 | 698.92 | 1.9 | Excellent |
| :svyby: api00 | api00 | H | 625.82 | 15.341 | 595.75 | 655.89 | 2.5 | Excellent |
| :svyby: api00 | api00 | M | 636.60 | 16.502 | 604.26 | 668.94 | 2.6 | Excellent |
| metasurvey 0.0.24 \| CI: 95% \| 2026-07-07 |  |  |  |  |  |  |  |  |

Export to any format supported by
[`gt::gtsave()`](https://gt.rstudio.com/reference/gtsave.html):

``` r

tbl <- workflow_table(estimates)
gt::gtsave(tbl, "estimates.html")
gt::gtsave(tbl, "estimates.docx")
gt::gtsave(tbl, "estimates.png")
```

## Next Steps

- **[Creating and Publishing
  Recipes](https://metasurveyr.github.io/metasurvey/articles/recipes.md)**
  – Build reproducible transformation pipelines
- **[Survey Designs and
  Validation](https://metasurveyr.github.io/metasurvey/articles/complex-designs.md)**
  – Stratification, clustering, replicate weights
- **[Case Study:
  ECH](https://metasurveyr.github.io/metasurvey/articles/ech-case-study.md)**
  – Complete labor market analysis with estimation
