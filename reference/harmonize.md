# Harmonize surveys using registry recipes

For each survey in the list, fetches matching recipes from the active
backend (by survey type and edition), sorts them by dependency order,
applies them via
[`bake_recipes`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md),
and assembles the results into a
[`PoolSurvey`](https://metasurveyr.github.io/metasurvey/reference/PoolSurvey.md)
ready for
[`workflow`](https://metasurveyr.github.io/metasurvey/reference/workflow.md).

## Usage

``` r
harmonize(
  surveys,
  survey_type = NULL,
  topic = NULL,
  category = NULL,
  certification_level = NULL,
  grouping = "annual",
  group_name = "series",
  .verbose = getOption("metasurvey.verbose", TRUE)
)
```

## Arguments

- surveys:

  List of
  [`Survey`](https://metasurveyr.github.io/metasurvey/reference/Survey.md)
  objects to harmonize.

- survey_type:

  Character. Override survey type for recipe lookup. If `NULL`
  (default), uses each survey's own `type` field.

- topic:

  Character. Filter recipes by topic (e.g. `"compatibilizada"`). Default
  `NULL` (no filter).

- category:

  Character. Optional category filter for recipes.

- certification_level:

  Character. Optional certification level filter (e.g. `"official"`,
  `"reviewed"`).

- grouping:

  Character. Time hierarchy for the PoolSurvey structure. One of
  `"annual"` (default), `"quarterly"`, `"monthly"`, `"biannual"`.

- group_name:

  Character. Name of the group in the PoolSurvey structure (default
  `"series"`).

- .verbose:

  Logical. Print progress messages (default uses `metasurvey.verbose`
  option).

## Value

A
[`PoolSurvey`](https://metasurveyr.github.io/metasurvey/reference/PoolSurvey.md)
object containing the harmonized surveys, structured as
`list(<grouping> = list(<group_name> = list(svy1, svy2, ...)))`.

## Details

The function performs the following steps for each survey:

1.  Calls
    [`filter_recipes`](https://metasurveyr.github.io/metasurvey/reference/filter_recipes.md)
    with the survey's type and edition (plus optional
    category/certification filters).

2.  Sorts matching recipes using topological sort on
    `depends_on_recipes`.

3.  Attaches recipes via
    [`add_recipe`](https://metasurveyr.github.io/metasurvey/reference/Survey.md)
    and applies them with
    [`bake_recipes`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md).

If no recipes are found for a survey, it is included in the pool
unchanged (with a warning).

## See also

[`filter_recipes`](https://metasurveyr.github.io/metasurvey/reference/filter_recipes.md),
[`bake_recipes`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md),
[`PoolSurvey`](https://metasurveyr.github.io/metasurvey/reference/PoolSurvey.md),
[`workflow`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)

Other recipes:
[`Recipe-class`](https://metasurveyr.github.io/metasurvey/reference/Recipe-class.md),
[`add_recipe()`](https://metasurveyr.github.io/metasurvey/reference/add_recipe.md),
[`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md),
[`explore_recipes()`](https://metasurveyr.github.io/metasurvey/reference/explore_recipes.md),
[`get_recipe()`](https://metasurveyr.github.io/metasurvey/reference/get_recipe.md),
[`print.Recipe()`](https://metasurveyr.github.io/metasurvey/reference/print.Recipe.md),
[`publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/publish_recipe.md),
[`read_recipe()`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md),
[`recipe()`](https://metasurveyr.github.io/metasurvey/reference/recipe.md),
[`save_recipe()`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md),
[`steps_to_recipe()`](https://metasurveyr.github.io/metasurvey/reference/steps_to_recipe.md)

## Examples

``` r
# \donttest{
# Set up a local backend with a temp file
old <- set_backend("local", path = tempfile(fileext = ".json"))

# Create a small survey and a recipe
dt <- data.table::data.table(
  id = 1:10, x = 1:10, w = rep(1, 10)
)
svy <- Survey$new(
  data = dt, edition = "2023", type = "test",
  psu = NULL, engine = "data.table",
  weight = add_weight(annual = "w")
)
r <- Recipe$new(
  name = "demo", edition = "2023", survey_type = "test",
  default_engine = "data.table", depends_on = list(),
  user = "demo", description = "demo recipe",
  steps = list("step_compute(., z = x * 2)"),
  id = "demo_recipe"
)
publish_recipe(r)

pool <- harmonize(list(svy), .verbose = FALSE)

# Restore backend
options(metasurvey.backend = old)
# }
```
