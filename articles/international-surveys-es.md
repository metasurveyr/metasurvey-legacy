# Compatibilidad con encuestas internacionales (ES)

## Introduccion

La clase `Survey` y el pipeline de steps (`step_compute`, `step_recode`,
`step_rename`, `step_remove`, `step_join`) de metasurvey son agnosticos
respecto a la encuesta: funcionan con cualquier dato tabular. Esta
vigneta demuestra la compatibilidad con 7 encuestas de hogares de 6
paises, utilizando datos reales incluidos en los paquetes cuando es
posible.

Para cada encuesta mostramos el flujo completo: cargar datos, crear un
`Survey`, aplicar steps, estimar con
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
y empaquetar el pipeline como `Recipe`.

### Matriz de compatibilidad

| Funcionalidad   | ECH | EPH | CASEN | PNADc | CPS | ENIGH | DHS |
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

### Instalacion de paquetes complementarios

La mayoria de los paquetes estan en CRAN. El paquete `casen` solo esta
disponible desde GitHub. Los paquetes faltantes se instalan
automaticamente al construir esta vigneta, pero tambien se pueden
instalar manualmente:

``` r

# Paquetes de CRAN
install.packages(c("eph", "PNADcIBGE", "ipumsr", "rdhs"))

# Paquetes solo en GitHub
# install.packages("remotes")
remotes::install_github("pachadotdev/casen")
```

## ECH – Uruguay

