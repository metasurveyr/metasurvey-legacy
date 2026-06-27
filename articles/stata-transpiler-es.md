# Transpilando archivos .do de STATA a Recetas metasurvey (ES)

## Motivacion

Muchos grupos de investigacion latinoamericanos mantienen decadas de
archivos `.do` de STATA que procesan microdatos de encuestas de hogares.
Estos scripts codifican conocimiento institucional sobre armonizacion de
variables, descomposicion de ingresos y construccion de indicadores –
pero estan encerrados en un formato dificil de versionar, compartir o
integrar con flujos de trabajo modernos en R.

El **transpilador de metasurvey** convierte archivos `.do` de STATA en
objetos Recipe de metasurvey. Esto permite:

- **Reproducibilidad**: los pipelines de STATA se convierten en recetas
  JSON versionadas
- **Interoperabilidad**: la misma receta se ejecuta sobre cualquier
  objeto Survey respaldado por `data.table`
- **Descubrimiento**: las recetas transpiladas pueden publicarse en la
  API de metasurvey para que otros investigadores las encuentren y
  reutilicen

El transpilador maneja los patrones de STATA mas comunes en scripts de
procesamiento de encuestas: generacion de variables, reemplazo
condicional, recodificacion, agregacion, loops, codificacion de valores
faltantes y extraccion de etiquetas.

## Inicio rapido

``` r

library(metasurvey)

# Transpilar un archivo .do
result <- transpile_stata("demographics.do")
result$steps[1:3]
#> [1] "step_rename(svy, hh_id = \"id\", person_id = \"nper\")"
#> [2] "step_compute(svy, weight_yr = pesoano)"
#> [3] "step_compute(svy, sex = e26)"
```

El resultado es una lista con cuatro elementos:

| Elemento | Descripcion |
|----|----|
| `steps` | Vector de caracteres con llamadas a steps de metasurvey |
| `labels` | Etiquetas de variables y valores extraidas del archivo `.do` |
| `warnings` | Comandos que requieren revision manual |
| `stats` | Conteos de comandos traducidos, omitidos y para revision manual |

## Pipeline de transpilacion

El transpilador trabaja en cuatro pasadas:

      archivo .do
         |
         v
      [1] parse_do_file()      -- tokenizar lineas en objetos de comando
         |
         v
      [2] translate_commands()  -- mapear cada comando STATA a steps de metasurvey
         |
         v
      [3] optimize_steps()      -- consolidar renames, drops, etc. consecutivos
         |
         v
      [4] Recipe / JSON         -- empaquetar steps con metadatos

### Pasada 1: Parsing

