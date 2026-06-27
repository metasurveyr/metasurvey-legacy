# metasurvey

**metasurvey** is an R package for processing and analysing complex
survey data using metaprogramming and reproducible pipelines. It
integrates with the
[`survey`](https://cran.r-project.org/package=survey) package and is
designed for **complex sampling designs** and **recurring estimations**
over time (rotating panels, repeated cross-sections).

> If you find this useful, please consider giving us a ⭐ [star on
> GitHub](https://github.com/metasurveyr/metasurvey) — it helps others
> discover the project!

------------------------------------------------------------------------

## Live services

The full stack is deployed and publicly available:

| Service | URL | Description |
|----|----|----|
| **Recipe Explorer** | [metasurvey-shiny-production.up.railway.app](https://metasurvey-shiny-production.up.railway.app) | Interactive Shiny app to browse, search and inspect community recipes and workflows |
| **REST API** | [API reference](https://metasurveyr.github.io/metasurvey/articles/api-database.html) | Plumber API backed by MongoDB for publishing and discovering recipes ([self-hosting guide](https://metasurveyr.github.io/metasurvey/articles/self-hosting.html)) |
| **pkgdown site** | [metasurveyr.github.io/metasurvey](https://metasurveyr.github.io/metasurvey/) | Full package documentation and vignettes |

------------------------------------------------------------------------

## Key features

- **Steps**: lazy transformation pipeline (`step_compute`,
  `step_recode`, `step_rename`, `step_remove`, `step_join`) executed via
  [`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md).
- **Recipes**: portable, versioned objects that encapsulate
  harmonisation pipelines with automatic documentation (`doc()`) and
  validation (`validate()`).
- **Workflows**: estimation with
  [`survey::svymean`](https://rdrr.io/pkg/survey/man/surveysummary.html),
  `svytotal`, `svyratio` and `svyby` integrated in
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md),
  returning a `data.table` with value, standard error and coefficient of
  variation.
- **Rotating panels**: support for `RotativePanelSurvey` with
  implantation and follow-ups, and `PoolSurvey` for combined estimation.
- **Replicate weights**: bootstrap replicate configuration via
  [`add_replicate()`](https://metasurveyr.github.io/metasurvey/reference/add_replicate.md)
  for robust variance with
  [`survey::svrepdesign`](https://rdrr.io/pkg/survey/man/svrepdesign.html).
- **Recipe registry**: publish, search and discover recipes and
  workflows through a self-hosted REST API or a local JSON registry.
- **Shiny app**: [interactive recipe and workflow
  explorer](https://metasurvey-shiny-production.up.railway.app) with
  [`explore_recipes()`](https://metasurveyr.github.io/metasurvey/reference/explore_recipes.md).
- **Self-hosting**: deploy the full stack on your infrastructure with
  Docker Compose or Kubernetes. Publish indicators with full
  traceability (indicator → workflow → recipe) while keeping microdata
  private. See
  [`vignette("self-hosting")`](https://metasurveyr.github.io/metasurvey/articles/self-hosting.md).
- **STATA transpiler**: convert `.do` files into reproducible Recipe
  objects.

------------------------------------------------------------------------

## Works with any household survey

The step pipeline and workflow system are survey-agnostic. The same
verbs process Argentina’s EPH, Chile’s CASEN, Brazil’s PNAD-C, the US
CPS, Mexico’s ENIGH, or DHS data from 90+ countries.

|  | EPH | CASEN | PNAD-C | CPS | ENIGH | DHS |
|----|:--:|:--:|:--:|:--:|:--:|:--:|
| Steps (compute / recode / rename / remove / join) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Weights (`add_weight`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Stratified + cluster designs | ✅ | ✅ | ✅ | – | ✅ | ✅ |
| Replicate weights (`add_replicate`) | – | – | ✅ | ✅ | – | – |
| Rotating panels (`RotativePanelSurvey`) | ✅ | – | ✅ | ✅ | – | – |
| Recipes & workflows | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

``` r

# Same pipeline, different surveys ─────────────────────────

# Argentina (eph)
eph_svy <- Survey$new(
  data = as.data.table(eph::get_microdata(2023, 3)),
  edition = "2023-T3", type = "eph", psu = NULL,
  engine = "data.table", weight = add_weight(quarterly = "PONDERA")
)

# Chile (casen)
casen_svy <- Survey$new(
  data = as.data.table(casen::descargar_casen_github(2017)),
  edition = "2017", type = "casen", psu = "varunit",
  engine = "data.table", weight = add_weight(annual = "expr")
)

# Both use the exact same verbs
process <- function(svy) {
  svy |>
    step_recode(employed, labor_status == 1 ~ 1L, .default = 0L,
                comment = "Binary employment indicator") |>
    bake_steps()
}
```

See
[`vignette("international-surveys")`](https://metasurveyr.github.io/metasurvey/articles/international-surveys.md)
for reproducible examples with all seven surveys.

------------------------------------------------------------------------

## Installation

Install the stable version from CRAN:

``` r

install.packages("metasurvey")
```

Or the development version from GitHub:

``` r

# install.packages("devtools")
devtools::install_github("metasurveyR/metasurvey")
```

------------------------------------------------------------------------

## Quick example

``` r

library(metasurvey)

# Create a survey with sample data
data(api, package = "survey")

svy <- Survey$new(
  data    = apistrat,
  edition = "2000",
  type    = "api",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "pw")
)

# Lazy transformations
svy <- step_compute(svy, growth = api00 - api99, comment = "API growth")
svy <- step_recode(svy, school_level,
  stype == "E" ~ "Elementary",
  stype == "M" ~ "Middle",
  stype == "H" ~ "High",
  .default = NA_character_
)
svy <- bake_steps(svy)

# Estimation
workflow(
  list(svy),
  survey::svymean(~growth, na.rm = TRUE),
  estimation_type = "annual"
)
```

------------------------------------------------------------------------

## Full example: ECH panel with bootstrap replicate weights

This example uses the rotating panel from Uruguay’s [*Encuesta Continua
de Hogares*](https://www.gub.uy/instituto-nacional-estadistica/) (ECH)
with bootstrap replicate weights. First, download the example data:

``` r

download_example_ech <- function() {
  zip_url <- "https://informe-tfg.s3.us-east-2.amazonaws.com/example-data.zip"
  dest_zip <- "example-data.zip"
  temp_dir <- tempfile("example-data")
  download.file(zip_url, destfile = dest_zip, mode = "wb")
  dir.create(temp_dir)
  unzip(dest_zip, exdir = temp_dir)
  target_dir <- "example-data"
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  file.rename(
    list.files(file.path(temp_dir, "example-data"), full.names = TRUE),
    file.path(target_dir, basename(list.files(file.path(temp_dir, "example-data"))))
  )
  unlink(dest_zip)
  unlink(temp_dir, recursive = TRUE)
}
download_example_ech()
```

With the data downloaded:

``` r

library(metasurvey)
library(magrittr)

path_dir <- file.path("example-data", "ech", "ech_2023")

ech_2023 <- load_panel_survey(
  path_implantation = file.path(path_dir, "ECH_implantacion_2023.csv"),
  path_follow_up = file.path(path_dir, "seguimiento"),
  svy_type = "ECH_2023",
  svy_weight_implantation = add_weight(annual = "W_ANO"),
  svy_weight_follow_up = add_weight(
    monthly = add_replicate(
      "W",
      replicate_path = file.path(
        path_dir,
        c(
          "Pesos replicados Bootstrap mensuales enero_junio 2023",
          "Pesos replicados Bootstrap mensuales julio_diciembre 2023"
        ),
        c(
          "Pesos replicados mensuales enero_junio 2023",
          "Pesos replicados mensuales Julio_diciembre 2023"
        )
      ),
      replicate_id = c("ID" = "ID"),
      replicate_pattern = "wr[0-9]+",
      replicate_type = "bootstrap"
    )
  )
)

# Build labour market indicators
ech_2023 <- ech_2023 %>%
  step_recode("pea", POBPCOAC %in% 2:5 ~ 1, .default = 0,
              comment = "EAP", .level = "follow_up") %>%
  step_recode("pet", e27 >= 14 ~ 1, .default = 0,
              comment = "WAP", .level = "follow_up") %>%
  step_recode("po", POBPCOAC == 2 ~ 1, .default = 0,
              comment = "Employed", .level = "follow_up") %>%
  step_recode("pd", POBPCOAC %in% 3:5 ~ 1, .default = 0,
              comment = "Unemployed", .level = "follow_up")

ech_2023_bake <- bake_steps(ech_2023)

# Quarterly rates: activity, employment and unemployment
workflow_result <- workflow(
  survey = extract_surveys(ech_2023_bake, quarterly = 1:4),
  survey::svyratio(~pea, denominator = ~pet),
  survey::svyratio(~po, denominator = ~pet),
  survey::svyratio(~pd, denominator = ~pea),
  estimation_type = "quarterly:monthly",
  rho = 0.5,
  R = 5 / 6
)

workflow_result
```

This pipeline loads a rotating panel with bootstrap replicate weights,
builds binary labour market indicators (EAP, WAP, employed, unemployed),
and estimates activity, employment and unemployment rates by quarter
with robust variance.

------------------------------------------------------------------------

## STATA transpiler

Many research groups maintain decades of STATA `.do` files that process
household survey microdata. The metasurvey transpiler converts these
scripts into reproducible Recipe objects.

``` r

library(metasurvey)

# Transpile a .do file to metasurvey steps
result <- transpile_stata("demographics.do")
result$steps[1:3]
#> [1] "step_rename(svy, hh_id = \"id\", person_id = \"nper\")"
#> [2] "step_compute(svy, weight_yr = pesoano)"
#> [3] "step_compute(svy, sex = e26)"

# Transpile an entire year directory into separate recipes
recipes <- transpile_stata_module(
  year_dir = "do_files/2022",
  year = 2022,
  user = "research_team",
  output_dir = "recipes/"
)

# Check coverage before migrating
transpile_coverage("do_files/")
```

Supported STATA patterns: `gen`/`replace` chains, `recode`, `egen` with
by-groups, `foreach`/`forvalues` loops, `mvencode`, `destring`,
`rename`, `drop`/`keep`, variable and value labels, `inrange`/`inlist`
expressions, and variable ranges.

See
[`vignette("stata-transpiler")`](https://metasurveyr.github.io/metasurvey/articles/stata-transpiler.md)
for the full reference.

------------------------------------------------------------------------

## Documentation

- [Getting
  started](https://metasurveyr.github.io/metasurvey/articles/getting-started.html)
- [International survey
  compatibility](https://metasurveyr.github.io/metasurvey/articles/international-surveys.html)
- [Recipes](https://metasurveyr.github.io/metasurvey/articles/recipes.html)
- [Workflows and
  estimation](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.html)
- [Complex
  designs](https://metasurveyr.github.io/metasurvey/articles/complex-designs.html)
- [Rotating
  panels](https://metasurveyr.github.io/metasurvey/articles/panel-analysis.html)
- [Case study:
  ECH](https://metasurveyr.github.io/metasurvey/articles/ech-case-study.html)
- [STATA
  transpiler](https://metasurveyr.github.io/metasurvey/articles/stata-transpiler.html)
- [ECH demographics
  recipe](https://metasurveyr.github.io/metasurvey/articles/ech-demographics-recipe.html)
- [Interactive
  explorer](https://metasurveyr.github.io/metasurvey/articles/shiny-explorer.html)
- [API and
  database](https://metasurveyr.github.io/metasurvey/articles/api-database.html)
- [Self-hosting
  guide](https://metasurveyr.github.io/metasurvey/articles/self-hosting.html)

------------------------------------------------------------------------

## Related work

| Package | Focus | metasurvey adds |
|----|----|----|
| [survey](https://cran.r-project.org/package=survey) | Sampling designs and estimation | Lazy step pipeline, recipe system, rotating panels |
| [srvyr](https://cran.r-project.org/package=srvyr) | dplyr-style interface to survey | Portable recipes, workflow registry, panel support |
| [recipes](https://cran.r-project.org/package=recipes) | Feature engineering for modelling | Survey-aware steps, complex designs, community sharing |
| [eph](https://cran.r-project.org/package=eph) | Argentina’s EPH survey | Survey-agnostic: works with any household survey |
| [targets](https://cran.r-project.org/package=targets) | General pipeline orchestration | Domain-specific steps, built-in survey semantics |

metasurvey is **not** a wrapper around `survey`. It adds a
reproducibility layer (steps, recipes, workflows) that is
survey-agnostic: the same pipeline processes ECH, EPH, CASEN, PNAD-C,
CPS, ENIGH, or DHS data without survey-specific code.

------------------------------------------------------------------------

## Citation

To cite metasurvey in publications use:

``` r

citation("metasurvey")
```

> Loprete M, da Silva N, Machado F (2026). *metasurvey: Reproducible
> Survey Data Processing with Step Pipelines*. R package,
> <https://CRAN.R-project.org/package=metasurvey>.

------------------------------------------------------------------------

## Contributing

Please see
[CONTRIBUTING.md](https://github.com/metasurveyr/metasurvey/blob/main/CONTRIBUTING.md)
for guidelines on how to contribute to metasurvey.

## Code of Conduct

Please note that the metasurvey project is released with a [Contributor
Code of
Conduct](https://github.com/metasurveyr/metasurvey/blob/main/CODE_OF_CONDUCT.md).
By contributing to this project you agree to abide by its terms.
