# Flujos de Trabajo y Estimacion (ES)

## Que es un Workflow?

Luego de transformar los datos de la encuesta con steps y recipes, la
siguiente tarea es la **estimacion**: calcular medias, totales, razones
y sus errores estandar teniendo en cuenta el diseno complejo de la
encuesta.

La funcion
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
envuelve los estimadores del paquete `survey` (`svymean`, `svytotal`,
`svyratio`, `svyby`) y devuelve resultados ordenados en formato
`data.table` que incluyen:

- Estimaciones puntuales y errores estandar
- Coeficientes de variacion (CV)
- Intervalos de confianza
- Metadatos para la reproducibilidad

## Configuracion inicial

Utilizamos el conjunto de datos Academic Performance Index (API) del
paquete `survey`, que contiene datos reales de escuelas estratificadas
de California.

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

## Estimacion basica

### Media

Estimamos la media poblacional del puntaje API en el ano 2000:

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

Estimamos la matriculacion total en todas las escuelas:

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

### Multiples estimaciones a la vez

Es posible pasar varias llamadas de estimacion a
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
para calcularlas en un unico paso:

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

## Estimacion por dominio

Utilizamos
[`survey::svyby()`](https://rdrr.io/pkg/survey/man/svyby.html) para
calcular estimaciones por subpoblaciones (dominios):

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

## Evaluacion de la calidad

El **coeficiente de variacion (CV)** mide la precision de la estimacion.
Se puede utilizar
[`evaluate_cv()`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md)
para clasificar la calidad siguiendo las directrices estandar:

| Rango de CV | Calidad      | Recomendacion                          |
|-------------|--------------|----------------------------------------|
| \< 5%       | Excelente    | Usar sin restricciones                 |
| 5-10%       | Muy buena    | Usar con confianza                     |
| 10-15%      | Buena        | Usar para la mayoria de los propositos |
| 15-25%      | Aceptable    | Usar con precaucion                    |
| 25-35%      | Deficiente   | Solo para tendencias generales         |
| \>= 35%     | No confiable | No publicar                            |

``` r

# Evaluate quality of the API score estimate
cv_pct <- results$cv[1] * 100
quality <- evaluate_cv(cv_pct)

cat("CV:", round(cv_pct, 2), "%\n")
#> CV: 1.45 %
cat("Quality:", quality, "\n")
#> Quality: Excellent
```

## RecipeWorkflow: Estimaciones publicables

Un `RecipeWorkflow` agrupa llamadas de estimacion con metadatos, lo que
hace que el analisis sea reproducible y compartible. Registra:

- Que recipes se utilizaron para la preparacion de los datos
- Que llamadas de estimacion se realizaron
- Informacion de autoria y versionado

### Creacion de un RecipeWorkflow

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

### Publicacion en el registro

Publicamos el workflow para que otros puedan descubrirlo y reutilizarlo:

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

### Busqueda de workflows asociados a un recipe

Si se dispone de un recipe y se desea conocer que estimaciones han sido
publicadas para el mismo, se puede utilizar
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

## Compartir mediante la API remota

Para una difusion mas amplia, es posible publicar workflows en la API de
metasurvey:

``` r

# Requires authentication
api_login("you@example.com", "password")

# Publish
api_publish_workflow(wf)

# Browse
all <- api_list_workflows(survey_type = "ech")
specific <- api_get_workflow("workflow_id_here")
```

## Pipeline completo

A continuacion se presenta un pipeline completo desde los datos crudos
hasta la estimacion publicable, utilizando el conjunto de datos API:

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

## Provenance: Linaje de datos

Cada objeto `Survey` registra metadatos de **provenance**: de donde
vinieron los datos, que steps se aplicaron, cuantas filas sobrevivieron
a cada paso y que versiones de R y metasurvey se utilizaron. Esto
permite rastrear cualquier estimacion hasta los datos originales.

``` r

# El provenance se completa automaticamente despues de bake_steps()
prov <- provenance(svy_full)
prov
#> ── Data Provenance ─────────────────────────────────────────────────────────────
#> Loaded: 2026-07-07T21:19:59 
#> Initial rows: 200 
#> 
#> Environment:
#>   metasurvey: 0.2.0 
#>   R: 4.6.1 
#>   survey: 4.5
```

El provenance tambien se adjunta a los resultados de
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md),
de modo que siempre es posible inspeccionar el linaje completo de una
estimacion:

``` r

prov_wf <- provenance(estimates)
cat("metasurvey version:", prov_wf$environment$metasurvey_version, "\n")
#> metasurvey version: 0.2.0
cat("Steps applied:", length(prov_wf$steps), "\n")
#> Steps applied: 0
```

Para pistas de auditoria, se exporta el provenance a JSON:

``` r

provenance_to_json(prov, "audit_trail.json")
```

Para comparar dos ejecuciones (por ejemplo, diferentes ediciones), se
utiliza
[`provenance_diff()`](https://metasurveyr.github.io/metasurvey/reference/provenance_diff.md):

``` r

diff <- provenance_diff(prov_2022, prov_2023)
diff$steps_changed
diff$n_final_changed
```

## Tablas de calidad publicacion

[`workflow_table()`](https://metasurveyr.github.io/metasurvey/reference/workflow_table.md)
formatea los resultados de estimacion como tablas listas para publicar
usando el paquete `gt`. Agrega intervalos de confianza, clasificacion de
calidad del CV con colores y notas al pie basadas en el provenance.

``` r

workflow_table(estimates)
```

| Survey Estimation Results |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|
| Statistic | variable | Estimate | SE | CI Lower | CI Upper | CV (%) | Quality |
| :svymean: api_growth | api_growth | 32.89 | 2.158 | 28.66 | 37.12 | 6.6 | Very good |
| :svymean: high_growth | high_growth | 0.29 | 0.036 | 0.22 | 0.37 | 12.4 | Good |
| metasurvey 0.2.0 \| CI: 95% \| 2026-07-07 |  |  |  |  |  |  |  |

Se puede personalizar la salida:

``` r

# Locale en espaniol, ocultar SE, titulo personalizado
workflow_table(
  estimates,
  locale = "es",
  show_se = FALSE,
  title = "Indicadores de crecimiento API",
  subtitle = "Escuelas de California, 2000"
)
```

| Indicadores de crecimiento API |  |  |  |  |  |  |
|----|----|----|----|----|----|----|
| Escuelas de California, 2000 |  |  |  |  |  |  |
| Statistic | variable | Estimate | CI Lower | CI Upper | CV (%) | Quality |
| :svymean: api_growth | api_growth | 32,89 | 28,66 | 37,12 | 6,6 | Very good |
| :svymean: high_growth | high_growth | 0,29 | 0,22 | 0,37 | 12,4 | Good |
| metasurvey 0.2.0 \| CI: 95% \| 2026-07-07 |  |  |  |  |  |  |

Para estimaciones por dominio, la tabla detecta automaticamente las
columnas de grupo:

``` r

workflow_table(by_school)
```

| Survey Estimation Results |  |  |  |  |  |  |  |  |
|----|----|----|----|----|----|----|----|----|
| Statistic | variable | stype | Estimate | SE | CI Lower | CI Upper | CV (%) | Quality |
| :svyby: api00 | api00 | E | 674.43 | 12.493 | 649.94 | 698.92 | 1.9 | Excellent |
| :svyby: api00 | api00 | H | 625.82 | 15.341 | 595.75 | 655.89 | 2.5 | Excellent |
| :svyby: api00 | api00 | M | 636.60 | 16.502 | 604.26 | 668.94 | 2.6 | Excellent |
| metasurvey 0.2.0 \| CI: 95% \| 2026-07-07 |  |  |  |  |  |  |  |  |

Se exporta a cualquier formato soportado por
[`gt::gtsave()`](https://gt.rstudio.com/reference/gtsave.html):

``` r

tbl <- workflow_table(estimates)
gt::gtsave(tbl, "estimates.html")
gt::gtsave(tbl, "estimates.docx")
gt::gtsave(tbl, "estimates.png")
```

## Proximos pasos

- **[Creacion y publicacion de
  Recipes](https://metasurveyr.github.io/metasurvey/articles/recipes.md)**
  – Construir pipelines de transformacion reproducibles
- **[Disenos de encuesta y
  validacion](https://metasurveyr.github.io/metasurvey/articles/complex-designs.md)**
  – Estratificacion, conglomerados, pesos replicados
- **[Estudio de caso:
  ECH](https://metasurveyr.github.io/metasurvey/articles/ech-case-study.md)**
  – Analisis completo del mercado laboral con estimacion
