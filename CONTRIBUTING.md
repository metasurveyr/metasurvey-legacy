# Contributing to metasurvey

Thank you for your interest in contributing to metasurvey. This document
outlines how to propose changes, report bugs, and contribute code.

## Bug reports

If you find a bug, please file an issue on
[GitHub](https://github.com/metasurveyr/metasurvey/issues) with a
minimal reproducible example using the
[reprex](https://reprex.tidyverse.org/) package.

Include: - A description of the expected behavior vs. actual behavior. -
The output of
[`sessionInfo()`](https://rdrr.io/r/utils/sessionInfo.html). - A minimal
dataset or use `make_test_survey()` from the test helpers.

## Feature requests and improvements

**Use [GitHub
Discussions](https://github.com/orgs/metasurveyr/discussions)** to
propose new features, improvements, and ideas. Post in the “Ideas”
category with a clear description of the problem and your proposed
solution. If the feature relates to a specific survey (ECH, EPH, EAII),
include the relevant variable names and edition.

The metasurvey team reviews discussions and decides which ideas get
prioritized for implementation. Issues are reserved for confirmed bugs —
the team manages their prioritization.

## Contributing recipes

The most impactful way to contribute to metasurvey is by **publishing a
recipe** to the community registry. A recipe captures the full
processing pipeline for a household survey — variable construction,
recodes, filters — so other researchers can reproduce your work or apply
it to new editions.

### Publish a recipe to the registry

``` r

library(metasurvey)

# 1. Connect to the registry
configure_api("https://metasurvey-api.onrender.com")

# 2. Create an account (once)
api_register("Your Name", "you@example.com", "your_password")

# 3. Build your recipe
svy <- survey_empty("eph", "2023T1")
r <- recipe(
  name = "Labor Market Indicators",
  user = "you@example.com",
  svy = svy,
  description = "Activity, employment, and unemployment rates from EPH"
)

# 4. Publish
api_publish_recipe(r)
```

### Browse existing recipes

``` r

# From R
configure_api("https://metasurvey-api.onrender.com")
list_recipes()
search_recipes("labor")

# Or launch the Shiny explorer
explore_recipes()
```

### Surveys we’re looking for

We are building a community collection for Latin American household
surveys:

| Survey | Country   | Office |
|--------|-----------|--------|
| EPH    | Argentina | INDEC  |
| PNADc  | Brazil    | IBGE   |
| CASEN  | Chile     | MDS    |
| GEIH   | Colombia  | DANE   |
| ENIGH  | Mexico    | INEGI  |

If you work with any of these (or any other complex survey), publish
your recipe and [open an
issue](https://github.com/metasurveyr/metasurvey/issues/new?template=new_recipe.md)
to let us know.

## Development environment

### Installing the stack

**macOS**

``` bash
# 1. R (via Homebrew or CRAN installer)
brew install --cask r

# 2. Python 3 + pre-commit
brew install python
pip3 install pre-commit

# 3. Docker Desktop
brew install --cask docker
# Open Docker Desktop at least once to finish setup

# 4. R development tools (RStudio optional)
brew install --cask rstudio  # optional
```

**Ubuntu / Debian**

``` bash
# 1. R (CRAN repo for latest version)
sudo apt update
sudo apt install -y software-properties-common dirmngr
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | \
  sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
sudo apt install -y r-base r-base-dev

# 2. System libraries required by R packages
sudo apt install -y libcurl4-openssl-dev libssl-dev libxml2-dev \
  libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
  libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev

# 3. Python 3 + pre-commit
sudo apt install -y python3 python3-pip
pip3 install pre-commit

# 4. Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group membership to take effect
```

**Windows (WSL2)**

``` bash
# Inside WSL2 (Ubuntu), follow the Ubuntu instructions above.
# Install Docker Desktop for Windows with WSL2 backend.
```

### Quick start

``` bash
# 1. Clone and install everything
git clone https://github.com/metasurveyr/metasurvey.git
cd metasurvey
make dev-setup        # installs R deps + pre-commit hooks

# 2. Verify the package
make test             # run the 2700+ test suite
make pre-commit       # run all code quality hooks
make check            # full R CMD check

# 3. Start the API + MongoDB stack
cp .env.example .env  # edit with your values (or use defaults for local dev)
make docker-up        # starts mongo, api, worker, shiny
make docker-seed      # loads recipes, workflows, users, ANDA metadata

# 4. Verify the stack
curl http://localhost:8787/health   # API
curl http://localhost:8788/health   # Worker
open http://localhost:3838          # Shiny Explorer
```

Run `make help` to see all available targets.

### Pre-commit hooks

Pre-commit runs automatically on every commit. The hooks enforce:

| Hook | What it does |
|----|----|
| **R code quality** |  |
| `style-files` | Formats R code with `styler::tidyverse_style()` |
| `roxygenize` | Regenerates `man/` and `NAMESPACE` |
| `lintr` | Lints R files against `.lintr` rules |
| `use-tidy-description` | Keeps `DESCRIPTION` fields sorted |
| `spell-check` | Spell-checks documentation (uses `inst/WORDLIST`) |
| `parsable-R` | Checks R files parse without errors |
| `no-browser-statement` | Blocks [`browser()`](https://rdrr.io/r/base/browser.html) calls in source |
| `no-print-statement` | Blocks [`print()`](https://rdrr.io/r/base/print.html) in source (tests/vignettes excluded) |
| `no-debug-statement` | Blocks [`debug()`](https://rdrr.io/r/base/debug.html)/[`debugonce()`](https://rdrr.io/r/base/debug.html) calls |
| `deps-in-desc` | Checks all used packages are in `DESCRIPTION` |
| **File quality** |  |
| `end-of-file-fixer` | Ensures files end with a newline |
| `trailing-whitespace` | Removes trailing whitespace |
| `mixed-line-ending` | Enforces LF line endings |
| `check-yaml` | Validates YAML syntax |
| `check-json` | Validates JSON syntax |
| `check-merge-conflict` | Detects unresolved merge markers |
| `check-case-conflict` | Detects files that differ only in case |
| `check-added-large-files` | Blocks files \> 200 KB |
| `detect-private-key` | Blocks accidental key commits |
| **Branch protection** |  |
| `no-commit-to-branch` | Prevents direct commits to `main` |
| `forbid-to-commit` | Blocks `.Rhistory`, `.RData`, `.rds` artifacts |
| `forbid-secrets` | Blocks `.env`, credentials, key files |

If the renv cache inside pre-commit gets corrupted (lock errors):

``` bash
make dev-clean-hooks
```

### Architecture

    R/
    ├── survey.R          # Survey + PoolSurvey R6 classes
    ├── PanelSurvey.R     # RotativePanelSurvey R6 class
    ├── Step.R            # Step R6 class (lazy transformation unit)
    ├── steps.R           # step_compute(), step_recode(), step_rename(),
    │                     # step_remove(), step_join(), bake_steps()
    ├── Recipes.R         # Recipe R6 class + read_recipe()
    ├── RecipeRegistry.R  # RecipeRegistry + RecipeBackend (JSON, MongoDB)
    ├── workflow.R        # workflow() — svymean/svytotal/svyratio/svyby
    ├── RecipeWorkflow.R  # RecipeWorkflow R6 class
    ├── transpile.R       # STATA .do → Recipe transpiler
    └── meta.R            # Package options (engine, lazy_processing, use_copy)

**Key patterns:**

- **Lazy evaluation**: `step_*()` functions record but don’t execute.
  Call
  [`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
  to materialize.
- **data.table everywhere**: Internal data ops use `data.table` syntax,
  never `dplyr`. External packages use `:=`, `set()`,
  `merge.data.table()`.
- **No rlang**: All metaprogramming uses base R
  ([`substitute()`](https://rdrr.io/r/base/substitute.html),
  [`eval()`](https://rdrr.io/r/base/eval.html),
  [`match.call()`](https://rdrr.io/r/base/match.call.html)). rlang is
  prohibited.
- **R6 classes**: PascalCase names, `$initialize()`, `$print()`,
  `$clone()`. Step functions are functional wrappers that create Step
  objects internally.
- **Copy semantics**: `use_copy` option controls whether steps clone
  data. Default `TRUE` for safety. Use
  [`set_data()`](https://metasurveyr.github.io/metasurvey/reference/set_data.md)
  instead of `$data <-` assignment.

### Docker services

The full stack (optional, for recipe ecosystem development):

| Service  | Port  | Purpose                              |
|----------|-------|--------------------------------------|
| `mongo`  | 27017 | MongoDB storage                      |
| `api`    | 8787  | Plumber REST API (recipe CRUD, auth) |
| `worker` | 8788  | Background compute (indicators)      |
| `shiny`  | 3838  | Recipe Explorer app                  |

Seed data lives in `inst/seed-data/` (recipes, workflows, users, ANDA
variables).

## Pull requests

1.  Fork the repo and create a branch from `develop`.
2.  Run `make pre-commit` to check code quality.
3.  Add or update tests in `tests/testthat/`.
4.  Run `make test` and ensure all tests pass.
5.  Run `make check` and fix any warnings or notes.
6.  Submit a PR to the `develop` branch.

### Code style

- Use `data.table` syntax for internal data operations.
- Follow existing naming conventions: `step_*` for step functions, `R6`
  classes use PascalCase.
- Keep functions focused and avoid over-engineering.
- No rlang — use base R metaprogramming only.

### Testing

- Use testthat edition 3.
- Test helpers are in `tests/testthat/helper-survey.R`
  (`make_test_survey()`, `make_test_panel()`).
- Integration tests that need external data should use `skip_on_cran()`.
- [`print()`](https://rdrr.io/r/base/print.html) calls in tests are fine
  (used to test R6 `$print()` methods).

## Code of Conduct

Please note that this project is released with a [Contributor Code of
Conduct](https://github.com/metasurveyr/metasurvey/blob/main/CODE_OF_CONDUCT.md).
By participating in this project you agree to abide by its terms.
