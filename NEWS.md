# metasurvey 0.1.0

## Breaking changes
* Step execution model: `step_compute()`, `step_recode()` and `step_join()`
  now record their `Step` as already executed (`bake = TRUE`). They still run
  eagerly on creation, but `bake_steps()` no longer re-executes them.
  Previously every eager step ran twice (once on creation, once on bake),
  silently corrupting non-idempotent expressions (e.g. `age = age * 2` ended
  up as `age * 4`). `step_remove()`/`step_rename()` now record
  `bake = !lazy`, closing the double-execution gotcha with
  `lazy_processing = FALSE`.
* `step_recode()`: conditions are now evaluated first-match-wins
  (`dplyr::case_when()` semantics), as documented. Previously the last
  matching condition won. The STATA transpiler now emits `gen` + `replace`
  chains with reversed conditions to preserve their original
  last-write-wins semantics.

## New features
* `step_recode()` accepts non-character RHS values (numeric, integer,
  logical); previously anything but character failed with an internal
  `vapply` error.

## Bug fixes
* `workflow()`: survey editions stored as `Date` are handled in the workflow
  capture, and pooled estimations (`workflow_pool`) use the correct grouped
  standard error.
* `add_replicate()`: `svrepdesign` is built with the full replicate-weight
  set; step calls captured in recipes are portable across sessions.
