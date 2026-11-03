# Construyendo una Receta de Demografia ECH (ES)

## Dos caminos: transpilar rapido o construir bien

metasurvey ofrece dos formas de crear recetas a partir de codigo STATA
existente:

1.  **Transpilar automaticamente** con
    [`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md)
    – convierte archivos `.do` a recetas en segundos. Ideal para migrar
    codigo legacy rapidamente (ver
    [`vignette("stata-transpiler-es")`](https://metasurveyr.github.io/metasurvey/articles/stata-transpiler-es.md)).
2.  **Construir desde cero** en R – mas trabajo inicial, pero el
    resultado es mas limpio, usa modismos propios de R y se controla
    cada detalle.

El transpilador es un atajo pragmatico: lee cientos de lineas de STATA y
produce una receta funcional, pero la salida hereda la estructura del
codigo original – largas cadenas `gen`/`replace` se convierten en largas
llamadas a `step_recode`, las variables temporales sobreviven, y
patrones especificos de STATA (como `mvencode`) se traducen literalmente
en lugar de repensarse.

Una receta artesanal, en cambio, permite **redisenar la logica** en R
desde cero. Se eligen nombres de variables significativos, se combinan
transformaciones relacionadas en un solo step, y se omiten variables
intermedias que solo existian porque STATA las necesitaba. El resultado
es mas corto, mas legible y mas facil de mantener.

Esta vignette construye una receta de demografia desde cero en unas 20
lineas de R. Una version transpilada del mismo pipeline tomaria 80+
steps y arrastraria nombres de variables como `bc_pe2` y `bc_pe3` que no
significan nada fuera del archivo `.do` original.

## Configurando la encuesta

Comenzamos con un objeto Survey vacio. Esto declara el tipo de encuesta
y la edicion sin cargar datos todavia – la receta funcionara con
cualquier dato que le proporcionemos despues.

``` r

library(metasurvey)

svy <- survey_empty(type = "ech", edition = "2023")
svy
```

Ahora adjuntamos algunos datos de ejemplo. En produccion estos vendrian
de `anda_download_microdata("2023")` o un archivo local; aqui los
simulamos.

``` r

set.seed(42)
n <- 200
dt <- data.table::data.table(
  id       = rep(1:50, each = 4),
  nper     = rep(1:4, 50),
  pesoano  = runif(n, 50, 300),
  e26      = sample(1:2, n, replace = TRUE),
  e27      = sample(0:90, n, replace = TRUE),
  e30      = sample(1:7, n, replace = TRUE),
  e51_2    = sample(c(0:6, -9), n, replace = TRUE),
  region_4 = sample(1:4, n, replace = TRUE)
)

svy <- svy |> set_data(dt)
```

## Construyendo el pipeline

Cada transformacion es un **step**. Los steps de datos (`step_compute`,
`step_recode`, `step_join`) se ejecutan al crearse y quedan registrados
en el pipeline; `step_rename` y `step_remove` quedan diferidos por
defecto hasta
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md).
El pipeline registrado es lo que permite inspeccionar, documentar y
reutilizar cada transformacion.

Comparar con el enfoque del transpilador:
[`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md)
produciria un step por cada comando STATA, preservando fielmente cada
`gen` y `replace`. Aqui pensamos en terminos de las *variables de
salida* que queremos, no de los comandos que necesitamos escribir.

### Renombrar identificadores

``` r

svy <- svy |>
  step_rename(
    hh_id = "id", person_id = "nper",
    comment = "Estandarizar identificadores"
  )
```

Nada le paso a los datos todavia: `step_rename` queda diferido por
defecto
([`lazy_default()`](https://metasurveyr.github.io/metasurvey/reference/lazy_default.md)
es `TRUE`) hasta
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md):

``` r

names(get_data(svy))[1:4]
#> [1] "id"      "nper"    "pesoano" "e26"
```

Los nombres de columna originales siguen ahi porque el step esta
pendiente. Los recodes que siguen, en cambio, se ejecutan al crearse.
Sigamos agregando steps.

### Recodificar sexo

En STATA esto seria una secuencia gen + replace + replace (3 comandos).
Con `step_recode` es un unico mapeo declarativo que produce etiquetas
legibles:

``` r

svy <- svy |>
  step_recode(sex,
    e26 == 1 ~ "Hombre",
    e26 == 2 ~ "Mujer",
    .default = NA_character_,
    comment = "Sexo desde e26"
  )
```

