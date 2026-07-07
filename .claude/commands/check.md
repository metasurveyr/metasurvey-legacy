---
description: Run R CMD check and analyze results
---

Run a full R CMD check and provide actionable analysis.

## Steps

1. Run `Rscript -e 'devtools::document()'` to regenerate NAMESPACE and man/
2. Run `Rscript -e 'devtools::check()'` and capture full output
3. Parse the results and report:

**Summary**: X errors, Y warnings, Z notes

For each issue found:
- **What**: The check that failed
- **Where**: File and line number
- **Fix**: Concrete code change to resolve it

## Targets
- rOpenSci requires: **0 errors, 0 warnings**
- NOTEs are acceptable but should be minimized
- If warnings exist, fix them and re-run automatically
