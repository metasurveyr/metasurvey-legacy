---
description: Audit package readiness for rOpenSci submission
---

Perform a comprehensive audit of the metasurvey package against rOpenSci submission requirements.

## Audit Areas

### 1. R CMD check
Run `Rscript -e 'devtools::check()'` — must be 0 errors, 0 warnings.

### 2. pkgcheck
Run `Rscript -e 'pkgcheck::pkgcheck()'` if available. This is what rOpenSci runs automatically on submission.

### 3. Documentation Completeness
- Check ALL exported functions have `@return` and `@examples`
- Verify DESCRIPTION fields (Title Case, no "in R", ORCID IDs)
- Confirm README has all required sections
- Verify vignettes build and are substantial

### 4. Code Quality
- No `print()`/`cat()` outside print methods
- snake_case naming
- No hardcoded credentials
- `message()` for user-facing output

### 5. Metadata
- codemeta.json version matches DESCRIPTION
- inst/CITATION uses bibentry format
- NEWS.md has proper version headers

### 6. CI/CD
- GitHub Actions for R CMD check on Linux/Mac/Win
- Code coverage reporting (Codecov)
- pkgdown site deployment

### 7. Community Files
- CONTRIBUTING.md present
- CODE_OF_CONDUCT.md references rOpenSci
- Issue templates configured

## Output

Produce a final report with:
1. **PASS** items (compliant)
2. **ACTION REQUIRED** items (must fix before submission)
3. **RECOMMENDED** items (nice to have)
4. Estimated effort to reach submission-ready state