### Grupos de edad

El equivalente en STATA usa cinco lineas `replace` con
[`inrange()`](https://rdrr.io/pkg/data.table/man/between.html). Aqui
escribimos la misma logica como un unico recode con condiciones
legibles:

``` r

svy <- svy |>
  step_recode(age_group,
    e27 >= 0 & e27 <= 13 ~ "Ninio",
    e27 >= 14 & e27 <= 17 ~ "Adolescente",
    e27 >= 18 & e27 <= 29 ~ "Joven adulto",
    e27 >= 30 & e27 <= 64 ~ "Adulto",
    e27 >= 65 ~ "Adulto mayor",
    .default = NA_character_,
    comment = "Grupos de edad desde e27"
  )
```

### Relacion con el jefe de hogar

``` r

svy <- svy |>
  step_recode(relationship,
    e30 == 1 ~ "Jefe",
    e30 == 2 ~ "Conyuge",
    e30 >= 3 & e30 <= 5 ~ "Hijo",
    e30 == 6 ~ "Otro familiar",
    e30 == 7 ~ "No familiar",
    .default = "Desconocido",
    comment = "Relacion desde e30"
  )
```

### Nivel educativo

``` r

svy <- svy |>
  step_recode(edu_level,
    e51_2 == 0 ~ "Sin instruccion",
    e51_2 >= 1 & e51_2 <= 2 ~ "Primaria",
    e51_2 >= 3 & e51_2 <= 4 ~ "Secundaria",
    e51_2 >= 5 & e51_2 <= 6 ~ "Terciaria",
    .default = NA_character_,
    comment = "Nivel educativo desde e51_2"
  )
```

### Area geografica

``` r

svy <- svy |>
  step_recode(area,
    region_4 == 1 ~ "Montevideo",
    region_4 == 2 ~ "Urbano >5k",
    region_4 == 3 ~ "Urbano <5k",
    region_4 == 4 ~ "Rural",
    .default = NA_character_,
    comment = "Area geografica desde region_4"
  )
```

Notar que todas nuestras variables de salida tienen **etiquetas
significativas** en lugar de codigos numericos. Una receta transpilada
mantendria los codigos enteros originales (1, 2, 3…) porque eso es lo
que usaba el codigo STATA. Construir desde cero permite elegir la
representacion que facilita el analisis.

### Remover variables crudas

``` r

svy <- svy |>
  step_remove(e26, e27, e30, e51_2, region_4,
    comment = "Eliminar variables crudas de ECH"
  )
```

## Inspeccionando el pipeline

En este punto tenemos siete steps registrados: los cinco recodes ya se
ejecutaron, y el rename y el remove siguen pendientes. Veamos que se
registro:

``` r

length(get_steps(svy))
#> [1] 7
```

Esta es una de las ventajas clave de construir desde cero: **7 steps que
cada uno hace una cosa clara**. Una version transpilada del modulo
completo de demografia del IECON tiene 80+ steps porque preserva cada
comando STATA intermedio.

El pipeline es un DAG (grafo aciclico dirigido) de transformaciones.
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)
lo renderiza como una red interactiva – cada nodo es un step, y las
aristas muestran dependencias de variables:

``` r

view_graph(svy)
```

Con solo 7 nodos el grafo es limpio y navegable. Comparar con una receta
transpilada donde el DAG puede tener 100+ nodos – aun util para
auditoria, pero mucho mas dificil de leer de un vistazo.

Para salida estatica podemos inspeccionar la lista de steps:

``` r

for (s in get_steps(svy)) {
  cat(sprintf("[%s] %s\n", s$type, s$comment %||% ""))
}
#> [step_rename] Estandarizar identificadores
#> [recode] Sexo desde e26
#> [recode] Grupos de edad desde e27
#> [recode] Relacion desde e30
#> [recode] Nivel educativo desde e51_2
#> [recode] Area geografica desde region_4
#> [step_remove] Eliminar variables crudas de ECH
```

## Empaquetando como receta

Una receta empaqueta los steps con metadatos para que cualquiera pueda
reproducir el mismo pipeline con datos diferentes. Los steps registrados
son el pipeline: no importa si ya se ejecutaron o no, la receta
re-ejecuta cada step al hornearse sobre datos nuevos – ahi vive la
reproducibilidad:

