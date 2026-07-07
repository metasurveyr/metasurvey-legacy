# Package index

## Surveys

Create and manipulate Survey objects

- [`Survey`](https://metasurveyr.github.io/metasurvey/reference/Survey.md)
  : Survey R6 class
- [`RotativePanelSurvey`](https://metasurveyr.github.io/metasurvey/reference/RotativePanelSurvey.md)
  : RotativePanelSurvey Class
- [`PoolSurvey`](https://metasurveyr.github.io/metasurvey/reference/PoolSurvey.md)
  : PoolSurvey Class
- [`load_survey()`](https://metasurveyr.github.io/metasurvey/reference/load_survey.md)
  : Load survey from file and create Survey object
- [`load_panel_survey()`](https://metasurveyr.github.io/metasurvey/reference/load_panel_survey.md)
  : Read panel survey files from different formats and create a
  RotativePanelSurvey object
- [`load_survey_example()`](https://metasurveyr.github.io/metasurvey/reference/load_survey_example.md)
  : Load survey example data
- [`survey_empty()`](https://metasurveyr.github.io/metasurvey/reference/survey_empty.md)
  : survey_empty
- [`get_data()`](https://metasurveyr.github.io/metasurvey/reference/get_data.md)
  : get_data
- [`set_data()`](https://metasurveyr.github.io/metasurvey/reference/set_data.md)
  : Set data on a Survey
- [`get_metadata()`](https://metasurveyr.github.io/metasurvey/reference/get_metadata.md)
  : get_metadata
- [`get_steps()`](https://metasurveyr.github.io/metasurvey/reference/get_steps.md)
  : get_steps
- [`has_steps()`](https://metasurveyr.github.io/metasurvey/reference/has_steps.md)
  : Check if survey has steps
- [`has_recipes()`](https://metasurveyr.github.io/metasurvey/reference/has_recipes.md)
  : Check if survey has recipes
- [`has_design()`](https://metasurveyr.github.io/metasurvey/reference/has_design.md)
  : Check if survey has a design
- [`is_baked()`](https://metasurveyr.github.io/metasurvey/reference/is_baked.md)
  : Check if all steps are baked
- [`survey_to_data_frame()`](https://metasurveyr.github.io/metasurvey/reference/survey_to_data_frame.md)
  : survey_to_data_frame
- [`survey_to_datatable()`](https://metasurveyr.github.io/metasurvey/reference/survey_to_datatable.md)
  [`survey_to_data.table()`](https://metasurveyr.github.io/metasurvey/reference/survey_to_datatable.md)
  : Convert survey to data.table
- [`survey_to_tibble()`](https://metasurveyr.github.io/metasurvey/reference/survey_to_tibble.md)
  : survey_to_tibble

## Steps

Reproducible transformations on surveys

- [`step_compute()`](https://metasurveyr.github.io/metasurvey/reference/step_compute.md)
  : Create computation steps for survey variables
- [`step_recode()`](https://metasurveyr.github.io/metasurvey/reference/step_recode.md)
  : Create recoding steps for categorical variables
- [`step_filter()`](https://metasurveyr.github.io/metasurvey/reference/step_filter.md)
  : Filter rows from survey data
- [`step_rename()`](https://metasurveyr.github.io/metasurvey/reference/step_rename.md)
  : Rename variables in survey data (step)
- [`step_remove()`](https://metasurveyr.github.io/metasurvey/reference/step_remove.md)
  : Remove variables from survey data (step)
- [`step_join()`](https://metasurveyr.github.io/metasurvey/reference/step_join.md)
  : Join external data into survey (step)
- [`step_weight()`](https://metasurveyr.github.io/metasurvey/reference/step_weight.md)
  : Apply survey weights from a weightflow specification
- [`step_quantile()`](https://metasurveyr.github.io/metasurvey/reference/step_quantile.md)
  : Weighted quantile groups (step)
- [`step_collapse()`](https://metasurveyr.github.io/metasurvey/reference/step_collapse.md)
  : Collapse survey data to one row per group (step)
- [`step_validate()`](https://metasurveyr.github.io/metasurvey/reference/step_validate.md)
  : Validate data during the step pipeline
- [`bake_steps()`](https://metasurveyr.github.io/metasurvey/reference/bake_steps.md)
  : Execute all pending steps

## Recipes

Reproducible and portable pipelines

- [`Recipe-class`](https://metasurveyr.github.io/metasurvey/reference/Recipe-class.md)
  [`Recipe`](https://metasurveyr.github.io/metasurvey/reference/Recipe-class.md)
  : Recipe R6 class
- [`recipe()`](https://metasurveyr.github.io/metasurvey/reference/recipe.md)
  : Create a survey data transformation recipe
- [`steps_to_recipe()`](https://metasurveyr.github.io/metasurvey/reference/steps_to_recipe.md)
  : Convert a list of steps to a recipe
- [`add_recipe()`](https://metasurveyr.github.io/metasurvey/reference/add_recipe.md)
  : Add a recipe to a Survey
- [`bake_recipes()`](https://metasurveyr.github.io/metasurvey/reference/bake_recipes.md)
  : Bake recipes
- [`save_recipe()`](https://metasurveyr.github.io/metasurvey/reference/save_recipe.md)
  : Save Recipe
- [`read_recipe()`](https://metasurveyr.github.io/metasurvey/reference/read_recipe.md)
  : Read Recipe
- [`get_recipe()`](https://metasurveyr.github.io/metasurvey/reference/get_recipe.md)
  : Get recipe from repository or API
- [`certify_recipe()`](https://metasurveyr.github.io/metasurvey/reference/certify_recipe.md)
  : Certify a recipe
- [`print(`*`<Recipe>`*`)`](https://metasurveyr.github.io/metasurvey/reference/print.Recipe.md)
  : Print method for Recipe objects
- [`recipe_user()`](https://metasurveyr.github.io/metasurvey/reference/recipe_user.md)
  : Create a recipe user
- [`recipe_category()`](https://metasurveyr.github.io/metasurvey/reference/recipe_category.md)
  : Create a recipe category
- [`recipe_certification()`](https://metasurveyr.github.io/metasurvey/reference/recipe_certification.md)
  : Create a recipe certification
- [`add_category()`](https://metasurveyr.github.io/metasurvey/reference/add_category.md)
  : Add a category to a recipe
- [`remove_category()`](https://metasurveyr.github.io/metasurvey/reference/remove_category.md)
  : Remove a category from a recipe
- [`default_categories()`](https://metasurveyr.github.io/metasurvey/reference/default_categories.md)
  : Default recipe categories
- [`set_user_info()`](https://metasurveyr.github.io/metasurvey/reference/set_user_info.md)
  : Set user info on a recipe
- [`set_version()`](https://metasurveyr.github.io/metasurvey/reference/set_version.md)
  : Set version on a recipe

## Recipe Discovery

Search, filter, and publish recipes

- [`list_recipes()`](https://metasurveyr.github.io/metasurvey/reference/list_recipes.md)
  : List all recipes
- [`search_recipes()`](https://metasurveyr.github.io/metasurvey/reference/search_recipes.md)
  : Search recipes
- [`filter_recipes()`](https://metasurveyr.github.io/metasurvey/reference/filter_recipes.md)
  : Filter recipes by criteria
- [`harmonize()`](https://metasurveyr.github.io/metasurvey/reference/harmonize.md)
  : Harmonize surveys using registry recipes
- [`rank_recipes()`](https://metasurveyr.github.io/metasurvey/reference/rank_recipes.md)
  : Rank recipes by downloads
- [`explore_recipes()`](https://metasurveyr.github.io/metasurvey/reference/explore_recipes.md)
  : Launch the Recipe Explorer Shiny App
- [`publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/publish_recipe.md)
  : Publish Recipe
- [`set_backend()`](https://metasurveyr.github.io/metasurvey/reference/set_backend.md)
  : Set recipe backend
- [`get_backend()`](https://metasurveyr.github.io/metasurvey/reference/get_backend.md)
  : Get recipe backend

## Estimation

Survey estimation workflows

- [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
  : Execute estimation workflow for surveys
- [`workflow_table()`](https://metasurveyr.github.io/metasurvey/reference/workflow_table.md)
  : Create publication-quality table from workflow results
- [`RecipeWorkflow-class`](https://metasurveyr.github.io/metasurvey/reference/RecipeWorkflow-class.md)
  [`RecipeWorkflow`](https://metasurveyr.github.io/metasurvey/reference/RecipeWorkflow-class.md)
  : RecipeWorkflow R6 class
- [`evaluate_cv()`](https://metasurveyr.github.io/metasurvey/reference/evaluate_cv.md)
  : Evaluate estimation with Coefficient of Variation

## Provenance

Data lineage and audit trails

- [`provenance()`](https://metasurveyr.github.io/metasurvey/reference/provenance.md)
  : Get provenance from a survey or workflow result
- [`provenance_to_json()`](https://metasurveyr.github.io/metasurvey/reference/provenance_to_json.md)
  : Export provenance to JSON
- [`provenance_diff()`](https://metasurveyr.github.io/metasurvey/reference/provenance_diff.md)
  : Compare two provenance objects
- [`print(`*`<metasurvey_provenance>`*`)`](https://metasurveyr.github.io/metasurvey/reference/print.metasurvey_provenance.md)
  : Print provenance information
- [`print(`*`<metasurvey_provenance_diff>`*`)`](https://metasurveyr.github.io/metasurvey/reference/print.metasurvey_provenance_diff.md)
  : Print provenance diff
- [`save_workflow()`](https://metasurveyr.github.io/metasurvey/reference/save_workflow.md)
  : Save a RecipeWorkflow to a JSON file
- [`read_workflow()`](https://metasurveyr.github.io/metasurvey/reference/read_workflow.md)
  : Read a RecipeWorkflow from a JSON file
- [`workflow_from_list()`](https://metasurveyr.github.io/metasurvey/reference/workflow_from_list.md)
  : Construct a RecipeWorkflow from a plain list
- [`list_workflows()`](https://metasurveyr.github.io/metasurvey/reference/list_workflows.md)
  : List all workflows
- [`search_workflows()`](https://metasurveyr.github.io/metasurvey/reference/search_workflows.md)
  : Search workflows
- [`filter_workflows()`](https://metasurveyr.github.io/metasurvey/reference/filter_workflows.md)
  : Filter workflows by criteria
- [`rank_workflows()`](https://metasurveyr.github.io/metasurvey/reference/rank_workflows.md)
  : Rank workflows by downloads
- [`find_workflows_for_recipe()`](https://metasurveyr.github.io/metasurvey/reference/find_workflows_for_recipe.md)
  : Find workflows that use a specific recipe
- [`publish_workflow()`](https://metasurveyr.github.io/metasurvey/reference/publish_workflow.md)
  : Publish a workflow to the active backend
- [`set_workflow_backend()`](https://metasurveyr.github.io/metasurvey/reference/set_workflow_backend.md)
  : Set workflow backend
- [`get_workflow_backend()`](https://metasurveyr.github.io/metasurvey/reference/get_workflow_backend.md)
  : Get workflow backend
- [`reproduce_workflow()`](https://metasurveyr.github.io/metasurvey/reference/reproduce_workflow.md)
  : Reproduce a workflow from its published specification
- [`print(`*`<RecipeWorkflow>`*`)`](https://metasurveyr.github.io/metasurvey/reference/print.RecipeWorkflow.md)
  : Print method for RecipeWorkflow objects

## Rotating Panels

Panels with implantation and follow-ups

- [`get_implantation()`](https://metasurveyr.github.io/metasurvey/reference/get_implantation.md)
  : Get implantation survey from a rotating panel
- [`get_follow_up()`](https://metasurveyr.github.io/metasurvey/reference/get_follow_up.md)
  : Get follow-up surveys from a rotating panel
- [`extract_surveys()`](https://metasurveyr.github.io/metasurvey/reference/extract_surveys.md)
  : Extract surveys by periodicity from a rotating panel

## Weights and Design

Weight and sampling design configuration

- [`add_weight()`](https://metasurveyr.github.io/metasurvey/reference/add_weight.md)
  : Configure weights by periodicity for Survey objects
- [`add_replicate()`](https://metasurveyr.github.io/metasurvey/reference/add_replicate.md)
  : Configure replicate weights for variance estimation
- [`resolve_weight_spec()`](https://metasurveyr.github.io/metasurvey/reference/resolve_weight_spec.md)
  : Resolve a portable weight specification to a usable weight
  configuration
- [`cat_design()`](https://metasurveyr.github.io/metasurvey/reference/cat_design.md)
  : Display survey design information
- [`cat_design_type()`](https://metasurveyr.github.io/metasurvey/reference/cat_design_type.md)
  : cat_design_type
- [`set_engine()`](https://metasurveyr.github.io/metasurvey/reference/set_engine.md)
  : Configure the survey data engine
- [`get_engine()`](https://metasurveyr.github.io/metasurvey/reference/get_engine.md)
  : Get the current survey data engine
- [`show_engines()`](https://metasurveyr.github.io/metasurvey/reference/show_engines.md)
  : List available survey data engines
- [`set_use_copy()`](https://metasurveyr.github.io/metasurvey/reference/set_use_copy.md)
  : Set data copy option
- [`use_copy_default()`](https://metasurveyr.github.io/metasurvey/reference/use_copy_default.md)
  : Get data copy option
- [`set_lazy_processing()`](https://metasurveyr.github.io/metasurvey/reference/set_lazy_processing.md)
  : Set lazy processing
- [`lazy_default()`](https://metasurveyr.github.io/metasurvey/reference/lazy_default.md)
  : Lazy processing

## Time and Dates

Utilities for editions and periodicity

- [`extract_time_pattern()`](https://metasurveyr.github.io/metasurvey/reference/extract_time_pattern.md)
  : Extract time pattern
- [`validate_time_pattern()`](https://metasurveyr.github.io/metasurvey/reference/validate_time_pattern.md)
  : Validate time pattern
- [`group_dates()`](https://metasurveyr.github.io/metasurvey/reference/group_dates.md)
  : Group dates

## Visualization

- [`view_graph()`](https://metasurveyr.github.io/metasurvey/reference/view_graph.md)
  : View graph

## Remote API

REST client for the recipe registry

- [`configure_api()`](https://metasurveyr.github.io/metasurvey/reference/configure_api.md)
  : Configure metasurvey API
- [`api_login()`](https://metasurveyr.github.io/metasurvey/reference/api_login.md)
  : Login
- [`api_logout()`](https://metasurveyr.github.io/metasurvey/reference/api_logout.md)
  : Logout
- [`api_register()`](https://metasurveyr.github.io/metasurvey/reference/api_register.md)
  : Register a new user
- [`api_me()`](https://metasurveyr.github.io/metasurvey/reference/api_me.md)
  : Get current user profile
- [`api_refresh_token()`](https://metasurveyr.github.io/metasurvey/reference/api_refresh_token.md)
  : Refresh JWT token
- [`api_list_recipes()`](https://metasurveyr.github.io/metasurvey/reference/api_list_recipes.md)
  : List recipes from API
- [`api_get_recipe()`](https://metasurveyr.github.io/metasurvey/reference/api_get_recipe.md)
  : Get recipe(s) by ID
- [`api_publish_recipe()`](https://metasurveyr.github.io/metasurvey/reference/api_publish_recipe.md)
  : Publish a recipe
- [`api_list_workflows()`](https://metasurveyr.github.io/metasurvey/reference/api_list_workflows.md)
  : List workflows from API
- [`api_get_workflow()`](https://metasurveyr.github.io/metasurvey/reference/api_get_workflow.md)
  : Get a single workflow by ID
- [`api_publish_workflow()`](https://metasurveyr.github.io/metasurvey/reference/api_publish_workflow.md)
  : Publish a workflow
- [`api_get_anda_variables()`](https://metasurveyr.github.io/metasurvey/reference/api_get_anda_variables.md)
  : Get ANDA variable metadata from the API
- [`api_star_recipe()`](https://metasurveyr.github.io/metasurvey/reference/api_star_recipe.md)
  : Rate a recipe
- [`api_get_recipe_stars()`](https://metasurveyr.github.io/metasurvey/reference/api_get_recipe_stars.md)
  : Get star summary for a recipe
- [`api_comment_recipe()`](https://metasurveyr.github.io/metasurvey/reference/api_comment_recipe.md)
  : Add a comment to a recipe
- [`api_get_recipe_comments()`](https://metasurveyr.github.io/metasurvey/reference/api_get_recipe_comments.md)
  : Get comments for a recipe
- [`api_get_recipe_dependents()`](https://metasurveyr.github.io/metasurvey/reference/api_get_recipe_dependents.md)
  : Get recipes that depend on a recipe
- [`api_star_workflow()`](https://metasurveyr.github.io/metasurvey/reference/api_star_workflow.md)
  : Rate a workflow
- [`api_get_workflow_stars()`](https://metasurveyr.github.io/metasurvey/reference/api_get_workflow_stars.md)
  : Get star summary for a workflow
- [`api_comment_workflow()`](https://metasurveyr.github.io/metasurvey/reference/api_comment_workflow.md)
  : Add a comment to a workflow
- [`api_get_workflow_comments()`](https://metasurveyr.github.io/metasurvey/reference/api_get_workflow_comments.md)
  : Get comments for a workflow
- [`api_delete_comment()`](https://metasurveyr.github.io/metasurvey/reference/api_delete_comment.md)
  : Delete a comment

## ANDA

INE Uruguay ANDA catalog metadata

- [`anda_variables()`](https://metasurveyr.github.io/metasurvey/reference/anda_variables.md)
  **\[experimental\]** : Query ANDA variable metadata from the API
- [`anda_download_microdata()`](https://metasurveyr.github.io/metasurvey/reference/anda_download_microdata.md)
  **\[experimental\]** : Download ECH microdata from ANDA5

## STATA Transpiler

Convert STATA do-files to metasurvey recipes

- [`transpile_stata()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata.md)
  **\[experimental\]** : Transpile a STATA .do file to metasurvey steps
- [`transpile_stata_module()`](https://metasurveyr.github.io/metasurvey/reference/transpile_stata_module.md)
  **\[experimental\]** : Transpile and group do-files by thematic module
- [`transpile_coverage()`](https://metasurveyr.github.io/metasurvey/reference/transpile_coverage.md)
  **\[experimental\]** : Analyze transpilation coverage for STATA
  do-files
- [`parse_do_file()`](https://metasurveyr.github.io/metasurvey/reference/parse_do_file.md)
  : Parse a STATA .do file into structured commands
- [`parse_stata_labels()`](https://metasurveyr.github.io/metasurvey/reference/parse_stata_labels.md)
  : Parse STATA label commands from source lines

## Ecosystem Classes

R6 classes for the recipe ecosystem

- [`RecipeCategory`](https://metasurveyr.github.io/metasurvey/reference/RecipeCategory.md)
  : RecipeCategory
- [`RecipeCertification`](https://metasurveyr.github.io/metasurvey/reference/RecipeCertification.md)
  : RecipeCertification
- [`RecipeUser`](https://metasurveyr.github.io/metasurvey/reference/RecipeUser.md)
  : RecipeUser
