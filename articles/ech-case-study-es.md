# Estudio de caso ECH: De STATA a R (ES)

## El problema de la compatibilización de la ECH

La *Encuesta Continua de Hogares* (ECH) de Uruguay es publicada
anualmente por el Instituto Nacional de Estadística (INE). A lo largo de
los años, el INE ha modificado nombres de variables, definiciones del
libro de códigos y la estructura de módulos entre ediciones. Quienes
investigan con datos de la ECH deben *compatibilizar* variables —es
decir, mapear las distintas convenciones de nombres a un esquema común—
antes de que cualquier análisis inter-anual sea posible.

La compatibilización de la ECH ha sido un trabajo histórico del
Instituto de Economía (IECON) de la Universidad de la República. El
dataset resultante está disponible en [FCEA - ECH
Compatibilizadas](https://fcea.udelar.edu.uy/portada-ech-compatibilizadas.html)
(Instituto de Economía, 2020). metasurvey busca complementar y facilitar
este tipo de trabajo ofreciendo herramientas reproducibles en R.

En la academia uruguaya, este trabajo se ha realizado en STATA durante
más de 30 años. Un pipeline de compatibilización típico consiste en
aproximadamente **8 archivos .do por año**, cubriendo:

1.  `2_correc_datos.do` – Carga de datos crudos, unión de archivos de
    personas y hogares, corrección de nombres de variables
2.  `3_compatibilizacion_mod_1_4.do` – Armonización de módulos
    demográficos, de salud, educación y trabajo
3.  `4_ingreso_ht11.do` – Construcción del ingreso del hogar (`ht11`)
4.  `5_descomp_fuentes.do` – Descomposición del ingreso por fuente
5.  `6_ingreso_ht11_sss.do` – Ajustes de seguridad social
6.  `7_check_ingr.do` – Validación de variables de ingreso
7.  `8_arregla_base_comp.do` – Preparación final del dataset
8.  `9_labels.do` – Aplicación de etiquetas de valores

Multiplicado por más de 30 años, eso significa más de **240 scripts de
STATA** haciendo esencialmente la misma tarea: mapear variables crudas
de la ECH a un esquema común.

**metasurvey resuelve esto con recipes.** En lugar de mantener cientos
de archivos `.do`, se escribe un único recipe que codifica la lógica de
transformación y puede aplicarse a cualquier edición de la ECH.

## STATA vs metasurvey: Comparación lado a lado

A continuación se presenta un fragmento de un script de
compatibilización típico en STATA para sexo, edad y parentesco:

``` stata
* STATA: Typical ECH compatibility script

* sexo
g bc_pe2 = e26

* edad
g bc_pe3 = e27

* parentesco (e30 en ECH 2023, era e31 en ediciones anteriores)
g bc_pe4 = -9
  replace bc_pe4 = 1 if e30 == 1
  replace bc_pe4 = 2 if e30 == 2
  replace bc_pe4 = 3 if e30 == 3 | e30 == 4 | e30 == 5
  replace bc_pe4 = 4 if e30 == 7 | e30 == 8
  replace bc_pe4 = 5 if e30 == 6 | e30 == 9 | e30 == 10 | e30 == 11 | e30 == 12
  replace bc_pe4 = 6 if e30 == 13
  replace bc_pe4 = 7 if e30 == 14
```

El equivalente en metasurvey:

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

Las diferencias clave:

| Aspecto | Archivo `.do` de STATA | Recipe de metasurvey |
|----|----|----|
| Formato | Script plano con rutas hardcodeadas | JSON portable con metadatos |
| Validación | Verificaciones manuales con `assert` | Método automático `validate()` |
| Documentación | Comentarios en el código | Método auto-generado `doc()` |
| Compartir | Copiar archivos por email/servidor | Registry con búsqueda y versionado |
| Reproducibilidad | Depende de rutas de archivos y entorno | Autocontenido, cualquier máquina |
| Inter-ediciones | Duplicar script por año | Un recipe, múltiples ediciones |

## Carga de microdatos reales de la ECH

Utilizamos una muestra de microdatos reales de la ECH 2023, publicada
por el INE. La muestra contiene 200 hogares (~500 personas) con las
variables clave necesarias para el analisis del mercado laboral.

``` r

library(metasurvey)
library(data.table)

# Cargar muestra real de la ECH 2023
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

## Paso 1: Variables demográficas

Recodificar los códigos crudos del INE a nombres legibles y recodificar
variables categóricas:

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

## Paso 2: Clasificación de la fuerza laboral

La variable `POBPCOAC` (Población por condición de actividad) es la
clasificación central del estado laboral en la ECH. Códigos del INE:

- 1 = Menor de 14
- 2 = Ocupado
- 3-5 = Desocupado (diversas subcategorías)
- 6-10 = Inactivo
- 11 = No aplica

Esto replica el marco estándar de fuerza laboral de la OIT:

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

## Paso 3: Variables de ingreso

Construir indicadores de ingreso siguiendo la metodología estándar
utilizada con datos de la ECH:

``` r

svy <- step_compute(svy,
  income_pc = HT11 / nper,
  income_thousands = HT11 / 1000,
  log_income = log(HT11 + 1),
  comment = "Income transformations"
)
```

## Paso 4: Clasificación geográfica

Los microdatos reales de la ECH ya incluyen `nom_dpto` (nombre del
departamento) y `region` (1-3). Demostramos un join con lineas de
pobreza por region:

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

## Construcción del recipe

Convertir todas las transformaciones en un recipe portable:

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

### Documentación automática

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

### Publicación en el registry

Publicar el recipe para que otras personas puedan descubrirlo y
reutilizarlo:

``` r

# Set up a local registry
set_backend("local", path = tempfile(fileext = ".json"))
publish_recipe(ech_recipe)

# Ahora cualquiera puede recuperarla por ID
r <- get_recipe("ech_labor")
print(r)
#> NULL
```

## Estimación con workflow()

Ahora calculamos indicadores estándar del mercado laboral:

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

### Estimación por dominio

Calcular estimaciones por subpoblación:

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

### Evaluación de calidad

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

## Reproducibilidad: mismo recipe, distinta edición

El poder de los recipes radica en aplicarlos sin modificaciones a datos
nuevos. En un flujo de trabajo real, se cargarían los datos de otra
edicion y se aplicaría el mismo recipe:

``` r

# Cargar microdatos de la ECH 2024 (cuando esten disponibles)
svy_2024 <- load_survey(
  path = "ECH_2024.csv",
  type = "ech", edition = "2024",
  weight = add_weight(annual = "W_ANO")
)

# Aplicar el mismo recipe
svy_2024 <- add_recipe(svy_2024, ech_recipe)
svy_2024 <- bake_recipes(svy_2024)

# Estimar con metodología consistente
result_2024 <- workflow(
  list(svy_2024),
  survey::svymean(~HT11, na.rm = TRUE),
  survey::svymean(~employed, na.rm = TRUE),
  estimation_type = "annual"
)
```

Mismo recipe, datos diferentes, metodología consistente.

## Para usuarios de STATA: referencia rápida

Si estás haciendo la transición de STATA a R para análisis de encuestas,
aquí hay un mapeo de operaciones comunes:

| STATA | metasurvey | Notas |
|----|----|----|
| `gen var = expr` | `step_compute(svy, var = expr)` | Se ejecuta de inmediato y registra el step en el pipeline |
| `replace var = x if cond` | `step_compute(svy, var = ifelse(cond, x, var))` | Asignación condicional |
| `recode var (old=new)` | `step_recode(svy, new_var, old == val ~ "label")` | Crea una nueva variable |
| `rename old new` | `step_rename(svy, new = old)` |  |
| `drop var1 var2` | `step_remove(svy, var1, var2)` |  |
| `merge using file` | `step_join(svy, data, by = "key")` | Left join por defecto |
| `svy: mean var` | `workflow(list(svy), svymean(~var))` | Devuelve data.table con SE, CV |
| `svy: total var` | `workflow(list(svy), svytotal(~var))` |  |
| `svy: mean var, over(group)` | `workflow(list(svy), svyby(~var, ~group, svymean))` |  |
| `.do` file | [`steps_to_recipe()`](https://metasurveyr.github.io/metasurvey/reference/steps_to_recipe.md) + publish | Portable, descubrible, con control de versiones |
| `use "data.dta"` | `load_survey(path = "data.dta")` | Lee STATA, CSV, RDS, etc. |

### Diferencias clave

1.  **Pipeline registrado**: En STATA, los comandos se ejecutan sin
    dejar rastro. En metasurvey, compute/recode/join también se ejecutan
    de inmediato, pero cada step queda registrado en el pipeline de la
    encuesta (provenance,
    [`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md),
    recipes). Los filtros quedan diferidos hasta
    [`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
    porque afectan el diseño muestral.

2.  **Inmutabilidad**: metasurvey crea nuevas variables en lugar de
    modificar las existentes.
    [`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md)
    crea una nueva columna; no sobreescribe la variable fuente.