``` r

rec <- steps_to_recipe(
  name = "ECH Demografia (minima)",
  user = "equipo_investigacion",
  svy = svy,
  steps = get_steps(svy),
  description = paste(
    "Demografia armonizada: sexo, grupo de edad, relacion,",
    "nivel educativo y area geografica."
  ),
  topic = "demographics"
)

rec
#> 
#> ── Recipe: ECH Demografia (minima) ──
#> Author:  equipo_investigacion
#> Survey:  ech / 2023
#> Version: 1.0.0
#> Topic:   demographics
#> Description: Demografia armonizada: sexo, grupo de edad, relacion, nivel educativo y area geografica.
#> Certification: community
#> 
#> ── Requires (5 variables) ──
#>   e26, e27, e30, e51_2, region_4
#> 
#> ── Pipeline (7 steps) ──
#>   1. [step_rename] -> mapping  "Estandarizar identificadores"
#>   2. [recode] -> sex  "Sexo desde e26"
#>   3. [recode] -> age_group  "Grupos de edad desde e27"
#>   4. [recode] -> relationship  "Relacion desde e30"
#>   5. [recode] -> edu_level  "Nivel educativo desde e51_2"
#>   6. [recode] -> area  "Area geografica desde region_4"
#>   7. [step_remove] -> (no output)  "Eliminar variables crudas de ECH"
#> 
#> ── Produces (6 variables) ──
#>   sex [categorical], age_group [categorical], relationship [categorical], edu_level [categorical], area [categorical], mapping [inherited]
```

La receta auto-genera documentacion a partir de los steps:

``` r

doc <- rec$doc()
cat("Variables de entrada: ", paste(doc$input_variables, collapse = ", "), "\n")
#> Variables de entrada:  e26, e27, e30, e51_2, region_4
cat("Variables de salida:  ", paste(doc$output_variables, collapse = ", "), "\n")
#> Variables de salida:   mapping, sex, age_group, relationship, edu_level, area
cat("Steps del pipeline:   ", length(doc$pipeline), "\n")
#> Steps del pipeline:    7
```

## Bake: materializando los steps pendientes

