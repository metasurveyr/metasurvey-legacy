# Interactive Recipe Explorer

## Overview

metasurvey includes a Shiny web application for interactively exploring,
searching, and managing recipes and workflows. The application connects
to the metasurvey API to display community-contributed recipes, or works
in offline mode with built-in sample data.

## Launching the application

``` r

library(metasurvey)

# Open in your default browser
explore_recipes()

# Or specify host and port
explore_recipes(port = 3838, host = "127.0.0.1")
```

The
[`explore_recipes()`](https://metasurveyr.github.io/metasurvey/reference/explore_recipes.md)
function starts the Shiny application and opens it in the browser. No
additional configuration is needed: the application automatically
connects to the production API.

## Interface navigation

The application has three main tabs in the top navigation bar:

### Recipes tab

The **Recipes** tab is the main entry point. It displays a searchable
grid of published recipes, each presented as a card with:

- **Name and edition** as metadata
- **Description** (truncated to two lines)
- **Category tags** with colored badges (Labor Market, Income,
  Education, Health, Demographics, Housing)
- **Certification level** indicated by the card header color:
  - Indigo = Official
  - Emerald = Reviewed
  - Slate = Community
- **Download count** and a “View” button

#### Search and filtering

The top of the Recipes tab offers four filters:

| Filter | Options | Purpose |
|----|----|----|
| Search | Free text | Searches recipe name and description |
| Survey type | ECH, EAII, EPH, EAI | Filter by survey |
| Category | Labor Market, Income, Education, Health, Demographics, Housing | Filter by topic |
| Certification | Official, Reviewed, Community | Filter by trust level |

Filters are applied client-side for instant results. Use the refresh
button to reload data from the API.

#### Statistics row

Below the filters, three statistics boxes summarize the current data:

- **Total recipes** in the registry
- **Official recipes** with institutional certification
- **Total downloads** across all recipes

#### Recipe detail modal

Click “View” on any recipe card to open a detail modal showing:

1.  **Metadata**: name, description, edition, survey type
2.  **Author information**: creator name, institution, trust level
3.  **Input variables**: what the recipe expects to find in the survey
    data (displayed as chips)
4.  **Output variables**: what the recipe creates (displayed as chips)
5.  **Pipeline visualization**: interactive step graph (if the
    `visNetwork` package is installed)
6.  **Dependent recipes**: other recipes this one depends on (with
    navigation links)
7.  **Referencing workflows**: workflows that use this recipe (with a
    link to navigate to the Workflows tab)
8.  **ANDA metadata**: variable labels from the INE data catalog, when
    available (unofficial integration; verify against the official
    codebook)

### Workflows tab

The **Workflows** tab displays published estimation workflows. Each
workflow card shows the estimation type (Annual, Quarterly, Monthly) and
the recipes it references.

Workflows use the same search and filtering interface as recipes. The
detail modal shows:

- All estimation calls (`svymean`, `svytotal`, `svyratio`, `svyby`)
  presented as a visual timeline
- Cross-references to the recipes used for data preparation
- Click a referenced recipe to navigate directly to its detail

### Cross-navigation

Recipes and workflows are linked bidirectionally:

- From a **recipe detail**, click a referencing workflow to go to the
  Workflows tab and open that workflow’s detail
- From a **workflow detail**, click a referenced recipe to return to the
  Recipes tab and open that recipe’s detail

This allows tracing the complete analysis pipeline: from data
transformation (recipe) to estimation (workflow).

### Profile tab

The Profile tab changes based on the authentication state:

**Before logging in**: displays a login/registration form with two
sub-tabs:

- **Login**: email and password
- **Register**: name, email, password, account type (Individual,
  Institutional Member, or Institution)

**After logging in**: displays the profile with:

- Name, account type, trust level, email, and institution
- **My Recipes** button to view published recipes
- **API Token** section to generate a long-lived token for use in
  scripts
- **Logout** button

#### Generating an API Token

From the Profile tab, click “Generate API Token” to create a 90-day
token for use in R scripts:

``` r

# Use the token generated from the app
Sys.setenv(METASURVEY_TOKEN = "your-token-here")

# Now API calls work without interactive login
recipes <- api_list_recipes(survey_type = "ech")
```

This is useful for automated scripts and CI/CD pipelines.

#### Administration panel

If your account has administrator privileges, an additional panel
appears for reviewing institutional account requests. Administrators can
approve or reject pending registrations.

## Offline mode

If the API is unavailable, the application automatically switches to
offline mode using built-in sample data. This includes 13 sample recipes
and 6 sample workflows covering common ECH use cases:

- Labor market indicators
- Income distribution and poverty
- Education and health coverage
- Demographics and housing
- Innovation indicators (EAII)

Offline mode is useful for demonstrations and for exploring the
interface without network access.

## Docker deployment

For production deployment or team-internal use, the application includes
a Dockerfile:

``` bash
# Build the image
docker build -t metasurvey-shiny inst/shiny/

# Run on port 3838
docker run -p 3838:3838 \
  -e METASURVEY_API_URL="https://metasurvey-api-production.up.railway.app" \
  metasurvey-shiny
```

The `METASURVEY_API_URL` environment variable configures which API the
application connects to. It can point to a self-hosted instance.

## Next steps

- **[API and Database
  Reference](https://metasurveyr.github.io/metasurvey/articles/api-database.html)**
  – Technical details about the API endpoints and MongoDB schema
- **[Creating and Sharing
  Recipes](https://metasurveyr.github.io/metasurvey/articles/recipes.md)**
  – Build recipes programmatically and publish them
- **[Estimation
  Workflows](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.md)**
  – Compute weighted survey estimates with
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
