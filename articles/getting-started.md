# Getting Started with metasurvey

## Introduction

Working with household survey microdata involves a great deal of
repetitive processing: recoding categorical variables, building
indicators, joining external data, and computing weighted estimates.
Each researcher writes their own version of these transformations, and
the code is rarely shared or documented in a way that others can reuse.

**metasurvey** addresses this problem by providing a metaprogramming
layer on top of the `survey` package ([Lumley 2004](#ref-lumley2004)).
Instead of writing ad hoc scripts, you build a **pipeline** of
transformations that is:

- **Documented** – every step carries a comment, its input/output
  variables, and its dependencies
- **Reproducible** – the pipeline can be saved as a recipe and applied
  to new data
- **Shareable** – recipes can be published to a public API where other
  researchers can discover and reuse them

The pipeline has three levels:

1.  **Steps** – individual transformations (compute, recode, filter,
    rename, remove, join, validate)
2.  **Recipes** – reusable collections of steps bundled with metadata
3.  **Workflows** – statistical estimates (`svymean`, `svytotal`,
    `svyby`) that produce the final tables

The package handles the survey design —stratification, clusters,
replicate weights— automatically through the `Survey` object. The user
focuses on the substantive analysis; metasurvey takes care of the
infrastructure.

## Installation

``` r

# Install from GitHub
devtools::install_github("metaSurveyR/metasurvey")
```

``` r

library(metasurvey)
library(data.table)
```

## Creating a Survey object

A `Survey` object groups the microdata together with metadata about
weights, edition, and survey type. We use a sample of real microdata
from Uruguay’s *Encuesta Continua de Hogares* (ECH, Continuous Household
Survey) 2023, published by the Instituto Nacional de Estadistica (INE).

The ECH is a rotating-panel household survey. Key variables include:

- **e27**: Age in years
- **e26**: Sex (1 = Male, 2 = Female)
- **e30**: Relationship to head of household (1-14)
- **POBPCOAC**: Activity status
  - 1 = Under 14
  - 2 = Employed
  - 3-5 = Unemployed
  - 6-10 = Inactive
  - 11 = Not applicable
- **HT11**: Household income (Uruguayan pesos)
- **W_ANO**: Annual expansion factor (weight)

``` r

library(metasurvey)
library(data.table)

# Load a sample of real ECH 2023 microdata (200 households, ~500 persons)
dt <- fread(system.file("extdata", "ech_2023_sample.csv", package = "metasurvey"))

# Create Survey object
svy <- Survey$new(
  data    = dt,
  edition = "2023",
  type    = "ech",
  engine  = "data.table",
  weight  = add_weight(annual = "W_ANO")
)
```

The
[`add_weight()`](https://metasurveyr.github.io/metasurvey/reference/add_weight.md)
function maps periodicity labels (e.g., “annual”, “monthly”) to the
weight column names in the data. This lets the same recipe work across
different survey editions.

You can inspect the data at any time:

``` r

head(get_data(svy), 3)
#>       ID  nper  anio   mes region  dpto   nom_dpto   e26   e27   e30 e51_2
#>    <int> <int> <int> <int>  <int> <int>     <char> <int> <int> <int> <int>
#> 1: 34561     1  2023     1      1     1 Montevideo     2    26     1     6
#> 2: 34561     2  2023     1      1     1 Montevideo     2    45     7     6
#> 3: 34561     3  2023     1      1     1 Montevideo     2     7     4     1
#>    POBPCOAC SUBEMPLEO    HT11 pobre06 W_ANO
#>       <int>     <int>   <num>   <int> <int>
#> 1:        2         0 55429.6       0    57
#> 2:        4         0 55429.6       0    57
#> 3:        1         0 55429.6       0    57
```

## Working with Steps

Steps are **lazy by default**: they are recorded but not executed until
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
is called. This allows you to:

1.  Build a complete transformation pipeline
2.  Inspect and validate the steps before execution
3.  Reuse step sequences as recipes
4.  Ensure all dependencies exist before processing

### Computing new variables

Use
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md)
to create derived variables. The package automatically:

- Validates that input variables exist
- Detects dependencies between steps
- Optimizes expressions for performance

``` r

svy <- step_compute(svy,
  # Convert income to thousands for readability
  ht11_thousands = HT11 / 1000,

  # Create employment indicator following ILO definitions
  employed = ifelse(POBPCOAC == 2, 1, 0),

  # Working age population (14+ years, ECH standard)
  working_age = ifelse(e27 >= 14, 1, 0),
  comment = "Basic labor force indicators"
)
```

You can group computations using the `.by` parameter (similar to
`data.table`):

``` r

# Calculate mean household income per department
svy <- step_compute(svy,
  mean_income_dept = mean(HT11, na.rm = TRUE),
  .by = "dpto",
  comment = "Department-level income averages"
)
```

### Recoding into categories

Use
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md)
to create categorical variables from conditions. Conditions are
evaluated **top to bottom**, and the first match applies.

``` r

# Recode labor force status (POBPCOAC) into meaningful categories
svy <- step_recode(svy, labor_status,
  POBPCOAC == 2 ~ "Employed",
  POBPCOAC %in% 3:5 ~ "Unemployed",
  POBPCOAC %in% 6:10 ~ "Inactive",
  .default = "Not classified",
  comment = "Labor force status - ILO standard"
)

# Create standard age groups for labor statistics
svy <- step_recode(svy, age_group,
  e27 < 25 ~ "Youth (14-24)",
  e27 < 45 ~ "Adult (25-44)",
  e27 < 65 ~ "Mature (45-64)",
  .default = "Elderly (65+)",
  .to_factor = TRUE, # Convert to factor
  ordered = TRUE, # Ordered factor
  comment = "Age groups for labor analysis"
)

# Recode sex into descriptive labels
svy <- step_recode(svy, gender,
  e26 == 1 ~ "Male",
  e26 == 2 ~ "Female",
  .default = "Other",
  comment = "Gender classification"
)
```

### Filtering rows

Use
[`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md)
to subset rows based on logical conditions. Multiple conditions are
combined with AND. Like other steps, filters are lazy by default.

``` r

# Keep only working-age individuals (14+)
svy <- step_filter(svy,
  e27 >= 14,
  comment = "Working-age population only"
)
```

### Renaming and removing variables

Rename variables for clarity or consistency:

``` r

svy <- step_rename(svy,
  age = e27, # Rename e27 to age
  sex_code = e26 # Keep original as sex_code
)
```

Remove variables that are no longer needed:

``` r

# Remove intermediate calculations
svy <- step_remove(svy, working_age, mean_income_dept)
```

### Joining external data

Use
[`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md)
to merge in external reference data. This is useful for adding:

- Geographic names and classifications
- Exchange rates or deflators
- External benchmarks or targets

Note that real ECH microdata already includes `nom_dpto` and `region`.
Here we demonstrate a join with a poverty-line lookup as an example:

``` r

# Poverty lines by region (illustrative values in UYU, 2023)
poverty_lines <- data.table(
  region = 1:3,
  poverty_line = c(19000, 12500, 11000),
  region_name = c("Montevideo", "Interior loc. >= 5000", "Interior loc. < 5000")
)

svy <- step_join(svy,
  poverty_lines,
  by = "region",
  type = "left",
  comment = "Add poverty lines by region"
)
```

## Executing transformations

### Applying steps (bake)

Call
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
to execute all pending transformations:

``` r

svy <- bake_steps(svy)
head(get_data(svy), 3)
#>    region  dpto    ID  nper  anio   mes   nom_dpto sex_code   age   e30 e51_2
#>     <int> <int> <int> <int> <int> <int>     <char>    <int> <int> <int> <int>
#> 1:      1     1 34561     1  2023     1 Montevideo        2    26     1     6
#> 2:      1     1 34561     2  2023     1 Montevideo        2    45     7     6
#> 3:      1     1 34678     1  2023     1 Montevideo        1    48     1     6
#>    POBPCOAC SUBEMPLEO     HT11 pobre06 W_ANO ht11_thousands employed
#>       <int>     <int>    <num>   <int> <int>          <num>    <num>
#> 1:        2         0  55429.6       0    57        55.4296        1
#> 2:        4         0  55429.6       0    57        55.4296        0
#> 3:        2         0 152958.8       0    54       152.9588        1
#>    labor_status      age_group gender poverty_line region_name
#>          <char>          <ord> <char>        <num>      <char>
#> 1:     Employed  Adult (25-44) Female        19000  Montevideo
#> 2:   Unemployed Mature (45-64) Female        19000  Montevideo
#> 3:     Employed Mature (45-64)   Male        19000  Montevideo
```

The step history is preserved for documentation and reproducibility:

``` r

steps <- get_steps(svy)
length(steps) # Number of transformation steps
#> [1] 9

# View step details
cat("Step 1:", steps[[1]]$name, "\n")
#> Step 1: step_1 Compute: ht11_thousands, employed, working_age
cat("Comment:", steps[[1]]$comment, "\n")
#> Comment: Basic labor force indicators
```

### Visualizing the pipeline

You can visualize the transformation pipeline as a directed graph:

``` r

view_graph(svy, init_step = "Load ECH 2023")
```

The interactive DAG is not rendered in this vignette to keep the package
size small. Run
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)
in your R session to get an interactive graph showing:

- Data sources and joins
- Transformation steps
- Variable dependencies
- Comments and metadata

## Statistical estimates

Once the data is prepared, use
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
to compute survey estimates. The function wraps estimators from the
`survey` package ([Lumley 2004](#ref-lumley2004)) and returns tidy
results with standard errors and coefficients of variation.

**Important:** The survey object must be passed inside a
[`list()`](https://rdrr.io/r/base/list.html).

### Basic estimates

``` r

# Estimate mean household income
result <- workflow(
  list(svy),
  survey::svymean(~HT11, na.rm = TRUE),
  estimation_type = "annual"
)

result
#>                     stat variable    value       se         cv confint_lower
#>                   <char>   <char>    <num>    <num>      <num>         <num>
#> 1: survey::svymean: HT11     HT11 110389.3 4076.154 0.03692528      102400.1
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:      118378.4 Excellent
```

The output includes:

- `estimate`: Point estimate
- `se`: Standard error
- `cv`: Coefficient of variation
- `var_name`: Variable name
- `level`: Factor level (for categorical variables)

### Multiple estimates

You can compute several statistics in a single call:

``` r

results <- workflow(
  list(svy),
  survey::svymean(~HT11, na.rm = TRUE),
  survey::svytotal(~employed, na.rm = TRUE),
  survey::svymean(~labor_status, na.rm = TRUE),
  estimation_type = "annual"
)

results
#>                                           stat                   variable
#>                                         <char>                     <char>
#> 1:                       survey::svymean: HT11                       HT11
#> 2:                  survey::svytotal: employed                   employed
#> 3:       survey::svymean: labor_statusEmployed       labor_statusEmployed
#> 4:       survey::svymean: labor_statusInactive       labor_statusInactive
#> 5: survey::svymean: labor_statusNot classified labor_statusNot classified
#> 6:     survey::svymean: labor_statusUnemployed     labor_statusUnemployed
#>           value           se         cv confint_lower confint_upper
#>           <num>        <num>      <num>         <num>         <num>
#> 1: 1.103893e+05 4.076154e+03 0.03692528  1.024001e+05  1.183784e+05
#> 2: 1.426200e+04 6.756206e+02 0.04737208  1.293781e+04  1.558619e+04
#> 3: 5.480115e-01 2.596045e-02 0.04737208  4.971300e-01  5.988931e-01
#> 4: 3.810951e-01 2.528765e-02 0.06635522  3.315322e-01  4.306580e-01
#> 5: 1.287224e-02 5.797576e-03 0.45039378  1.509198e-03  2.423528e-02
#> 6: 5.802113e-02 1.292837e-02 0.22282174  3.268199e-02  8.336027e-02
#>          evaluate
#>            <char>
#> 1:      Excellent
#> 2:      Excellent
#> 3:      Excellent
#> 4:      Very good
#> 5: Do not publish
#> 6:     Acceptable
```

### Domain estimation

Compute estimates for subpopulations using
[`survey::svyby()`](https://rdrr.io/pkg/survey/man/svyby.html):

``` r

# Mean income by gender
income_by_gender <- workflow(
  list(svy),
  survey::svyby(~HT11, ~gender, survey::svymean, na.rm = TRUE),
  estimation_type = "annual"
)

income_by_gender
#>                   stat variable    value       se         cv confint_lower
#>                 <char>   <char>    <num>    <num>      <num>         <num>
#> 1: survey::svyby: HT11     HT11 111107.9 5955.676 0.05360263      99434.99
#> 2: survey::svyby: HT11     HT11 109608.9 5519.291 0.05035439      98791.31
#>    confint_upper  evaluate gender
#>            <num>    <char> <char>
#> 1:      122780.8 Very good Female
#> 2:      120426.5 Very good   Male
```

## Quality assessment

The **coefficient of variation (CV)** measures the reliability of
estimates. A lower CV indicates more precise estimates. Following the
INE Uruguay guidelines ([Instituto Nacional de Estadística (INE)
2023](#ref-ine2023)):

| CV range | Quality category | Recommendation                       |
|----------|------------------|--------------------------------------|
| \< 5%    | Excellent        | Use without restrictions             |
| 5%–10%   | Very good        | Use with confidence                  |
| 10%–15%  | Good             | Use for most purposes                |
| 15%–25%  | Acceptable       | Use with caution, noting limitations |
| 25%–35%  | Poor             | Use only for general trends          |
| \>= 35%  | Unreliable       | Do not publish                       |

Use
[`evaluate_cv()`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md)
to classify estimate quality:

``` r

# Check quality of mean income estimate
cv_percentage <- results$cv[1] * 100
quality <- evaluate_cv(cv_percentage)

cat("CV:", round(cv_percentage, 2), "%\n")
#> CV: 3.69 %
cat("Quality:", quality, "\n")
#> Quality: Excellent
```

For official statistics, always report:

1.  Point estimate
2.  Standard error or confidence interval
3.  Coefficient of variation
4.  Quality classification
5.  Sample size

## Working with Recipes

Recipes bundle transformation steps for **reproducibility** and
**sharing**. Once you have developed a working pipeline, you can convert
it into a recipe that can be:

- Applied to different survey editions
- Shared with collaborators
- Published for transparency
- Versioned and documented

### Creating a Recipe

Create a recipe from the steps you have developed:

``` r

# Convert current steps to a recipe
labor_recipe <- steps_to_recipe(
  name = "ECH Labor Force Indicators",
  user = "National Statistics Office",
  svy = svy,
  description = paste(
    "Standard labor force indicators following ILO definitions.",
    "Creates employment status, age groups, and gender classifications."
  ),
  steps = get_steps(svy),
  topic = "labor_statistics"
)

class(labor_recipe)
#> [1] "Recipe" "R6"
labor_recipe$name
#> [1] "ECH Labor Force Indicators"
```

Or you can define a recipe from scratch:

``` r

minimal_recipe <- recipe(
  name = "Basic Demographics - ECH",
  user = "analyst",
  svy = survey_empty(type = "ech", edition = "2023"),
  description = "Basic demographic recoding for ECH microdata",
  topic = "demographics",

  # Define steps inline
  step_recode(
    gender,
    e26 == 1 ~ "Male",
    e26 == 2 ~ "Female",
    .default = "Other"
  ),
  step_recode(
    age_group,
    e27 < 14 ~ "Child",
    e27 < 65 ~ "Adult",
    .default = "Senior"
  )
)
```

### Applying Recipes to new data

Once published, anyone can retrieve a recipe by ID and apply it to their
data:

``` r

# Get a recipe by ID from the API (requires server)
r <- api_get_recipe("ech_labor_001")

# Apply to a new survey
new_svy <- add_recipe(new_svy, r)
processed <- bake_recipes(new_svy)
```

### Recipe documentation

Recipes automatically document their transformations:

``` r

doc <- labor_recipe$doc()
names(doc)
#> [1] "meta"             "input_variables"  "output_variables" "pipeline"

# Input variables required
doc$input_variables
#> [1] "HT11"     "POBPCOAC" "e27"      "e26"      "region"

# Output variables created
doc$output_variables
#> [1] "ht11_thousands"   "employed"         "working_age"      "mean_income_dept"
#> [5] "labor_status"     "age_group"        "gender"           "mapping"
```

## Package configuration

metasurvey provides global settings that can be adjusted to suit your
workflow:

``` r

# Check current lazy-processing setting
lazy_default() # TRUE = steps recorded but not executed immediately
#> [1] TRUE

# Check data-copy behavior
use_copy_default() # TRUE = operate on copies (safer but slower)
#> [1] TRUE

# View available computation engines
show_engines() # "data.table", "dplyr", etc.
#> [1] "data.table" "tidyverse"  "dplyr"
```

You can modify settings for the current session:

``` r

# Disable lazy evaluation (execute steps immediately)
set_lazy_processing(FALSE)

# Modify inplace (faster, but modifies original data)
set_use_copy(FALSE)

# Reset to defaults
set_lazy_processing(TRUE)
set_use_copy(TRUE)
```

## Sharing your work: the recipe ecosystem

One of the goals of metasurvey is to reduce duplicated effort among the
community of researchers working with surveys. If you have built a
useful processing pipeline, you can publish it so that others can find
and reuse it. The package connects to a public API where recipes and
workflows are stored:

``` r

# Browse existing recipes (requires API server)
ech_recipes <- api_list_recipes(survey_type = "ech")
length(ech_recipes)

# Search for something specific
labor <- api_list_recipes(search = "labor")

# To publish your own, create an account first
api_register("Your Name", "you@example.com", "password")

# Then publish
api_publish_recipe(labor_recipe)
```

The ecosystem supports three certification levels (community, reviewed,
official) and three account types (individual, institutional member,
institution). Institutional accounts require administrator approval,
ensuring that certifications carry real backing.

For more details, see [Creating and Sharing
Recipes](https://metasurveyr.github.io/metasurvey/articles/recipes.md).

## Data and acknowledgments

The sample data used in this vignette comes from the *Encuesta Continua
de Hogares* (ECH) 2023, published by Uruguay’s Instituto Nacional de
Estadistica (INE). The full microdata is available at
[INE](https://www.gub.uy/instituto-nacional-estadistica/).

The **[ech](https://calcita.github.io/ech/)** package by Gabriela
Mathieu and Richard Detomasi was an important inspiration for
metasurvey. While `ech` provides ready-to-use functions for computing
socioeconomic indicators, metasurvey takes a different approach: it
provides a metaprogramming layer that lets users define, share, and
reproduce their own processing pipelines.

## Related packages

metasurvey is part of a growing ecosystem of R packages for household
survey analysis in Latin America:

- **[ech](https://calcita.github.io/ech/)** – Functions for computing
  socioeconomic indicators with Uruguay’s ECH (Mathieu & Detomasi).
  Provides ready-to-use functions for poverty, income, education, and
  employment indicators.
- **[eph](https://docs.ropensci.org/eph/)** – Tools for working with
  Argentina’s Encuesta Permanente de Hogares. Published on rOpenSci.
  Covers data download, panel construction, and poverty calculation.
- **[survey](https://cran.r-project.org/package=survey)** – The
  foundational package for design-based inference with complex surveys
  ([Lumley 2004](#ref-lumley2004)). metasurvey builds on top of it.

## Next steps

Now that you understand the basics, you can explore these guides:

- **[Creating and Sharing
  Recipes](https://metasurveyr.github.io/metasurvey/articles/recipes.md)**
  – Recipe registry, certification, and discovery
- **[Estimation
  Workflows](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.md)**
  –
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md),
  `RecipeWorkflow`, and publishable estimates
- **[Survey Designs and
  Validation](https://metasurveyr.github.io/metasurvey/articles/complex-designs.md)**
  – Stratification, clusters, replicate weights, pipeline validation
- **[Rotating Panels and
  PoolSurvey](https://metasurveyr.github.io/metasurvey/articles/panel-analysis.md)**
  – Longitudinal analysis with `RotativePanelSurvey` and `PoolSurvey`
- **[ECH Case
  Study](https://metasurveyr.github.io/metasurvey/articles/ech-case-study.md)**
  – Full labor market analysis with STATA comparison

## References

Instituto Nacional de Estadística (INE). 2023. *Encuesta Continua de
Hogares: Metodología y Documentación*. Instituto Nacional de Estadística
(INE), Uruguay. <https://www.gub.uy/instituto-nacional-estadistica/>.

Lumley, Thomas. 2004. “Analysis of Complex Survey Samples.” *Journal of
Statistical Software* 9 (1): 1–19.
<https://doi.org/10.18637/jss.v009.i08>.
