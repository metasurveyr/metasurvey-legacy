# Creating and Sharing Recipes

## Why Recipes?

Anyone who works with household survey microdata knows this pattern: you
download the raw files, open the codebook, and spend days recoding
employment status, harmonizing income variables, and building
indicators. Months later, a colleague starts the same project and writes
the same code from scratch.

In STATA, teams share `.do` files, but these are tightly coupled to
specific file paths and variable names, and there is no standard way to
discover or validate them.

**Recipes** are metasurvey’s answer to this problem. A recipe is a
portable, documented, and validated collection of transformation steps
that can:

- Be applied to any compatible edition of a survey with a single
  function call
- Be published to a registry where others can discover and reuse them
- Be certified by institutions for official use
- Generate automatic documentation of inputs, outputs, and pipeline

## Recipe Lifecycle

      ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
      │  1. Develop   │────▶│  2. Package   │────▶│  3. Validate  │
      │  steps on a   │     │  steps into   │     │  against new  │
      │  survey       │     │  a recipe     │     │  data         │
      └──────────────┘     └──────────────┘     └──────┬───────┘
                                                        │
      ┌──────────────┐     ┌──────────────┐             │
      │  5. Discover  │◀────│  4. Publish   │◀────────────┘
      │  & reuse      │     │  to registry  │
      │  recipes      │     │  or API       │
      └──────────────┘     └──────────────┘

## Loading a Survey