[`parse_do_file()`](https://metasurveyr.github.io/metasurvey/reference/parse_do_file.md)
lee un archivo `.do` y produce una lista de objetos de comando. Maneja:

- **Eliminacion de comentarios**: `*`, `//`, y bloques `/* */`
- **Continuacion de linea**: `///` y `/* */` usados como marcadores de
  continuacion
- **Expansion de loops**: `foreach` y `forvalues` se desenrollan,
  sustituyendo macros con backtick (`` `var' ``) con cada valor de
  iteracion
- **Manejo de prefijos**: `capture`, `bysort group:`, y abreviaciones de
  comandos (`g` por `gen`, `cap` por `capture`)

``` r

commands <- parse_do_file("demographics.do")
commands[[1]]
#> $cmd
#> [1] "gen"
#> $args
#> [1] "sex = e26"
#> $if_clause
#> NULL
#> $by_group
#> NULL
#> $capture
#> [1] FALSE
```

### Pasada 2: Traduccion de comandos

Cada comando parseado se mapea a una o mas cadenas de steps de
metasurvey. La siguiente tabla muestra los comandos de STATA soportados
y sus traducciones.

## Patrones soportados

### gen / generate

La creacion simple de variables se traduce a `step_compute`:

``` stata
gen sex = q01
gen is_urban = (region < 3)
gen byte age_group = -9
```

``` r

step_compute(svy, sex = q01)
step_compute(svy, is_urban = (region < 3))
step_compute(svy, age_group = -9L)
```

Cuando un `gen` incluye una clausula `if`, la condicion se envuelve en
`fifelse`:

``` stata
gen employed = hours_worked if age >= 14
```

``` r

step_compute(svy, employed = data.table::fifelse(age >= 14, hours_worked, NA))
```

### Cadenas gen + replace (el patron dominante)

El patron mas comun en archivos `.do` de encuestas es inicializar una
variable y luego completarla con reemplazos condicionales:

``` stata
gen relationship = -9
replace relationship = 1 if q05 == 1
replace relationship = 2 if q05 == 2
replace relationship = 3 if inrange(q05, 3, 5)
replace relationship = 4 if q05 == 6
```

Cuando **todos** los lados derechos son constantes, el transpilador
emite un unico `step_recode`:

``` r

step_recode(svy, relationship,
    q05 == 1 ~ 1L,
    q05 == 2 ~ 2L,
    q05 >= 3 & q05 <= 5 ~ 3L,
    q05 == 6 ~ 4L,
    .default = -9L)
```

Cuando algun lado derecho es una **expresion**, el transpilador emite
una cadena de `step_compute` con `fifelse`:

``` stata
gen labour_inc = 0
replace labour_inc = wage if job_type == 1
replace labour_inc = wage + bonus if job_type == 2
```

``` r

step_compute(svy, labour_inc = 0L)
step_compute(svy, labour_inc = data.table::fifelse(
    job_type == 1, wage, labour_inc))
step_compute(svy, labour_inc = data.table::fifelse(
    job_type == 2, wage + bonus, labour_inc))
```

### recode

STATA `recode` con mapeos entre parentesis o sintaxis inline:

``` stata
recode urban_filter (0=2)
recode edu_level (2=2) (3=-9) (4=3) (5=4), gen(edu_compat)
recode var1 var2 var3 .=0
```

``` r

step_compute(svy, urban_filter = data.table::fifelse(
    urban_filter == 0, 2, urban_filter))

step_compute(svy, edu_compat = edu_level)
step_compute(svy, edu_compat = data.table::fifelse(
    edu_compat == 2, 2, edu_compat))
# ... un fifelse por mapeo

# Recode multi-variable: un step por variable
step_compute(svy, var1 = data.table::fifelse(is.na(var1), 0, var1))
step_compute(svy, var2 = data.table::fifelse(is.na(var2), 0, var2))
step_compute(svy, var3 = data.table::fifelse(is.na(var3), 0, var3))
```

### egen (agregacion con by-groups)

``` stata
bysort household: egen hh_income = sum(income)
egen max_age = max(age), by(household)
```

``` r

step_compute(svy, hh_income = sum(income, na.rm = TRUE),
    .by = "household")
step_compute(svy, max_age = max(age, na.rm = TRUE),
    .by = "household")
```

Funciones `egen` soportadas: `sum`, `max`, `min`, `mean`, `count`, `sd`,
`median`, `total`, `rowtotal`, `rowmean`.

### Loops foreach

Los loops se expanden durante el parsing. El transpilador desenrolla
`foreach` tanto con listas `in` como con rangos `of numlist`, incluyendo
loops anidados:

``` stata
foreach i of numlist 1/4 {
    gen contrib`i' = 0
    replace contrib`i' = amount if provider == `i'
}
```

Se expande a 4 pares de gen+replace, cada uno transpilado
independientemente:

``` r

step_recode(svy, contrib1, provider == 1 ~ amount, .default = 0L)
step_recode(svy, contrib2, provider == 2 ~ amount, .default = 0L)
step_recode(svy, contrib3, provider == 3 ~ amount, .default = 0L)
step_recode(svy, contrib4, provider == 4 ~ amount, .default = 0L)
```

### mvencode (codificacion de valores faltantes)

``` stata
mvencode income_1 income_2 income_3, mv(0)
```

``` r

step_compute(svy, income_1 = data.table::fifelse(
    is.na(income_1), 0, income_1))
step_compute(svy, income_2 = data.table::fifelse(
    is.na(income_2), 0, income_2))
step_compute(svy, income_3 = data.table::fifelse(
    is.na(income_3), 0, income_3))
```

### destring

``` stata
destring wage bonus, replace force
```

``` r

step_compute(svy, wage = suppressWarnings(
    as.numeric(as.character(wage))))
step_compute(svy, bonus = suppressWarnings(
    as.numeric(as.character(bonus))))
```

### rename, drop, keep

``` stata
rename id hh_id
drop aux1 aux2 aux3
```

``` r

step_rename(svy, hh_id = "id")
step_remove(svy, aux1, aux2, aux3)
```

Los renames consecutivos se consolidan en una unica llamada a
`step_rename`, y los drops consecutivos se fusionan en un solo
`step_remove`.

### Traduccion de expresiones STATA

La sintaxis especifica de STATA en expresiones se traduce
automaticamente:

| STATA                | R (data.table)                             |
|----------------------|--------------------------------------------|
| `inrange(x, a, b)`   | `(x >= a & x <= b)`                        |
| `inlist(x, 1, 2, 3)` | `(x %in% c(1, 2, 3))`                      |
| `var == .`           | `is.na(var)`                               |
| `var != .`           | `!is.na(var)`                              |
| `.` (como valor)     | `NA`                                       |
| `string(var)`        | `as.character(var)`                        |
| `var[_n-1]`          | `data.table::shift(var, 1, type = "lag")`  |
| `var[_n+1]`          | `data.table::shift(var, 1, type = "lead")` |
| `_N`                 | `.N`                                       |

### Rangos de variables

STATA permite rangos de variables como `aux1-aux4` que significan
`aux1 aux2 aux3 aux4`. El transpilador los expande en comandos `drop`,
`recode` y `mvencode`:

``` stata
drop contrib1-contrib4
```

``` r

step_remove(svy, contrib1, contrib2, contrib3, contrib4)
```

### Etiquetas

Las etiquetas de variables y valores se extraen y almacenan en los
metadatos de la receta:

``` stata
lab var sex "Sex of respondent"
lab def sex_lbl 1 "Male" 2 "Female"
lab val sex sex_lbl
```

``` r

result$labels
#> $var_labels
#> $var_labels$sex
#> [1] "Sex of respondent"
#>
#> $val_labels
#> $val_labels$sex
#> $val_labels$sex$`1`
#> [1] "Male"
#> $val_labels$sex$`2`
#> [1] "Female"
```

## Comandos omitidos

Los comandos que no modifican datos de la encuesta se omiten
silenciosamente durante la transpilacion. Estos incluyen:

- E/S: `use`, `save`, `import`, `export`, `insheet`, `outsheet`
- Visualizacion: `tabulate`, `summarize`, `describe`, `list`, `browse`,
  `display`
- Flujo de control: `if`/`else`, `while`, `program`, `exit`
- Configuracion: `set`, `sort`, `order`, `compress`, `format`
- Macros: `global`, `local`, `scalar`, `matrix`

El elemento `$stats` del resultado reporta cuantos comandos cayeron en
cada categoria.

## Un ejemplo realista

El siguiente archivo `.do` es una version simplificada de un modulo
tipico de demografia de encuestas. No es un script de produccion real,
pero usa los mismos patrones encontrados en pipelines reales de
procesamiento de la ECH.

Guardar como `demo_module.do`:

``` stata
* ──────────────────────────────────────────────
* Modulo de demografia -- ejemplo simplificado
* ──────────────────────────────────────────────

rename id hh_id
rename nper person_id

gen weight_yr = pesoano
gen weight_qt = pesotri

* ── Sexo ──
gen sex = q01

* ── Relacion con el jefe de hogar ──
g relationship = -9
replace relationship = 1 if q05 == 1
replace relationship = 2 if q05 == 2
replace relationship = 3 if inrange(q05, 3, 5)
replace relationship = 4 if q05 == 6
replace relationship = 5 if q05 == 7

* ── Area ──
gen area = .
replace area = 1 if region == 1
replace area = 2 if region == 2
replace area = 3 if region == 3

* ── Nivel educativo (armonizado) ──
recode q20 (2=2) (3=-9) (4=3) (5=4), gen(edu_compat)

* ── Estadisticas de edad a nivel de hogar ──
bysort hh_id: egen max_age = max(edad)
bysort hh_id: egen n_members = count(person_id)

* ── Inicializar contribuciones de seguro de salud ──
foreach i of numlist 1/3 {
    gen contrib`i' = 0
    replace contrib`i' = amount if provider == `i'
}

* ── Codificar valores faltantes ──
mvencode contrib1 contrib2 contrib3, mv(0)

* ── Limpiar ──
drop region q01 q05 q20

* ── Etiquetas ──
lab var sex "Sexo"
lab var relationship "Relacion con el jefe de hogar"
lab def sex_lbl 1 "Hombre" 2 "Mujer"
lab val sex sex_lbl
lab def rel_lbl 1 "Jefe" 2 "Conyuge" 3 "Hijo" 4 "Otro familiar" 5 "No familiar"
lab val relationship rel_lbl
```

``` r

library(metasurvey)

# Escribir el archivo .do de ejemplo en una ubicacion temporal
# Nota: las macros de STATA usan backtick-quote (`var') que construimos con paste0
bt <- "`" # backtick
sq <- "'" # comilla simple
do_lines <- c(
  "rename id hh_id",
  "rename nper person_id",
  "gen weight_yr = pesoano",
  "gen weight_qt = pesotri",
  "gen sex = q01",
  "g relationship = -9",
  "replace relationship = 1 if q05 == 1",
  "replace relationship = 2 if q05 == 2",
  "replace relationship = 3 if inrange(q05, 3, 5)",
  "replace relationship = 4 if q05 == 6",
  "replace relationship = 5 if q05 == 7",
  "gen area = .",
  "replace area = 1 if region == 1",
  "replace area = 2 if region == 2",
  "replace area = 3 if region == 3",
  "recode q20 (2=2) (3=-9) (4=3) (5=4), gen(edu_compat)",
  "bysort hh_id: egen max_age = max(edad)",
  "bysort hh_id: egen n_members = count(person_id)",
  "foreach i of numlist 1/3 {",
  paste0("gen contrib", bt, "i", sq, " = 0"),
  paste0("replace contrib", bt, "i", sq, " = amount if provider == ", bt, "i", sq),
  "}",
  "mvencode contrib1 contrib2 contrib3, mv(0)",
  "drop region q01 q05 q20",
  'lab var sex "Sexo"',
  'lab var relationship "Relacion con el jefe de hogar"',
  'lab def sex_lbl 1 "Hombre" 2 "Mujer"',
  "lab val sex sex_lbl",
  'lab def rel_lbl 1 "Jefe" 2 "Conyuge" 3 "Hijo" 4 "Otro familiar" 5 "No familiar"',
  "lab val relationship rel_lbl"
)
do_file <- tempfile(fileext = ".do")
writeLines(do_lines, do_file)

result <- transpile_stata(do_file)
```

### Inspeccionando la salida

``` r

cat("Traducidos:", result$stats$translated, "\n")
#> Traducidos: 27
cat("Omitidos:  ", result$stats$skipped, "\n")
#> Omitidos:   6
cat("Manual:    ", result$stats$manual_review, "\n")
#> Manual:     0
```

``` r

# Imprimir los steps generados
for (s in result$steps) cat(s, "\n")
#> step_rename(svy, hh_id = "id", person_id = "nper") 
#> step_compute(svy, weight_yr = pesoano, weight_qt = pesotri, sex = q01) 
#> step_recode(svy, relationship,
#>     q05 == 1 ~ "1",
#>     q05 == 2 ~ "2",
#>     (q05 >= 3 & q05 <= 5) ~ "3",
#>     q05 == 6 ~ "4",
#>     q05 == 7 ~ "5",
#>     .default = "-9") 
#> step_compute(svy, area = NA, area = data.table::fifelse(region == 1, 1, area), area = data.table::fifelse(region == 2, 2, area), area = data.table::fifelse(region == 3, 3, area), edu_compat = q20, edu_compat = data.table::fifelse(q20 == 2, 2, edu_compat), edu_compat = data.table::fifelse(q20 == 3, -9, edu_compat), edu_compat = data.table::fifelse(q20 == 4, 3, edu_compat), edu_compat = data.table::fifelse(q20 == 5, 4, edu_compat)) 
#> step_compute(svy, max_age = max(edad, na.rm = TRUE), n_members = sum(!is.na(person_id)), .by = "hh_id") 
#> step_compute(svy, contrib1 = 0, contrib1 = data.table::fifelse(provider == 1, amount, contrib1), contrib2 = 0, contrib2 = data.table::fifelse(provider == 2, amount, contrib2), contrib3 = 0, contrib3 = data.table::fifelse(provider == 3, amount, contrib3), contrib1 = data.table::fifelse(is.na(contrib1), 0, contrib1), contrib2 = data.table::fifelse(is.na(contrib2), 0, contrib2), contrib3 = data.table::fifelse(is.na(contrib3), 0, contrib3)) 
#> step_remove(svy, region, q01, q05, q20)
```

### Etiquetas

``` r

str(result$labels$var_labels)
#> List of 2
#>  $ sex         : chr "Sexo"
#>  $ relationship: chr "Relacion con el jefe de hogar"
str(result$labels$val_labels)
#> List of 2
#>  $ sex         :List of 2
#>   ..$ 1: chr "Hombre"
#>   ..$ 2: chr "Mujer"
#>  $ relationship:List of 5
#>   ..$ 1: chr "Jefe"
#>   ..$ 2: chr "Conyuge"
#>   ..$ 3: chr "Hijo"
#>   ..$ 4: chr "Otro familiar"
#>   ..$ 5: chr "No familiar"
```

### Construir una Recipe a partir de los steps transpilados

``` r

rec <- Recipe$new(
  id = "example_demographics",
  name = "Demografia (transpilada)",
  user = "equipo_investigacion",
  edition = "2022",
  survey_type = "ech",
  default_engine = "data.table",
  depends_on = character(0),
  description = "Demografia armonizada desde transpilacion de STATA",
  steps = result$steps,
  labels = result$labels
)

# Guardar como JSON
save_recipe(rec, "demographics_recipe.json")

# Aplicar a datos de encuesta
svy <- survey_empty(type = "ech", edition = "2022") |>
  set_data(my_data) |>
  add_recipe(rec) |>
  bake_recipes()
```

## Transpilacion a nivel de modulo

Para proyectos que organizan archivos `.do` por anio y modulo tematico,
[`transpile_stata_module()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata_module.md)
procesa un directorio de un anio completo y agrupa los resultados en
objetos Recipe separados:

``` r

recipes <- transpile_stata_module(
  year_dir = "do_files/2022",
  year = 2022,
  user = "equipo_investigacion",
  output_dir = "recipes/"
)

names(recipes)
#> [1] "data_prep"        "demographics"     "income_detail"
#> [4] "income_aggregate" "cleanup"

# Cada receta tiene dependencias inter-modulo
recipes$income_detail$depends_on_recipes
#> [1] "ech_2022_data_prep"    "ech_2022_demographics"
```

## Analisis de cobertura

[`transpile_coverage()`](https://metasurveyr.github.io/metasurvey/reference/transpile_coverage.md)
reporta cuantos comandos en un archivo `.do` (o directorio) pueden
transpilarse automaticamente:

``` r

transpile_coverage("do_files/")
#>                               file total translated skipped manual coverage
#> 1   2022/2_correc_datos.do             82        60      22      0   100.00
#> 2   2022/3_compatibiliz...do          420       380      40      0   100.00
#> 3   2022/4_ingreso_ht11...do          310       270      40      0   100.00
```

La columna `coverage_pct` reporta el porcentaje de comandos **que
transforman datos** que fueron traducidos (excluyendo comandos no-datos
omitidos). Un valor por debajo de 100% significa que algunos comandos
necesitan revision manual – consultar el elemento `$warnings` para
detalles.

## Limitaciones

El transpilador **no** maneja:

- Comandos `merge` (dependen de archivos externos y se traducen como
  comentarios con `# MANUAL_REVIEW`)
- `collapse` / `reshape` (transformaciones estructurales de datos)
- Definiciones de `program` personalizados
- Bloques `mata` o llamadas a `plugin`
- Comentarios de bloque `/* */` anidados que contienen continuaciones de
  linea `/* */` internamente (raro; solo visto en codigo legacy
  comentado)

Los comandos que quedan fuera del alcance del transpilador se marcan con
`# MANUAL_REVIEW` en la salida y se cuentan en `$stats$manual_review`.

## Resumen

| Funcionalidad | Estado |
|----|----|
| gen / generate | Completamente soportado |
| replace (condicional) | Completamente soportado |
| Cadenas gen + replace | Auto-agrupadas en step_recode o step_compute |
| recode (simple y multi-variable) | Completamente soportado |
| egen con by-groups | Completamente soportado |
| foreach / forvalues | Expandidos durante el parsing |
| mvencode | Completamente soportado |
| destring / tostring | Completamente soportado |
| rename / drop / keep | Completamente soportado |
| Etiquetas de variables y valores | Extraidas a metadatos de la receta |
| Expresiones STATA | inrange, inlist, missing, lag/lead, \_N |
| Rangos de variables | Expandidos (ej., var1-var4) |
| Loops anidados | Expansion recursiva |
| Continuacion de linea (///) | Unidas durante el parsing |
| Prefijo capture | Manejado (errores suprimidos) |
| Prefijo bysort | Convertido a parametro .by |
