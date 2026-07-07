# Building an ECH Demographics Recipe

## Two paths: transpile fast or build right

metasurvey offers two ways to create recipes from existing STATA code:

1.  **Transpile automatically** with
    [`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md)
    – converts `.do` files to recipes in seconds. Great for migrating
    legacy code quickly (see
    [`vignette("stata-transpiler")`](https://metasurveyr.github.io/metasurvey/articles/stata-transpiler.md)).
2.  **Build from scratch** in R – more work upfront, but the result is
    cleaner, uses proper R idioms, and you control every detail.

The transpiler is a pragmatic shortcut: it reads hundreds of lines of
STATA and produces a working recipe, but the output inherits the
original code’s structure – long `gen`/`replace` chains become long
`step_recode` calls, temporary variables survive, and STATA-specific
patterns (like `mvencode`) get translated literally rather than
rethought.

A hand-crafted recipe, on the other hand, lets you **redesign the
logic** in R from the ground up. You pick meaningful variable names,
combine related transformations into a single step, and skip
intermediate variables that only existed because STATA needed them. The
result is shorter, easier to read, and easier to maintain.

This vignette builds a demographics recipe from scratch in about 20
lines of R. A transpiled version of the same pipeline would take 80+
steps and carry over variable names like `bc_pe2` and `bc_pe3` that mean
nothing outside the original `.do` file.

## Setting up the survey

We start with an empty Survey object. This declares the survey type and
edition without loading any data yet – the recipe will work on whatever
data we feed it later.

``` r

library(metasurvey)

svy <- survey_empty(type = "ech", edition = "2023")
svy
```

Now let’s attach some sample data. In production this would come from
`anda_download_microdata("2023")` or a local file; here we simulate it.

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

## Building the pipeline

Every transformation is a **step**. Data steps (`step_compute`,
`step_recode`, `step_join`) execute when created and are recorded in the
pipeline; `step_rename` and `step_remove` are deferred by default until
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md).
The recorded pipeline is what lets you inspect, document, and reuse
every transformation.

Compare this with the transpiler approach:
[`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md)
would produce one step per STATA command, faithfully preserving every
`gen` and `replace`. Here we think in terms of the *output variables* we
want, not the commands we need to type.

### Rename identifiers

``` r

svy <- svy |>
  step_rename(
    hh_id = "id", person_id = "nper",
    comment = "Standardize identifiers"
  )
```

