## R CMD check results

0 errors | 0 warnings | 0 notes

## Update

Changes since the previous CRAN version (0.0.24). This is a minor-version
update (0.2.0) because the step execution model changed; both changes fix
silent correctness bugs and align behavior with the documentation:

### Breaking changes
* Steps execute exactly once: `step_compute()`/`step_recode()`/`step_join()`
  run eagerly on creation and `bake_steps()` no longer re-executes them.
  Previously every step ran twice, silently corrupting non-idempotent
  expressions (e.g. `age = age * 2` yielded `age * 4`).
* `step_recode()` conditions are evaluated first-match-wins
  (`dplyr::case_when()` semantics), as documented. Previously the last
  matching condition won.

### New features
* Per-call `domain =` in `workflow()` for subpopulation estimation via
  `survey::subset.survey.design()`.
* `estimation_type = "annual:mean_of_months"` for rotating panels
  (mean of monthly estimates with combined SEs).
* New steps: `step_quantile()` (weighted quantiles), `step_collapse()`
  (household-level collapse), `step_weight()` (weightflow integration),
  and chained expressions within a single `step_compute()` call.
* Input-validation layer on exported functions with actionable error
  messages.

### Bug fixes
* `step_compute(.by=)` no longer reorders rows; `step_remove()` resolves
  columns before the calling environment; `svrepdesign` uses the full
  replicate set; recode options are preserved when re-baking recipes;
  `evaluate_cv()` returns `NA` for non-finite CV.

## Test environments

* local macOS (aarch64-apple-darwin24.2.0), R 4.4.3
* GitHub Actions: ubuntu-latest (release, devel, oldrel-1),
  macOS-latest (release), windows-latest (release)

## Notes

* Package contains 3,340 tests with 0 failures.
* The `eph`, `PNADcIBGE`, and `ipumsr` packages in Suggests are used
  conditionally in the international-surveys vignette; sections are
  skipped when these packages are not installed.
