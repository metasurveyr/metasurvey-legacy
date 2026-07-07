---
name: "\U0001F4CB Contribute a Recipe"
about: Claim a survey and publish a recipe to the metasurvey registry
title: 'Recipe: [SURVEY] [COUNTRY]'
labels: 'recipe'
assignees: ''

---

## Survey

- **Name**: <!-- e.g., EPH (Encuesta Permanente de Hogares) -->
- **Country**: <!-- e.g., Argentina -->
- **Statistical office**: <!-- e.g., INDEC -->
- **Edition(s)**: <!-- e.g., 2023T1 -->
- **Design**: <!-- e.g., rotating panel, cross-sectional, stratified -->

## What does this recipe do?

<!-- Describe the processing pipeline: what variables does it create, what recodes does it apply? -->

## Status

- [ ] I published this recipe to the registry with `api_publish_recipe()`
- [ ] Recipe ID: <!-- paste the ID returned by the API, e.g., r_1739654400_742 -->

## How to publish your recipe

```r
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
  description = "Compute activity, employment, and unemployment rates from EPH"
)

# 4. Publish
api_publish_recipe(r)
```

You can also browse existing recipes:
```r
explore_recipes()   # Shiny app
list_recipes()      # from R console
```

## Surveys we're looking for

| Survey | Country | Office | Status |
|--------|---------|--------|--------|
| ECH | Uruguay | INE | Available |
| EPH | Argentina | INDEC | Wanted |
| PNADc | Brazil | IBGE | Wanted |
| CASEN | Chile | MDS | Wanted |
| GEIH | Colombia | DANE | Wanted |
| ENIGH | Mexico | INEGI | Wanted |
