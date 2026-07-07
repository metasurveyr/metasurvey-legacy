# ECH Case Study: From STATA to R

## The ECH harmonization problem

Uruguay’s *Encuesta Continua de Hogares* (ECH) is published annually by
the Instituto Nacional de Estadistica (INE). Over the years, the INE has
changed variable names, codebook definitions, and module structure
across editions. Researchers working with ECH data must *harmonize*
variables —that is, map different naming conventions to a common schema—
before any cross-year analysis is possible.

ECH harmonization has historically been carried out by the Instituto de
Economia (IECON) at the Universidad de la Republica. The resulting
dataset is available at [FCEA - ECH
Compatibilizadas](https://fcea.udelar.edu.uy/portada-ech-compatibilizadas.html)
(Instituto de Economia, 2020). metasurvey aims to complement and
facilitate this kind of work by providing reproducible tools in R.

In Uruguayan academia, this work has been done in STATA for over 30
years. A typical harmonization pipeline consists of approximately **8
.do files per year**, covering:

1.  `2_correc_datos.do` – Raw data loading, merging person and household
    files, variable name corrections
2.  `3_compatibilizacion_mod_1_4.do` – Harmonization of demographic,
    health, education, and labor modules
3.  `4_ingreso_ht11.do` – Household income construction (`ht11`)
4.  `5_descomp_fuentes.do` – Income decomposition by source
5.  `6_ingreso_ht11_sss.do` – Social security adjustments
6.  `7_check_ingr.do` – Income variable validation
7.  `8_arregla_base_comp.do` – Final dataset preparation
8.  `9_labels.do` – Value label application

Multiplied over 30+ years, that means over **240 STATA scripts** doing
essentially the same task: mapping raw ECH variables to a common schema.

**metasurvey solves this with recipes.** Instead of maintaining hundreds
of `.do` files, you write a single recipe that encodes the
transformation logic and can be applied to any ECH edition.

## STATA vs metasurvey: Side-by-side comparison

Below is a snippet from a typical STATA harmonization script for sex,
age, and relationship to head of household:

``` stata
* STATA: Typical ECH compatibility script

* sexo
g bc_pe2 = e26

* edad
g bc_pe3 = e27

* parentesco (e30 in ECH 2023, was e31 in earlier editions)
g bc_pe4 = -9
  replace bc_pe4 = 1 if e30 == 1
  replace bc_pe4 = 2 if e30 == 2
  replace bc_pe4 = 3 if e30 == 3 | e30 == 4 | e30 == 5
  replace bc_pe4 = 4 if e30 == 7 | e30 == 8
  replace bc_pe4 = 5 if e30 == 6 | e30 == 9 | e30 == 10 | e30 == 11 | e30 == 12
  replace bc_pe4 = 6 if e30 == 13
  replace bc_pe4 = 7 if e30 == 14
```

The metasurvey equivalent:

``` r

svy <- step_rename(svy, sex = e26, age = e27)

svy <- step_recode(svy, relationship,
  e30 == 1                ~ "Head",
  e30 == 2                ~ "Spouse",
  e30 %in% 3:5            ~ "Child",
  e30 %in% c(7, 8)        ~ "Parent",
  e30 %in% c(6, 9:12)     ~ "Other relative",
  e30 == 13               ~ "Domestic service",
  e30 == 14               ~ "Non-relative",
  .default = NA_character_,
  comment = "Relationship to head of household"
)
```

Key differences:

| Aspect | STATA `.do` file | metasurvey recipe |
|----|----|----|
| Format | Flat script with hard-coded paths | Portable JSON with metadata |
| Validation | Manual checks with `assert` | Automatic `validate()` method |
| Documentation | In-code comments | Auto-generated `doc()` method |
| Sharing | Copy files via email/server | Registry with search and versioning |
| Reproducibility | Depends on file paths and environment | Self-contained, any machine |
| Cross-edition | Duplicate script per year | One recipe, multiple editions |

## Loading real ECH microdata

We use a sample of real microdata from the ECH 2023, published by the
INE. The sample contains 200 households (~500 persons) with the key
variables needed for labor market analysis.

``` r

library(metasurvey)
library(data.table)

# Load real ECH 2023 sample
dt <- fread(system.file("extdata", "ech_2023_sample.csv", package = "metasurvey"))

svy <- Survey$new(
  data    = dt,
  edition = "2023",
  type    = "ech",
  engine  = "data.table",
  weight  = add_weight(annual = "W_ANO")
)

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

## Step 1: Demographic variables

Recode raw INE codes to readable names and recode categorical variables:

``` r

# Recode sex from INE codes (e26: 1=Male, 2=Female)
svy <- step_recode(svy, sex,
  e26 == 1 ~ "Male",
  e26 == 2 ~ "Female",
  .default = NA_character_,
  comment = "Sex: 1=Male, 2=Female (INE e26)"
)

# Recode age groups (standard ECH grouping, e27 = age)
svy <- step_recode(svy, age_group,
  e27 < 14 ~ "Child (0-13)",
  e27 < 25 ~ "Youth (14-24)",
  e27 < 45 ~ "Adult (25-44)",
  e27 < 65 ~ "Mature (45-64)",
  .default = "Senior (65+)",
  .to_factor = TRUE,
  ordered = TRUE,
  comment = "Standard age groups for labor statistics"
)
```

## Step 2: Labor force classification

The `POBPCOAC` variable (Population by activity status) is the central
labor status classification in the ECH. INE codes:

- 1 = Under 14
- 2 = Employed
- 3-5 = Unemployed (various subcategories)
- 6-10 = Inactive
- 11 = Not applicable

This replicates the standard ILO labor force framework:

``` r

svy <- step_recode(svy, labor_status,
  POBPCOAC == 2 ~ "Employed",
  POBPCOAC %in% 3:5 ~ "Unemployed",
  POBPCOAC %in% 6:10 ~ "Inactive",
  .default = NA_character_,
  comment = "ILO labor force status from POBPCOAC"
)

# Create binary indicators
svy <- step_compute(svy,
  employed = ifelse(POBPCOAC == 2, 1L, 0L),
  unemployed = ifelse(POBPCOAC %in% 3:5, 1L, 0L),
  active = ifelse(POBPCOAC %in% 2:5, 1L, 0L),
  working_age = ifelse(e27 >= 14, 1L, 0L),
  comment = "Labor force binary indicators"
)
```

## Step 3: Income variables

Build income indicators following the standard methodology used with ECH
data:

``` r

svy <- step_compute(svy,
  income_pc = HT11 / nper,
  income_thousands = HT11 / 1000,
  log_income = log(HT11 + 1),
  comment = "Income transformations"
)
```

## Step 4: Geographic classification

The real ECH microdata already includes `nom_dpto` (department name) and
`region` (1-3). We demonstrate a join with poverty lines by region:

``` r

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

## Building the recipe

Convert all transformations into a portable recipe:

``` r

ech_recipe <- steps_to_recipe(
  name = "ECH Labor Market Indicators",
  user = "Research Team",
  svy = svy,
  description = paste(
    "Standard labor market indicators for the ECH.",
    "Includes demographic recoding, ILO labor classification,",
    "income transformations, and geographic joins."
  ),
  steps = get_steps(svy),
  topic = "labor"
)

ech_recipe
#> 
#> ── Recipe: ECH Labor Market Indicators ──
#> Author:  Research Team
#> Survey:  ech / 2023
#> Version: 1.0.0
#> Topic:   labor
#> Description: Standard labor market indicators for the ECH. Includes demographic recoding, ILO labor classification, income transformations, and geographic joins.
#> Certification: community
#> 
#> ── Requires (6 variables) ──
#>   e26, e27, POBPCOAC, HT11, nper, region
#> 
#> ── Pipeline (6 steps) ──
#>   1. [recode] -> sex  "Sex: 1=Male, 2=Female (INE e26)"
#>   2. [recode] -> age_group  "Standard age groups for labor statistics"
#>   3. [recode] -> labor_status  "ILO labor force status from POBPCOAC"
#>   4. [compute] -> employed, unemployed, active, working_age  "Labor force binary indicators"
#>   5. [compute] -> income_pc, income_thousands, log_income  "Income transformations"
#>   6. [step_join] -> (no output)  "Add poverty lines by region"
#> 
#> ── Produces (10 variables) ──
#>   sex [categorical], age_group [categorical], labor_status [categorical], employed [numeric], unemployed [numeric], active [numeric], working_age [numeric], income_pc [numeric], income_thousands [numeric], log_income [numeric]
```

### Automatic documentation

``` r

doc <- ech_recipe$doc()

# What variables does the recipe need?
doc$input_variables
#> [1] "e26"      "e27"      "POBPCOAC" "HT11"     "nper"     "region"

# What variables does it create?
doc$output_variables
#>  [1] "sex"              "age_group"        "labor_status"     "employed"        
#>  [5] "unemployed"       "active"           "working_age"      "income_pc"       
#>  [9] "income_thousands" "log_income"
```

### Publishing to the registry

Publish the recipe so others can discover and reuse it:

``` r

# Set up a local registry
set_backend("local", path = tempfile(fileext = ".json"))
publish_recipe(ech_recipe)

# Now anyone can retrieve it by ID
r <- get_recipe("ech_labor")
print(r)
#> NULL
```

## Estimation with workflow()

Now we compute standard labor market indicators:

``` r

# Mean household income
result_income <- workflow(
  list(svy),
  survey::svymean(~HT11, na.rm = TRUE),
  estimation_type = "annual"
)

result_income
#>                     stat variable    value       se         cv confint_lower
#>                   <char>   <char>    <num>    <num>      <num>         <num>
#> 1: survey::svymean: HT11     HT11 107869.1 3473.836 0.03220417      101060.5
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:      114677.7 Excellent
```

``` r

# Employment rate (proportion employed among total population)
result_employment <- workflow(
  list(svy),
  survey::svymean(~employed, na.rm = TRUE),
  estimation_type = "annual"
)

result_employment
#>                         stat variable     value         se         cv
#>                       <char>   <char>     <num>      <num>      <num>
#> 1: survey::svymean: employed employed 0.4422188 0.02343197 0.05298728
#>    confint_lower confint_upper  evaluate
#>            <num>         <num>    <char>
#> 1:      0.396293     0.4881447 Very good
```

### Domain estimation

Compute estimates by subpopulation:

``` r

# Mean income by region name
income_region <- workflow(
  list(svy),
  survey::svyby(~HT11, ~region_name, survey::svymean, na.rm = TRUE),
  estimation_type = "annual"
)

income_region
#>                   stat variable     value       se         cv confint_lower
#>                 <char>   <char>     <num>    <num>      <num>         <num>
#> 1: survey::svyby: HT11     HT11  90397.57 4632.957 0.05125091      81317.14
#> 2: survey::svyby: HT11     HT11 103877.64 5949.558 0.05727467      92216.72
#> 3: survey::svyby: HT11     HT11 118302.36 5412.484 0.04575127     107694.09
#>    confint_upper  evaluate           region_name
#>            <num>    <char>                <char>
#> 1:       99478.0 Very good  Interior loc. < 5000
#> 2:      115538.6 Very good Interior loc. >= 5000
#> 3:      128910.6 Excellent            Montevideo
```

``` r

# Employment by sex
employment_sex <- workflow(
  list(svy),
  survey::svyby(~employed, ~sex, survey::svymean, na.rm = TRUE),
  estimation_type = "annual"
)

employment_sex
#>                       stat variable     value         se         cv
#>                     <char>   <char>     <num>      <num>      <num>
#> 1: survey::svyby: employed employed 0.3824018 0.03146234 0.08227562
#> 2: survey::svyby: employed employed 0.5076963 0.03449008 0.06793446
#>    confint_lower confint_upper  evaluate    sex
#>            <num>         <num>    <char> <char>
#> 1:     0.3207367     0.4440669 Very good Female
#> 2:     0.4400970     0.5752956 Very good   Male
```

### Quality assessment

``` r

results_all <- workflow(
  list(svy),
  survey::svymean(~HT11, na.rm = TRUE),
  survey::svymean(~employed, na.rm = TRUE),
  estimation_type = "annual"
)

for (i in seq_len(nrow(results_all))) {
  cv_pct <- results_all$cv[i] * 100
  cat(
    results_all$stat[i], ":",
    round(cv_pct, 1), "% CV -",
    evaluate_cv(cv_pct), "\n"
  )
}
#> survey::svymean: HT11 : 3.2 % CV - Excellent 
#> survey::svymean: employed : 5.3 % CV - Very good
```

## Reproducibility: same recipe, different edition

The power of recipes lies in applying them unchanged to new data. In a
real workflow, you would load a different edition of the ECH and apply
the same recipe:

``` r

# Load ECH 2024 microdata (requires external data file)
svy_2024 <- load_survey(
  path = "ECH_2024.csv",
  type = "ech", edition = "2024",
  weight = add_weight(annual = "W_ANO")
)

# Apply the exact same recipe
svy_2024 <- add_recipe(svy_2024, ech_recipe)
svy_2024 <- bake_recipes(svy_2024)

# Estimate with consistent methodology
result_2024 <- workflow(
  list(svy_2024),
  survey::svymean(~HT11, na.rm = TRUE),
  survey::svymean(~employed, na.rm = TRUE),
  estimation_type = "annual"
)
```

Same recipe, different data, consistent methodology.

## For STATA users: quick reference

If you are transitioning from STATA to R for survey analysis, here is a
mapping of common operations:

| STATA | metasurvey | Notes |
|----|----|----|
| `gen var = expr` | `step_compute(svy, var = expr)` | Executes immediately and records the step in the pipeline |
| `replace var = x if cond` | `step_compute(svy, var = ifelse(cond, x, var))` | Conditional assignment |
| `recode var (old=new)` | `step_recode(svy, new_var, old == val ~ "label")` | Creates a new variable |
| `rename old new` | `step_rename(svy, new = old)` |  |
| `drop var1 var2` | `step_remove(svy, var1, var2)` |  |
| `merge using file` | `step_join(svy, data, by = "key")` | Left join by default |
| `svy: mean var` | `workflow(list(svy), svymean(~var))` | Returns data.table with SE, CV |
| `svy: total var` | `workflow(list(svy), svytotal(~var))` |  |
| `svy: mean var, over(group)` | `workflow(list(svy), svyby(~var, ~group, svymean))` |  |
| `.do` file | [`steps_to_recipe()`](https://metasurveyr.github.io/metasurvey/reference/steps_to_recipe.md) + publish | Portable, discoverable, version-controlled |
| `use "data.dta"` | `load_survey(path = "data.dta")` | Reads STATA, CSV, RDS, etc. |

### Key differences

1.  **Recorded pipeline**: In STATA, commands execute and leave no
    trace. In metasurvey, compute/recode/join also execute immediately,
    but every step is recorded in the survey’s pipeline (provenance,
    [`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md),
    recipes). Filters are deferred until
    [`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
    because they affect the sampling design.

2.  **Immutability**: metasurvey creates new variables instead of
    modifying existing ones.
    [`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md)
    creates a new column; it does not overwrite the source variable.

3.  **Design awareness**: Survey weights and design are attached to the
    `Survey` object. There is no need to prefix commands with `svy:` or
    remember to set up the design
    —[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
    handles it automatically.

4.  **Recipes vs .do files**: Recipes are self-documenting (via
    `doc()`), self-validating (via `validate()`), and discoverable (via
    the registry). A `.do` file is just a script; a recipe is a
    structured, portable object.

## Data and acknowledgments

The sample data used in this vignette comes from the *Encuesta Continua
de Hogares* (ECH) 2023, published by Uruguay’s Instituto Nacional de
Estadistica (INE). The full microdata is available at
[INE](https://www.gub.uy/instituto-nacional-estadistica/).

The **[ech](https://calcita.github.io/ech/)** package by Gabriela
Mathieu and Richard Detomasi was an important inspiration for
metasurvey. While `ech` provides ready-to-use functions for computing
ECH indicators, metasurvey takes a different approach: it lets users
define, share, and reproduce their own processing pipelines as recipes.

## Next steps

- **[Creating and publishing
  recipes](https://metasurveyr.github.io/metasurvey/articles/recipes.md)**
  – Learn about recipe registries, certification, and discovery
- **[Estimation
  workflows](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.md)**
  – Deep dive into
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  and `RecipeWorkflow`
- **[Rotating panels and
  PoolSurvey](https://metasurveyr.github.io/metasurvey/articles/panel-analysis.md)**
  – Working with the ECH’s rotating panel structure
- **[Getting
  started](https://metasurveyr.github.io/metasurvey/articles/getting-started.md)**
  – Review the basics
