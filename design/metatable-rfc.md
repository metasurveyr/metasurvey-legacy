# RFC: metatable — motor de planes lazy con optimizador para el pipeline de steps

- **Issue**: #214
- **Estado**: Draft
- **Alcance**: diseño únicamente. Este documento NO implementa el motor; define
  estructuras, reglas, contratos y el plan de PRs incrementales.
- **Base de código citada**: `main` v0.1.0 (commit `881a8b35`). Todas las
  referencias `archivo:línea` corresponden a ese commit.

---

## 1. Restricción rectora: la API del usuario NO cambia

`metatable` es un motor **interno**. Ninguna función exportada cambia de firma
ni de semántica observable:

| Superficie pública | Comportamiento con `metatable` |
|---|---|
| `step_compute()`, `step_recode()`, `step_join()`, `step_remove()`, `step_rename()`, `step_filter()`, `step_validate()`, `step_weight()` | Misma firma, mismo valor de retorno, mismos errores/warnings de validación (`validate_step()`, `R/Step.R:134-152`) |
| `bake_steps()` (`R/Step.R:361-371`) | Misma firma; internamente construye y ejecuta un plan en vez de iterar `bake_step()` |
| `bake_recipes()` (`R/survey.R:1118-1200`) | Misma firma; los steps de la receta se registran y se ejecutan como plan |
| `workflow()` (`R/workflow.R:111-126`) | Misma firma; puede actuar como *sink* que informa poda de proyección |
| `get_data()`, `get_steps()`, `view_graph()`, provenance | Idénticos (ver §5 contrato del executor) |

**Activación**: exclusivamente vía la opción de engine que ya existe:

```r
options(metasurvey.engine = "metatable")   # o set_engine("metatable")
```

- `get_engine()` lee `Sys.getenv("metasurvey.engine") %@% getOption(...)`
  (`R/set_engine.R:84-87`).
- `set_engine()` valida contra la whitelist `show_engines()`
  (`R/set_engine.R:66-72`): hay que agregar `"metatable"` ahí.
- Default actual (`"data.table"`) intacto hasta que el motor madure.

**Única superficie nueva (aditiva)**: `explain(svy)`, que imprime el plan
(grupos narrow fusionados, barreras wide, columnas podadas, filtros movidos).
No altera estado.

### 1.1 Punto de intercepción y semántica del modelo mixto actual

El modelo de ejecución vigente es **mixto** (documentado en los `@details` de
cada step y en CLAUDE.md):

- **Eager en la creación** (`bake = TRUE` al registrarse): `step_compute`
  (llama `compute(..., lazy = FALSE)` en `R/steps.R:353-357` y `R/steps.R:396`),
  `step_recode` (`recode(..., lazy = FALSE)` en `R/steps.R:703-710` y
  `R/steps.R:730-737`), `step_join` (el merge corre en `R/steps.R:1062-1070` y
  el Step se registra con `bake = TRUE`, `R/steps.R:1120`).
- **Diferidos hasta `bake_steps()`** (`bake = FALSE`): `step_filter`
  (`R/steps.R:1656`), `step_validate` (`R/steps.R:1572`).
- **Según `lazy_default()`** (`bake = !lazy`): `step_remove`
  (`R/steps.R:1275`), `step_rename` (`R/steps.R:1430`), `step_weight`
  (`R/steps.R:1854`).

`bake_steps_survey()` (`R/Step.R:409-469`) recorre `svy$steps` en orden,
**saltea** los que tienen `bake = TRUE` (`R/Step.R:167-169`) y ejecuta el
resto vía `bake_step()`, registrando provenance por step (`n_before`,
`n_after`, `duration_ms`; `R/Step.R:428-437`).

Consecuencia clave para el diseño: **el usuario puede observar los datos entre
steps** (`get_data()` tras un `step_compute` eager devuelve la columna nueva).
Por lo tanto `metatable` NO puede convertir los steps eager en lazy en uso
interactivo sin cambiar semántica observable. El plan se construye y ejecuta
**solo en las ventanas donde ya existe un lote de trabajo diferido y ningún
observador intermedio**:

1. **`bake_steps()`**: los steps pendientes (`bake = FALSE`) acumulados forman
   el plan. Es la ventana natural: entre el registro y el bake nadie observó
   el efecto de esos steps (por definición siguen pendientes).
