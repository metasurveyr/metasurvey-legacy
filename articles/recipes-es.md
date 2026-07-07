# Creación y Compartición de Recipes (ES)

## ¿Por qué Recipes?

Cualquier persona que trabaje con microdatos de encuestas de hogares
conoce este patrón: se descargan los archivos sin procesar, se abre el
libro de códigos y se pasan días recodificando la situación laboral,
armonizando variables de ingreso y construyendo indicadores. Meses
después, un colega comienza el mismo proyecto y escribe el mismo código
desde cero.

En STATA, los equipos comparten archivos `.do`, pero estos están
fuertemente acoplados a rutas de archivos y nombres de variables
específicos, y no existe una forma estándar de descubrirlos o
validarlos.

Las **Recipes** son la respuesta de metasurvey a este problema. Una
recipe es una colección portable, documentada y validada de pasos de
transformación que puede:

- Aplicarse a cualquier edición compatible de una encuesta con una sola
  llamada a función
- Publicarse en un registro donde otros pueden descubrirlas y
  reutilizarlas
- Ser certificada por instituciones para uso oficial
- Generar documentación automática de inputs, outputs y pipeline

## Ciclo de Vida de una Recipe

      ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
      │ 1. Desarrollar│────▶│ 2. Empaquetar │────▶│  3. Validar   │
      │  steps sobre  │     │  steps en     │     │  contra datos │
      │  una encuesta │     │  una recipe   │     │  nuevos       │
      └──────────────┘     └──────────────┘     └──────┬───────┘
                                                        │
      ┌──────────────┐     ┌──────────────┐             │
      │ 5. Descubrir  │◀────│ 4. Publicar   │◀────────────┘
      │  y reutilizar │     │  en registro  │
      │  recipes      │     │  o API        │
      └──────────────┘     └──────────────┘

## Cargando una Encuesta

