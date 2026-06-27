# Transpiling STATA do-files to metasurvey Recipes

## Motivation

Many Latin American research groups maintain decades of STATA `.do`
files that process household survey microdata. These scripts encode
institutional knowledge about variable harmonization, income
decomposition, and indicator construction – but they are locked in a
format that is hard to version, share, or integrate with modern R
workflows.

The **metasurvey transpiler** converts STATA `.do` files into metasurvey
Recipe objects. This enables:

- **Reproducibility**: STATA pipelines become version-controlled JSON
  recipes
- **Interoperability**: the same recipe runs on any `data.table`-backed
  Survey object
- **Discovery**: transpiled recipes can be published to the metasurvey
  API for other researchers to find and reuse

The transpiler handles the most common STATA patterns found in survey
processing scripts: variable generation, conditional replacement,
recoding, aggregation, loops, missing-value encoding, and label
extraction.

## Quick start

``` r

library(metasurvey)

# Transpile a single .do file
result <- transpile_stata("demographics.do")
result$steps[1:3]
#> [1] "step_rename(svy, hh_id = \"id\", person_id = \"nper\")"
#> [2] "step_compute(svy, weight_yr = pesoano)"
#> [3] "step_compute(svy, sex = e26)"
```

The result is a list with four elements:

| Element    | Description                                               |
|------------|-----------------------------------------------------------|
| `steps`    | Character vector of metasurvey step calls                 |
| `labels`   | Variable and value labels extracted from the `.do` file   |
| `warnings` | Any commands that required manual review                  |
| `stats`    | Counts of translated, skipped, and manual-review commands |

## Transpilation pipeline

The transpiler works in four passes:

      .do file
         |
         v
      [1] parse_do_file()      -- tokenize lines into command objects
         |
         v
      [2] translate_commands()  -- map each STATA command to metasurvey steps
         |
         v
      [3] optimize_steps()      -- consolidate consecutive renames, drops, etc.
         |
         v
      [4] Recipe / JSON         -- bundle steps with metadata

### Pass 1: Parsing

