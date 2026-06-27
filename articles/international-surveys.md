# International Survey Compatibility

## Introduction

metasurvey’s `Survey` class and step pipeline (`step_compute`,
`step_recode`, `step_rename`, `step_remove`, `step_join`) are
survey-agnostic: they work with any tabular data. This vignette
demonstrates compatibility with 7 household surveys from 6 countries,
using real bundled data where possible.

For each survey we show the full flow: load data, create a `Survey`,
apply steps, estimate with
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md),
and package the pipeline as a `Recipe`.

### Compatibility matrix

| Feature         | ECH | EPH | CASEN | PNADc | CPS | ENIGH | DHS |
|-----------------|:---:|:---:|:-----:|:-----:|:---:|:-----:|:---:|
| `step_compute`  |  ✓  |  ✓  |   ✓   |   ✓   |  ✓  |   ✓   |  ✓  |
| `step_recode`   |  ✓  |  ✓  |   ✓   |   ✓   |  ✓  |   ✓   |  ✓  |
| `step_rename`   |  ✓  |  ✓  |   ✓   |   ✓   |  ✓  |   ✓   |  ✓  |
| `step_remove`   |  ✓  |  ✓  |   ✓   |   ✓   |  ✓  |   ✓   |  ✓  |
| `add_weight`    |  ✓  |  ✓  |   ✓   |   ✓   |  ✓  |   ✓   |  ✓  |
| `strata`        | N/A | N/A |   ✓   |   ✓   | N/A |   ✓   |  ✓  |
| `psu`           | N/A | N/A |   ✓   |   ✓   | N/A |   ✓   |  ✓  |
| `add_replicate` |  ✓  | N/A |  N/A  |   ✓   |  ✓  |  N/A  | N/A |
| `workflow`      |  ✓  |  ✓  |   ✓   |   ✓   |  ✓  |   ✓   |  ✓  |
| `Recipe`        |  ✓  |  ✓  |   ✓   |   ✓   |  ✓  |   ✓   |  ✓  |

### Installing companion packages

Most packages are on CRAN. The `casen` package is only available from
GitHub. Sections for unavailable packages are skipped automatically.
Install them manually to see all examples:

``` r

# CRAN packages
install.packages(c("eph", "PNADcIBGE", "ipumsr", "rdhs"))

# GitHub-only packages
# install.packages("remotes")
remotes::install_github("pachadotdev/casen")
```

## ECH – Uruguay

The ECH (Encuesta Continua de Hogares) is the primary survey metasurvey
was built for. A bundled sample is included in the package.

``` r

library(metasurvey)
library(data.table)

dt_ech <- fread(
  system.file("extdata", "ech_2023_sample.csv", package = "metasurvey")
)

svy_ech <- Survey$new(
  data    = dt_ech,
  edition = "2023",
  type    = "ech",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "W_ANO")
)

svy_ech <- svy_ech |>
  step_recode(labor_status,
    POBPCOAC == 2 ~ "Employed",
    POBPCOAC %in% 3:5 ~ "Unemployed",
    POBPCOAC %in% c(6:10, 1) ~ "Inactive or under 14",
    comment = "ILO labor force status"
  ) |>
  step_compute(
    income_pc = HT11 / nper,
    comment = "Per capita household income"
  ) |>
  bake_steps()

workflow(
  list(svy_ech),
  survey::svymean(~HT11, na.rm = TRUE),
  estimation_type = "annual"
)
#>                     stat variable    value       se         cv confint_lower
#>                   <char>   <char>    <num>    <num>      <num>         <num>
#> 1: survey::svymean: HT11     HT11 107869.1 3473.836 0.03220417      101060.5
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:      114677.7 Excellent
```