El punto de partida típico es cargar una encuesta con
[`load_survey()`](https://metasurveyr.github.io/metasurvey/reference/load_survey.md).
Se pueden cargar datos de ejemplo o apuntar a archivos propios:

``` r

library(metasurvey)

# Cargar ECH 2022 con datos de ejemplo
ech_2022 <- load_survey(
  load_survey_example("ech", "ech_2022"),
  svy_type    = "ech",
  svy_edition = "2022",
  svy_weight  = add_weight(annual = "pesoano")
)

# O cargar con recipes existentes del registry
ech_2022 <- load_survey(
  load_survey_example("ech", "ech_2022"),
  svy_type    = "ech",
  svy_edition = "2022",
  svy_weight  = add_weight(annual = "pesoano"),
  recipes     = get_recipe("ech", "2022")
)
```

## Construyendo una Recipe a partir de Steps

El flujo de trabajo más común consiste en desarrollar las
transformaciones de forma interactiva sobre una encuesta y luego
convertir los steps registrados en una recipe.

``` r

library(metasurvey)
library(data.table)

set.seed(42)
n <- 200

# Simular microdatos de encuesta (sustituto de load_survey)
dt <- data.table(
  id = 1:n,
  age = sample(18:80, n, replace = TRUE),
  sex = sample(c(1, 2), n, replace = TRUE),
  income = round(runif(n, 5000, 80000)),
  activity = sample(c(2, 3, 5, 6), n,
    replace = TRUE,
    prob = c(0.55, 0.05, 0.05, 0.35)
  ),
  weight = round(runif(n, 0.5, 3.0), 4)
)

svy <- Survey$new(
  data    = dt,
  edition = "2023",
  type    = "ech",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "weight")
)

# Desarrollar transformaciones interactivamente
svy <- step_compute(svy,
  income_thousands = income / 1000,
  employed = ifelse(activity == 2, 1L, 0L),
  comment = "Escalado de ingreso e indicador de empleo"
)

svy <- step_recode(svy, labor_status,
  activity == 2 ~ "Empleado",
  activity %in% 3:5 ~ "Desempleado",
  activity %in% 6:8 ~ "Inactivo",
  .default = "Otro",
  comment = "Clasificacion OIT de fuerza laboral"
)

svy <- step_recode(svy, age_group,
  age < 25 ~ "Joven",
  age < 45 ~ "Adulto",
  age < 65 ~ "Maduro",
  .default = "Mayor",
  comment = "Grupos etarios estandar"
)

# Convertir todos los steps a una recipe
labor_recipe <- steps_to_recipe(
  name        = "Indicadores de Fuerza Laboral",
  user        = "Equipo de Investigacion",
  svy         = svy,
  description = "Indicadores estandar de fuerza laboral segun definiciones OIT",
  steps       = get_steps(svy),
  topic       = "labor"
)

labor_recipe
#> 
#> ── Recipe: Indicadores de Fuerza Laboral ──
#> Author:  Equipo de Investigacion
#> Survey:  ech / 2023
#> Version: 1.0.0
#> Topic:   labor
#> Description: Indicadores estandar de fuerza laboral segun definiciones OIT
#> Certification: community
#> 
#> ── Requires (3 variables) ──
#>   income, activity, age
#> 
#> ── Pipeline (3 steps) ──
#>   1. [compute] -> income_thousands, employed  "Escalado de ingreso e indicador de empleo"
#>   2. [recode] -> labor_status  "Clasificacion OIT de fuerza laboral"
#>   3. [recode] -> age_group  "Grupos etarios estandar"
#> 
#> ── Produces (4 variables) ──
#>   labor_status [categorical], age_group [categorical], income_thousands [numeric], employed [numeric]
```

## Documentación de Recipes

Toda recipe puede generar automáticamente su documentación a partir de
sus steps. El método `doc()` devuelve una lista con las variables de
entrada, las variables de salida y el pipeline paso a paso:

``` r

doc <- labor_recipe$doc()
names(doc)
#> [1] "meta"             "input_variables"  "output_variables" "pipeline"
```

``` r

# ¿Qué variables necesita la recipe?
doc$input_variables
#> [1] "income"   "activity" "age"

# ¿Qué variables crea?
doc$output_variables
#> [1] "income_thousands" "employed"         "labor_status"     "age_group"

# Pipeline paso a paso
doc$pipeline
#> [[1]]
#> [[1]]$index
#> [1] 1
#> 
#> [[1]]$type
#> [1] "compute"
#> 
#> [[1]]$outputs
#> [1] "income_thousands" "employed"        
#> 
#> [[1]]$inputs
#> [1] "income"   "activity"
#> 
#> [[1]]$inferred_type
#> [1] "numeric"
#> 
#> [[1]]$comment
#> [1] "Escalado de ingreso e indicador de empleo"
#> 
#> 
#> [[2]]
#> [[2]]$index
#> [1] 2
#> 
#> [[2]]$type
#> [1] "recode"
#> 
#> [[2]]$outputs
#> [1] "labor_status"
#> 
#> [[2]]$inputs
#> [1] "activity"
#> 
#> [[2]]$inferred_type
#> [1] "categorical"
#> 
#> [[2]]$comment
#> [1] "Clasificacion OIT de fuerza laboral"
#> 
#> 
#> [[3]]
#> [[3]]$index
#> [1] 3
#> 
#> [[3]]$type
#> [1] "recode"
#> 
#> [[3]]$outputs
#> [1] "age_group"
#> 
#> [[3]]$inputs
#> [1] "age"
#> 
#> [[3]]$inferred_type
#> [1] "categorical"
#> 
#> [[3]]$comment
#> [1] "Grupos etarios estandar"
```

Esta documentación se genera automáticamente, sin necesidad de esfuerzo
manual.

## Validación

Antes de aplicar una recipe a nuevos datos, es conveniente verificar que
todas las variables requeridas existan. El método `validate()` se
detiene con un error claro si falta alguna dependencia:

``` r

labor_recipe$validate(svy)
#> [1] TRUE
```

## Aplicación de Recipes a una Encuesta

Se pueden adjuntar una o más recipes a una encuesta y aplicarlas con
[`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md):

``` r

# Crear una encuesta nueva con la misma estructura (simulando una nueva edición)
set.seed(99)
dt2 <- data.table(
  id = 1:100,
  age = sample(18:80, 100, replace = TRUE),
  sex = sample(c(1, 2), 100, replace = TRUE),
  income = round(runif(100, 5000, 80000)),
  activity = sample(c(2, 3, 5, 6), 100,
    replace = TRUE,
    prob = c(0.55, 0.05, 0.05, 0.35)
  ),
  weight = round(runif(100, 0.5, 3.0), 4)
)

svy2 <- Survey$new(
  data = dt2, edition = "2024", type = "ech",
  psu = NULL, engine = "data.table",
  weight = add_weight(annual = "weight")
)

# Adjuntar y aplicar
svy2 <- add_recipe(svy2, labor_recipe)
svy2 <- bake_recipes(svy2)

head(get_data(svy2)[, .(id, income_thousands, labor_status, age_group)], 5)
#>       id income_thousands labor_status age_group
#>    <int>            <num>       <char>    <char>
#> 1:     1           47.346  Desempleado     Mayor
#> 2:     2           28.114     Empleado    Maduro
#> 3:     3           43.583     Empleado    Maduro
#> 4:     4           13.440  Desempleado    Adulto
#> 5:     5           55.638     Empleado     Mayor
```

La misma recipe aplicada a una edición diferente produce resultados
consistentes. Así es como metasurvey garantiza la reproducibilidad a lo
largo del tiempo.

En la práctica, se puede cargar una encuesta y aplicar recipes
publicadas en una sola llamada:

``` r

# Cargar ECH 2023 y aplicar la recipe laboral del registry
ech_2023 <- load_survey(
  load_survey_example("ech", "ech_2023"),
  svy_type    = "ech",
  svy_edition = "2023",
  svy_weight  = add_weight(annual = "pesoano"),
  recipes     = get_recipe("ech", "2023", topic = "labor_market"),
  bake        = TRUE
)
```

## Categorías

Las categorías ayudan a organizar las recipes por tema:

``` r

cats <- default_categories()
vapply(cats, function(c) c$name, character(1))
#> [1] "labor_market" "income"       "education"    "health"       "demographics"
#> [6] "housing"
```

Agregar categorías a una recipe con
[`add_category()`](https://metasurveyr.github.io/metasurvey/reference/add_category.md):

``` r

labor_recipe <- add_category(labor_recipe, "labor_market", "Analisis del mercado laboral")
labor_recipe <- add_category(labor_recipe, "income", "Indicadores de ingreso")
labor_recipe
#> 
#> ── Recipe: Indicadores de Fuerza Laboral ──
#> Author:  Equipo de Investigacion
#> Survey:  ech / 2023
#> Version: 1.0.0
#> Topic:   labor
#> Description: Indicadores estandar de fuerza laboral segun definiciones OIT
#> Certification: community
#> Categories: labor_market, income
#> 
#> ── Requires (3 variables) ──
#>   income, activity, age
#> 
#> ── Pipeline (3 steps) ──
#>   1. [compute] -> income_thousands, employed  "Escalado de ingreso e indicador de empleo"
#>   2. [recode] -> labor_status  "Clasificacion OIT de fuerza laboral"
#>   3. [recode] -> age_group  "Grupos etarios estandar"
#> 
#> ── Produces (4 variables) ──
#>   labor_status [categorical], age_group [categorical], income_thousands [numeric], employed [numeric]
```

## Certificación

El sistema de certificación ofrece tres niveles de confianza:

| Nivel       | Significado                                         |
|-------------|-----------------------------------------------------|
| `community` | Contribución de usuario (por defecto), sin revisión |
| `reviewed`  | Revisada por pares de un equipo reconocido          |
| `official`  | Avalada para estadísticas oficiales                 |

Los niveles de certificación más altos aparecen primero en los
resultados de búsqueda e indican que la recipe ha sido revisada.

## Publicación y Descubrimiento de Recipes

El verdadero poder de las recipes radica en compartirlas. Cada recipe
que crees puede ser publicada en el **registry de metasurvey**, donde
otros investigadores pueden descubrirla, reutilizarla y construir sobre
tu trabajo.

### Publicar en el Registry Público

El flujo recomendado es publicar las recipes en la API pública.
Cualquier persona puede explorar recipes sin cuenta; para publicar se
necesita registro:

``` r

# Una sola vez: registrarse y autenticarse
api_register("Tu Nombre", "tu@email.com", "password")
api_login("tu@email.com", "password")

# Publicar tu recipe (tu perfil se adjunta automáticamente)
api_publish_recipe(labor_recipe)
```

Al estar autenticado,
[`api_publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/api_publish_recipe.md)
adjunta automáticamente tu perfil de usuario a la recipe. Los demás
usuarios ven quién la publicó, junto con la afiliación institucional y
el nivel de certificación. Esto genera responsabilidad y confianza en
las recipes compartidas.

### Exploración y Búsqueda

No se necesita autenticación para explorar y descargar recipes:

``` r

# Explorar todas las recipes de la ECH
ech_recipes <- api_list_recipes(survey_type = "ech")

# Obtener una recipe por ID
r <- api_get_recipe(id = "recipe_id_aqui")
```

### Explorador Interactivo

La app Shiny provee una interfaz visual para explorar recipes y
workflows:

``` r

explore_recipes()
```

El explorador muestra tarjetas de recipes con badges de certificacion,
conteo de descargas y preview del pipeline. Al hacer clic en una recipe
se abre una vista de detalle con el pipeline completo, snippet de codigo
R y links a workflows relacionados.

### Registry Privado para Instituciones

Las instituciones que trabajan con **encuestas confidenciales o de
acceso restringido** pueden necesitar un registry privado. metasurvey
soporta esto mediante un backend propio con MongoDB:

``` r

# Apuntar a la API privada de tu institución
configure_api("https://tu-institucion.example.com/api")

# A partir de aquí, el flujo es idéntico
api_login("analista@institucion.edu", "password")
api_publish_recipe(labor_recipe)
api_list_recipes(survey_type = "ech")
```

Consulta la vignette [API y Base de
Datos](https://metasurveyr.github.io/metasurvey/articles/api-database.html)
para instrucciones sobre cómo desplegar la API Plumber con MongoDB para
tu propia organización.

## Buenas Prácticas

1.  **Nombrar las recipes de forma descriptiva** – incluir el tipo de
    encuesta y el tema (por ejemplo,
    `"ECH Indicadores de Fuerza Laboral"`).
2.  **Agregar descripciones** – documentar qué calcula la recipe y por
    qué.
3.  **Usar categorías y temas** – facilitar que las recipes sean
    descubribles.
4.  **Validar antes de compartir** – llamar a `validate()` sobre datos
    de ejemplo para asegurar que todas las dependencias existan.
5.  **Versionar las recipes** – usar
    [`set_version()`](https://metasurveyr.github.io/metasurvey/reference/set_version.md)
    al actualizarlas.

## Próximos Pasos

- **[Flujos de
  Estimación](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.md)**
  – Usar
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  para calcular estimaciones ponderadas a partir de los datos procesados
- **[Caso de Estudio
  ECH](https://metasurveyr.github.io/metasurvey/articles/ech-case-study.md)**
  – Ver recipes en acción en un análisis real del mercado laboral
- **[Primeros
  Pasos](https://metasurveyr.github.io/metasurvey/articles/getting-started.md)**
  – Revisar los conceptos básicos de steps y objetos Survey
