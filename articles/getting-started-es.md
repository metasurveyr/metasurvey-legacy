# Primeros pasos con metasurvey (ES)

## Introduccion

Trabajar con microdatos de encuestas de hogares implica una gran
cantidad de procesamiento repetitivo: recodificar variables categoricas,
construir indicadores, unir datos externos y calcular estimaciones
ponderadas. Cada investigador escribe su propia version de estas
transformaciones, y el codigo rara vez se comparte o documenta de forma
que otros puedan reutilizarlo.

**metasurvey** aborda este problema proporcionando una capa de
metaprogramacion sobre el paquete `survey` ([Lumley
2004](#ref-lumley2004)). En lugar de escribir scripts ad hoc, se
construye un **pipeline** de transformaciones que es:

- **Documentado** – cada paso lleva un comentario, sus variables de
  entrada/salida y sus dependencias
- **Reproducible** – el pipeline puede guardarse como una receta y
  aplicarse a nuevos datos
- **Compartible** – las recetas pueden publicarse en una API publica
  donde otros investigadores pueden descubrirlas y reutilizarlas

El pipeline tiene tres niveles:

1.  **Steps** – transformaciones individuales (compute, recode, filter,
    rename, remove, join, validate)
2.  **Recipes** – colecciones reutilizables de steps agrupados con
    metadatos
3.  **Workflows** – estimaciones estadisticas (`svymean`, `svytotal`,
    `svyby`) que producen las tablas finales

El paquete maneja el survey design —estratificacion, conglomerados,
pesos replicados— automaticamente a traves del objeto `Survey`. El
usuario se enfoca en el analisis sustantivo; metasurvey se encarga de la
infraestructura.

## Instalacion

``` r

# Install from GitHub
devtools::install_github("metaSurveyR/metasurvey")
```

``` r

library(metasurvey)
library(data.table)
```

## Creacion de un objeto Survey

Un objeto `Survey` agrupa los microdatos con metadatos sobre pesos,
edicion y tipo de encuesta. Utilizamos una muestra de microdatos reales
de la *Encuesta Continua de Hogares* (ECH) 2023, publicada por el
Instituto Nacional de Estadistica (INE) de Uruguay.

La ECH es una encuesta de hogares de panel rotativo. Las variables clave
incluyen:

- **e27**: Edad en anios
- **e26**: Sexo (1 = Hombre, 2 = Mujer)
- **e30**: Parentesco con el jefe de hogar (1-14)
- **POBPCOAC**: Condicion de actividad
  - 1 = Menor de 14
  - 2 = Ocupado
  - 3-5 = Desocupado
  - 6-10 = Inactivo
  - 11 = No aplica
- **HT11**: Ingreso del hogar (pesos uruguayos)
- **W_ANO**: Factor de expansion anual (peso)

``` r

library(metasurvey)
library(data.table)

# Cargar muestra de microdatos reales de la ECH 2023 (200 hogares, ~500 personas)
dt <- fread(system.file("extdata", "ech_2023_sample.csv", package = "metasurvey"))

# Crear objeto Survey
svy <- Survey$new(
  data    = dt,
  edition = "2023",
  type    = "ech",
  engine  = "data.table",
  weight  = add_weight(annual = "W_ANO")
)
```

La funcion
[`add_weight()`](https://metasurveyr.github.io/metasurvey/reference/add_weight.md)
mapea etiquetas de periodicidad (por ejemplo, “annual”, “monthly”) a los
nombres de las columnas de pesos en los datos. Esto permite que la misma
receta funcione con distintas ediciones de la encuesta.

Es posible inspeccionar los datos en cualquier momento:

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

## Trabajo con Steps

Los steps son **lazy por defecto**: se registran pero no se ejecutan
hasta que se llama a
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md).
Esto permite:

1.  Construir un pipeline de transformacion completo
2.  Inspeccionar y validar los steps antes de la ejecucion
3.  Reutilizar secuencias de steps como recetas
4.  Asegurar que todas las dependencias existan antes del procesamiento

### Calculo de nuevas variables

Se utiliza
[`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md)
para crear variables derivadas. El paquete automaticamente:

- Valida que las variables de entrada existan
- Detecta dependencias entre steps
- Optimiza las expresiones para mejorar el rendimiento

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

Es posible agrupar calculos usando el parametro `.by` (similar a
`data.table`):

``` r

# Calculate mean household income per department
svy <- step_compute(svy,
  mean_income_dept = mean(HT11, na.rm = TRUE),
  .by = "dpto",
  comment = "Department-level income averages"
)
```

### Recodificacion en categorias

Se utiliza
[`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md)
para crear variables categoricas a partir de condiciones. Las
condiciones se evaluan **de arriba hacia abajo**, y la primera
coincidencia es la que se aplica.

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

### Filtrado de filas

Se utiliza
[`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md)
para seleccionar filas segun condiciones logicas. Multiples condiciones
se combinan con AND. Al igual que los demas steps, los filtros son lazy
por defecto.

``` r

# Mantener solo individuos en edad de trabajar (14+)
svy <- step_filter(svy,
  e27 >= 14,
  comment = "Working-age population only"
)
```

### Renombrar y eliminar variables

Se renombran variables para mayor claridad o consistencia:

``` r

svy <- step_rename(svy,
  age = e27, # Rename e27 to age
  sex_code = e26 # Keep original as sex_code
)
```

Se eliminan variables que ya no son necesarias:

``` r

# Remove intermediate calculations
svy <- step_remove(svy, working_age, mean_income_dept)
```

### Union con datos externos

Se utiliza
[`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md)
para unir datos de referencia externos. Esto es util para agregar:

- Nombres y clasificaciones geograficas
- Tipos de cambio o deflactores
- Benchmarks o metas externas

Los microdatos reales de la ECH ya incluyen `nom_dpto` y `region`. Aqui
demostramos un join con lineas de pobreza como ejemplo:

``` r

# Lineas de pobreza por region (valores ilustrativos en UYU, 2023)
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

## Ejecucion de transformaciones

### Aplicacion de steps (bake)

Se llama a
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
para ejecutar todas las transformaciones pendientes:

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
#>    labor_status      age_group gender poverty_line region_name poverty_line.y
#>          <char>         <fctr> <char>        <num>      <char>          <num>
#> 1:     Employed Mature (45-64) Female        19000  Montevideo          19000
#> 2:   Unemployed Mature (45-64) Female        19000  Montevideo          19000
#> 3:     Employed Mature (45-64)   Male        19000  Montevideo          19000
#>    region_name.y
#>           <char>
#> 1:    Montevideo
#> 2:    Montevideo
#> 3:    Montevideo
```

El historial de steps se preserva para documentacion y reproducibilidad:

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

### Visualizacion del pipeline

Es posible visualizar el pipeline de transformacion como un grafo
dirigido:

``` r

view_graph(svy, init_step = "Load ECH 2023")
```

Esto genera un grafo interactivo que muestra:

- Fuentes de datos y uniones
- Steps de transformacion
- Dependencias entre variables
- Comentarios y metadatos

## Estimaciones estadisticas

Una vez preparados los datos, se utiliza
[`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
para calcular estimaciones de encuesta. La funcion envuelve los
estimadores del paquete `survey` ([Lumley 2004](#ref-lumley2004)) y
devuelve resultados ordenados con errores estandar y coeficientes de
variacion.

**Importante:** Se debe pasar el objeto survey dentro de un
[`list()`](https://rdrr.io/r/base/list.html).

### Estimaciones basicas

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

La salida incluye:

- `estimate`: Estimacion puntual
- `se`: Error estandar
- `cv`: Coeficiente de variacion
- `var_name`: Nombre de la variable
- `level`: Nivel del factor (para variables categoricas)

### Estimaciones multiples

Es posible calcular varias estadisticas en una sola llamada:

``` r

results <- workflow(
  list(svy),
  survey::svymean(~HT11, na.rm = TRUE), # Mean income
  survey::svytotal(~employed, na.rm = TRUE), # Total employed
  survey::svymean(~labor_status, na.rm = TRUE), # Employment distribution
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

### Estimacion por dominios

Se calculan estimaciones para subpoblaciones usando
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

## Evaluacion de calidad

El **coeficiente de variacion (CV)** mide la confiabilidad de las
estimaciones. Un CV mas bajo indica estimaciones mas precisas. Siguiendo
las pautas del INE Uruguay ([Instituto Nacional de Estadística (INE)
2023](#ref-ine2023)):

| Rango de CV | Categoria de calidad | Recomendacion |
|----|----|----|
| \< 5% | Excelente | Usar sin restricciones |
| 5%–10% | Muy buena | Usar con confianza |
| 10%–15% | Buena | Usar para la mayoria de los propositos |
| 15%–25% | Aceptable | Usar con precaucion, senialando limitaciones |
| 25%–35% | Pobre | Usar solo para tendencias generales |
| \>= 35% | No confiable | No publicar |

Se utiliza
[`evaluate_cv()`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md)
para clasificar la calidad de las estimaciones:

``` r

# Check quality of mean income estimate
cv_percentage <- results$cv[1] * 100
quality <- evaluate_cv(cv_percentage)

cat("CV:", round(cv_percentage, 2), "%\n")
#> CV: 3.69 %
cat("Quality:", quality, "\n")
#> Quality: Excellent
```

Para estadisticas oficiales, siempre se debe reportar:

1.  Estimacion puntual
2.  Error estandar o intervalo de confianza
3.  Coeficiente de variacion
4.  Clasificacion de calidad
5.  Tamanio de la muestra

## Trabajo con Recipes

Las recipes agrupan steps de transformacion para **reproducibilidad** y
**comparticion**. Una vez desarrollado un pipeline funcional, se puede
convertir en una receta que puede ser:

- Aplicada a diferentes ediciones de la encuesta
- Compartida con colaboradores
- Publicada para garantizar transparencia
- Versionada y documentada

### Creacion de una Recipe

Se crea una receta a partir de los steps desarrollados:

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

O se puede definir una receta desde cero:

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

### Aplicacion de Recipes a nuevos datos

Una vez publicada, cualquier persona puede recuperar una receta por ID y
aplicarla a sus datos:

``` r

# Obtener una receta por ID desde la API (requiere servidor)
r <- api_get_recipe("ech_labor_001")

# Aplicar a una nueva encuesta
new_svy <- add_recipe(new_svy, r)
processed <- bake_recipes(new_svy)
```

### Documentacion de Recipes

Las recetas documentan automaticamente sus transformaciones:

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

## Configuracion del paquete

metasurvey ofrece configuraciones globales que se pueden ajustar segun
el flujo de trabajo:

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

Se pueden modificar las configuraciones para la sesion actual:

``` r

# Disable lazy evaluation (execute steps immediately)
set_lazy_processing(FALSE)

# Modify inplace (faster, but modifies original data)
set_use_copy(FALSE)

# Reset to defaults
set_lazy_processing(TRUE)
set_use_copy(TRUE)
```

## Compartir el trabajo: el ecosistema de recipes

Uno de los objetivos de metasurvey es reducir el esfuerzo duplicado en
la comunidad de investigadores que trabajan con encuestas. Si se ha
construido un pipeline de procesamiento util, es posible publicarlo para
que otros lo encuentren y reutilicen. El paquete se conecta a una API
publica donde se almacenan recipes y workflows:

``` r

# Buscar recipes existentes (requiere servidor API)
ech_recipes <- api_list_recipes(survey_type = "ech")
length(ech_recipes)

# Buscar algo especifico
labor <- api_list_recipes(search = "labor")

# Para publicar, crear una cuenta primero
api_register("Your Name", "you@example.com", "password")

# Luego publicar
api_publish_recipe(labor_recipe)
```

El ecosistema soporta tres niveles de certificacion (comunitaria,
revisada, oficial) y tres tipos de cuenta (individual, miembro
institucional, institucion). Las cuentas institucionales requieren
aprobacion de un administrador, lo que asegura que las certificaciones
tengan respaldo real.

Para mas detalles, consultar [Creacion y comparticion de
Recipes](https://metasurveyr.github.io/metasurvey/articles/recipes.md).

## Datos y agradecimientos

Los datos de ejemplo utilizados en esta vinieta provienen de la
*Encuesta Continua de Hogares* (ECH) 2023, publicada por el Instituto
Nacional de Estadistica (INE) de Uruguay. Los microdatos completos estan
disponibles en
[INE](https://www.gub.uy/instituto-nacional-estadistica/).

El paquete **[ech](https://calcita.github.io/ech/)** de Gabriela Mathieu
y Richard Detomasi fue una inspiracion importante para metasurvey.
Mientras que `ech` provee funciones listas para usar para calcular
indicadores socioeconomicos, metasurvey toma un enfoque diferente:
proporciona una capa de metaprogramacion que permite a los usuarios
definir, compartir y reproducir sus propios pipelines de procesamiento.

## Paquetes relacionados

metasurvey es parte de un ecosistema creciente de paquetes de R para el
analisis de encuestas de hogares en America Latina:

- **[ech](https://calcita.github.io/ech/)** – Funciones para el calculo
  de indicadores socioeconomicos con la ECH de Uruguay (Mathieu &
  Detomasi). Provee funciones listas para usar sobre pobreza, ingresos,
  educacion e indicadores de empleo.
- **[eph](https://docs.ropensci.org/eph/)** – Herramientas para trabajar
  con la Encuesta Permanente de Hogares de Argentina. Publicado en
  rOpenSci. Cubre descarga de datos, construccion de paneles y calculo
  de pobreza.
- **[survey](https://cran.r-project.org/package=survey)** – El paquete
  fundamental para inferencia basada en disenio con encuestas complejas
  ([Lumley 2004](#ref-lumley2004)). metasurvey se construye sobre el.

## Proximos pasos

Ahora que se comprenden los conceptos basicos, se pueden explorar estas
guias:

- **[Creacion y comparticion de
  Recipes](https://metasurveyr.github.io/metasurvey/articles/recipes.md)**
  – Registro de recipes, certificacion y descubrimiento
- **[Workflows de
  estimacion](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.md)**
  –
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md),
  `RecipeWorkflow` y estimaciones publicables
- **[Survey designs y
  validacion](https://metasurveyr.github.io/metasurvey/articles/complex-designs.md)**
  – Estratificacion, conglomerados, pesos replicados, validacion del
  pipeline
- **[Paneles rotativos y
  PoolSurvey](https://metasurveyr.github.io/metasurvey/articles/panel-analysis.md)**
  – Analisis longitudinal con `RotativePanelSurvey` y `PoolSurvey`
- **[Caso de estudio
  ECH](https://metasurveyr.github.io/metasurvey/articles/ech-case-study.md)**
  – Analisis completo del mercado laboral con comparacion con STATA

## Referencias

Instituto Nacional de Estadística (INE). 2023. *Encuesta Continua de
Hogares: Metodología y Documentación*. Instituto Nacional de Estadística
(INE), Uruguay. <https://www.gub.uy/instituto-nacional-estadistica/>.

Lumley, Thomas. 2004. “Analysis of Complex Survey Samples.” *Journal of
Statistical Software* 9 (1): 1–19.
<https://doi.org/10.18637/jss.v009.i08>.