Nothing happened to the data yet: `step_rename` is deferred by default
([`lazy_default()`](https://metasurveyr.github.io/metasurvey/reference/lazy_default.md)
is `TRUE`) until
[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md):

``` r

names(get_data(svy))[1:4]
```

The original column names are still there because the step is pending.
The recodes that follow, by contrast, execute when created. Let’s keep
adding steps.

### Recode sex

In STATA this would be a `gen` + `replace` + `replace` sequence (3
commands). With `step_recode` it’s a single, declarative mapping that
produces human-readable labels:

``` r

svy <- svy |>
  step_recode(sex,
    e26 == 1 ~ "Male",
    e26 == 2 ~ "Female",
    .default = NA_character_,
    comment = "Sex from e26"
  )
```

### Age groups

The STATA equivalent uses five `replace` lines with
[`inrange()`](https://rdrr.io/pkg/data.table/man/between.html). Here we
write the same logic as a single recode with readable conditions:

``` r

svy <- svy |>
  step_recode(age_group,
    e27 >= 0 & e27 <= 13 ~ "Child",
    e27 >= 14 & e27 <= 17 ~ "Adolescent",
    e27 >= 18 & e27 <= 29 ~ "Young adult",
    e27 >= 30 & e27 <= 64 ~ "Adult",
    e27 >= 65 ~ "Elderly",
    .default = NA_character_,
    comment = "Age groups from e27"
  )
```

### Relationship to head of household

``` r

svy <- svy |>
  step_recode(relationship,
    e30 == 1 ~ "Head",
    e30 == 2 ~ "Spouse",
    e30 >= 3 & e30 <= 5 ~ "Child",
    e30 == 6 ~ "Other relative",
    e30 == 7 ~ "Non-relative",
    .default = "Unknown",
    comment = "Relationship from e30"
  )
```

### Education level

``` r

svy <- svy |>
  step_recode(edu_level,
    e51_2 == 0 ~ "None",
    e51_2 >= 1 & e51_2 <= 2 ~ "Primary",
    e51_2 >= 3 & e51_2 <= 4 ~ "Secondary",
    e51_2 >= 5 & e51_2 <= 6 ~ "Tertiary",
    .default = NA_character_,
    comment = "Education level from e51_2"
  )
```

### Geographic area

``` r

svy <- svy |>
  step_recode(area,
    region_4 == 1 ~ "Montevideo",
    region_4 == 2 ~ "Urban >5k",
    region_4 == 3 ~ "Urban <5k",
    region_4 == 4 ~ "Rural",
    .default = NA_character_,
    comment = "Geographic area from region_4"
  )
```

Notice that all our output variables have **meaningful labels** instead
of numeric codes. A transpiled recipe would keep the original integer
codes (1, 2, 3…) because that’s what the STATA code used. Building from
scratch lets you choose the representation that makes analysis easier.

### Remove raw variables

``` r

svy <- svy |>
  step_remove(e26, e27, e30, e51_2, region_4,
    comment = "Drop raw ECH variables"
  )
```

## Inspecting the pipeline

At this point we have seven recorded steps: the five recodes already
executed, while the rename and the remove are still pending. Let’s see
what was recorded:

``` r

length(get_steps(svy))
```

This is one of the key advantages of building from scratch: **7 steps
that each do one clear thing**. A transpiled version of the full IECON
demographics module has 80+ steps because it preserves every
intermediate STATA command.

The pipeline is a DAG (directed acyclic graph) of transformations.
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)
renders it as an interactive network – each node is a step, and edges
show variable dependencies:

``` r

view_graph(svy)
```

The interactive DAG is not rendered in this vignette to keep the package
size small. Run
[`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)
in your R session to explore it. With only 7 nodes the graph is clean
and navigable. Compare that with a transpiled recipe where the DAG can
have 100+ nodes – still useful for auditing, but much harder to read at
a glance.

For static output we can inspect the step list:

``` r

for (s in get_steps(svy)) {
  cat(sprintf("[%s] %s\n", s$type, s$comment %||% ""))
}
```

## Packaging as a recipe

A recipe bundles the steps with metadata so anyone can reproduce the
same pipeline on different data. The recorded steps are the pipeline:
whether they already executed or not does not matter – the recipe
re-runs every step when baked on new data, and that is where
reproducibility lives:

``` r

rec <- steps_to_recipe(
  name = "ECH Demographics (minimal)",
  user = "research_team",
  svy = svy,
  steps = get_steps(svy),
  description = paste(
    "Harmonized demographics: sex, age group, relationship,",
    "education level, and geographic area."
  ),
  topic = "demographics"
)

rec
```

The recipe auto-generates documentation from the steps:

``` r

doc <- rec$doc()
cat("Input variables: ", paste(doc$input_variables, collapse = ", "), "\n")
cat("Output variables:", paste(doc$output_variables, collapse = ", "), "\n")
cat("Pipeline steps:  ", length(doc$pipeline), "\n")
```

## Baking: materializing the pending steps

[`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
runs the deferred steps (here, the rename and the remove) and skips the
ones that already executed, so there is never double execution. Calling
it is safe and idempotent:

``` r

svy <- bake_steps(svy)
```

The data has the new columns with readable labels:

``` r

head(get_data(svy)[, .(
  hh_id, person_id, sex, age_group, relationship,
  edu_level, area
)])
```

The raw variables are gone:

``` r

"e26" %in% names(get_data(svy))
```

## Saving and loading

Recipes serialize to JSON for version control and sharing:

``` r

f <- tempfile(fileext = ".json")
save_recipe(rec, f)
```

``` r

rec2 <- read_recipe(f)
rec2$name
length(rec2$steps)
```

The JSON is human-readable and diffable in git:

``` r

cat(readLines(f, n = 15), sep = "\n")
```

## Applying to a new edition

The same recipe works on any edition. Load the recipe from JSON, attach
it to new data, and bake:

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
```

No code changes needed. The recipe encodes the *logic*, not the data.

## Transpiler vs hand-crafted: when to use each

|  | Transpiler ([`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md)) | Hand-crafted recipe |
|----|----|----|
| **Speed** | Seconds – instant migration | Hours – requires understanding the logic |
| **Steps** | 80-200 per module (one per STATA line) | 5-20 (one per concept) |
| **Variable names** | Inherits STATA names (`bc_pe2`, `bc_pe3`) | Your own names (`sex`, `age_group`) |
| **Labels** | Numeric codes (`1`, `2`, `3`) | Readable labels (`"Male"`, `"Female"`) |
| **Readability** | Faithful to original, verbose | Clean, self-documenting |
| **Maintenance** | Hard to modify individual steps | Easy to change any mapping |
| **DAG visualization** | Large, hard to read | Compact, meaningful nodes |
| **Best for** | Migrating legacy code fast | New projects, critical pipelines |

**Recommended workflow**: use
[`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md)
to migrate your existing `.do` files immediately so you have a working
baseline. Then gradually replace transpiled recipes with hand-crafted
ones as you review each module. The transpiled version keeps you
running; the hand-crafted version is where you want to end up.

## What metasurvey gives you

| Manual STATA scripts | metasurvey recipe |
|----|----|
| Copy-paste `.do` files per year | One recipe, any edition |
| Undocumented variable names | Auto-generated input/output docs |
| No dependency tracking | DAG visualization with [`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md) |
| Flat scripts, no validation | `validate()` checks required variables |
| Email `.do` files to colleagues | [`publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/publish_recipe.md) to shared registry |
| Re-run entire script to test | Recorded pipeline: inspect with [`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md) |

## Next steps

- **Add more variables**: income, labor force status, housing conditions
  – each can be a separate recipe with `depends_on_recipes`
- **Certify your recipe**: use
  [`certify_recipe()`](https://metasurveyr.github.io/metasurvey/reference/certify_recipe.md)
  to mark it as reviewed or official
- **Publish**: `publish_recipe(rec)` uploads to the shared registry
  where others can find it with `search_recipes(topic = "demographics")`
- **Start from STATA**: if you already have `.do` files, use
  [`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md)
  to generate a working baseline immediately – see
  [`vignette("stata-transpiler")`](https://metasurveyr.github.io/metasurvey/articles/stata-transpiler.md)
  – then refine the output into a hand-crafted recipe like the one in
  this vignette