La ECH (Encuesta Continua de Hogares) es la encuesta principal para la
que se construyo metasurvey. Una muestra viene incluida en el paquete.

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
    comment = "Estado de actividad segun OIT"
  ) |>
  step_compute(
    income_pc = HT11 / nper,
    comment = "Ingreso per capita del hogar"
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

Para el pipeline completo de la ECH, ver
[`vignette("ech-case-study")`](https://metasurveyr.github.io/metasurvey/articles/ech-case-study.md).

## EPH – Argentina

La EPH (Encuesta Permanente de Hogares) es la encuesta trimestral de
fuerza laboral de Argentina. El paquete `eph`
([CRAN](https://cran.r-project.org/package=eph),
[GitHub](https://github.com/ropensci/eph)) incluye una base de juguete.

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
    comment = "Estado de actividad (INDEC)"
  ) |>
  step_recode(sex,
    CH04 == 1 ~ "Male",
    CH04 == 2 ~ "Female",
    .default = NA_character_,
    comment = "Sexo (CH04)"
  ) |>
  step_compute(
    employed = ifelse(ESTADO == 1, 1L, 0L),
    comment = "Indicador de empleo"
  ) |>
  bake_steps()

# Tasa de empleo
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

Para descargar microdatos reales de la EPH:
`eph::get_microdata(year = 2023, period = 3, type = "individual")`.

## CASEN – Chile

La CASEN (Encuesta de Caracterizacion Socioeconomica Nacional) es la
principal encuesta socioeconomica de Chile. Utiliza muestreo
estratificado por conglomerados. El paquete `casen`
([GitHub](https://github.com/pachadotdev/casen)) incluye una muestra de
la region de Los Rios.

Instalar con `remotes::install_github("pachadotdev/casen")`.

``` r

# Requiere: remotes::install_github("pachadotdev/casen")
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
    comment = "Sexo (codebook MDS)"
  ) |>
  step_recode(poverty_status,
    pobreza == 1 ~ "Extreme poverty",
    pobreza == 2 ~ "Non-extreme poverty",
    pobreza == 3 ~ "Not poor",
    .default = NA_character_,
    comment = "Situacion de pobreza"
  ) |>
  step_compute(
    log_income = log(ytotcorh + 1),
    comment = "Log del ingreso del hogar"
  ) |>
  bake_steps()

# Ingreso medio del hogar
workflow(
  list(svy_casen),
  survey::svymean(~ytotcorh, na.rm = TRUE),
  estimation_type = "annual"
)
```

Para los microdatos completos de la CASEN:
`descargar_casen_github(2017, tempdir())` del paquete casen.

## PNADc – Brasil

La PNADc (Pesquisa Nacional por Amostra de Domicilios Continua) es la
encuesta trimestral de fuerza laboral de Brasil, con muestreo
estratificado por conglomerados. El paquete `PNADcIBGE`
([CRAN](https://cran.r-project.org/package=PNADcIBGE)) incluye
microdatos de ejemplo.

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
    comment = "Sexo (V2007)"
  ) |>
  step_compute(
    age = as.integer(V2009),
    comment = "Edad en anios"
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

Para microdatos reales de la PNADc:
`PNADcIBGE::get_pnadc(year = 2023, quarter = 1)`. La descarga es de
aproximadamente 200 MB.

## CPS – Estados Unidos

La CPS (Current Population Survey) es la encuesta mensual de fuerza
laboral de Estados Unidos. El paquete `ipumsr`
([CRAN](https://cran.r-project.org/package=ipumsr),
[GitHub](https://github.com/ipums/ipumsr)) incluye un extracto de CPS.

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
    comment = "Estado de salud autopercibido"
  ) |>
  step_compute(
    log_income = log(INCTOT + 1),
    comment = "Log del ingreso total"
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

Los datos de IPUMS requieren una cuenta gratuita en
<https://cps.ipums.org>. El archivo DDI XML proporciona metadatos de
variables para el etiquetado.

## ENIGH – Mexico

La ENIGH (Encuesta Nacional de Ingresos y Gastos de los Hogares) es la
encuesta de ingresos y gastos de Mexico. No existe un paquete de R
dedicado; los datos estan disponibles en
[INEGI](https://www.inegi.org.mx/programas/enigh/). A continuacion se
presenta un ejemplo sintetico que replica la estructura real.

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
    comment = "Sexo del jefe de hogar"
  ) |>
  step_compute(
    income_pc = ing_cor / tam_hog,
    comment = "Ingreso per capita del hogar"
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

## DHS – Internacional

El programa DHS (Demographic and Health Surveys) cubre mas de 90 paises.
El paquete `rdhs` ([CRAN](https://cran.r-project.org/package=rdhs),
[GitHub](https://github.com/ropensci/rdhs)) proporciona acceso a la API.
Los datasets modelo (sin necesidad de autenticacion) estan disponibles
en <https://dhsprogram.com/data/model-datasets.cfm>.

``` r

library(haven)

# Descargar el modelo Individual Recode (sin credenciales)
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

# Los ponderadores DHS deben dividirse por 1.000.000
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
    comment = "Nivel educativo (v106)"
  ) |>
  step_compute(
    children = as.numeric(v201),
    comment = "Hijos nacidos vivos"
  ) |>
  bake_steps()

workflow(
  list(svy_dhs),
  survey::svymean(~children, na.rm = TRUE),
  estimation_type = "annual"
)
```

Los datos de DHS requieren registro en <https://dhsprogram.com>. El
paquete `rdhs` gestiona la autenticacion con la API. Los ponderadores
(v005) deben dividirse por 1.000.000 antes de usarlos.

## Portabilidad de recipes

La misma estructura `Recipe` funciona independientemente de la encuesta
de origen:

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
  description = "Indicadores demograficos reutilizables",
  steps       = get_steps(svy_demo),
  topic       = "demographics"
)

doc <- my_recipe$doc()
cat("Entradas:", paste(doc$input_variables, collapse = ", "), "\n")
#> Entradas: age
cat("Salidas:", paste(doc$output_variables, collapse = ", "), "\n")
#> Salidas: indicator, age_group
```

Los recipes capturan *que* transformaciones aplicar, no *de que*
encuesta provienen. Un recipe construido para la EPH puede adaptarse
para la PNADc simplemente renombrando variables.

## Proximos pasos

- [Primeros
  pasos](https://metasurveyr.github.io/metasurvey/articles/getting-started-es.md)
  – Objetos Survey y steps
- [Disenos de encuestas y
  validacion](https://metasurveyr.github.io/metasurvey/articles/complex-designs-es.md)
  – Disenos estratificados y por conglomerados, ponderadores de replicas
- [Paneles
  rotativos](https://metasurveyr.github.io/metasurvey/articles/panel-analysis-es.md)
  – `RotativePanelSurvey` y `PoolSurvey`
- [Recipes](https://metasurveyr.github.io/metasurvey/articles/recipes-es.md)
  – Crear, guardar y compartir recipes
- [Caso de estudio
  ECH](https://metasurveyr.github.io/metasurvey/articles/ech-case-study-es.md)
  – Pipeline completo de la ECH de Uruguay
