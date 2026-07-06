# Changelog

## metasurvey 0.0.24

CRAN release: 2026-06-27

### Breaking changes

- [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md):
  parameter `conf.level` renamed to `level` to match
  [`stats::confint()`](https://rdrr.io/r/stats/confint.html) and
  `survey` package conventions. Per-call overrides now use `level` as
  well (e.g., `svymean(~x, level = 0.90)`).

### Bug fixes

- `step_compute(.by=)`: grouped computations now survive
  [`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md).
  Previously the `.by` parameter was not stored in the `Step` object, so
  re-baking would re-execute without grouping, producing wrong results.
- `compute()` with `.by`: fixed
  [`merge()`](https://rdrr.io/r/base/merge.html) creating `.x`/`.y`
  suffix columns when the target column already existed in the data
  (e.g., during re-baking).

## metasurvey 0.0.23

### New features

- [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  now supports `conf.level` inside individual estimation calls (e.g.,
  `svymean(~x, na.rm = TRUE, conf.level = 0.80)`). The per-call value
  overrides the
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  default, allowing different confidence levels for each estimation in
  the same call.

## metasurvey 0.0.22

### New features

- [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  gains a `conf.level` parameter (default `0.95`) to control the
  confidence level of the interval. Passed through to
  [`stats::confint()`](https://rdrr.io/r/stats/confint.html) for all
  estimation types (`svymean`, `svyby`, `svyratio`, `convey`).
- [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  output now includes `variable` and `evaluate` columns across all
  estimation types. `variable` enables clean filtering/grouping;
  `evaluate` classifies CV quality via
  [`evaluate_cv()`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md).
  `svyby` results no longer embed group labels in the `stat` column —
  grouping variables (`region`, `sexo`, etc.) appear as separate
  columns.

## metasurvey 0.0.21

CRAN release: 2026-02-25

### New features

- [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  now supports `convey` package functions (`svygini`, `svyatk`,
  `svyarpr`, `svyfgt`, etc.) for poverty and inequality estimation with
  proper standard errors and CVs.

### Bug fixes

- `validate_weight()` now shows available columns when weight is not
  found.
- `validate_replicate()` now lists missing replicate ID columns in the
  error.
- [`set_use_copy()`](https://metasurveyr.github.io/metasurvey/reference/set_use_copy.md)
  and
  [`set_lazy_processing()`](https://metasurveyr.github.io/metasurvey/reference/set_lazy_processing.md)
  reject non-scalar logical input.

### Internal

- Step functions (`step_join`, `step_remove`, `step_rename`,
  `step_validate`, `step_filter`) now return `invisible(out)` per R
  convention for side-effect functions.
- Added `@rdname provenance` to S3 method documentation.
- Removed unused [`stats::median`](https://rdrr.io/r/stats/median.html)
  and [`stats::quantile`](https://rdrr.io/r/stats/quantile.html)
  imports.
- Use fully qualified
  [`stats::confint()`](https://rdrr.io/r/stats/confint.html) in
  `cat_estimation.svyratio`.
- Added edge case tests: double bake idempotency, filter-then-compute
  chain, `provenance_diff` print output.

## metasurvey 0.0.20

### Breaking changes

- [`survey_to_data.table()`](https://metasurveyr.github.io/metasurvey/reference/survey_to_datatable.md)
  is deprecated in favor of
  [`survey_to_datatable()`](https://metasurveyr.github.io/metasurvey/reference/survey_to_datatable.md)
  (avoids non-standard dots in function names). The old function still
  works with a deprecation warning.

### New features

- `metasurvey_msg()` internal helper wraps
  [`message()`](https://rdrr.io/r/base/message.html) behind
  `options(metasurvey.verbose = FALSE)` for silent operation in scripts.
- All HTTP requests (ANDA, API client, Shiny) now send a
  `metasurvey/<version>` User-Agent header.
- `read_file()` now gives an actionable install hint when the required
  reader package is missing (e.g., `haven` for `.dta` files).

### Bug fixes

- Added `call. = FALSE` to all
  [`stop()`](https://rdrr.io/r/base/stop.html) and
  [`warning()`](https://rdrr.io/r/base/warning.html) calls for cleaner
  error tracebacks without internal call stack noise.
- Fixed `&` vs `&&` in `compute()` and `cat_estimation()` — single `&`
  would evaluate both sides even when the first was FALSE.
- [`get_metadata()`](https://metasurveyr.github.io/metasurvey/reference/get_metadata.md)
  now uses [`cat()`](https://rdrr.io/r/base/cat.html) instead of
  [`message()`](https://rdrr.io/r/base/message.html), making output
  testable with `expect_output()` and suppressible with
  [`capture.output()`](https://rdrr.io/r/utils/capture.output.html).
- Removed `.onAttach()` startup message (package loads silently).

### Documentation

- Fixed all broken URLs flagged by CRAN: updated Azure AKS and INE
  Uruguay redirects, removed dead Railway API and metasurvey-infra
  links.
- Included `api-database` vignette in build (was excluded via
  `.Rbuildignore`, causing broken cross-vignette file URI references).
- Reduced vignette tarball from 10.6 MB to 3.7 MB by disabling
  `visNetwork` widget rendering (`eval = FALSE`).
- Replaced `\dontrun{}` examples in
  [`get_implantation()`](https://metasurveyr.github.io/metasurvey/reference/get_implantation.md)
  and
  [`get_follow_up()`](https://metasurveyr.github.io/metasurvey/reference/get_follow_up.md)
  with runnable examples using test data.
- Added runnable examples for
  [`provenance_to_json()`](https://metasurveyr.github.io/metasurvey/reference/provenance_to_json.md)
  and
  [`provenance_diff()`](https://metasurveyr.github.io/metasurvey/reference/provenance_diff.md).
- Added `@family transpiler` cross-references to all transpiler
  functions.
- Documented default parameter values across all `step_*` and tidy API
  functions.
- Added `print.metasurvey_provenance_diff` man page.
- Removed unused `digest` from Suggests.

## metasurvey 0.0.19

### New features

- [`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md):
  new step type for row-level filtering within the pipeline. Multiple
  conditions are AND-combined. Supports `.by` for within-group
  filtering, lazy evaluation, and RotativePanelSurvey dispatch.
- [`provenance()`](https://metasurveyr.github.io/metasurvey/reference/provenance.md):
  lightweight data lineage tracking. Surveys now record source file,
  load timestamp, initial row count, and per-step history (type, N
  before/after, duration). Workflow results carry provenance as an
  attribute. Includes
  [`provenance_to_json()`](https://metasurveyr.github.io/metasurvey/reference/provenance_to_json.md)
  for audit trails and
  [`provenance_diff()`](https://metasurveyr.github.io/metasurvey/reference/provenance_diff.md)
  for cross-edition comparison.
- [`workflow_table()`](https://metasurveyr.github.io/metasurvey/reference/workflow_table.md):
  publication-quality formatted tables from
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  results using `gt`. Features confidence intervals, CV quality
  classification with color coding, `compare_by` for side-by-side
  edition comparison, locale-aware formatting (“en”/“es”), and
  provenance-based source notes. Falls back to
  [`knitr::kable()`](https://rdrr.io/pkg/knitr/man/kable.html) if `gt`
  is not installed.

### Bug fixes

- Fixed stars and comments not persisting to MongoDB: the plumber API
  star/comment endpoints used `if (!is.null(auth_err))` to check
  authentication, but `require_auth()` always returns non-NULL (user
  object on success, error list on failure). The endpoints returned the
  JWT payload immediately without ever reaching the database write.
  Fixed all 5 affected endpoints (recipe star, recipe comment, workflow
  star, workflow comment, delete comment) and added `result$ok` checks
  in Shiny modules so errors are reported instead of silently swallowed.

### Dependencies

- Added `gt` (\>= 0.10.0) to Suggests.

## metasurvey 0.0.18

### New features

- [`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md):
  declarative data validation step that checks invariants without
  mutating data. Supports row-level logical expressions, named checks,
  `.min_n`, and `.action = "stop"` or `"warn"`.
- Stars and comments API: users can rate (1-5) and comment on recipes
  and workflows. New R functions:
  [`api_star_recipe()`](https://metasurveyr.github.io/metasurvey/reference/api_star_recipe.md),
  [`api_get_recipe_stars()`](https://metasurveyr.github.io/metasurvey/reference/api_get_recipe_stars.md),
  [`api_comment_recipe()`](https://metasurveyr.github.io/metasurvey/reference/api_comment_recipe.md),
  [`api_get_recipe_comments()`](https://metasurveyr.github.io/metasurvey/reference/api_get_recipe_comments.md),
  [`api_delete_comment()`](https://metasurveyr.github.io/metasurvey/reference/api_delete_comment.md),
  [`api_get_recipe_dependents()`](https://metasurveyr.github.io/metasurvey/reference/api_get_recipe_dependents.md),
  and workflow equivalents.
- Backlinks: `GET /recipes/:id/dependents` returns recipes that depend
  on a given recipe via `depends_on_recipes`.
- Shiny app: star rating widget, comment section, and dependents panel
  in recipe and workflow detail modals.

### Performance

- `optimize_steps()` now collapses consecutive independent
  [`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md)
  calls into single calls with dependency analysis, reducing transpiled
  step counts.

### Bug fixes

- Fixed DHS vignette chunk failing when external URL is unreachable.

## metasurvey 0.0.17

### New features

- Indicators API module: new `/indicators` REST endpoints for publishing
  estimation results with full traceability (indicator -\> workflow -\>
  recipe). Feature-gated via `METASURVEY_ENABLE_INDICATORS` env var.
- Compute worker service: on-demand estimation via
  `POST /indicators/compute`. The worker loads private microdata,
  applies recipes, and runs
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md).
  Deployed as a separate Docker container, never exposes raw survey
  data.
- Self-hosting vignette: deployment guide with Docker Compose, including
  hybrid mode (public recipe registry + private worker with microdata).

### Documentation

- Updated self-hosting vignette with hybrid deployment architecture
  diagram.

## metasurvey 0.0.16

### Dependencies

- Migrated `crayon` to `cli` for terminal output coloring. All
  [`crayon::bold()`](http://r-lib.github.io/crayon/reference/crayon.md),
  [`crayon::silver()`](http://r-lib.github.io/crayon/reference/crayon.md),
  [`crayon::green()`](http://r-lib.github.io/crayon/reference/crayon.md),
  etc. replaced with
  [`cli::style_bold()`](https://cli.r-lib.org/reference/ansi-styles.html),
  [`cli::col_silver()`](https://cli.r-lib.org/reference/ansi-styles.html),
  [`cli::col_green()`](https://cli.r-lib.org/reference/ansi-styles.html),
  etc. across 8 files.
- Migrated `httr` to `httr2` for HTTP requests. All API client, ANDA
  catalog, and Shiny helper functions now use the pipe-based `httr2` API
  (`request() |> req_headers() |> req_perform()`).
- Replaced all
  [`glue::glue_col()`](https://glue.tidyverse.org/reference/glue_col.html)
  calls (which depended on crayon color functions) with
  [`glue::glue()`](https://glue.tidyverse.org/reference/glue.html) +
  `cli::col_*()` wrappers.
- Removed `bit64` and `jose` (already unused since 0.0.14) from
  Dockerfile.
- Removed `casen` from Suggests (GitHub-only package, not available on
  CRAN).
- Removed `pak` from Suggests (no longer used in vignettes).

### Bug fixes

- Fixed international-surveys vignette crash on PNADcIBGE example data:
  set `options(survey.lonely.psu = "adjust")` for strata with single
  PSUs.
- Fixed vignette setup chunk that attempted to install packages at build
  time via `pak`; replaced with
  [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html) guards.
- Updated Shiny Dockerfile dependencies to match new imports (httr2,
  cli).

### Internal

- Excluded 9 Spanish (`*-es.Rmd`) vignettes from CRAN tarball via
  `.Rbuildignore` (remain available on pkgdown site).

## metasurvey 0.0.15

### New features

- Added `strata` parameter to `Survey$new()`,
  [`survey_empty()`](https://metasurveyr.github.io/metasurvey/reference/survey_empty.md),
  [`load_survey()`](https://metasurveyr.github.io/metasurvey/reference/load_survey.md),
  and
  [`load_panel_survey()`](https://metasurveyr.github.io/metasurvey/reference/load_panel_survey.md)
  for stratified sampling designs. Passed to
  `survey::svydesign(strata = ...)`.
- New vignette: “International Survey Compatibility” (EN + ES) with
  reproducible examples for ECH, EPH, CASEN, PNADc, CPS, ENIGH, and DHS.

### Documentation

- Eliminated `eval=FALSE` from all vignettes — chunks now use
  conditional eval or markdown code blocks for non-runnable examples.
- Improved man page examples: replaced `\dontrun{}` with `\donttest{}`
  and runnable local-data examples for `cat_design`, `bake_recipes`,
  `recipe`, `steps_to_recipe`, `transpile_stata`, `parse_do_file`, and
  others.
- Added stratified cluster design section to complex-designs vignette.
- Rewrote README with live service links (Shiny explorer, REST API),
  CRAN status badge, and GitHub star call-to-action.

### Internal

- Expanded test suite to 2810 tests covering strata support, edge cases
  in STATA transpiler, API client, panel surveys, and recipe system.
- Expanded test suite to cover strata support in survey construction and
  workflow estimation.

## metasurvey 0.0.14

### Breaking changes

- `Step$comments` field renamed to `Step$comment`. The old name still
  works as a legacy alias but will be removed in a future version.
- [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  first parameter renamed from `survey` to `svy` for consistency.
  Positional usage is unchanged.
- `Survey$set_weight()` no longer emits `message("Setting weight")`.
- [`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md)
  `.name_step` parameter is deprecated; use `comment` instead.

### New features

- `use_copy` parameter in all step functions (`step_compute`,
  `step_recode`, `step_join`, `step_remove`, `step_rename`) is
  deprecated in favour of `.copy`, following dplyr’s dot-prefix
  convention for secondary arguments.
- Added survey state predicates:
  [`has_steps()`](https://metasurveyr.github.io/metasurvey/reference/has_steps.md),
  [`has_recipes()`](https://metasurveyr.github.io/metasurvey/reference/has_recipes.md),
  [`is_baked()`](https://metasurveyr.github.io/metasurvey/reference/is_baked.md),
  [`has_design()`](https://metasurveyr.github.io/metasurvey/reference/has_design.md).
- [`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md),
  [`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md),
  [`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md),
  [`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md)
  no longer default `svy` to
  [`survey_empty()`](https://metasurveyr.github.io/metasurvey/reference/survey_empty.md);
  the survey argument is now required.
- [`extract_time_pattern()`](https://metasurveyr.github.io/metasurvey/reference/extract_time_pattern.md)
  now recognises quarter/trimester editions (`"2023-T3"`, `"2023-Q1"`),
  parsed as `Quarterly` periodicity.

### Bug fixes

- Fixed
  [`validate_time_pattern()`](https://metasurveyr.github.io/metasurvey/reference/validate_time_pattern.md)
  crash when `svy_edition` is `NA`.
- Fixed `shallow_clone()` re-running
  [`validate_time_pattern()`](https://metasurveyr.github.io/metasurvey/reference/validate_time_pattern.md)
  on already-parsed editions, causing cascading NULL → NA → crash.
- Fixed
  [`get_metadata()`](https://metasurveyr.github.io/metasurvey/reference/get_metadata.md)
  crash when edition is NULL or NA.
- Fixed `cat_estimation.svyby()` producing wrong output: margins index
  was integer (not column name), SE column `"se"` was missed by grep,
  and [`cv()`](https://rdrr.io/pkg/survey/man/surveysummary.html)
  data.frame was not handled. Output now shows group labels in the
  `stat` column (e.g. `svyby: x [sexo=1]`).
- Mixed estimation types (`svymean` + `svyby`) no longer fail on
  `rbindlist` due to mismatched columns.
- Fixed
  [`set_engine()`](https://metasurveyr.github.io/metasurvey/reference/set_engine.md)
  logic bug where `identical(.engine, show_engines())` compared string
  vs vector, silently failing.
- Fixed vague `stop("Error in step")` in
  [`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md)
  validation — now reports which variables failed.
- Removed dead dots-filtering code in
  [`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md)
  and
  [`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md).

### Dependencies

- Removed unused `bit64` import (CRAN compliance).
- Replaced `jose` dependency with
  [`jsonlite::base64url_dec()`](https://jeroen.r-universe.dev/jsonlite/reference/base64.html)
  for JWT decoding — one less hard dependency.
- `design_active` active binding now delegates to `ensure_design()`,
  removing duplicated design-building logic.

### Documentation

- All `step_*` functions now document lazy evaluation behavior in
  `@details`.
- Improved
  [`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md)
  and
  [`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md)
  roxygen with full `@details` sections matching
  [`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md)
  depth.
- [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  `@param svy` now prominently documents the
  [`list()`](https://rdrr.io/r/base/list.html) requirement.
- Cleaned up Survey class roxygen: removed duplicate Methods sections.
- Updated vignettes to use `Step$comment` instead of `Step$comments`.
- Vignettes now use real ECH 2023 sample data instead of simulated data.
- Fixed ECH variable names for 2023 edition (`e31` → `e30`).

## metasurvey 0.0.12

### Bug fixes

- Fixed critical memory leak when chaining N steps: eliminated
  `svy_before` retention chain that prevented GC from freeing N copies
  of the data.table.
- Fixed `bake_step` re-recording step_join/step_remove/step_rename
  during bake, which caused duplicate steps.

### Performance

- [`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
  uses `shallow_clone()` instead of `clone(deep=TRUE)`, avoiding
  duplication of the entire step chain on every bake.
- `add_step()` invalidates design lazily instead of rebuilding
  `svydesign` on every step addition.
- Removed wasteful
  [`copy()`](https://rdrr.io/pkg/data.table/man/copy.html) calls in
  `step_compute` and `step_recode`.

### Internal

- Added 500+ tests: memory behavior (test-memory.R), expanded
  integration pipelines (test-integration.R), and stress tests with 100
  steps on 10k+ rows (test-stress.R, skipped on CRAN).

## metasurvey 0.0.11

### Documentation

- Fixed examples across 12 R files for strict CRAN compliance: functions
  requiring an API server, external files, or interactive sessions now
  use `\dontrun{}` instead of `\donttest{}`.
- Fixed `RecipeWorkflow` examples: corrected `recipe_ids` parameter
  name, removed non-existent `variables` parameter.
- Fixed `add_weight`/`add_replicate` examples: removed double-escaped
  regex patterns, removed
  [`load_survey()`](https://metasurveyr.github.io/metasurvey/reference/load_survey.md)
  calls that depend on external files.
- Made `set_workflow_backend`/`get_workflow_backend` examples runnable
  without `\dontrun{}` wrapper.

### Internal

- Fixed GitHub Actions: added `main` to R-CMD-check PR triggers,
  replaced `master` with `main` in test-coverage and pkgdown, removed
  broken `setup-r-test.yml`.
- Fixed deploy workflow: secrets passed via env vars instead of inline
  shell interpolation, Railway CLI installed via npm with pinned
  version.

## metasurvey 0.0.10

### New features

- Docker deployment pipeline with GitHub Actions: builds and pushes
  images to GHCR, deploys to Railway on push to main.
- `docker-compose.yml` for local development (API + Shiny stack).

### Bug fixes

- `api_url()` no longer falls back to a hardcoded production URL;
  returns NULL when no URL is configured via option or environment
  variable.

### Documentation

- Replaced remaining `\dontrun{}` with `\donttest{}` across all exported
  examples for CRAN compliance.
- Added runnable examples for `RecipeWorkflow`, `save_workflow`,
  `read_workflow`, `search_workflows`, `rank_workflows`,
  `RecipeBackend`.
- Added STATA transpiler usage section to README.
- Added Spanish vignettes: `stata-transpiler-es`,
  `ech-demographics-recipe-es`.

### Internal

- Updated API Dockerfile with curl-based healthcheck.
- Updated Shiny Dockerfile: configurable `METASURVEY_REF` build arg,
  added `jose` and `git` dependencies.

## metasurvey 0.0.9

### CRAN compliance

- Namespaced all global options: `use_copy` → `metasurvey.use_copy`,
  `lazy_processing` → `metasurvey.lazy_processing`.
- [`set_use_copy()`](https://metasurveyr.github.io/metasurvey/reference/set_use_copy.md)
  and
  [`set_lazy_processing()`](https://metasurveyr.github.io/metasurvey/reference/set_lazy_processing.md)
  return the previous value invisibly, matching
  [`set_engine()`](https://metasurveyr.github.io/metasurvey/reference/set_engine.md)
  behavior.
- [`set_backend()`](https://metasurveyr.github.io/metasurvey/reference/set_backend.md)
  and
  [`set_workflow_backend()`](https://metasurveyr.github.io/metasurvey/reference/set_workflow_backend.md)
  return the previous value invisibly.
- Replaced all `\dontrun{}` examples with runnable or `\donttest{}`
  where appropriate
  ([`set_engine()`](https://metasurveyr.github.io/metasurvey/reference/set_engine.md),
  [`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md),
  [`survey_empty()`](https://metasurveyr.github.io/metasurvey/reference/survey_empty.md),
  [`set_workflow_backend()`](https://metasurveyr.github.io/metasurvey/reference/set_workflow_backend.md),
  [`get_workflow_backend()`](https://metasurveyr.github.io/metasurvey/reference/get_workflow_backend.md)).
- Fixed `print.RecipeWorkflow` example: removed non-existent
  `recipe_name` and `results` arguments.
- Fixed
  [`extract_time_pattern()`](https://metasurveyr.github.io/metasurvey/reference/extract_time_pattern.md)
  roxygen block: was accidentally attached to internal
  `validate_monthly()`, causing the export to be dropped.
- Fixed malformed `@keywords` tags: removed comma-separated values in
  `PoolSurvey` and `RotativePanelSurvey`, removed duplicate description
  block in `Survey` that was parsed as keyword entries.
- Simplified `.onAttach()` to a single version message.
- Removed hardcoded production API URL from `.onLoad()`.
- Deleted orphan Spanish-only vignette `metasurvey-es.Rmd`.
- Added `.Rbuildignore` entries for deployment artifacts
  (`inst/scripts`, `inst/seed-data`, Dockerfiles, `inst/shiny-auth.R`).
- Deleted empty `inst/extdata/` directory.
- Fixed
  [`add_weight()`](https://metasurveyr.github.io/metasurvey/reference/add_weight.md)
  regex example.
- Fixed
  [`load_survey()`](https://metasurveyr.github.io/metasurvey/reference/load_survey.md)
  example.
- Fixed `set_lazy()` →
  [`set_lazy_processing()`](https://metasurveyr.github.io/metasurvey/reference/set_lazy_processing.md)
  in vignettes.
- Enabled `eval=TRUE` on in-memory vignette chunks (`bake`,
  `get-steps`).
- [`load_survey_example()`](https://metasurveyr.github.io/metasurvey/reference/load_survey_example.md):
  removed dead [`file.exists()`](https://rdrr.io/r/base/files.html)
  branch, wrapped
  [`download.file()`](https://rdrr.io/r/utils/download.file.html) in
  [`tryCatch()`](https://rdrr.io/r/base/conditions.html) for graceful
  failure.
- Added
  [`requireNamespace("htmltools")`](https://github.com/rstudio/htmltools)
  check in
  [`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md).
- Removed version constraint from `parallel` in Suggests.
- R CMD check: 0 errors, 0 warnings, 1 note (new submission).

### Translations

- All remaining Spanish return values translated to English:
  `"Trianual"` → `"Triennial"`, `"Multianual"` → `"Multi-year"`.
- All Spanish inline comments translated to English.
- Translated roxygen documentation for
  [`recipe()`](https://metasurveyr.github.io/metasurvey/reference/recipe.md),
  [`extract_surveys()`](https://metasurveyr.github.io/metasurvey/reference/extract_surveys.md),
  [`get_implantation()`](https://metasurveyr.github.io/metasurvey/reference/get_implantation.md),
  [`get_follow_up()`](https://metasurveyr.github.io/metasurvey/reference/get_follow_up.md).

### New features

- Added STATA-to-metasurvey transpiler:
  [`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md),
  [`transpile_stata_module()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata_module.md),
  [`parse_do_file()`](https://metasurveyr.github.io/metasurvey/reference/parse_do_file.md),
  [`parse_stata_labels()`](https://metasurveyr.github.io/metasurvey/reference/parse_stata_labels.md),
  and
  [`transpile_coverage()`](https://metasurveyr.github.io/metasurvey/reference/transpile_coverage.md).
  Converts `.do` files into Recipe JSON, supporting gen/replace chains,
  recode, egen, foreach loops, mvencode, destring, labels, and more.
- Added `labels` field to `Recipe` class for storing variable and value
  labels from STATA transpilation.
- Added Shiny DAG graph loading spinner and disclaimer for recipes with
  more than 20 steps.

### Bug fixes

- Fixed `validate_weight_time_pattern()` crash when `weight` is NULL
  (triggered by `shallow_clone()` on surveys without weights).
- Fixed
  [`steps_to_recipe()`](https://metasurveyr.github.io/metasurvey/reference/steps_to_recipe.md)
  producing unparseable step strings: long `step_recode` calls were
  split across multiple lines by
  [`deparse()`](https://rdrr.io/r/base/deparse.html), breaking JSON
  round-trip.
- Fixed
  [`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md)
  not executing `step_rename` and `step_remove`: recipe step replay now
  temporarily disables lazy processing so all steps execute immediately.
- Fixed Shiny `category_tag()` crash when recipe topic is NULL.

### Documentation

- Added `@family` tags to all exported functions across 16 groups.
- Standardized `@keywords` tags (removed commas, fixed multi-word
  entries).
- Removed redundant `@title` tags in `R/set_engine.R`.
- Updated `cran-comments.md` to reflect 1 NOTE (new submission).
- Added `stata-transpiler` vignette covering all supported STATA
  patterns.
- Added `ech-demographics-recipe` vignette showing hand-crafted vs
  transpiled recipe workflows.

## metasurvey 0.0.8

### Bug fixes

- Fixed 5 occurrences of `stop(message(...))` which silently called
  `stop(NULL)` instead of raising a proper error
  ([`set_engine()`](https://metasurveyr.github.io/metasurvey/reference/set_engine.md),
  [`load_survey()`](https://metasurveyr.github.io/metasurvey/reference/load_survey.md),
  [`recipe()`](https://metasurveyr.github.io/metasurvey/reference/recipe.md)).
- Fixed `.Rbuildignore` double-escape bug: patterns had `\\\\.` instead
  of `\\.`, causing hidden files and non-standard files to leak into the
  tarball.
- Replaced unsafe `1:n` sequences with
  [`seq_len()`](https://rdrr.io/r/base/seq.html)/[`seq.int()`](https://rdrr.io/r/base/seq.html)
  to avoid `c(1, 0)` when n=0 (7 occurrences across survey.R,
  workflow.R, steps.R).
- Removed duplicate internal
  [`set_data()`](https://metasurveyr.github.io/metasurvey/reference/set_data.md)
  definition in survey.R.
- Replaced raw ANSI escape codes with
  [`crayon::red()`](http://r-lib.github.io/crayon/reference/crayon.md)/[`crayon::green()`](http://r-lib.github.io/crayon/reference/crayon.md)
  in
  [`cat_design()`](https://metasurveyr.github.io/metasurvey/reference/cat_design.md)
  for cross-platform compatibility.
- Removed unreachable dead code in
  [`load_survey_example()`](https://metasurveyr.github.io/metasurvey/reference/load_survey_example.md).
- [`requireNamespace("parallel")`](https://rdrr.io/r/base/ns-load.html)
  now uses `quietly = TRUE` and checks the return value before using the
  package.
- [`requireNamespace("rio")`](https://gesistsa.github.io/rio/) return
  value is now checked before calling
  [`rio::convert()`](http://gesistsa.github.io/rio/reference/convert.md).

### Security

- SSL certificate verification in ANDA client is now enabled by default.
  Previously hardcoded `ssl_verifypeer = FALSE`; now user-controllable
  via `options(metasurvey.ssl_verify = FALSE)`.
- [`api_logout()`](https://metasurveyr.github.io/metasurvey/reference/api_logout.md)
  no longer calls `Sys.unsetenv("METASURVEY_TOKEN")` — only clears the R
  option, per CRAN policy on environment variables.

### CRAN compliance

- [`set_engine()`](https://metasurveyr.github.io/metasurvey/reference/set_engine.md),
  [`set_use_copy()`](https://metasurveyr.github.io/metasurvey/reference/set_use_copy.md),
  [`set_lazy_processing()`](https://metasurveyr.github.io/metasurvey/reference/set_lazy_processing.md),
  and
  [`configure_api()`](https://metasurveyr.github.io/metasurvey/reference/configure_api.md)
  now return the previous value invisibly, allowing users to restore
  global options.
- All user-facing messages translated from Spanish to English.
- [`evaluate_cv()`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md)
  returns English labels (“Excellent”, “Good”, etc.).
- [`extract_time_pattern()`](https://metasurveyr.github.io/metasurvey/reference/extract_time_pattern.md)
  returns “Invalid format”/“Unknown format”.
- DESCRIPTION title and description rewritten to be substantive.
- `inst/CITATION` updated: removed deprecated
  [`citHeader()`](https://rdrr.io/r/utils/citation.html), dynamic year.
- Fixed inconsistent maintainer email across DESCRIPTION and package
  docs.
- R CMD check now passes with 0 errors, 0 warnings, 0 NOTEs.

## metasurvey 0.0.7

### New features

- `Recipe$to_list()` and `RecipeWorkflow$to_list()` now include
  `metasurvey_version` for reproducibility tracking.

### Bug fixes

- Fixed `bake_step()` crash when executing
  [`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md):
  removed invalid `record=FALSE` argument passed to internal `recode()`.
- Fixed `bake_steps_survey()` iterating over the original survey’s steps
  instead of the cloned copy, causing inconsistent state.
- Fixed
  [`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md)
  environment leakage: recipe step evaluation now uses an isolated
  [`new.env()`](https://rdrr.io/r/base/environment.html) instead of the
  calling [`environment()`](https://rdrr.io/r/base/environment.html).
- Removed redundant
  [`copy()`](https://rdrr.io/pkg/data.table/man/copy.html) in
  `compute()` and `recode()` — the `shallow_clone()` already handles
  data copying.
- [`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md)
  now uses
  [`merge.data.table()`](https://rdrr.io/pkg/data.table/man/merge.html)
  directly and
  [`set_data()`](https://metasurveyr.github.io/metasurvey/reference/set_data.md)
  instead of assigning to `$data`.
- Fixed Shiny admin panel memory leak: replaced dynamic
  `observe→lapply→observeEvent` pattern with delegated event handlers.
- Removed `invalidateLater(0)` from admin panel refresh.

### Security

- `store_token()` no longer calls
  [`Sys.setenv()`](https://rdrr.io/r/base/Sys.setenv.html) — API tokens
  are stored in R options only, not leaked to environment variables.
- `token_expires_soon()` returns `TRUE` for `NULL`, malformed, or
  missing `exp` claims, forcing token refresh instead of using
  potentially invalid tokens.
- API error messages are sanitized to 200 characters maximum.
- Added `validate_api_id()` with alphanumeric whitelist for
  recipe/workflow IDs.
- Added password length validation (8–128 characters) in
  [`api_register()`](https://metasurveyr.github.io/metasurvey/reference/api_register.md).
- [`api_download_recipe()`](https://metasurveyr.github.io/metasurvey/reference/api_download_recipe.md)
  and
  [`api_download_workflow()`](https://metasurveyr.github.io/metasurvey/reference/api_download_workflow.md)
  now warn on failure instead of silently swallowing errors.

### Performance

- Added `debounce(300)` on Shiny recipe search input to reduce excessive
  reactivity.

### Internal

- Replaced [`sapply()`](https://rdrr.io/r/base/lapply.html) with
  [`vapply()`](https://rdrr.io/r/base/lapply.html) or
  [`lapply()`](https://rdrr.io/r/base/lapply.html) across the codebase
  for type-safe return values.
- [`set_engine()`](https://metasurveyr.github.io/metasurvey/reference/set_engine.md)
  uses [`requireNamespace()`](https://rdrr.io/r/base/ns-load.html)
  instead of `eval(install.packages(...))`.
- [`read_recipe()`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md)
  now warns when step parsing falls back to raw strings.
- Added ORCID identifiers for authors in DESCRIPTION.
- Added ANDA fetch failure notification in Shiny explore module.

## metasurvey 0.0.6

### Documentation

- All exported functions and R6 classes now have `@return` and
  `@examples` roxygen2 tags, meeting rOpenSci documentation
  requirements.
- Added `@return` to R6 class exports: `Recipe`, `RecipeWorkflow`,
  `RecipeCategory`, `RecipeCertification`, `RecipeUser`, `PoolSurvey`,
  `RotativePanelSurvey`, and `Survey`.
- Added `@examples` to
  [`set_engine()`](https://metasurveyr.github.io/metasurvey/reference/set_engine.md),
  [`show_engines()`](https://metasurveyr.github.io/metasurvey/reference/show_engines.md),
  [`get_engine()`](https://metasurveyr.github.io/metasurvey/reference/get_engine.md),
  and all API/backend functions.
- Added `@return` to
  [`get_metadata()`](https://metasurveyr.github.io/metasurvey/reference/get_metadata.md),
  [`set_lazy_processing()`](https://metasurveyr.github.io/metasurvey/reference/set_lazy_processing.md),
  [`set_use_copy()`](https://metasurveyr.github.io/metasurvey/reference/set_use_copy.md),
  [`set_backend()`](https://metasurveyr.github.io/metasurvey/reference/set_backend.md),
  [`set_workflow_backend()`](https://metasurveyr.github.io/metasurvey/reference/set_workflow_backend.md),
  and
  [`explore_recipes()`](https://metasurveyr.github.io/metasurvey/reference/explore_recipes.md).

### Bug fixes

- Fixed Codecov GitHub Actions workflow: replaced deprecated
  [`covr::codecov()`](http://covr.r-lib.org/reference/codecov.md) with
  [`covr::package_coverage()`](http://covr.r-lib.org/reference/package_coverage.md) +
  `codecov/codecov-action@v5` for reliable coverage uploads with token
  authentication.
- Added CI guard to `.Rprofile` to skip example-data setup in GitHub
  Actions, preventing potential download failures during CI builds.
- Added missing `archive`, `haven`, and `openxlsx` to `Suggests` in
  DESCRIPTION, fixing R CMD check warnings about undeclared
  dependencies.

### Internal

- Added `.claude/` directory with development agents and commands for
  code review, testing, documentation auditing, and rOpenSci
  preparation.

## metasurvey 0.0.5

### Breaking changes

- **AST engine removed**: The Abstract Syntax Tree evaluation engine
  (`R/ast.R`) has been replaced by direct `data.table` expression
  evaluation. This simplifies the step pipeline and removes ~760 lines
  of internal code. Users who relied on internal AST functions
  (`parse_ast`, `evaluate_ast_node`, `recode_with_ast`, `optimize_node`)
  will need to update their code. The public API
  ([`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md),
  [`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md),
  [`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md))
  remains unchanged.

- **API client migrated to JWT**: The API client (`R/api_client.R`) now
  uses JWT authentication with a self-hosted Plumber backend, replacing
  the previous Atlas Data API approach.

### New features

- **Lazy design initialization**: `Survey$new()` no longer builds
  `svydesign` objects at construction time. Designs are created
  on-demand when needed (e.g., during
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  or
  [`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)),
  significantly improving construction performance for large datasets.
  The `psu` parameter is now optional (default `NULL`).

- **Recipe ecosystem**: New infrastructure for publishing, discovering,
  and managing reproducible survey processing recipes:

  - `RecipeRegistry` R6 class with pluggable backends (JSON file,
    MongoDB).
  - `RecipeCategory` for hierarchical categorization of recipes.
  - `RecipeCertification` for quality certification levels (official,
    reviewed, community).
  - `RecipeUser` for author/maintainer profiles with institutional
    affiliations.
  - Tidy API:
    [`list_recipes()`](https://metasurveyr.github.io/metasurvey/reference/list_recipes.md),
    [`search_recipes()`](https://metasurveyr.github.io/metasurvey/reference/search_recipes.md),
    [`filter_recipes()`](https://metasurveyr.github.io/metasurvey/reference/filter_recipes.md),
    [`rank_recipes()`](https://metasurveyr.github.io/metasurvey/reference/rank_recipes.md).
  - `Recipe$doc()` for auto-generated documentation.
  - `Recipe$validate(svy)` for dependency checking against a survey.
  - `print.Recipe` S3 method for human-readable output.
  - [`save_recipe()`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md)
    /
    [`read_recipe()`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md)
    for JSON serialization.

- **Workflow system**: New estimation workflow infrastructure:

  - `RecipeWorkflow` R6 class capturing
    `svymean`/`svytotal`/`svyratio`/`svyby` calls with recipe references
    and reproducibility metadata.
  - `WorkflowRegistry` with pluggable backends (JSON, MongoDB).
  - Auto-capture of workflow metadata via `.capture_workflow()` when
    surveys contain recipes.
  - [`workflow_from_list()`](https://metasurveyr.github.io/metasurvey/reference/workflow_from_list.md)
    for reconstructing workflows from JSON/API responses.
  - Tidy API:
    [`list_workflows()`](https://metasurveyr.github.io/metasurvey/reference/list_workflows.md),
    [`search_workflows()`](https://metasurveyr.github.io/metasurvey/reference/search_workflows.md),
    [`filter_workflows()`](https://metasurveyr.github.io/metasurvey/reference/filter_workflows.md),
    [`rank_workflows()`](https://metasurveyr.github.io/metasurvey/reference/rank_workflows.md),
    [`find_workflows_for_recipe()`](https://metasurveyr.github.io/metasurvey/reference/find_workflows_for_recipe.md),
    [`publish_workflow()`](https://metasurveyr.github.io/metasurvey/reference/publish_workflow.md).
  - [`save_workflow()`](https://metasurveyr.github.io/metasurvey/reference/save_workflow.md)
    /
    [`read_workflow()`](https://metasurveyr.github.io/metasurvey/reference/read_workflow.md)
    for serialization.

- **REST API** (`inst/api/plumber.R`): Self-hosted Plumber API with JWT
  authentication for recipe and workflow publishing. Endpoints for CRUD
  operations on recipes, workflows, and user management. Includes Docker
  deployment configuration.

- **ANDA catalog integration** (`R/anda.R`): Functions for accessing INE
  Uruguay’s ANDA5 catalog metadata:

  - [`anda_catalog_search()`](https://metasurveyr.github.io/metasurvey/reference/anda_catalog_search.md)
    for searching the catalog.
  - [`anda_list_editions()`](https://metasurveyr.github.io/metasurvey/reference/anda_list_editions.md)
    for listing available survey editions.
  - [`anda_fetch_ddi()`](https://metasurveyr.github.io/metasurvey/reference/anda_fetch_ddi.md)
    for fetching DDI metadata.
  - [`anda_parse_variables()`](https://metasurveyr.github.io/metasurvey/reference/anda_parse_variables.md)
    for extracting variable definitions.
  - [`anda_variable_detail()`](https://metasurveyr.github.io/metasurvey/reference/anda_variable_detail.md)
    for detailed variable information.

- **Shiny explorer app** (`inst/shiny/`): Interactive recipe and
  workflow browser launched via
  [`explore_recipes()`](https://metasurveyr.github.io/metasurvey/reference/explore_recipes.md):

  - Recipe gallery with search, filtering by survey type/certification,
    and detail modals showing pipeline visualization and R code
    snippets.
  - Workflow gallery with estimation timeline and cross-references to
    recipes.
  - User authentication with registration, login, and profile
    management.
  - Token generation for programmatic API access from R scripts.

- **[`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md)
  handles string steps**: Steps stored as strings (from JSON/API) are
  now parsed to call objects before evaluation, fixing the previous
  “attempt to apply non-function” error.

### Bug fixes

- `is_blank()` now handles `NULL` and zero-length inputs without error.
- Fixed regex in
  [`extract_time_pattern()`](https://metasurveyr.github.io/metasurvey/reference/extract_time_pattern.md):
  type prefix detection now correctly matches only at string start.
- Multianual year-range patterns (e.g., `"2019_2021"`) are now correctly
  parsed when separated by underscore.
- [`validate_time_pattern()`](https://metasurveyr.github.io/metasurvey/reference/validate_time_pattern.md)
  gracefully handles `NULL`/empty edition strings.
- Improved `public_key()` error handling with informative messages.
- [`workflow_from_list()`](https://metasurveyr.github.io/metasurvey/reference/workflow_from_list.md)
  is now exported (was `@keywords internal`), fixing Shiny app workflow
  parsing from API responses.

### Documentation

- Complete vignette rewrite with `eval=TRUE` examples:
  - `getting-started`: Survey creation, steps, recipes, and workflows.
  - `recipes`: Recipe ecosystem, publishing, and discovery.
  - `workflows-and-estimation`: Estimation workflows and registry.
  - `complex-designs`: Replicate weights, stratified designs.
  - `panel-analysis`: Rotating panel surveys.
  - `ech-case-study`: Full ECH processing example.
  - `shiny-explorer`: Interactive app usage guide.
  - `api-database`: REST API and database architecture.
- All vignettes available in Spanish (`*-es.Rmd`).
- Added `references.bib` for academic citations.
- Added `pkgdown` site configuration with rOpenSci template.

## metasurvey 0.0.3

- Added
  [`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md)
  for merging external reference data into surveys.
- Added
  [`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md)
  and
  [`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md)
  for variable management.

## metasurvey 0.0.2

- Added `RotativePanelSurvey` and `PoolSurvey` R6 classes for complex
  designs.
- Added
  [`extract_surveys()`](https://metasurveyr.github.io/metasurvey/reference/extract_surveys.md),
  [`get_implantation()`](https://metasurveyr.github.io/metasurvey/reference/get_implantation.md),
  [`get_follow_up()`](https://metasurveyr.github.io/metasurvey/reference/get_follow_up.md).

## metasurvey 0.0.1

- Initial CRAN submission.