The typical starting point is loading a survey with
[`load_survey()`](https://metasurveyr.github.io/metasurvey/reference/load_survey.md).
You can load example data or point to your own files:

``` r

library(metasurvey)

# Load ECH 2022 with example data (downloads from GitHub)
ech_2022 <- load_survey(
  load_survey_example("ech", "ech_2022"),
  svy_type    = "ech",
  svy_edition = "2022",
  svy_weight  = add_weight(annual = "pesoano")
)

# Or load with existing recipes from the registry (requires API server)
ech_2022 <- load_survey(
  load_survey_example("ech", "ech_2022"),
  svy_type    = "ech",
  svy_edition = "2022",
  svy_weight  = add_weight(annual = "pesoano"),
  recipes     = get_recipe("ech", "2022")
)
```

## Building a Recipe from Steps

The most common workflow consists of developing transformations
interactively on a survey and then converting the recorded steps into a
recipe.

``` r

library(metasurvey)
library(data.table)

set.seed(42)
n <- 200

# Simulate survey microdata (standing in for load_survey)
dt <- data.table(
  id = 1:n,
  age = sample(18:80, n, replace = TRUE),
  sex = sample(c(1, 2), n, replace = TRUE),
  income = round(runif(n, 5000, 80000)),
  activity = sample(c(2, 3, 5, 6), n,
    replace = TRUE,
    prob = c(0.55, 0.05, 0.05, 0.35)
  ),
  weight = round(runif(n, 0.5, 3.0), 4)
)

svy <- Survey$new(
  data    = dt,
  edition = "2023",
  type    = "ech",
  psu     = NULL,
  engine  = "data.table",
  weight  = add_weight(annual = "weight")
)

# Develop transformations interactively
svy <- step_compute(svy,
  income_thousands = income / 1000,
  employed = ifelse(activity == 2, 1L, 0L),
  comment = "Income scaling and employment indicator"
)

svy <- step_recode(svy, labor_status,
  activity == 2 ~ "Employed",
  activity %in% 3:5 ~ "Unemployed",
  activity %in% 6:8 ~ "Inactive",
  .default = "Other",
  comment = "ILO labor force classification"
)

svy <- step_recode(svy, age_group,
  age < 25 ~ "Youth",
  age < 45 ~ "Adult",
  age < 65 ~ "Mature",
  .default = "Senior",
  comment = "Standard age groups"
)

# Convert all steps to a recipe
labor_recipe <- steps_to_recipe(
  name        = "Labor Force Indicators",
  user        = "Research Team",
  svy         = svy,
  description = "Standard labor force indicators following ILO definitions",
  steps       = get_steps(svy),
  topic       = "labor"
)

labor_recipe
#> 
#> ── Recipe: Labor Force Indicators ──
#> Author:  Research Team
#> Survey:  ech / 2023
#> Version: 1.0.0
#> Topic:   labor
#> Description: Standard labor force indicators following ILO definitions
#> Certification: community
#> 
#> ── Requires (3 variables) ──
#>   income, activity, age
#> 
#> ── Pipeline (3 steps) ──
#>   1. [compute] -> income_thousands, employed  "Income scaling and employment indicator"
#>   2. [recode] -> labor_status  "ILO labor force classification"
#>   3. [recode] -> age_group  "Standard age groups"
#> 
#> ── Produces (4 variables) ──
#>   labor_status [categorical], age_group [categorical], income_thousands [numeric], employed [numeric]
```

## Recipe Documentation

Every recipe can automatically generate its documentation from its
steps. The `doc()` method returns a list with input variables, output
variables, and the step-by-step pipeline:

``` r

doc <- labor_recipe$doc()
names(doc)
#> [1] "meta"             "input_variables"  "output_variables" "pipeline"
```

``` r

# What variables does the recipe need?
doc$input_variables
#> [1] "income"   "activity" "age"

# What variables does it create?
doc$output_variables
#> [1] "income_thousands" "employed"         "labor_status"     "age_group"

# Step-by-step pipeline
doc$pipeline
#> [[1]]
#> [[1]]$index
#> [1] 1
#> 
#> [[1]]$type
#> [1] "compute"
#> 
#> [[1]]$outputs
#> [1] "income_thousands" "employed"        
#> 
#> [[1]]$inputs
#> [1] "income"   "activity"
#> 
#> [[1]]$inferred_type
#> [1] "numeric"
#> 
#> [[1]]$comment
#> [1] "Income scaling and employment indicator"
#> 
#> 
#> [[2]]
#> [[2]]$index
#> [1] 2
#> 
#> [[2]]$type
#> [1] "recode"
#> 
#> [[2]]$outputs
#> [1] "labor_status"
#> 
#> [[2]]$inputs
#> [1] "activity"
#> 
#> [[2]]$inferred_type
#> [1] "categorical"
#> 
#> [[2]]$comment
#> [1] "ILO labor force classification"
#> 
#> 
#> [[3]]
#> [[3]]$index
#> [1] 3
#> 
#> [[3]]$type
#> [1] "recode"
#> 
#> [[3]]$outputs
#> [1] "age_group"
#> 
#> [[3]]$inputs
#> [1] "age"
#> 
#> [[3]]$inferred_type
#> [1] "categorical"
#> 
#> [[3]]$comment
#> [1] "Standard age groups"
```

This documentation is generated automatically, with no manual effort
required.

## Validation

Before applying a recipe to new data, verify that all required variables
exist. The `validate()` method stops with a clear error if any
dependency is missing:

``` r

labor_recipe$validate(svy)
#> [1] TRUE
```

## Applying Recipes to a Survey

Attach one or more recipes to a survey and apply them with
[`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md):

``` r

# Create a fresh survey with same structure (simulating a new edition)
set.seed(99)
dt2 <- data.table(
  id = 1:100,
  age = sample(18:80, 100, replace = TRUE),
  sex = sample(c(1, 2), 100, replace = TRUE),
  income = round(runif(100, 5000, 80000)),
  activity = sample(c(2, 3, 5, 6), 100,
    replace = TRUE,
    prob = c(0.55, 0.05, 0.05, 0.35)
  ),
  weight = round(runif(100, 0.5, 3.0), 4)
)

svy2 <- Survey$new(
  data = dt2, edition = "2024", type = "ech",
  psu = NULL, engine = "data.table",
  weight = add_weight(annual = "weight")
)

# Attach and bake
svy2 <- add_recipe(svy2, labor_recipe)
svy2 <- bake_recipes(svy2)

head(get_data(svy2)[, .(id, income_thousands, labor_status, age_group)], 5)
#>       id income_thousands labor_status age_group
#>    <int>            <num>       <char>    <char>
#> 1:     1           47.346   Unemployed    Senior
#> 2:     2           28.114     Employed    Mature
#> 3:     3           43.583     Employed    Mature
#> 4:     4           13.440   Unemployed     Adult
#> 5:     5           55.638     Employed    Senior
```

The same recipe applied to a different edition produces consistent
results. This is how metasurvey ensures reproducibility over time.

In practice, you can load a survey and apply published recipes in a
single call:

``` r

# Load ECH 2023 and apply the labor recipe from the registry (requires API)
ech_2023 <- load_survey(
  load_survey_example("ech", "ech_2023"),
  svy_type    = "ech",
  svy_edition = "2023",
  svy_weight  = add_weight(annual = "pesoano"),
  recipes     = get_recipe("ech", "2023", topic = "labor_market"),
  bake        = TRUE
)
```

## Categories

Categories help organize recipes by topic:

``` r

cats <- default_categories()
vapply(cats, function(c) c$name, character(1))
#> [1] "labor_market" "income"       "education"    "health"       "demographics"
#> [6] "housing"
```

Add categories to a recipe using
[`add_category()`](https://metasurveyr.github.io/metasurvey/reference/add_category.md):

``` r

labor_recipe <- add_category(labor_recipe, "labor_market", "Labor market analysis")
labor_recipe <- add_category(labor_recipe, "income", "Income-related indicators")
labor_recipe
#> 
#> ── Recipe: Labor Force Indicators ──
#> Author:  Research Team
#> Survey:  ech / 2023
#> Version: 1.0.0
#> Topic:   labor
#> Description: Standard labor force indicators following ILO definitions
#> Certification: community
#> Categories: labor_market, income
#> 
#> ── Requires (3 variables) ──
#>   income, activity, age
#> 
#> ── Pipeline (3 steps) ──
#>   1. [compute] -> income_thousands, employed  "Income scaling and employment indicator"
#>   2. [recode] -> labor_status  "ILO labor force classification"
#>   3. [recode] -> age_group  "Standard age groups"
#> 
#> ── Produces (4 variables) ──
#>   labor_status [categorical], age_group [categorical], income_thousands [numeric], employed [numeric]
```

## Certification

The certification system offers three levels of trust:

| Level       | Meaning                                |
|-------------|----------------------------------------|
| `community` | User contribution (default), no review |
| `reviewed`  | Peer-reviewed by a recognized team     |
| `official`  | Endorsed for official statistics       |

Higher certification levels appear first in search results and signal
that the recipe has been reviewed.

## Publishing and Discovering Recipes

The real power of recipes lies in sharing them. Every recipe you create
can be published to the **metasurvey registry**, where other researchers
can discover, reuse, and build upon your work.

### Publishing to the Public Registry

The recommended workflow is to publish recipes to the public API. Anyone
can browse recipes without an account; publishing requires registration:

``` r

# One-time: register and authenticate
api_register("Your Name", "you@example.com", "password")
api_login("you@example.com", "password")

# Publish your recipe (your profile is attached automatically)
api_publish_recipe(labor_recipe)
```

When authenticated,
[`api_publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/api_publish_recipe.md)
attaches your user profile to the recipe. Other users see who published
it, along with institutional affiliation and certification level. This
builds accountability and trust in shared recipes.

### Browsing and Searching

No authentication is needed to browse and download recipes:

``` r

# Browse all ECH recipes
ech_recipes <- api_list_recipes(survey_type = "ech")

# Get a specific recipe by ID
r <- api_get_recipe(id = "recipe_id_here")
```

### Interactive Explorer

The Shiny app provides a visual interface for browsing recipes and
workflows:

``` r

explore_recipes()
```

The explorer shows recipe cards with certification badges, download
counts, and pipeline previews. Clicking a recipe opens a detail view
with the full pipeline, an R code snippet, and links to related
workflows.

### Private Registry for Institutions

Institutions that work with **confidential or restricted-access
surveys** may need a private registry. metasurvey supports this via a
self-hosted backend with MongoDB:

``` r

# Point to your institution's private API
configure_api("https://your-institution.example.com/api")

# From here, the workflow is identical
api_login("analyst@institution.edu", "password")
api_publish_recipe(labor_recipe)
api_list_recipes(survey_type = "ech")
```

See the [API and
Database](https://metasurveyr.github.io/metasurvey/articles/api-database.md)
vignette for instructions on deploying the Plumber API with MongoDB for
your own organization.

## Best Practices

1.  **Name recipes descriptively** – include the survey type and topic
    (e.g., `"ECH Labor Force Indicators"`).
2.  **Add descriptions** – document what the recipe computes and why.
3.  **Use categories and topics** – make recipes easier to discover.
4.  **Validate before sharing** – call `validate()` on sample data to
    ensure all dependencies exist.
5.  **Version your recipes** – use
    [`set_version()`](https://metasurveyr.github.io/metasurvey/reference/set_version.md)
    when updating them.

## Next Steps

- **[Estimation
  Workflows](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.md)**
  – Use
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  to compute weighted estimates from processed data
- **[ECH Case
  Study](https://metasurveyr.github.io/metasurvey/articles/ech-case-study.md)**
  – See recipes in action in a real labor market analysis
- **[Getting
  Started](https://metasurveyr.github.io/metasurvey/articles/getting-started.md)**
  – Review the basics of steps and Survey objects