[`parse_do_file()`](https://metasurveyr.github.io/metasurvey/reference/parse_do_file.md)
reads a `.do` file and produces a list of command objects. It handles:

- **Comment stripping**: `*`, `//`, and `/* */` block comments
- **Line continuation**: `///` and `/* */` used as continuation markers
- **Loop expansion**: `foreach` and `forvalues` are unrolled,
  substituting backtick macros (`` `var' ``) with each iteration value
- **Prefix handling**: `capture`, `bysort group:`, and command
  abbreviations (`g` for `gen`, `cap` for `capture`)

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

### Pass 2: Command translation

Each parsed command is mapped to one or more metasurvey step strings.
The following table shows the supported STATA commands and their
translations.

## Supported patterns

### gen / generate

Simple variable creation translates to `step_compute`:

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

When a `gen` includes an `if` clause, the condition is wrapped in
`fifelse`:

``` stata
gen employed = hours_worked if age >= 14
```

``` r

step_compute(svy, employed = data.table::fifelse(age >= 14, hours_worked, NA))
```

### gen + replace chains (the dominant pattern)

The most common pattern in survey `.do` files is initializing a variable
and then filling it with conditional replacements:

``` stata
gen relationship = -9
replace relationship = 1 if q05 == 1
replace relationship = 2 if q05 == 2
replace relationship = 3 if inrange(q05, 3, 5)
replace relationship = 4 if q05 == 6
```

When **all** right-hand sides are constants, the transpiler emits a
single `step_recode`:

``` r

step_recode(svy, relationship,
    q05 == 1 ~ 1L,
    q05 == 2 ~ 2L,
    q05 >= 3 & q05 <= 5 ~ 3L,
    q05 == 6 ~ 4L,
    .default = -9L)
```

When any right-hand side is an **expression**, the transpiler emits a
chain of `step_compute` with `fifelse`:

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

STATA `recode` with parenthesized mappings or inline syntax:

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
# ... one fifelse per mapping

# Multi-variable recode: one step per variable
step_compute(svy, var1 = data.table::fifelse(is.na(var1), 0, var1))
step_compute(svy, var2 = data.table::fifelse(is.na(var2), 0, var2))
step_compute(svy, var3 = data.table::fifelse(is.na(var3), 0, var3))
```

### egen (aggregation with by-groups)

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

Supported `egen` functions: `sum`, `max`, `min`, `mean`, `count`, `sd`,
`median`, `total`, `rowtotal`, `rowmean`.

### foreach loops

Loops are expanded during parsing. The transpiler unrolls `foreach` with
both `in` lists and `of numlist` ranges, including nested loops:

``` stata
foreach i of numlist 1/4 {
    gen contrib`i' = 0
    replace contrib`i' = amount if provider == `i'
}
```

Expands to 4 pairs of gen+replace, each transpiled independently:

``` r

step_recode(svy, contrib1, provider == 1 ~ amount, .default = 0L)
step_recode(svy, contrib2, provider == 2 ~ amount, .default = 0L)
step_recode(svy, contrib3, provider == 3 ~ amount, .default = 0L)
step_recode(svy, contrib4, provider == 4 ~ amount, .default = 0L)
```

### mvencode (missing value encoding)

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

Consecutive renames are consolidated into a single `step_rename` call,
and consecutive drops are merged into one `step_remove`.

### STATA expression translation

STATA-specific syntax in expressions is automatically translated:

| STATA                | R (data.table)                             |
|----------------------|--------------------------------------------|
| `inrange(x, a, b)`   | `(x >= a & x <= b)`                        |
| `inlist(x, 1, 2, 3)` | `(x %in% c(1, 2, 3))`                      |
| `var == .`           | `is.na(var)`                               |
| `var != .`           | `!is.na(var)`                              |
| `.` (as value)       | `NA`                                       |
| `string(var)`        | `as.character(var)`                        |
| `var[_n-1]`          | `data.table::shift(var, 1, type = "lag")`  |
| `var[_n+1]`          | `data.table::shift(var, 1, type = "lead")` |
| `_N`                 | `.N`                                       |

### Variable ranges

STATA allows variable ranges like `aux1-aux4` meaning
`aux1 aux2 aux3 aux4`. The transpiler expands these in `drop`, `recode`,
and `mvencode` commands:

``` stata
drop contrib1-contrib4
```

``` r

step_remove(svy, contrib1, contrib2, contrib3, contrib4)
```

### Labels

Variable and value labels are extracted and stored in the recipe
metadata:

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

## Skipped commands

Commands that do not modify survey data are silently skipped during
transpilation. These include:

- I/O: `use`, `save`, `import`, `export`, `insheet`, `outsheet`
- Display: `tabulate`, `summarize`, `describe`, `list`, `browse`,
  `display`
- Control flow: `if`/`else`, `while`, `program`, `exit`
- Settings: `set`, `sort`, `order`, `compress`, `format`
- Macros: `global`, `local`, `scalar`, `matrix`

The `$stats` element of the result reports how many commands fell into
each category.

## A realistic example

The following `.do` file is a simplified version of a typical survey
demographics module. It is not a real production script, but it uses the
same patterns found in actual ECH processing pipelines.

Save this as `demo_module.do`:

``` stata
* ──────────────────────────────────────────────
* Demographics module -- simplified example
* ──────────────────────────────────────────────

rename id hh_id
rename nper person_id

gen weight_yr = pesoano
gen weight_qt = pesotri

* ── Sex ──
gen sex = q01

* ── Relationship to head ──
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

* ── Education level (harmonized) ──
recode q20 (2=2) (3=-9) (4=3) (5=4), gen(edu_compat)

* ── Household-level age stats ──
bysort hh_id: egen max_age = max(edad)
bysort hh_id: egen n_members = count(person_id)

* ── Initialize health insurance contributions ──
foreach i of numlist 1/3 {
    gen contrib`i' = 0
    replace contrib`i' = amount if provider == `i'
}

* ── Encode missing values ──
mvencode contrib1 contrib2 contrib3, mv(0)

* ── Clean up ──
drop region q01 q05 q20

* ── Labels ──
lab var sex "Sex"
lab var relationship "Relationship to household head"
lab def sex_lbl 1 "Male" 2 "Female"
lab val sex sex_lbl
lab def rel_lbl 1 "Head" 2 "Spouse" 3 "Child" 4 "Other relative" 5 "Non-relative"
lab val relationship rel_lbl
```

``` r

library(metasurvey)

# Write the example do-file to a temp location
# Note: STATA macros use backtick-quote (`var') which we build with paste0
bt <- "`" # backtick
sq <- "'" # single quote
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
  'lab var sex "Sex"',
  'lab var relationship "Relationship to household head"',
  'lab def sex_lbl 1 "Male" 2 "Female"',
  "lab val sex sex_lbl",
  'lab def rel_lbl 1 "Head" 2 "Spouse" 3 "Child" 4 "Other relative" 5 "Non-relative"',
  "lab val relationship rel_lbl"
)
do_file <- tempfile(fileext = ".do")
writeLines(do_lines, do_file)

