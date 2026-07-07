## R CMD check results

0 errors | 0 warnings | 0 notes

## Resubmission

This is a resubmission. Changes since the previous CRAN version (0.0.21):

### 0.0.24
* **Breaking**: `workflow()` parameter `conf.level` renamed to `level` to
  match `stats::confint()` and `survey` package conventions.
* Fixed `step_compute(.by=)` not surviving `bake_steps()` (grouped
  computations lost the `.by` parameter).
* Fixed `bake_recipes()` leaking `lazy_processing = FALSE` when baking
  multiple recipes.
* Added missing `topic` parameter to `filter_recipes()`.

### 0.0.23
* `workflow()` now supports per-call confidence level overrides
  (e.g., `svymean(~x, conf.level = 0.80)`).

### 0.0.22
* `workflow()` gains a `conf.level` parameter (default `0.95`).
* `workflow()` output now includes `variable` and `evaluate` columns
  across all estimation types, with cleaner `svyby` group handling.

## Test environments

* local macOS (aarch64-apple-darwin24.2.0), R 4.4.3
* GitHub Actions: ubuntu-latest (release, devel, oldrel-1),
  macOS-latest (release), windows-latest (release)

## Notes

* Package contains 3,013 tests with 0 failures.
* The `eph`, `PNADcIBGE`, and `ipumsr` packages in Suggests are used
  conditionally in the international-surveys vignette; sections are
  skipped when these packages are not installed.
