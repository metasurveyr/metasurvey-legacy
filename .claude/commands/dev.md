# metasurvey Development Guide

You are contributing to **metasurvey**, an R package for processing survey data. Follow these principles strictly.

## Core Principles

1. **TDD (Test-Driven Development)**: Write tests BEFORE implementation. Red → Green → Refactor. Every new function or bug fix starts with a failing test.
2. **DRY (Don't Repeat Yourself)**: Reuse existing helpers, avoid code duplication. If similar logic exists, extract a shared function.
3. **Simple API**: The public API must feel like dplyr — pipe-friendly, verb-based, minimal arguments. Complexity stays internal.
4. **data.table internally**: All data operations use `data.table` syntax (`:=`, `.SD`, `setnames`, `fwrite`). Never convert to data.frame internally.
5. **Document everything exported**: roxygen2 with `@param`, `@return`, `@export`, `@examples`. Internal functions use `@keywords internal`.

## Architecture Overview

```
Survey (R6)
├── data: data.table
├── type: "ech", "eaii", etc.
├── edition: "2023"
├── weight: add_weight(annual = "w")
├── steps: list(Step)
├── recipes: list(Recipe)
└── design: svydesign (lazy, built on demand)

Step Pipeline (lazy by default):
  step_compute(svy, new_col = expr)
  step_recode(svy, new_col, ...)
  step_rename(svy, new = old)
  step_remove(svy, col)
  step_join(svy, data, by)
  bake_steps(svy)  # materializes all pending steps

Recipe = metadata + list of step calls (portable, serializable)
  recipe(name, user, svy, description, steps)
  add_recipe(svy, recipe)
  bake_recipes(svy)

Workflow = estimation calls on Survey objects
  workflow(list(svy), svymean(~x, design, na.rm = TRUE))
```

## File Map

| File | What | Lines |
|------|------|-------|
| `R/survey.R` | Survey, PoolSurvey R6 classes | ~1050 |
| `R/steps.R` | step_* functions, bake_steps, compute, recode | ~1674 |
| `R/Recipes.R` | Recipe R6, recipe(), save/read_recipe | ~500 |
| `R/Step.R` | Step R6 class | ~200 |
| `R/PanelSurvey.R` | RotativePanelSurvey R6 | ~300 |
| `R/workflow.R` | workflow() estimation function | ~350 |
| `R/RecipeWorkflow.R` | RecipeWorkflow R6 class | ~250 |
| `R/utils.R` | add_weight, add_replicate, helpers | ~900 |
| `R/load_survey.R` | load_survey, read_file, config_survey | ~550 |
| `R/anda.R` | ANDA5 catalog integration | ~400 |
| `R/api_client.R` | REST API client (JWT auth) | ~450 |
| `R/recipe_tidy_api.R` | list/search/filter/rank_recipes | ~320 |
| `R/set_engine.R` | Engine configuration | ~100 |

## TDD Workflow

### 1. Start with a test

```r
# tests/testthat/test-{feature}.R
test_that("step_compute creates new column from expression", {
  svy <- make_test_survey()
  svy <- step_compute(svy, income_log = log(income))
  svy <- bake_steps(svy)
  expect_true("income_log" %in% names(svy$data))
  expect_equal(svy$data$income_log, log(svy$data$income))
})
```

### 2. Run the test (should FAIL)

```bash
Rscript -e 'devtools::test(filter = "feature")'
```

### 3. Implement the minimum code to pass

### 4. Refactor, run all tests

```bash
Rscript -e 'devtools::test()'        # 0 failures
Rscript -e 'devtools::check()'       # 0 errors, 0 warnings
Rscript -e 'covr::package_coverage()' # 85%+
```

## Test Helpers

```r
# In tests, always use these:
svy <- make_test_survey(n = 10)    # Survey with id, x, y, age, income, region, status, group, w
dt  <- make_test_data(n = 10)      # Just the data.table
panel <- make_test_panel()         # RotativePanelSurvey

# For mocking HTTP calls:
local_mocked_bindings(
  api_request = function(endpoint, method = "GET", body = NULL, params = NULL) {
    list(ok = TRUE, data = list())
  }
)
```

## API Design Rules

### DO: Simple, pipe-friendly, verb-based

```r
svy <- load_survey("data.csv", svy_type = "ech", svy_edition = "2023",
                   svy_weight = add_weight(annual = "pesoano"))

svy <- svy |>
  step_compute(income_log = log(income)) |>
  step_recode(employed, pobpcoac == 2 ~ 1, .default = 0) |>
  step_rename(region_code = region) |>
  bake_steps()

result <- workflow(list(svy), svymean(~income_log, design, na.rm = TRUE))
```

### DON'T

- Don't require the user to call `$new()` directly for common tasks — provide functional wrappers
- Don't expose internal data.table mechanics in the API
- Don't add parameters "just in case" — YAGNI
- Don't break existing function signatures without deprecation

## data.table Patterns

```r
# Column creation (by reference)
dt[, new_col := expr]

# Recode with conditions
dt[condition, new_col := value]

# Rename
data.table::setnames(dt, old, new)

# Remove
dt[, (cols) := NULL]

# Join
result <- merge(dt1, dt2, by = key, all.x = TRUE)

# NEVER do this:
dt <- as.data.frame(dt)  # kills performance
dt$col <- value           # copies the whole table
```

## Known Gotchas

1. **recode + bake_steps bug**: `bake_step()` passes `record=FALSE` to internal `recode()` which doesn't accept it. Test recode with `use_copy=TRUE` (applies immediately) instead of `bake_steps()`.

2. **lazy_processing=FALSE**: Steps apply immediately BUT Step objects are created with `bake=FALSE`, causing double-execution on `bake_steps()`. Always default to `lazy_processing=TRUE`.

3. **PoolSurvey construction**: Nested list: `PoolSurvey$new(list(annual = list("group1" = list(s1, s2))))`.

4. **Case-insensitive columns**: INE data has inconsistent casing (POBPCOAC vs pobpcoac). Recipe validation and bake_recipes use `tolower()` comparison and normalize column names with `setnames()`.

5. **Recipe in list()**: `load_survey(recipes = list(r))` — extract with `[[1]]`, not `$field`.

## Documentation Template

```r
#' Compute a new variable
#'
#' Adds one or more computed columns to the survey data using data.table
#' expressions. By default the computation is lazy (recorded but not applied
#' until \code{bake_steps()}).
#'
#' @param svy A Survey object.
#' @param ... Named expressions (e.g., \code{income_log = log(income)}).
#' @param .copy Logical. If TRUE, operates on a copy of the data.
#' @return The Survey object (modified by reference or copied).
#'
#' @examples
#' svy <- make_test_survey()
#' svy <- step_compute(svy, z = x + y)
#' svy <- bake_steps(svy)
#' head(svy$data$z)
#'
#' @export
step_compute <- function(svy, ..., .copy = use_copy_default()) {
  # implementation
}
```

## Git Conventions

- Branch from `develop`, PR to `develop`
- Commit messages: `type: description` (feat, fix, test, docs, refactor, chore)
- Run `devtools::document()` after changing roxygen comments
- Run `devtools::test()` before every commit
- Never commit generated files (man/, NAMESPACE) without running `devtools::document()` first

## Checklist Before PR

- [ ] Tests written FIRST (TDD)
- [ ] `devtools::test()` — 0 failures
- [ ] `devtools::check()` — 0 errors, 0 warnings
- [ ] `devtools::document()` — NAMESPACE and man/ regenerated
- [ ] Coverage maintained at 85%+
- [ ] No unnecessary dependencies added
- [ ] Public API is pipe-friendly and well-documented
- [ ] No `as.data.frame()` conversions in hot paths