result <- transpile_stata(do_file)
```

### Inspecting the output

``` r

cat("Translated:", result$stats$translated, "\n")
cat("Skipped:   ", result$stats$skipped, "\n")
cat("Manual:    ", result$stats$manual_review, "\n")
```

``` r

# Print the generated steps
for (s in result$steps) cat(s, "\n")
```

### Labels

``` r

str(result$labels$var_labels)
str(result$labels$val_labels)
```

### Building a Recipe from transpiled steps

``` r

rec <- Recipe$new(
  id = "example_demographics",
  name = "Demographics (transpiled)",
  user = "research_team",
  edition = "2022",
  survey_type = "ech",
  default_engine = "data.table",
  depends_on = character(0),
  description = "Harmonized demographics from STATA transpilation",
  steps = result$steps,
  labels = result$labels
)

# Save as JSON
save_recipe(rec, "demographics_recipe.json")

# Apply to survey data
svy <- survey_empty(type = "ech", edition = "2022") |>
  set_data(my_data) |>
  add_recipe(rec) |>
  bake_recipes()
```

## Module-level transpilation

For projects that organize `.do` files by year and thematic module,
[`transpile_stata_module()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata_module.md)
processes an entire year directory and groups the results into separate
Recipe objects:

``` r

recipes <- transpile_stata_module(
  year_dir = "do_files/2022",
  year = 2022,
  user = "research_team",
  output_dir = "recipes/"
)

names(recipes)
#> [1] "data_prep"        "demographics"     "income_detail"
#> [4] "income_aggregate" "cleanup"

# Each recipe has inter-module dependencies
recipes$income_detail$depends_on_recipes
#> [1] "ech_2022_data_prep"    "ech_2022_demographics"
```

## Coverage analysis

[`transpile_coverage()`](https://metasurveyr.github.io/metasurvey/reference/transpile_coverage.md)
reports how many commands in a `.do` file (or directory) can be
automatically transpiled:

``` r

transpile_coverage("do_files/")
#>                               file total translated skipped manual coverage
#> 1   2022/2_correc_datos.do             82        60      22      0   100.00
#> 2   2022/3_compatibiliz...do          420       380      40      0   100.00
#> 3   2022/4_ingreso_ht11...do          310       270      40      0   100.00
```

The `coverage_pct` column reports the percentage of
**data-transforming** commands that were translated (excluding skipped
non-data commands). A value below 100% means some commands need manual
review – look at the `$warnings` element for details.

## Limitations

The transpiler does **not** handle:

- `merge` commands (these depend on external files and are translated as
  comments with `# MANUAL_REVIEW`)
- `collapse` / `reshape` (structural data transformations)
- Custom `program` definitions
- `mata` blocks or `plugin` calls
- Nested `/* */` block comments that contain `/* */` line continuations
  internally (rare; only seen in commented-out legacy code)

Commands that fall outside the transpiler’s scope are flagged with
`# MANUAL_REVIEW` in the output and counted in `$stats$manual_review`.

## Summary

| Feature                     | Status                                        |
|-----------------------------|-----------------------------------------------|
| gen / generate              | Fully supported                               |
| replace (conditional)       | Fully supported                               |
| gen + replace chains        | Auto-grouped into step_recode or step_compute |
| recode (single & multi-var) | Fully supported                               |
| egen with by-groups         | Fully supported                               |
| foreach / forvalues         | Expanded during parsing                       |
| mvencode                    | Fully supported                               |
| destring / tostring         | Fully supported                               |
| rename / drop / keep        | Fully supported                               |
| Variable & value labels     | Extracted to recipe metadata                  |
| STATA expressions           | inrange, inlist, missing, lag/lead, \_N       |
| Variable ranges             | Expanded (e.g., var1-var4)                    |
| Nested loops                | Recursive expansion                           |
| Line continuation (///)     | Joined during parsing                         |
| capture prefix              | Handled (errors suppressed)                   |
| bysort prefix               | Converted to .by parameter                    |