2. **`bake_recipes()`**: la ventana más rentable. Hoy fuerza
   `options(metasurvey.lazy_processing = FALSE)` (`R/survey.R:1132-1134`) y
   evalúa cada call registrado de la receta (`R/survey.R:1171-1183`), es decir
   una pasada completa sobre los datos por step (15-30 pasadas en un pipeline
   UMAD típico). Con `metatable`, en su lugar: registrar todos los steps de
   todas las recetas como pendientes (forzar `lazy = TRUE` para
   remove/rename/weight; compute/recode/join pasan a registrarse sin ejecutar
   **solo dentro de esta ventana**), construir el plan, optimizar, ejecutar,
   marcar `bake = TRUE`. Una receta es un pipeline cerrado: nadie observa
   estados intermedios entre sus steps.
3. **`workflow()` sobre un survey con recetas sin hornear** (patrón
   `add_recipe() |> workflow()`, y `harmonize()` que llama `bake_recipes()` en
   `R/harmonize.R:221`): además habilita poda de proyección porque el
   consumidor final es conocido (§4.2).

Fuera de esas ventanas (uso interactivo step a step), `metatable` se comporta
igual que el motor actual: los eager ejecutan al crearse. No hay regresión ni
cambio observable; simplemente no hay nada que optimizar.

---

## 2. Estructuras del plan lógico

El DAG lógico ya existe: cada `Step` (R6, `R/Step.R:57-123`) almacena `type`,
`exprs`, `call`, `depends_on` (capturado con `all.vars()` menos
`collect_assigned_vars()`, `R/steps.R:7-24` y `R/steps.R:336-338`), `by_vars`,
`recode_opts` y `bake`. `metatable` no agrega campos a `Step`: construye un
plan *aparte* a partir de la lista de steps pendientes.

### 2.1 `meta_plan` y `meta_node`

Listas base R con clase S3 (sin R6: el plan es un valor inmutable y efímero;
sin rlang: toda la metaprogramación es `substitute`/`bquote`/`eval` base).

```r
# Un nodo del plan por Step pendiente
meta_node <- structure(
  list(
    step_idx   = 3L,            # índice en svy$steps (trazabilidad/provenance)
    step       = <Step>,        # referencia al Step original (no se clona)
    kind       = "narrow",      # "narrow" | "wide" | "filter" | "fence" | "meta"
    produces   = c("age2"),     # columnas que crea/modifica (de new_var/exprs)
    consumes   = c("age"),      # step$depends_on (+ by_vars + claves de join)
    row_effect = "none",        # "none" | "subset" | "reshape" (join/full)
    group_vars = NULL           # step$by_vars si aplica
  ),
  class = "meta_node"
)

meta_plan <- structure(
  list(
    nodes    = list(<meta_node>, ...),  # orden = orden efectivo de ejecución
    sinks    = NULL,                    # columnas requeridas aguas abajo o NULL (= todas)
    schedule = list(),                  # llenado por el optimizador: lista de
                                        # "pass groups" (§4.1) y anotaciones
    stats    = list()                   # para explain(): fusiones, podas, pushdowns
  ),
  class = "meta_plan"
)
```

`produces` se deriva de lo que ya registra cada step: `new_var` en
compute/recode (`R/steps.R:367`, `R/steps.R:717`), `mapping` en rename
(`R/steps.R:1424`), `vars` en remove (`R/steps.R:1269`), `weight_var` en
step_weight (`R/steps.R:1848`). Para join, `produces` = columnas del RHS
(conocidas en el registro: `exprs$x`, `R/steps.R:1112`).

### 2.2 Clasificación narrow/wide: tabla exacta

Criterio: un step es **narrow** si su efecto sobre cada fila depende solo de
esa fila (conmuta con selección de filas y es fusable en una sola pasada
`data.table`); es **wide** si depende del conjunto de filas (agregación, join,
alineación externa); **filter** selecciona filas; **fence** observa o exige un
estado global exacto (nada puede moverse a través); **meta** solo toca el
esquema (sin pasada sobre los datos).