[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
ejecuta los steps diferidos (aca, el rename y el remove) y saltea los
que ya se ejecutaron, asi que nunca hay doble ejecucion. Llamarlo es
seguro e idempotente:

``` r

svy <- bake_steps(svy)
```

Los datos tienen las nuevas columnas con etiquetas legibles:

``` r

head(get_data(svy)[, .(
  hh_id, person_id, sex, age_group, relationship,
  edu_level, area
)])
#>    hh_id person_id    sex    age_group relationship       edu_level       area
#>    <int>     <int> <char>       <char>       <char>          <char>     <char>
#> 1:     1         1  Mujer Adulto mayor  No familiar Sin instruccion Urbano <5k
#> 2:     1         2  Mujer       Adulto         Jefe        Primaria Montevideo
#> 3:     1         3 Hombre Joven adulto      Conyuge       Terciaria Urbano <5k
#> 4:     1         4  Mujer       Adulto         Hijo        Primaria      Rural
#> 5:     2         1 Hombre Adulto mayor         Hijo Sin instruccion Urbano >5k
#> 6:     2         2 Hombre Joven adulto      Conyuge       Terciaria      Rural
```

Las variables crudas ya no estan:

``` r

"e26" %in% names(get_data(svy))
#> [1] FALSE
```

## Guardar y cargar

Las recetas se serializan a JSON para control de versiones y compartir:

``` r

f <- tempfile(fileext = ".json")
save_recipe(rec, f)
```

``` r

rec2 <- read_recipe(f)
rec2$name
#> [1] "ECH Demografia (minima)"
length(rec2$steps)
#> [1] 7
```

El JSON es legible y diffeable en git:

``` r

cat(readLines(f, n = 15), sep = "\n")
#> {
#>   "name": "ECH Demografia (minima)",
#>   "user": "equipo_investigacion",
#>   "survey_type": "ech",
#>   "edition": 2023,
#>   "description": "Demografia armonizada: sexo, grupo de edad, relacion, nivel educativo y area geografica.",
#>   "topic": "demographics",
#>   "doi": {},
#>   "id": "r_1793664104_663",
#>   "version": "1.0.0",
#>   "downloads": 0,
#>   "categories": [],
#>   "certification": {
#>     "level": "community",
#>     "certified_at": "2026-11-03 00:01:44.950609"
```

## Aplicando a una nueva edicion

La misma receta funciona con cualquier edicion. Cargar la receta desde
JSON, adjuntarla a nuevos datos y hacer bake:

``` r

rec_loaded <- read_recipe(f)

svy_2024 <- survey_empty(type = "ech", edition = "2024") |>
  set_data(data.table::data.table(
    id       = rep(1:30, each = 3),
    nper     = rep(1:3, 30),
    pesoano  = runif(90, 50, 300),
    e26      = sample(1:2, 90, replace = TRUE),
    e27      = sample(0:90, 90, replace = TRUE),
    e30      = sample(1:7, 90, replace = TRUE),
    e51_2    = sample(c(0:6, -9), 90, replace = TRUE),
    region_4 = sample(1:4, 90, replace = TRUE)
  )) |>
  add_recipe(rec_loaded) |>
  bake_recipes()

head(get_data(svy_2024)[, .(hh_id, person_id, sex, age_group, area)])
#>    hh_id person_id    sex    age_group       area
#>    <int>     <int> <char>       <char>     <char>
#> 1:     1         1 Hombre Adulto mayor      Rural
#> 2:     1         2 Hombre       Adulto Urbano <5k
#> 3:     1         3  Mujer Joven adulto Urbano >5k
#> 4:     2         1 Hombre       Adulto Montevideo
#> 5:     2         2  Mujer Adulto mayor      Rural
#> 6:     2         3 Hombre Adulto mayor Urbano <5k
```

No se necesitan cambios en el codigo. La receta codifica la *logica*, no
los datos.

## Transpilador vs artesanal: cuando usar cada uno

|  | Transpilador ([`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md)) | Receta artesanal |
|----|----|----|
| **Velocidad** | Segundos – migracion instantanea | Horas – requiere entender la logica |
| **Steps** | 80-200 por modulo (uno por linea STATA) | 5-20 (uno por concepto) |
| **Nombres de variables** | Hereda nombres STATA (`bc_pe2`, `bc_pe3`) | Nombres propios (`sex`, `age_group`) |
| **Etiquetas** | Codigos numericos (`1`, `2`, `3`) | Etiquetas legibles (`"Hombre"`, `"Mujer"`) |
| **Legibilidad** | Fiel al original, verboso | Limpio, auto-documentado |
| **Mantenimiento** | Dificil modificar steps individuales | Facil cambiar cualquier mapeo |
| **Visualizacion DAG** | Grande, dificil de leer | Compacto, nodos significativos |
| **Mejor para** | Migrar codigo legacy rapido | Proyectos nuevos, pipelines criticos |

**Flujo de trabajo recomendado**: usar
[`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md)
para migrar los archivos `.do` existentes inmediatamente para tener un
baseline funcional. Luego reemplazar gradualmente las recetas
transpiladas con artesanales a medida que se revisa cada modulo. La
version transpilada mantiene todo funcionando; la version artesanal es
donde se quiere llegar.

## Lo que metasurvey ofrece

| Scripts STATA manuales | Receta metasurvey |
|----|----|
| Copiar-pegar archivos `.do` por anio | Una receta, cualquier edicion |
| Nombres de variables sin documentar | Documentacion auto-generada de entrada/salida |
| Sin seguimiento de dependencias | Visualizacion DAG con [`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md) |
| Scripts planos, sin validacion | `validate()` verifica variables requeridas |
| Enviar archivos `.do` por email | [`publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/publish_recipe.md) a registro compartido |
| Re-ejecutar todo el script para probar | Pipeline registrado: inspeccionar con [`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md) |

## Proximos pasos

- **Agregar mas variables**: ingresos, condicion de actividad,
  condiciones de vivienda – cada una puede ser una receta separada con
  `depends_on_recipes`
- **Certificar la receta**: usar
  [`certify_recipe()`](https://metasurveyr.github.io/metasurvey/reference/certify_recipe.md)
  para marcarla como revisada u oficial
- **Publicar**: `publish_recipe(rec)` sube al registro compartido donde
  otros pueden encontrarla con `search_recipes(topic = "demographics")`
- **Partir desde STATA**: si ya se tienen archivos `.do`, usar
  [`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md)
  para generar un baseline funcional inmediatamente – ver
  [`vignette("stata-transpiler-es")`](https://metasurveyr.github.io/metasurvey/articles/stata-transpiler-es.md)
  – y luego refinar la salida en una receta artesanal como la de esta
  vignette