* Recipes: `depends_on` lists only external inputs (columns not created by
  the recipe's own steps).
* Recode steps preserve their evaluated `.default`, `ordered` and
  `.to_factor` options, so `bake_recipes()` reproduces them exactly on new
  data.

# metasurvey 0.0.24

## Breaking changes
* `workflow()`: parameter `conf.level` renamed to `level` to match
  `stats::confint()` and `survey` package conventions. Per-call overrides now
  use `level` as well (e.g., `svymean(~x, level = 0.90)`).

## Bug fixes
* `step_compute(.by=)`: grouped computations now survive `bake_steps()`.
  Previously the `.by` parameter was not stored in the `Step` object, so
  re-baking would re-execute without grouping, producing wrong results.
* `compute()` with `.by`: fixed `merge()` creating `.x`/`.y` suffix columns
  when the target column already existed in the data (e.g., during re-baking).

# metasurvey 0.0.23

## New features
* `workflow()` now supports `conf.level` inside individual estimation calls
  (e.g., `svymean(~x, na.rm = TRUE, conf.level = 0.80)`). The per-call value
  overrides the `workflow()` default, allowing different confidence levels for
  each estimation in the same call.

# metasurvey 0.0.22

## New features
* `workflow()` gains a `conf.level` parameter (default `0.95`) to control the
  confidence level of the interval. Passed through to `stats::confint()` for
  all estimation types (`svymean`, `svyby`, `svyratio`, `convey`).
* `workflow()` output now includes `variable` and `evaluate` columns across
  all estimation types. `variable` enables clean filtering/grouping;
  `evaluate` classifies CV quality via `evaluate_cv()`. `svyby` results no
  longer embed group labels in the `stat` column — grouping variables
  (`region`, `sexo`, etc.) appear as separate columns.

# metasurvey 0.0.21

## New features
* `workflow()` now supports `convey` package functions (`svygini`, `svyatk`,
  `svyarpr`, `svyfgt`, etc.) for poverty and inequality estimation with
  proper standard errors and CVs.

## Bug fixes
* `validate_weight()` now shows available columns when weight is not found.
* `validate_replicate()` now lists missing replicate ID columns in the error.
* `set_use_copy()` and `set_lazy_processing()` reject non-scalar logical input.

## Internal
* Step functions (`step_join`, `step_remove`, `step_rename`, `step_validate`,
  `step_filter`) now return `invisible(out)` per R convention for side-effect
  functions.
* Added `@rdname provenance` to S3 method documentation.
* Removed unused `stats::median` and `stats::quantile` imports.
* Use fully qualified `stats::confint()` in `cat_estimation.svyratio`.
* Added edge case tests: double bake idempotency, filter-then-compute chain,
  `provenance_diff` print output.

# metasurvey 0.0.20

## Breaking changes
* `survey_to_data.table()` is deprecated in favor of `survey_to_datatable()`
  (avoids non-standard dots in function names). The old function still works
  with a deprecation warning.

## New features
* `metasurvey_msg()` internal helper wraps `message()` behind
  `options(metasurvey.verbose = FALSE)` for silent operation in scripts.
* All HTTP requests (ANDA, API client, Shiny) now send a
  `metasurvey/<version>` User-Agent header.
* `read_file()` now gives an actionable install hint when the required
  reader package is missing (e.g., `haven` for `.dta` files).

## Bug fixes
* Added `call. = FALSE` to all `stop()` and `warning()` calls for cleaner
  error tracebacks without internal call stack noise.
* Fixed `&` vs `&&` in `compute()` and `cat_estimation()` — single `&`
  would evaluate both sides even when the first was FALSE.
* `get_metadata()` now uses `cat()` instead of `message()`, making output
  testable with `expect_output()` and suppressible with `capture.output()`.
* Removed `.onAttach()` startup message (package loads silently).

## Documentation
* Fixed all broken URLs flagged by CRAN: updated Azure AKS and INE Uruguay
  redirects, removed dead Railway API and metasurvey-infra links.
* Included `api-database` vignette in build (was excluded via
  `.Rbuildignore`, causing broken cross-vignette file URI references).
* Reduced vignette tarball from 10.6 MB to 3.7 MB by disabling
  `visNetwork` widget rendering (`eval = FALSE`).
* Replaced `\dontrun{}` examples in `get_implantation()` and
  `get_follow_up()` with runnable examples using test data.
* Added runnable examples for `provenance_to_json()` and
  `provenance_diff()`.
* Added `@family transpiler` cross-references to all transpiler functions.
* Documented default parameter values across all `step_*` and tidy API
  functions.
* Added `print.metasurvey_provenance_diff` man page.
* Removed unused `digest` from Suggests.

# metasurvey 0.0.19

## New features
* `step_filter()`: new step type for row-level filtering within the pipeline.
  Multiple conditions are AND-combined. Supports `.by` for within-group
  filtering, lazy evaluation, and RotativePanelSurvey dispatch.
* `provenance()`: lightweight data lineage tracking. Surveys now record source
  file, load timestamp, initial row count, and per-step history (type, N
  before/after, duration). Workflow results carry provenance as an attribute.
  Includes `provenance_to_json()` for audit trails and `provenance_diff()` for
  cross-edition comparison.
* `workflow_table()`: publication-quality formatted tables from `workflow()`
  results using `gt`. Features confidence intervals, CV quality classification
  with color coding, `compare_by` for side-by-side edition comparison,
  locale-aware formatting ("en"/"es"), and provenance-based source notes.
  Falls back to `knitr::kable()` if `gt` is not installed.

## Bug fixes
* Fixed stars and comments not persisting to MongoDB: the plumber API
  star/comment endpoints used `if (!is.null(auth_err))` to check
  authentication, but `require_auth()` always returns non-NULL (user
  object on success, error list on failure). The endpoints returned the
  JWT payload immediately without ever reaching the database write.
  Fixed all 5 affected endpoints (recipe star, recipe comment, workflow
  star, workflow comment, delete comment) and added `result$ok` checks
  in Shiny modules so errors are reported instead of silently swallowed.

## Dependencies
* Added `gt` (>= 0.10.0) to Suggests.

# metasurvey 0.0.18

## New features
* `step_validate()`: declarative data validation step that checks invariants
  without mutating data. Supports row-level logical expressions, named checks,
  `.min_n`, and `.action = "stop"` or `"warn"`.
* Stars and comments API: users can rate (1-5) and comment on recipes and
  workflows. New R functions: `api_star_recipe()`, `api_get_recipe_stars()`,
  `api_comment_recipe()`, `api_get_recipe_comments()`, `api_delete_comment()`,
  `api_get_recipe_dependents()`, and workflow equivalents.
* Backlinks: `GET /recipes/:id/dependents` returns recipes that depend on a
  given recipe via `depends_on_recipes`.
* Shiny app: star rating widget, comment section, and dependents panel in
  recipe and workflow detail modals.

## Performance
* `optimize_steps()` now collapses consecutive independent `step_compute()`
  calls into single calls with dependency analysis, reducing transpiled step
  counts.

## Bug fixes
* Fixed DHS vignette chunk failing when external URL is unreachable.

# metasurvey 0.0.17

## New features
* Indicators API module: new `/indicators` REST endpoints for publishing
  estimation results with full traceability (indicator -> workflow -> recipe).
  Feature-gated via `METASURVEY_ENABLE_INDICATORS` env var.
* Compute worker service: on-demand estimation via `POST /indicators/compute`.
  The worker loads private microdata, applies recipes, and runs `workflow()`.
  Deployed as a separate Docker container, never exposes raw survey data.
* Self-hosting vignette: deployment guide with Docker Compose, including
  hybrid mode (public recipe registry + private worker with microdata).

## Documentation
* Updated self-hosting vignette with hybrid deployment architecture diagram.

# metasurvey 0.0.16

## Dependencies
* Migrated `crayon` to `cli` for terminal output coloring. All `crayon::bold()`,
  `crayon::silver()`, `crayon::green()`, etc. replaced with `cli::style_bold()`,
  `cli::col_silver()`, `cli::col_green()`, etc. across 8 files.
* Migrated `httr` to `httr2` for HTTP requests. All API client, ANDA catalog,
  and Shiny helper functions now use the pipe-based `httr2` API
  (`request() |> req_headers() |> req_perform()`).
* Replaced all `glue::glue_col()` calls (which depended on crayon color
  functions) with `glue::glue()` + `cli::col_*()` wrappers.
* Removed `bit64` and `jose` (already unused since 0.0.14) from Dockerfile.
* Removed `casen` from Suggests (GitHub-only package, not available on CRAN).
* Removed `pak` from Suggests (no longer used in vignettes).

## Bug fixes
* Fixed international-surveys vignette crash on PNADcIBGE example data:
  set `options(survey.lonely.psu = "adjust")` for strata with single PSUs.
* Fixed vignette setup chunk that attempted to install packages at build time
  via `pak`; replaced with `requireNamespace()` guards.
* Updated Shiny Dockerfile dependencies to match new imports (httr2, cli).

## Internal
* Excluded 9 Spanish (`*-es.Rmd`) vignettes from CRAN tarball via
  `.Rbuildignore` (remain available on pkgdown site).

# metasurvey 0.0.15

## New features
* Added `strata` parameter to `Survey$new()`, `survey_empty()`,
  `load_survey()`, and `load_panel_survey()` for stratified sampling
  designs. Passed to `survey::svydesign(strata = ...)`.
* New vignette: "International Survey Compatibility" (EN + ES) with
  reproducible examples for ECH, EPH, CASEN, PNADc, CPS, ENIGH, and DHS.

## Documentation
* Eliminated `eval=FALSE` from all vignettes — chunks now use conditional
  eval or markdown code blocks for non-runnable examples.
* Improved man page examples: replaced `\dontrun{}` with `\donttest{}` and
  runnable local-data examples for `cat_design`, `bake_recipes`, `recipe`,
  `steps_to_recipe`, `transpile_stata`, `parse_do_file`, and others.
* Added stratified cluster design section to complex-designs vignette.
* Rewrote README with live service links (Shiny explorer, REST API),
  CRAN status badge, and GitHub star call-to-action.

## Internal
* Expanded test suite to 2810 tests covering strata support, edge cases
  in STATA transpiler, API client, panel surveys, and recipe system.
* Expanded test suite to cover strata support in survey construction and
  workflow estimation.

# metasurvey 0.0.14

## Breaking changes
* `Step$comments` field renamed to `Step$comment`. The old name still works
  as a legacy alias but will be removed in a future version.
* `workflow()` first parameter renamed from `survey` to `svy` for consistency.
  Positional usage is unchanged.
* `Survey$set_weight()` no longer emits `message("Setting weight")`.
* `step_recode()` `.name_step` parameter is deprecated; use `comment` instead.

## New features
* `use_copy` parameter in all step functions (`step_compute`, `step_recode`,
  `step_join`, `step_remove`, `step_rename`) is deprecated in favour of `.copy`,
  following dplyr's dot-prefix convention for secondary arguments.
* Added survey state predicates: `has_steps()`, `has_recipes()`, `is_baked()`,
  `has_design()`.
* `step_recode()`, `step_join()`, `step_remove()`, `step_rename()` no longer
  default `svy` to `survey_empty()`; the survey argument is now required.
* `extract_time_pattern()` now recognises quarter/trimester editions
  (`"2023-T3"`, `"2023-Q1"`), parsed as `Quarterly` periodicity.

## Bug fixes
* Fixed `validate_time_pattern()` crash when `svy_edition` is `NA`.
* Fixed `shallow_clone()` re-running `validate_time_pattern()` on
  already-parsed editions, causing cascading NULL → NA → crash.
* Fixed `get_metadata()` crash when edition is NULL or NA.
* Fixed `cat_estimation.svyby()` producing wrong output: margins index was
  integer (not column name), SE column `"se"` was missed by grep, and
  `cv()` data.frame was not handled.  Output now shows group labels in
  the `stat` column (e.g. `svyby: x [sexo=1]`).
* Mixed estimation types (`svymean` + `svyby`) no longer fail on
  `rbindlist` due to mismatched columns.
* Fixed `set_engine()` logic bug where `identical(.engine, show_engines())`
  compared string vs vector, silently failing.
* Fixed vague `stop("Error in step")` in `step_compute()` validation —
  now reports which variables failed.
* Removed dead dots-filtering code in `step_remove()` and `step_rename()`.

## Dependencies
* Removed unused `bit64` import (CRAN compliance).
* Replaced `jose` dependency with `jsonlite::base64url_dec()` for JWT
  decoding — one less hard dependency.
* `design_active` active binding now delegates to `ensure_design()`,
  removing duplicated design-building logic.

## Documentation
* All `step_*` functions now document lazy evaluation behavior in `@details`.
* Improved `step_remove()` and `step_rename()` roxygen with full `@details`
  sections matching `step_compute()` depth.
* `workflow()` `@param svy` now prominently documents the `list()` requirement.
* Cleaned up Survey class roxygen: removed duplicate Methods sections.
* Updated vignettes to use `Step$comment` instead of `Step$comments`.
* Vignettes now use real ECH 2023 sample data instead of simulated data.
* Fixed ECH variable names for 2023 edition (`e31` → `e30`).

# metasurvey 0.0.12

## Bug fixes
* Fixed critical memory leak when chaining N steps: eliminated `svy_before`
  retention chain that prevented GC from freeing N copies of the data.table.
* Fixed `bake_step` re-recording step_join/step_remove/step_rename during bake,
  which caused duplicate steps.

## Performance
* `bake_steps()` uses `shallow_clone()` instead of `clone(deep=TRUE)`,
  avoiding duplication of the entire step chain on every bake.
* `add_step()` invalidates design lazily instead of rebuilding `svydesign`
  on every step addition.
* Removed wasteful `copy()` calls in `step_compute` and `step_recode`.

## Internal
* Added 500+ tests: memory behavior (test-memory.R), expanded integration
  pipelines (test-integration.R), and stress tests with 100 steps on 10k+
  rows (test-stress.R, skipped on CRAN).

# metasurvey 0.0.11

## Documentation
* Fixed examples across 12 R files for strict CRAN compliance: functions
  requiring an API server, external files, or interactive sessions now use
  `\dontrun{}` instead of `\donttest{}`.
* Fixed `RecipeWorkflow` examples: corrected `recipe_ids` parameter name,
  removed non-existent `variables` parameter.
* Fixed `add_weight`/`add_replicate` examples: removed double-escaped regex
  patterns, removed `load_survey()` calls that depend on external files.
* Made `set_workflow_backend`/`get_workflow_backend` examples runnable
  without `\dontrun{}` wrapper.

## Internal
* Fixed GitHub Actions: added `main` to R-CMD-check PR triggers, replaced
  `master` with `main` in test-coverage and pkgdown, removed broken
  `setup-r-test.yml`.
* Fixed deploy workflow: secrets passed via env vars instead of inline
  shell interpolation, Railway CLI installed via npm with pinned version.

# metasurvey 0.0.10

## New features
* Docker deployment pipeline with GitHub Actions: builds and pushes images
  to GHCR, deploys to Railway on push to main.
* `docker-compose.yml` for local development (API + Shiny stack).

## Bug fixes
* `api_url()` no longer falls back to a hardcoded production URL; returns
  NULL when no URL is configured via option or environment variable.

## Documentation
* Replaced remaining `\dontrun{}` with `\donttest{}` across all exported
  examples for CRAN compliance.
* Added runnable examples for `RecipeWorkflow`, `save_workflow`,
  `read_workflow`, `search_workflows`, `rank_workflows`, `RecipeBackend`.
* Added STATA transpiler usage section to README.
* Added Spanish vignettes: `stata-transpiler-es`, `ech-demographics-recipe-es`.

## Internal
* Updated API Dockerfile with curl-based healthcheck.
* Updated Shiny Dockerfile: configurable `METASURVEY_REF` build arg,
  added `jose` and `git` dependencies.

# metasurvey 0.0.9

## CRAN compliance

* Namespaced all global options: `use_copy` → `metasurvey.use_copy`,
  `lazy_processing` → `metasurvey.lazy_processing`.
* `set_use_copy()` and `set_lazy_processing()` return the previous value
  invisibly, matching `set_engine()` behavior.
* `set_backend()` and `set_workflow_backend()` return the previous value
  invisibly.
* Replaced all `\dontrun{}` examples with runnable or `\donttest{}` where
  appropriate (`set_engine()`, `view_graph()`, `survey_empty()`,
  `set_workflow_backend()`, `get_workflow_backend()`).
* Fixed `print.RecipeWorkflow` example: removed non-existent `recipe_name`
  and `results` arguments.
* Fixed `extract_time_pattern()` roxygen block: was accidentally attached to
  internal `validate_monthly()`, causing the export to be dropped.
* Fixed malformed `@keywords` tags: removed comma-separated values in
  `PoolSurvey` and `RotativePanelSurvey`, removed duplicate description
  block in `Survey` that was parsed as keyword entries.
* Simplified `.onAttach()` to a single version message.
* Removed hardcoded production API URL from `.onLoad()`.
* Deleted orphan Spanish-only vignette `metasurvey-es.Rmd`.
* Added `.Rbuildignore` entries for deployment artifacts (`inst/scripts`,
  `inst/seed-data`, Dockerfiles, `inst/shiny-auth.R`).
* Deleted empty `inst/extdata/` directory.
* Fixed `add_weight()` regex example.
* Fixed `load_survey()` example.
* Fixed `set_lazy()` → `set_lazy_processing()` in vignettes.
* Enabled `eval=TRUE` on in-memory vignette chunks (`bake`, `get-steps`).
* `load_survey_example()`: removed dead `file.exists()` branch, wrapped
  `download.file()` in `tryCatch()` for graceful failure.
* Added `requireNamespace("htmltools")` check in `view_graph()`.
* Removed version constraint from `parallel` in Suggests.
* R CMD check: 0 errors, 0 warnings, 1 note (new submission).

## Translations

* All remaining Spanish return values translated to English:
  `"Trianual"` → `"Triennial"`, `"Multianual"` → `"Multi-year"`.
* All Spanish inline comments translated to English.
* Translated roxygen documentation for `recipe()`, `extract_surveys()`,
  `get_implantation()`, `get_follow_up()`.

## New features

* Added STATA-to-metasurvey transpiler: `transpile_stata()`,
  `transpile_stata_module()`, `parse_do_file()`, `parse_stata_labels()`,
  and `transpile_coverage()`. Converts `.do` files into Recipe JSON,
  supporting gen/replace chains, recode, egen, foreach loops, mvencode,
  destring, labels, and more.
* Added `labels` field to `Recipe` class for storing variable and value
  labels from STATA transpilation.
* Added Shiny DAG graph loading spinner and disclaimer for recipes with
  more than 20 steps.

## Bug fixes

* Fixed `validate_weight_time_pattern()` crash when `weight` is NULL
  (triggered by `shallow_clone()` on surveys without weights).
* Fixed `steps_to_recipe()` producing unparseable step strings: long
  `step_recode` calls were split across multiple lines by `deparse()`,
  breaking JSON round-trip.
* Fixed `bake_recipes()` not executing `step_rename` and `step_remove`:
  recipe step replay now temporarily disables lazy processing so all
  steps execute immediately.
* Fixed Shiny `category_tag()` crash when recipe topic is NULL.

## Documentation

* Added `@family` tags to all exported functions across 16 groups.
* Standardized `@keywords` tags (removed commas, fixed multi-word entries).
* Removed redundant `@title` tags in `R/set_engine.R`.
* Updated `cran-comments.md` to reflect 1 NOTE (new submission).
* Added `stata-transpiler` vignette covering all supported STATA patterns.
* Added `ech-demographics-recipe` vignette showing hand-crafted vs
  transpiled recipe workflows.

# metasurvey 0.0.8

## Bug fixes

* Fixed 5 occurrences of `stop(message(...))` which silently called `stop(NULL)`
  instead of raising a proper error (`set_engine()`, `load_survey()`, `recipe()`).
* Fixed `.Rbuildignore` double-escape bug: patterns had `\\\\.` instead of `\\.`,
  causing hidden files and non-standard files to leak into the tarball.
* Replaced unsafe `1:n` sequences with `seq_len()`/`seq.int()` to avoid
  `c(1, 0)` when n=0 (7 occurrences across survey.R, workflow.R, steps.R).
* Removed duplicate internal `set_data()` definition in survey.R.
* Replaced raw ANSI escape codes with `crayon::red()`/`crayon::green()` in
  `cat_design()` for cross-platform compatibility.
* Removed unreachable dead code in `load_survey_example()`.
* `requireNamespace("parallel")` now uses `quietly = TRUE` and checks the
  return value before using the package.
* `requireNamespace("rio")` return value is now checked before calling
  `rio::convert()`.

## Security

* SSL certificate verification in ANDA client is now enabled by default.
  Previously hardcoded `ssl_verifypeer = FALSE`; now user-controllable
  via `options(metasurvey.ssl_verify = FALSE)`.
* `api_logout()` no longer calls `Sys.unsetenv("METASURVEY_TOKEN")` — only
  clears the R option, per CRAN policy on environment variables.

## CRAN compliance

* `set_engine()`, `set_use_copy()`, `set_lazy_processing()`, and
  `configure_api()` now return the previous value invisibly, allowing users
  to restore global options.
* All user-facing messages translated from Spanish to English.
* `evaluate_cv()` returns English labels ("Excellent", "Good", etc.).
* `extract_time_pattern()` returns "Invalid format"/"Unknown format".
* DESCRIPTION title and description rewritten to be substantive.
* `inst/CITATION` updated: removed deprecated `citHeader()`, dynamic year.
* Fixed inconsistent maintainer email across DESCRIPTION and package docs.
* R CMD check now passes with 0 errors, 0 warnings, 0 NOTEs.

# metasurvey 0.0.7

## New features

* `Recipe$to_list()` and `RecipeWorkflow$to_list()` now include
  `metasurvey_version` for reproducibility tracking.

## Bug fixes

* Fixed `bake_step()` crash when executing `step_recode()`: removed invalid
  `record=FALSE` argument passed to internal `recode()`.
* Fixed `bake_steps_survey()` iterating over the original survey's steps
  instead of the cloned copy, causing inconsistent state.
* Fixed `bake_recipes()` environment leakage: recipe step evaluation now
  uses an isolated `new.env()` instead of the calling `environment()`.
* Removed redundant `copy()` in `compute()` and `recode()` — the
  `shallow_clone()` already handles data copying.
* `step_join()` now uses `merge.data.table()` directly and `set_data()`
  instead of assigning to `$data`.
* Fixed Shiny admin panel memory leak: replaced dynamic
  `observe→lapply→observeEvent` pattern with delegated event handlers.
* Removed `invalidateLater(0)` from admin panel refresh.

## Security

* `store_token()` no longer calls `Sys.setenv()` — API tokens are stored
  in R options only, not leaked to environment variables.
* `token_expires_soon()` returns `TRUE` for `NULL`, malformed, or missing
  `exp` claims, forcing token refresh instead of using potentially invalid tokens.
* API error messages are sanitized to 200 characters maximum.
* Added `validate_api_id()` with alphanumeric whitelist for recipe/workflow IDs.
* Added password length validation (8–128 characters) in `api_register()`.
* `api_download_recipe()` and `api_download_workflow()` now warn on failure
  instead of silently swallowing errors.

## Performance

* Added `debounce(300)` on Shiny recipe search input to reduce excessive
  reactivity.

## Internal

* Replaced `sapply()` with `vapply()` or `lapply()` across the codebase
  for type-safe return values.
* `set_engine()` uses `requireNamespace()` instead of `eval(install.packages(...))`.
* `read_recipe()` now warns when step parsing falls back to raw strings.
* Added ORCID identifiers for authors in DESCRIPTION.
* Added ANDA fetch failure notification in Shiny explore module.

# metasurvey 0.0.6

## Documentation

* All exported functions and R6 classes now have `@return` and `@examples`
  roxygen2 tags, meeting rOpenSci documentation requirements.
* Added `@return` to R6 class exports: `Recipe`, `RecipeWorkflow`,
  `RecipeCategory`, `RecipeCertification`, `RecipeUser`, `PoolSurvey`,
  `RotativePanelSurvey`, and `Survey`.
* Added `@examples` to `set_engine()`, `show_engines()`, `get_engine()`,
  and all API/backend functions.
* Added `@return` to `get_metadata()`, `set_lazy_processing()`,
  `set_use_copy()`, `set_backend()`, `set_workflow_backend()`, and
  `explore_recipes()`.

## Bug fixes

* Fixed Codecov GitHub Actions workflow: replaced deprecated `covr::codecov()`
  with `covr::package_coverage()` + `codecov/codecov-action@v5` for reliable
  coverage uploads with token authentication.
* Added CI guard to `.Rprofile` to skip example-data setup in GitHub Actions,
  preventing potential download failures during CI builds.
* Added missing `archive`, `haven`, and `openxlsx` to `Suggests` in
  DESCRIPTION, fixing R CMD check warnings about undeclared dependencies.

## Internal

* Added `.claude/` directory with development agents and commands for
  code review, testing, documentation auditing, and rOpenSci preparation.

# metasurvey 0.0.5

## Breaking changes

* **AST engine removed**: The Abstract Syntax Tree evaluation engine (`R/ast.R`)
  has been replaced by direct `data.table` expression evaluation. This simplifies
  the step pipeline and removes ~760 lines of internal code. Users who relied on
  internal AST functions (`parse_ast`, `evaluate_ast_node`, `recode_with_ast`,
  `optimize_node`) will need to update their code. The public API
  (`step_compute()`, `step_recode()`, `bake_steps()`) remains unchanged.

* **API client migrated to JWT**: The API client (`R/api_client.R`) now uses
  JWT authentication with a self-hosted Plumber backend, replacing the previous
  Atlas Data API approach.

## New features

* **Lazy design initialization**: `Survey$new()` no longer builds `svydesign`
  objects at construction time. Designs are created on-demand when needed
  (e.g., during `workflow()` or `bake_steps()`), significantly improving
  construction performance for large datasets. The `psu` parameter is now
  optional (default `NULL`).

* **Recipe ecosystem**: New infrastructure for publishing, discovering, and
  managing reproducible survey processing recipes:
  - `RecipeRegistry` R6 class with pluggable backends (JSON file, MongoDB).
  - `RecipeCategory` for hierarchical categorization of recipes.
  - `RecipeCertification` for quality certification levels (official, reviewed,
    community).
  - `RecipeUser` for author/maintainer profiles with institutional affiliations.
  - Tidy API: `list_recipes()`, `search_recipes()`, `filter_recipes()`,
    `rank_recipes()`.
  - `Recipe$doc()` for auto-generated documentation.
  - `Recipe$validate(svy)` for dependency checking against a survey.
  - `print.Recipe` S3 method for human-readable output.
  - `save_recipe()` / `read_recipe()` for JSON serialization.

* **Workflow system**: New estimation workflow infrastructure:
  - `RecipeWorkflow` R6 class capturing `svymean`/`svytotal`/`svyratio`/`svyby`
    calls with recipe references and reproducibility metadata.
  - `WorkflowRegistry` with pluggable backends (JSON, MongoDB).
  - Auto-capture of workflow metadata via `.capture_workflow()` when surveys
    contain recipes.
  - `workflow_from_list()` for reconstructing workflows from JSON/API responses.
  - Tidy API: `list_workflows()`, `search_workflows()`, `filter_workflows()`,
    `rank_workflows()`, `find_workflows_for_recipe()`, `publish_workflow()`.
  - `save_workflow()` / `read_workflow()` for serialization.

* **REST API** (`inst/api/plumber.R`): Self-hosted Plumber API with JWT
  authentication for recipe and workflow publishing. Endpoints for CRUD
  operations on recipes, workflows, and user management. Includes Docker
  deployment configuration.

* **ANDA catalog integration** (`R/anda.R`): Functions for accessing INE
  Uruguay's ANDA5 catalog metadata:
  - `anda_catalog_search()` for searching the catalog.
  - `anda_list_editions()` for listing available survey editions.
  - `anda_fetch_ddi()` for fetching DDI metadata.
  - `anda_parse_variables()` for extracting variable definitions.
  - `anda_variable_detail()` for detailed variable information.

* **Shiny explorer app** (`inst/shiny/`): Interactive recipe and workflow
  browser launched via `explore_recipes()`:
  - Recipe gallery with search, filtering by survey type/certification, and
    detail modals showing pipeline visualization and R code snippets.
  - Workflow gallery with estimation timeline and cross-references to recipes.
  - User authentication with registration, login, and profile management.
  - Token generation for programmatic API access from R scripts.

* **`bake_recipes()` handles string steps**: Steps stored as strings (from
  JSON/API) are now parsed to call objects before evaluation, fixing the
  previous "attempt to apply non-function" error.

## Bug fixes

* `is_blank()` now handles `NULL` and zero-length inputs without error.
* Fixed regex in `extract_time_pattern()`: type prefix detection now correctly
  matches only at string start.
* Multianual year-range patterns (e.g., `"2019_2021"`) are now correctly
  parsed when separated by underscore.
* `validate_time_pattern()` gracefully handles `NULL`/empty edition strings.
* Improved `public_key()` error handling with informative messages.
* `workflow_from_list()` is now exported (was `@keywords internal`), fixing
  Shiny app workflow parsing from API responses.

## Documentation

* Complete vignette rewrite with `eval=TRUE` examples:
  - `getting-started`: Survey creation, steps, recipes, and workflows.
  - `recipes`: Recipe ecosystem, publishing, and discovery.
  - `workflows-and-estimation`: Estimation workflows and registry.
  - `complex-designs`: Replicate weights, stratified designs.
  - `panel-analysis`: Rotating panel surveys.
  - `ech-case-study`: Full ECH processing example.
  - `shiny-explorer`: Interactive app usage guide.
  - `api-database`: REST API and database architecture.
* All vignettes available in Spanish (`*-es.Rmd`).
* Added `references.bib` for academic citations.
* Added `pkgdown` site configuration with rOpenSci template.

# metasurvey 0.0.3

* Added `step_join()` for merging external reference data into surveys.
* Added `step_remove()` and `step_rename()` for variable management.

# metasurvey 0.0.2

* Added `RotativePanelSurvey` and `PoolSurvey` R6 classes for complex designs.
* Added `extract_surveys()`, `get_implantation()`, `get_follow_up()`.

# metasurvey 0.0.1

* Initial CRAN submission.