| Step / variante | Código que lo ejecuta | Clase | Por qué |
|---|---|---|---|
| `step_compute` sin `.by` | `compute()`, rama `else`: un solo `.data[, (names) := .exprs]` (`R/steps.R:79-84`) | **narrow** | Asignación fila a fila con `:=`; fusable con vecinos narrow |
| `step_compute` con `.by` | `compute()`, rama `.by`: agrega con `by` y hace `merge(.data, .agg, by = .by, all.x = TRUE)` (`R/steps.R:67-77`) | **wide** | El resultado depende del grupo completo → depende del conjunto de filas vigente. Además el `merge` (sort por defecto en `merge.data.table`) **reordena las filas por las claves `.by`**: efecto colateral observable que el executor debe reproducir (§5) |
| `step_recode` | `recode()`: asigna `.default` y luego un loop first-match-wins con máscara `.assigned` (`R/steps.R:159-176`) | **narrow** | Cada fila se decide con sus propios valores. Internamente hace k+1 sub-pasadas (una por condición), pero es row-local: no corta un grupo de fusión. v1 lo ejecuta tal cual dentro del grupo; v2 puede compilarlo a una cascada `fifelse`/`fcase` (§4.1) |
| `step_join` | merge en `step_join()` con `sort = FALSE` + relleno de pesos NA con 1 (`R/steps.R:1062-1092`) | **wide** | Cambia multiplicidad de filas (inner/right/full), el set de columnas, y muta pesos. `row_effect = "reshape"` |
| `step_remove` | `data.table::set(out$data, j = cols, value = NULL)` (`R/steps.R:1248-1260`) | **meta** | Solo esquema; costo O(1). En el plan actúa como anti-dependencia: nada que consuma la columna puede quedar después |
| `step_rename` | `data.table::setnames()` (`R/steps.R:1406-1409`) | **meta** | Solo esquema. El planner aplica el mapping a `consumes`/`produces` de los nodos posteriores para el análisis de dependencias |
| `step_filter` sin `.by` | `filter_rows()`: condiciones combinadas con AND, `.data[eval(combined, ...)]` (`R/steps.R:204-221`) | **filter** | Selección de filas; conmuta con narrow (guardas en §4.3), nunca con wide |
| `step_filter` con `.by` | `.data[, .SD[eval(combined, .SD)], by = .by]` (`R/steps.R:217-219`) | **wide** | La condición puede ser grupal (p. ej. `n() > 1` idiomático); además `by=` reagrupa y reordena la salida |
| `step_validate` | `bake_validate()`: evalúa checks contra el estado actual, sin mutar (`R/Step.R:274-329`) | **fence** | Observa el estado exacto (incluye `.min_n` = conteo de filas, `R/Step.R:281-293`). Mover un filter a través de un validate cambia qué datos se validan → prohibido |
| `step_weight` | `weightflow::prep()` + `collect_weights()`, exige `nrow(data) == length(weights)` (`R/steps.R:1798-1822`) | **fence** | Alineación posicional con datos externos; el roxygen ya exige llamarlo antes de cualquier filtro (`R/steps.R:1731-1734`). Además muta `svy$weight` y `design_initialized` (`R/steps.R:1828-1837`) |

Los nodos **fence** parten el plan: el optimizador trabaja de forma
independiente en cada segmento entre fences.

---

## 3. Construcción del plan

```
build_plan(steps_pendientes, sinks = NULL):
  nodes <- []
  rename_map <- identidad
  for (i, step) in enumerate(steps_pendientes):
    node <- classify(step)                # tabla §2.2
    node$consumes <- rename_map(step$depends_on ∪ step$by_vars ∪ join_keys(step))
    node$produces <- rename_map(outputs(step))
    if (step$type == "step_rename") rename_map <- rename_map ∘ step$mapping
    nodes.append(node)
  return meta_plan(nodes, sinks)
```

El orden de `nodes` es el orden en que el motor actual los ejecutaría dentro
del bake (orden de registro, salteando `bake = TRUE`), es decir la semántica
de `bake_steps_survey()` (`R/Step.R:420-438`). Ese orden es la **referencia
semántica**: toda transformación del optimizador debe probar equivalencia
contra él.

---

## 4. Reglas del optimizador

