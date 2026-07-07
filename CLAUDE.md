# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is metasurvey?

An R package for processing survey data using metaprogramming. It wraps the `survey` package with R6 classes, reproducible pipelines (steps/recipes/workflows), and support for complex designs like rotating panels with bootstrap replicate weights.

## Build & Test Commands

```bash
# Run full test suite
Rscript -e 'devtools::test()'

# Run a single test file
Rscript -e 'devtools::test(filter = "steps-basic")'

# R CMD check (full package validation: 0 errors/0 warnings expected)
Rscript -e 'devtools::check()'

# Regenerate docs (roxygen2 → NAMESPACE + man/)
Rscript -e 'devtools::document()'

# Build package
R CMD build .

# Install locally
Rscript -e 'devtools::install()'

# Test coverage
Rscript -e 'covr::package_coverage()'
```

## Architecture

### Core R6 Class Hierarchy

- **Survey** (`R/survey.R`) — Base class. Holds data (data.table), metadata (type, edition, periodicity), weight spec, sampling design (`survey::svydesign`/`svrepdesign`), and attached steps/recipes/workflows.
- **RotativePanelSurvey** (`R/PanelSurvey.R`) — Extends the concept for rotating panels: has an `implantation` Survey + list of `follow_up` Surveys. Steps can target `.level = "follow_up"` or `"implantation"`.
- **PoolSurvey** (`R/survey.R`) — Groups multiple surveys by time hierarchy (e.g., `list(annual = list(group1 = list(s1, s2)))`).

### Step Pipeline (lazy evaluation)

- **Step** (`R/Step.R`) — R6 class storing a transformation: type (`compute`/`recode`/`rename`/`remove`/`join`), expressions, dependencies, bake status.
- **Step functions** (`R/steps.R`, largest file) — `step_compute()`, `step_recode()`, `step_rename()`, `step_remove()`, `step_join()`. By default (`lazy_processing=TRUE`), steps are recorded but not executed until `bake_steps()` is called.
- **`bake_steps()`** (`R/steps.R`) — Materializes all pending lazy steps on the survey data.
- Internal `compute()` and `recode()` functions at the top of `R/steps.R` handle the actual data.table mutations.

### Recipe System

- **Recipe** (`R/Recipes.R`) — R6 class bundling metadata + a list of step calls for reproducible survey processing. Has `doc()` for auto-documentation and `validate(svy)` to check dependencies.
- **RecipeRegistry/RecipeBackend** (`R/RecipeRegistry.R`, `R/RecipeAPI.R`) — Registry pattern with pluggable backends (JSON file, MongoDB) for publishing/discovering recipes.
- **RecipeCategory, RecipeCertification, RecipeUser** — Supporting R6 classes for the recipe ecosystem.
- Tidy API wrappers in `R/recipe_tidy_api.R`: `list_recipes()`, `search_recipes()`, `filter_recipes()`, `rank_recipes()`, etc.

### Workflow System

- **`workflow()`** (`R/workflow.R`) — Executes `survey::svymean`/`svytotal`/`svyratio`/`svyby` calls on Survey objects, returns a `data.table` of results with metadata.
- **RecipeWorkflow** (`R/RecipeWorkflow.R`) — R6 class for publishable workflow objects (captures estimation calls, references recipe IDs).
- **WorkflowRegistry/WorkflowBackend** (`R/WorkflowRegistry.R`, `R/WorkflowBackend.R`) — Same registry pattern as recipes.
- Tidy API in `R/workflow_tidy_api.R`: `list_workflows()`, `search_workflows()`, etc.

### Global Options

Controlled via `options()`, set on package load in `R/meta.R`:
- `metasurvey.engine` — default data engine (`"data.table"`)
- `use_copy` — whether step operations clone data (`use_copy_default()`)
- `metasurvey.lazy_processing` — lazy step execution (`lazy_default()`, TRUE by default)

## Testing Conventions

- testthat edition 3 (`Config/testthat/edition: 3`)
- Test helpers in `tests/testthat/helper-survey.R`: `make_test_survey(n)`, `make_test_data(n)`, `make_test_panel()`
- Integration tests using `example-data/` directory use `skip_on_cran()` + `skip_if_not(file.exists(...))`
- Test file naming: `test-{topic}.R` (e.g., `test-steps-basic.R`, `test-recipe.R`, `test-workflow.R`)

## Known Gotchas

- **Step execution model (mixed)**: `step_compute`/`step_recode`/`step_join` execute **eagerly** on creation and record their Step with `bake=TRUE`, so `bake_steps()` never re-executes them (no double application). `step_filter`/`step_validate` are always lazy (recorded with `bake=FALSE`, executed on `bake_steps()`). `step_remove`/`step_rename` honor `lazy` and record `bake = !lazy`.
- **step_recode semantics**: first matching condition wins (case_when-style) and RHS values keep their native type (numeric/integer/logical/character all valid).
- **PoolSurvey construction**: Use nested list structure: `PoolSurvey$new(list(annual = list("group1" = list(s1, s2))))`.

## Git Workflow

- `main` branch for releases/PRs
- `develop` branch for active development
- roxygen2 generates NAMESPACE and man/ pages — run `devtools::document()` after changing any roxygen comments
