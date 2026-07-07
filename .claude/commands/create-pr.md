---
description: Create a PR with automatic commit splitting
---

Create a new branch, commit changes, and submit a pull request.

## Steps

1. Run `Rscript -e 'devtools::document()'` to ensure NAMESPACE is current
2. Run `Rscript -e 'devtools::test()'` to verify all tests pass
3. If tests fail, STOP and report the failures
4. Analyze `git diff` and split changes into logical commits:
   - Separate R/ changes from tests/ changes
   - Separate documentation from code changes
   - Group related file changes together
5. Create descriptive commit messages: `type: description`
   - Types: feat, fix, test, docs, refactor, chore
6. Push branch and create PR with:

```
## Summary
- Bullet points of changes

## Test plan
- [ ] `devtools::test()` passes
- [ ] `devtools::check()` 0 errors, 0 warnings
- [ ] Coverage maintained at 85%+
```

## Branch naming
- `feat/description` for features
- `fix/description` for bug fixes
- `docs/description` for documentation
- `refactor/description` for refactoring
