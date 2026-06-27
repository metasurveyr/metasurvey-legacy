# Diseños de encuestas y validación (ES)

## Introducción

Los diseños muestrales complejos requieren un tratamiento especial para
la estimación correcta de la varianza. metasurvey gestiona el diseño
muestral de forma automática a través del objeto `Survey`, de modo que
el usuario pueda concentrarse en el análisis y no en los detalles
técnicos.

Esta viñeta cubre los siguientes temas:

1.  Creación de encuestas con distintos tipos de diseño
2.  Configuración de ponderadores y motores de datos
3.  Validación del pipeline de procesamiento
4.  Verificación cruzada de resultados con el paquete `survey`

## Configuración inicial

Utilizamos el conjunto de datos Academic Performance Index (API) del
paquete `survey`. Este incluye versiones estratificadas, por
conglomerados y de muestreo aleatorio simple.

``` r

library(metasurvey)
library(survey)
library(data.table)

data(api, package = "survey")
dt_strat <- data.table(apistrat)
```

## Tipos de diseño muestral

### Diseño ponderado simple

El diseño más sencillo utiliza ponderadores de probabilidad sin
conglomerados ni estratificación:

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

### Diseno estratificado por conglomerados

Muchas encuestas nacionales utilizan muestreo estratificado
multietapico. Se pasan `strata` y `psu` a `Survey$new()`:

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

Validacion cruzada con el paquete `survey`:

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

Para ejemplos reales de disenos estratificados por conglomerados con
datos de CASEN, PNADc, ENIGH y DHS, ver
[`vignette("international-surveys")`](https://metasurveyr.github.io/metasurvey/articles/international-surveys.md).

### Inspeccion del diseno

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

### Múltiples tipos de ponderadores

Muchas encuestas proporcionan diferentes ponderadores según el período
de análisis (por ejemplo, anual vs. mensual). metasurvey asocia
etiquetas de periodicidad a columnas de ponderadores:

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

### Ponderadores de réplicas bootstrap

Para encuestas que proporcionan réplicas bootstrap (como la ECH de
Uruguay), se utiliza
[`add_replicate()`](https://metasurveyr.github.io/metasurvey/reference/add_replicate.md)
dentro de
[`add_weight()`](https://metasurveyr.github.io/metasurvey/reference/add_weight.md):

``` r

# This example requires external files
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

Cuando se configuran ponderadores de réplicas,
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
los utiliza automáticamente para la estimación de varianza mediante
[`survey::svrepdesign()`](https://rdrr.io/pkg/survey/man/svrepdesign.html).

## Configuración del motor y el procesamiento

### Motor de datos

metasurvey utiliza `data.table` por defecto para una manipulación rápida
de los datos:

``` r

# Current engine
get_engine()
#> [1] "data.table"

# Available engines
show_engines()
#> [1] "data.table" "tidyverse"  "dplyr"
```

### Procesamiento diferido (lazy)

Por defecto, los steps se registran pero no se ejecutan hasta que se
invoca
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md).
Esto permite realizar validaciones antes de la ejecución:

``` r

# Check current setting
lazy_default()
#> [1] TRUE

# Change for the session (not recommended for most workflows)
# set_lazy_processing(FALSE)
```

### Comportamiento de copia

Se puede controlar si las operaciones de steps modifican los datos
in-place o trabajan sobre copias:

``` r

# Current setting
use_copy_default()
#> [1] TRUE

# In-place is faster but modifies the original
# set_use_copy(FALSE)
```

## Estimación de varianza

### Varianza basada en el diseño

Estimación estándar de varianza utilizando el diseño muestral:

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

### Estimación por dominios

Se pueden calcular estimaciones para subpoblaciones utilizando
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

### Razones

``` r

ratio_result <- workflow(
  list(svy_simple),
  survey::svyratio(~api00, ~api99),
  estimation_type = "annual"
)

ratio_result
#>                             stat    variable    value         se          cv
#>                           <char>      <char>    <num>      <num>       <num>
#> 1: survey::svyratio: api00/api99 api00/api99 1.052261 0.00379243 0.003604079
#>    confint_lower confint_upper  evaluate
#>            <num>         <num>    <char>
#> 1:      1.044828      1.059694 Excellent
```

## Validación del pipeline

### Verificación paso a paso

Al construir pipelines complejos, conviene verificar cada paso de forma
independiente:

``` r

# Step 1: Compute new variable
svy_v <- step_compute(svy_simple,
  api_diff = api00 - api99,
  comment = "API score difference"
)

# Check that the step was recorded
steps <- get_steps(svy_v)
cat("Pending steps:", length(steps), "\n")
#> Pending steps: 1
```

### Validación cruzada con el paquete survey

Se pueden comparar los resultados de
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
de metasurvey con llamadas directas al paquete `survey`:

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

### Visualización del pipeline

Se puede utilizar
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)
para visualizar el grafo de dependencias entre steps:

``` r

# Requires the visNetwork package
svy_viz <- step_compute(svy_simple,
  api_diff = api00 - api99,
  high_growth = ifelse(api00 - api99 > 50, 1L, 0L)
)
view_graph(svy_viz, init_step = "Load API data")
```

### Evaluación de calidad

Se puede evaluar la calidad de las estimaciones utilizando el
coeficiente de variación:

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

### Validación de recipes

Se puede verificar que los recipes y sus steps sean consistentes:

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

## Lista de verificación para validación

Antes de poner en producción un pipeline de procesamiento de encuestas,
se recomienda verificar lo siguiente:

1.  **Integridad de los datos** – cantidad de filas, nombres de columnas
    y tipos de datos después de cada step
2.  **Validación de ponderadores** – las columnas de ponderadores
    existen y son positivas
3.  **Verificación del diseño** – el diseño muestral coincide con la
    especificación esperada (PSU, estratos, ponderadores)
4.  **Reproducibilidad del recipe** – guardar y recargar recipes,
    verificar el round-trip en JSON
5.  **Validación cruzada** – comparar estimaciones clave con valores
    publicados o llamadas directas al paquete `survey`
6.  **Umbrales de CV** – señalar estimaciones con coeficientes de
    variación elevados

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

## Buenas prácticas

1.  **Utilizar siempre los ponderadores adecuados** – nunca calcular
    estadísticos sin ponderar a partir de datos de encuestas
2.  **Usar ponderadores de réplicas cuando estén disponibles** –
    proporcionan estimaciones de varianza más robustas
3.  **Verificar los tamaños de muestra por dominio** – combinar dominios
    pequeños cuando los CV sean demasiado altos
4.  **Documentar el diseño** – incluir la especificación del diseño, la
    construcción de los ponderadores y el método de varianza
5.  **Validar cruzadamente las estimaciones clave** – comparar con
    valores publicados o métodos alternativos

## Próximos pasos

- **[Flujos de
  estimación](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.md)**
  –
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md),
  `RecipeWorkflow` y estimaciones publicables
- **[Paneles rotativos y
  PoolSurvey](https://metasurveyr.github.io/metasurvey/articles/panel-analysis.md)**
  – Análisis longitudinal con `RotativePanelSurvey` y `PoolSurvey`
- **[Primeros
  pasos](https://metasurveyr.github.io/metasurvey/articles/getting-started.md)**
  – Revisar los conceptos básicos de steps y objetos Survey