3.  **Conciencia del diseño**: Los pesos muestrales y el diseño están
    asociados al objeto `Survey`. No es necesario prefijar comandos con
    `svy:` ni recordar configurar el diseño
    —[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
    lo maneja automáticamente.

4.  **Recipes vs archivos .do**: Los recipes son auto-documentados (vía
    `doc()`), auto-validados (vía `validate()`), y descubribles (vía el
    registry). Un archivo `.do` es simplemente un script; un recipe es
    un objeto estructurado y portable.

## Datos y agradecimientos

Los datos de ejemplo utilizados en esta vinieta provienen de la
*Encuesta Continua de Hogares* (ECH) 2023, publicada por el Instituto
Nacional de Estadistica (INE) de Uruguay. Los microdatos completos estan
disponibles en
[INE](https://www.gub.uy/instituto-nacional-estadistica/).

El paquete **[ech](https://calcita.github.io/ech/)** de Gabriela Mathieu
y Richard Detomasi fue una inspiracion importante para metasurvey.
Mientras que `ech` provee funciones listas para usar para calcular
indicadores de la ECH, metasurvey toma un enfoque diferente: permite a
los usuarios definir, compartir y reproducir sus propios pipelines de
procesamiento como recipes.

## Próximos pasos

- **[Creación y publicación de
  recipes](https://metasurveyr.github.io/metasurvey/articles/recipes.md)**
  – Aprende sobre registries de recipes, certificación y descubrimiento
- **[Flujos de
  estimación](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.md)**
  – Profundización en
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  y `RecipeWorkflow`
- **[Paneles rotativos y
  PoolSurvey](https://metasurveyr.github.io/metasurvey/articles/panel-analysis.md)**
  – Trabajar con la estructura de panel rotativo de la ECH
- **[Primeros
  pasos](https://metasurveyr.github.io/metasurvey/articles/getting-started.md)**
  – Revisar los conceptos básicos