For the complete ECH pipeline, see
[`vignette("ech-case-study")`](https://metasurveyr.github.io/metasurvey/articles/ech-case-study.md).

## EPH – Argentina

The EPH (Encuesta Permanente de Hogares) is Argentina’s quarterly labor
force survey. The `eph` package
([CRAN](https://cran.r-project.org/package=eph),
[GitHub](https://github.com/ropensci/eph)) includes a bundled toybase.

``` r

library(eph)

data("toybase_individual_2016_04", package = "eph")
dt_eph <- data.table(toybase_individual_2016_04)

svy_eph <- Survey$new(
  data    = dt_eph,
  edition = "201604",
  type    = "eph",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(quarterly = "PONDERA")
)

svy_eph <- svy_eph |>
  step_recode(labor_status,
    ESTADO == 1 ~ "Employed",
    ESTADO == 2 ~ "Unemployed",
    ESTADO == 3 ~ "Inactive",
    .default = NA_character_,
    comment = "Labor force status (INDEC)"
  ) |>
  step_recode(sex,
    CH04 == 1 ~ "Male",
    CH04 == 2 ~ "Female",
    .default = NA_character_,
    comment = "Sex from CH04"
  ) |>
  step_compute(
    employed = ifelse(ESTADO == 1, 1L, 0L),
    comment = "Employment indicator"
  ) |>
  bake_steps()

# Employment rate
workflow(
  list(svy_eph),
  survey::svymean(~employed, na.rm = TRUE),
  estimation_type = "quarterly"
)
#>                         stat variable     value         se         cv
#>                       <char>   <char>     <num>      <num>      <num>
#> 1: survey::svymean: employed employed 0.4378169 0.01668347 0.03810603
#>    confint_lower confint_upper  evaluate
#>            <num>         <num>    <char>
#> 1:     0.4051179     0.4705159 Excellent
```

To download actual EPH microdata use
`eph::get_microdata(year = 2023, period = 3, type = "individual")`.

## CASEN – Chile

The CASEN (Encuesta de Caracterizacion Socioeconomica Nacional) is
Chile’s main socioeconomic survey. It uses stratified cluster sampling.
The `casen` package ([GitHub](https://github.com/pachadotdev/casen))
includes a bundled sample from the Los Rios region.

Install with `remotes::install_github("pachadotdev/casen")`.

``` r

# Requires: remotes::install_github("pachadotdev/casen")
data("casen_2017_los_rios")
dt_casen <- data.table(casen_2017_los_rios)

svy_casen <- Survey$new(
  data    = dt_casen,
  edition = "2017",
  type    = "casen",
  psu     = "varunit",
  strata  = "varstrat",
  engine  = "data.table",
  weight  = add_weight(annual = "expc")
)

svy_casen <- svy_casen |>
  step_recode(sex,
    sexo == 1 ~ "Male",
    sexo == 2 ~ "Female",
    .default = NA_character_,
    comment = "Sex (MDS codebook)"
  ) |>
  step_recode(poverty_status,
    pobreza == 1 ~ "Extreme poverty",
    pobreza == 2 ~ "Non-extreme poverty",
    pobreza == 3 ~ "Not poor",
    .default = NA_character_,
    comment = "Poverty status"
  ) |>
  step_compute(
    log_income = log(ytotcorh + 1),
    comment = "Log household income"
  ) |>
  bake_steps()

# Mean household income
workflow(
  list(svy_casen),
  survey::svymean(~ytotcorh, na.rm = TRUE),
  estimation_type = "annual"
)
```

For the full CASEN microdata, use
`descargar_casen_github(2017, tempdir())` from the casen package.

## PNADc – Brazil

The PNADc (Pesquisa Nacional por Amostra de Domicilios Continua) is
Brazil’s quarterly labor force survey with stratified cluster sampling.
The `PNADcIBGE` package
([CRAN](https://cran.r-project.org/package=PNADcIBGE)) includes bundled
example microdata.

``` r

library(PNADcIBGE)

dt_pnadc <- data.table(read_pnadc(
  microdata = system.file("extdata", "exampledata.txt", package = "PNADcIBGE"),
  input_txt = system.file("extdata", "input_example.txt", package = "PNADcIBGE")
))

svy_pnadc <- Survey$new(
  data    = dt_pnadc,
  edition = "202301",
  type    = "pnadc",
  psu     = "UPA",
  strata  = "Estrato",
  engine  = "data.table",
  weight  = add_weight(quarterly = "V1028")
)

svy_pnadc <- svy_pnadc |>
  step_recode(sex,
    V2007 == 1 ~ "Male",
    V2007 == 2 ~ "Female",
    .default = NA_character_,
    comment = "Sex (V2007)"
  ) |>
  step_compute(
    age = as.integer(V2009),
    comment = "Age in years"
  ) |>
  bake_steps()

workflow(
  list(svy_pnadc),
  survey::svymean(~age, na.rm = TRUE),
  estimation_type = "quarterly"
)
#>                    stat variable    value       se         cv confint_lower
#>                  <char>   <char>    <num>    <num>      <num>         <num>
#> 1: survey::svymean: age      age 35.55343 0.856023 0.02407708      33.87566
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:      37.23121 Excellent
```

For real PNADc microdata:
`PNADcIBGE::get_pnadc(year = 2023, quarter = 1)`. The download is
approximately 200 MB.

## CPS – United States

The CPS (Current Population Survey) is the US monthly labor force
survey. The `ipumsr` package
([CRAN](https://cran.r-project.org/package=ipumsr),
[GitHub](https://github.com/ipums/ipumsr)) includes a bundled CPS
extract.

``` r

library(ipumsr)

ddi <- read_ipums_ddi(
  system.file("extdata", "cps_00160.xml", package = "ipumsr")
)
dt_cps <- data.table(read_ipums_micro(ddi, verbose = FALSE))

svy_cps <- Survey$new(
  data    = dt_cps,
  edition = "2011",
  type    = "cps",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "ASECWT")
)

svy_cps <- svy_cps |>
  step_recode(health_status,
    HEALTH == 1 ~ "Excellent",
    HEALTH == 2 ~ "Very good",
    HEALTH == 3 ~ "Good",
    HEALTH == 4 ~ "Fair",
    HEALTH == 5 ~ "Poor",
    .default = NA_character_,
    comment = "Self-reported health status"
  ) |>
  step_compute(
    log_income = log(INCTOT + 1),
    comment = "Log total income"
  ) |>
  bake_steps()

workflow(
  list(svy_cps),
  survey::svymean(~INCTOT, na.rm = TRUE),
  estimation_type = "annual"
)
#>                       stat variable     value      se         cv confint_lower
#>                     <char>   <char>     <num>   <num>      <num>         <num>
#> 1: survey::svymean: INCTOT   INCTOT 191645236 4277528 0.02232004     183261435
#>    confint_upper  evaluate
#>            <num>    <char>
#> 1:     200029038 Excellent
```

IPUMS data requires a free account at <https://cps.ipums.org>. The DDI
XML file provides variable metadata for labeling.

## ENIGH – Mexico

The ENIGH (Encuesta Nacional de Ingresos y Gastos de los Hogares) is
Mexico’s income and expenditure survey. There is no dedicated R package;
data is available from
[INEGI](https://www.inegi.org.mx/programas/enigh/). Below is a synthetic
example that mirrors the real structure.

``` r

set.seed(42)
dt_enigh <- data.table(
  id = 1:200,
  upm = rep(1:40, each = 5),
  est_dis = rep(1:10, each = 20),
  factor = runif(200, 100, 500),
  sexo_jefe = sample(1:2, 200, replace = TRUE),
  edad_jefe = sample(18:80, 200, replace = TRUE),
  ing_cor = rlnorm(200, 10, 1),
  tam_hog = sample(1:8, 200, replace = TRUE)
)

svy_enigh <- Survey$new(
  data    = dt_enigh,
  edition = "2022",
  type    = "enigh",
  psu     = "upm",
  strata  = "est_dis",
  engine  = "data.table",
  weight  = add_weight(annual = "factor")
)

svy_enigh <- svy_enigh |>
  step_recode(sex_head,
    sexo_jefe == 1 ~ "Male",
    sexo_jefe == 2 ~ "Female",
    .default = NA_character_,
    comment = "Sex of household head"
  ) |>
  step_compute(
    income_pc = ing_cor / tam_hog,
    comment = "Per capita household income"
  ) |>
  bake_steps()

workflow(
  list(svy_enigh),
  survey::svymean(~income_pc, na.rm = TRUE),
  estimation_type = "annual"
)
#>                          stat  variable    value       se        cv
#>                        <char>    <char>    <num>    <num>     <num>
#> 1: survey::svymean: income_pc income_pc 11928.34 1473.022 0.1234893
#>    confint_lower confint_upper evaluate
#>            <num>         <num>   <char>
#> 1:      9041.267      14815.41     Good
```

## DHS – International

The DHS (Demographic and Health Surveys) program covers 90+ countries.
The `rdhs` package ([CRAN](https://cran.r-project.org/package=rdhs),
[GitHub](https://github.com/ropensci/rdhs)) provides API access. Model
datasets (no authentication needed) are available at
<https://dhsprogram.com/data/model-datasets.cfm>.

``` r

library(haven)

# Download the model Individual Recode (no credentials needed)
tf <- tempfile(fileext = ".zip")
download.file(
  "https://dhsprogram.com/data/model_data/dhs/zzir62dt.zip",
  tf,
  mode = "wb", quiet = TRUE
)
td <- tempdir()
unzip(tf, exdir = td)
dta_file <- list.files(td,
  pattern = "\\.DTA$", full.names = TRUE,
  ignore.case = TRUE
)
dt_dhs <- data.table(read_dta(dta_file[1]))

# DHS weights must be divided by 1,000,000
dt_dhs[, wt := as.numeric(v005) / 1e6]

svy_dhs <- Survey$new(
  data    = dt_dhs,
  edition = "2020",
  type    = "dhs",
  psu     = "v001",
  strata  = "v023",
  engine  = "data.table",
  weight  = add_weight(annual = "wt")
)

svy_dhs <- svy_dhs |>
  step_recode(education,
    v106 == 0 ~ "No education",
    v106 == 1 ~ "Primary",
    v106 == 2 ~ "Secondary",
    v106 == 3 ~ "Higher",
    .default = NA_character_,
    comment = "Education level (v106)"
  ) |>
  step_compute(
    children = as.numeric(v201),
    comment = "Children ever born"
  ) |>
  bake_steps()

workflow(
  list(svy_dhs),
  survey::svymean(~children, na.rm = TRUE),
  estimation_type = "annual"
)
```

DHS data requires registration at <https://dhsprogram.com>. The `rdhs`
package handles API authentication. Weights (v005) must be divided by
1,000,000 before use.

## Recipe portability

The same `Recipe` structure works regardless of the source survey:

``` r

set.seed(42)
dt_demo <- data.table(
  id     = 1:100,
  age    = sample(18:65, 100, replace = TRUE),
  income = round(runif(100, 1000, 5000), 2),
  w      = round(runif(100, 0.5, 2), 4)
)

svy_demo <- Survey$new(
  data    = dt_demo,
  edition = "2023",
  type    = "demo",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "w")
)

svy_demo <- svy_demo |>
  step_compute(indicator = ifelse(age > 30, 1L, 0L)) |>
  step_recode(age_group,
    age < 30 ~ "Young",
    age >= 30 ~ "Adult",
    .default = NA_character_
  )

my_recipe <- steps_to_recipe(
  name        = "Demo Indicators",
  user        = "Research Team",
  svy         = svy_demo,
  description = "Reusable demographic indicators",
  steps       = get_steps(svy_demo),
  topic       = "demographics"
)

doc <- my_recipe$doc()
cat("Inputs:", paste(doc$input_variables, collapse = ", "), "\n")
#> Inputs: age
cat("Outputs:", paste(doc$output_variables, collapse = ", "), "\n")
#> Outputs: indicator, age_group
```

Recipes capture *what* transformations to apply, not *which* survey they
came from. A recipe built for EPH can be adapted for PNADc by simply
renaming variables.

## Next steps

- [Getting
  Started](https://metasurveyr.github.io/metasurvey/articles/getting-started.md)
  – Survey objects and steps
- [Survey Designs and
  Validation](https://metasurveyr.github.io/metasurvey/articles/complex-designs.md)
  – Stratified and clustered designs, replicate weights
- [Rotating
  Panels](https://metasurveyr.github.io/metasurvey/articles/panel-analysis.md)
  – `RotativePanelSurvey` and `PoolSurvey`
- [Recipes](https://metasurveyr.github.io/metasurvey/articles/recipes.md)
  – Creating, saving, and sharing recipes
- [ECH Case
  Study](https://metasurveyr.github.io/metasurvey/articles/ech-case-study.md)
  – Full Uruguay ECH pipeline