Tres reglas, aplicadas en este orden dentro de cada segmento entre fences:
(1) pushdown de filtros, (2) poda de proyección, (3) fusión de narrow.
El orden importa: el pushdown reduce filas para los narrow; la poda reduce
columnas antes de decidir qué exprs entran a la fusión.

### 4.1 Fusión de cadenas narrow consecutivas

Una corrida maximal de nodos narrow (y meta) entre dos barreras se ejecuta en
**una sola pasada** `data.table` con evaluación secuencial, para que cada
expresión pueda referenciar columnas creadas por la anterior (patrón habitual:
`step_compute(a = ...) |> step_compute(b = f(a))`).

```
fuse_narrow(segment):
  groups <- particionar(segment, cortar_en = kind ∈ {wide, filter, fence})
  for g in groups donde count(narrow) >= 2:
    # una sola llamada a `[`, j evalúa las exprs en orden dentro de un env
    # respaldado por .SD — sin copias intermedias, un solo paso de
    # [.data.table (allocación de columnas en bloque via `:=`)
    emit pass_group(g)
```

Ejecución del pass group (esbozo del executor):

```r
# pseudocódigo del executor para un grupo fusionado
.data[, (all_outputs) := {
  # env secuencial: cada expr ve las salidas de las previas
  e1 <- eval(expr_1, .SD_plus_prev)
  e2 <- eval(expr_2, env(.SD, e1 = e1))
  ...
  list(e1, e2, ...)
}]
```

Notas de fidelidad:

- `compute()` hoy evalúa `.exprs <- eval(.exprs, .data)` y asigna con `:=`
  (`R/steps.R:79-84`). La fusión produce exactamente los mismos vectores: la
  evaluación es la misma, solo cambia cuántas veces se entra a `[.data.table`.
- Los `recode` dentro del grupo se ejecutan con su algoritmo actual
  (default + loop first-match-wins, `R/steps.R:143-176`) para garantizar
  byte-identidad en v1: siguen dentro del grupo (no cortan la fusión de los
  compute vecinos) pero como sub-bloque propio. La compilación de recode a
  `fcase()` queda para una versión posterior, con el mismo oráculo.
- Los nodos meta (rename/remove) se ejecutan en su posición relativa
  (son O(1); no hay ganancia en moverlos y sí riesgo).
- El entorno de evaluación replica el actual: `compute()` evalúa contra
  `.data` sin `parent.frame()` explícito; `recode()` sí pasa `.penv`
  (`R/steps.R:111`, `R/steps.R:121`). El executor debe conservar cada
  disciplina de scoping tal cual.

### 4.2 Poda de proyección transitiva

Solo activa cuando el consumidor es conocido (`sinks != NULL`), es decir en la
ventana `workflow()`/`harmonize()` donde el survey materializado es transitorio
y lo único observable es la tabla de estimaciones:

- `workflow_default()` evalúa calls `survey::svymean(~x, ...)` contra
  `survey$design[[estimation_type]]` (`R/workflow.R:141-168`). Los sinks se
  extraen con `all.vars()` sobre `.calls` (fórmulas y argumentos `by=` de
  `svyby`).
- A eso se suman siempre las columnas estructurales del diseño: pesos
  (`svy$weight`), `psu`, `strata` — las que consume `ensure_design()`.

```
prune_projection(plan):
  if (plan$sinks is NULL) return plan          # sin consumidor conocido: no podar
  live <- plan$sinks ∪ design_vars(svy)
  for node in reverse(plan$nodes):
    if (node$produces ∩ live == ∅ and node es narrow puro):
      marcar node como podado                   # no se evalúa
    else:
      live <- (live \ node$produces) ∪ node$consumes
  # nunca se podan nodos wide/filter/fence: tienen efectos sobre filas
```

En `bake_steps()`/`bake_recipes()` "sueltos" (el usuario se queda con el
survey y puede llamar `get_data()`), `sinks = NULL` y **no se poda nada**: el
set de columnas resultante es observable y debe ser idéntico al motor actual.
`explain(svy)` reporta qué se habría podado.

### 4.3 Pushdown de filtros con guarda semántica

Mover un nodo filter hacia arriba (antes) reduce las filas sobre las que
corren los narrow siguientes. Guardas:

```
pushdown_filter(segment):
  for f in nodos filter (kind == "filter"), en orden:
    pos <- índice de f
    while pos > primer índice del segmento:
      prev <- nodo en pos - 1
      if (prev$kind ∈ {wide, fence, filter-con-.by}): break      # G1: barrera dura
      if (prev$kind == "filter"): break                          # G2: no reordenar filtros entre sí
      if (f$consumes ∩ prev$produces != ∅): break                # G3: dependencia de datos
      if (prev$kind == "meta" and afecta nombres de f$consumes): break  # G4: rename/remove
      swap(prev, f); pos <- pos - 1
```

**G1 es la guarda del caso trampa** detectado en la revisión intensiva
(pilotos UMAD): `step_filter(...)` seguido o precedido de
`step_compute(..., .by = ...)`.

**Caso trampa (documentación obligatoria).** En el motor actual:

```r
svy |>
  step_filter(edad >= 14) |>                       # diferido (bake = FALSE)
  step_compute(ing_prom = mean(ingreso), .by = "dpto")  # eager (corre YA)
```

El compute grupal corre **al crearse**, sobre los datos SIN filtrar (el filter
sigue pendiente); recién en `bake_steps()` corre el filter, y el compute se
saltea por `bake = TRUE` (`R/Step.R:167-169`). Semántica observada del motor
actual: `ing_prom` = media por depto **sobre toda la población**. Esa es la
semántica que `metatable` debe reproducir byte a byte, aunque sea
sorprendente. Dos implicaciones:

1. Cuando el plan incluye un compute `.by` que en el motor actual fue eager y
   un filter registrado antes que él, el **orden efectivo** de referencia es
   `compute(.by)` primero, `filter` después (así lo produce hoy la mezcla
   eager/diferido). `build_plan()` debe construir el orden efectivo, no el
   orden textual del usuario. En la ventana `bake_recipes()` con registro
   diferido total, el orden efectivo se calcula con la misma regla:
   los tipos eager del motor actual se ordenan entre sí por registro y
   preceden a los diferidos del mismo tramo.
2. Aunque el filtro no consuma la salida del compute `.by` (G3 no dispara),
   cruzarlo cambiaría los grupos de agregación → resultados distintos. Por
   eso G1 prohíbe cruzar **cualquier** wide, sin excepción por análisis de
   dependencias. Un filter jamás cruza un `.by`, un join, un validate ni un
   step_weight, en ninguna dirección.

Fidelidad adicional del pushdown: filtrar antes de un narrow produce las
mismas filas y los mismos valores (row-local ⇒ conmuta con subsetting), y
`filter_rows()` preserva el orden relativo de las filas (subset simple,
`R/steps.R:220`). El único delta posible son atributos internos de data.table
(índices, `sorted`); el contrato §5 exige normalizarlos o verificarlos.

---

## 5. Contrato del executor

**Regla de oro: byte a byte idéntico al motor actual.** Formalmente, para todo
survey `s` y toda secuencia de llamadas de la API pública, con
`metasurvey.engine = "metatable"`:

1. `identical(get_data(s_dt), get_data(s_mt))` — mismos valores, mismos tipos,
   mismo orden de columnas, **mismo orden de filas** (incluido el reordenado
   por el `merge` del compute `.by`, §2.2), mismos niveles y `ordered` de
   factores (`recode_opts`, `R/Step.R:186-217`), mismos atributos (claves e
   índices de data.table normalizados con `setattr`/`setindex(NULL)` si hace
   falta).
2. Mismos errores y warnings, con los mismos mensajes y en el mismo orden de
   step (`validate_step()`, checks de `step_validate`, warning de
   `step_remove` sobre columnas inexistentes `R/steps.R:1240-1245`).
3. Mismo resultado de `workflow()`: los `svystat` se calculan sobre un diseño
   construido con los mismos datos ⇒ estimaciones, SE, CI y CV idénticos a
   todos los decimales.
4. **Provenance**: `bake_steps_survey()` registra por step `n_before`,
   `n_after`, `expression`, `duration_ms` (`R/Step.R:428-437`). El executor
   sintetiza una entrada por step aunque el step haya corrido dentro de un
   grupo fusionado: para narrow `n_before == n_after` (no cambian filas) así
   que los conteos son exactos; `duration_ms` se reparte por grupo (ya es
   no-determinista entre corridas, no forma parte del contrato byte a byte).
   `steps[[i]]$bake <- TRUE` se marca igual que hoy.
5. `update_design()` al final del bake, igual que hoy (`R/Step.R:439`,
   `R/Step.R:466`).

**Oráculo de verificación** (criterios de aceptación del issue):

- La suite completa (3000+ tests, testthat ed. 3) corrida con ambos engines.
  Mecanismo: en CI, un job adicional con
  `MS_TEST_ENGINE=metatable Rscript -e 'devtools::test()'` y un hook en
  `tests/testthat/helper-survey.R` que haga
  `options(metasurvey.engine = Sys.getenv("MS_TEST_ENGINE", "data.table"))`.
  FAIL 0 en ambos.
- Tests diferenciales dedicados (`test-metatable-parity.R`): pipelines
  generados que mezclan todos los tipos de step (incluido el caso trampa
  filter+compute(.by), joins con sufijos, recodes con `.default` no literal)
  ejecutados con los dos engines y comparados con `identical()` sobre
  `get_data()` y sobre el resultado de `workflow()`.
- **Pilotos UMAD**: los 4 pipelines reales (ECH 2023, `afamp.R` y compañía)
  con valores exactos a 7-8 decimales entre engines. Corren con
  `skip_on_cran()` + `skip_if_not(file.exists(...))` contra
  `example-data/ech/ech_2023/`.
- Benchmark ECH 2023 (~100k × 500): pipeline de 20+ steps; objetivo ≥2×
  menos pasadas sobre los datos (métrica primaria: pasadas contadas por el
  plan, reportadas por `explain()`; secundaria: tiempo y memoria con `bench`).

---

## 6. Plan de implementación incremental (PRs chicos)

Cada PR deja la suite verde **en ambos engines** (mientras el engine
`metatable` no ejecute distinto, la paridad es trivial; a medida que se
activan reglas, la paridad es el gate).

| PR | Contenido | Riesgo |
|---|---|---|
| 1 | `show_engines()` + `"metatable"`; estructuras `meta_plan`/`meta_node`; `classify()` con la tabla §2.2; `build_plan()`; `explain(svy)` imprimiendo el plan sin ejecutar nada. Ningún cambio de ejecución | Nulo |
| 2 | Executor **passthrough**: con engine `metatable`, `bake_steps()` construye el plan y lo ejecuta nodo a nodo delegando en `bake_step()` actual. Paridad trivial + infraestructura de tests diferenciales + job CI dual-engine | Bajo |
| 3 | Regla de fusión narrow (§4.1) para compute sin `.by`; recode entra al grupo como sub-bloque sin recompilar. Benchmark inicial | Medio |
| 4 | Ventana `bake_recipes()`: registro diferido total dentro de la receta + orden efectivo (§4.3, implicación 1) + ejecución por plan. Es el PR de mayor ganancia (15-30 pasadas → pocas) | Alto: aquí vive el caso trampa; tests de orden efectivo exhaustivos |
| 5 | Pushdown de filtros con guardas G1-G4 (§4.3) | Medio |
| 6 | Poda de proyección en la ventana `workflow()`/`harmonize()` (§4.2) | Medio |
| 7 | Pilotos UMAD como tests de integración dual-engine + benchmark ECH 2023 documentado + vignette corta de `explain()` | Bajo |
| 8 | (Opcional) compilar recode a `fcase()` dentro del grupo fusionado, con el mismo oráculo | Medio |

Cada PR: rama propia, `Refs #214`, sin tocar NEWS.md/DESCRIPTION hasta el
merge de la serie.

---

## 7. Fase 2: Arrow/DuckDB detrás de la misma opción de engine

Cuando el motor `metatable` esté maduro, el plan lógico (que es
engine-agnóstico: nodos con exprs base R + clasificación) habilita backends
out-of-core para la ECH panel completa multi-año:

- `options(metasurvey.engine = "metatable.arrow")` /
  `"metatable.duckdb"` — mismos valores en la whitelist de `show_engines()`,
  cero superficie nueva.
- **Traducción**: los grupos narrow fusionados se traducen a expresiones del
  backend (Arrow compute kernels / SQL generado por deparse + tabla de
  traducción de funciones base R soportadas). Sin rlang: la traducción es un
  walker recursivo sobre el AST (`is.call`/`is.name`, como
  `find_dependencies()` en `R/steps.R:2425-2442`).
- **Fallback obligatorio**: cualquier nodo no traducible (recode complejo,
  `step_weight`, funciones R arbitrarias en compute) fuerza `collect()` a
  data.table para ese segmento y continúa con el motor de Fase 1. El contrato
  §5 no se relaja: paridad byte a byte o el nodo no se traduce.
- **Límite conocido**: `workflow()` siempre colecta antes de `svydesign` — el
  paquete `survey` necesita los datos en memoria. La ganancia de Fase 2 está
  en el pipeline de steps (proyección/filtros empujados al scan del archivo),
  no en la estimación.
- Queda en issue aparte; este RFC solo garantiza que las estructuras de §2
  no asumen data.table en el IR (las exprs se guardan sin evaluar, la
  clasificación es semántica, no sintáctica).

---

## 8. Riesgos y alternativas descartadas

### Riesgos

| Riesgo | Mitigación |
|---|---|
| Semántica del modelo mixto mal replicada en el orden efectivo (§4.3, implicación 1) — es el riesgo #1 | PR 4 aislado; tests de orden efectivo generados combinatoriamente; los pilotos UMAD ya contienen el caso trampa real |
| Atributos data.table divergentes (claves, índices, `selfref`) rompen `identical()` sin diferencia de valores | Normalización explícita post-ejecución + comparador del test differencial que reporte el atributo exacto |
| Scoping de evaluación distinto en la fusión (compute evalúa contra `.data`; recode usa `parent.frame()` del registro, `R/steps.R:111`) | El executor conserva la disciplina por tipo de nodo; tests con variables del entorno del caller (`.default` vía variable, ya cubierto por `recode_opts` `R/Step.R:186-195`) |
| `bake_recipes()` diferido cambia mensajes/errores de orden (deps validadas por receta antes de ejecutar, `R/survey.R:1139-1151`) | La validación de deps de recetas se mantiene previa al plan, idéntica; los errores de step se emiten en orden de nodo |
| Overhead del planner en pipelines chicos (3 steps, 1k filas) | El planner es O(n·cols) sobre metadatos; passthrough si `length(nodes) < 2` o no hay regla aplicable |
| Deriva entre engines a futuro (nuevos steps que se olvidan de clasificar) | `classify()` falla con error explícito ante `type` desconocido (mismo patrón que la whitelist de `bake_step()`, `R/Step.R:220-230`); el job CI dual-engine es permanente |

### Alternativas descartadas

- **Adoptar dtplyr / dbplyr como capa lazy**: dependen de rlang, prohibido en
  este paquete; además su unidad de optimización es el verbo dplyr, no el
  `Step` con `depends_on` que ya tenemos.
- **Volver todo lazy por defecto (sin ventanas)**: rompe la observabilidad de
  `get_data()` entre steps y cambia la semántica del modelo mixto documentada
  en los roxygen de v0.1.0. Requeriría materialización implícita en cada
  accessor (flush-on-read), con superficie de bugs enorme y sin ganancia
  adicional: las ventanas §1.1 capturan los lotes reales (recetas, bakes).
- **Resucitar el AST engine** (`R/ast.R`, removido en v0.0.5): reescribía
  expresiones del usuario; el enfoque actual no reescribe nada — reordena y
  agrupa nodos cuyo contenido se evalúa igual que hoy. Menos poder, mucho
  menos riesgo.
- **Cambiar la semántica del caso trampa "de paso"** (que el compute `.by`
  vea los datos filtrados): es probablemente lo que el usuario espera, pero
  viola la restricción rectora (semántica observable idéntica) y el oráculo
  de 3000+ tests. Si se decide cambiarla, es un issue aparte con deprecación
  explícita, nunca un efecto colateral del motor.
- **Optimizar dentro de `[.data.table` con `verbose`/NSE profundo**: frágil
  ante versiones de data.table; el plan opera un nivel arriba (cuántas veces
  se entra a `[`), que es donde está el costo medido (15-30 pasadas).
