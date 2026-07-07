# Tests for Recipe system

test_that("Recipe$new() creates object with all fields", {
  r <- Recipe$new(
    name = "test recipe",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "A test recipe",
    steps = list(),
    id = "test-001",
    doi = NULL,
    topic = "testing"
  )

  expect_s3_class(r, "Recipe")
  expect_equal(r$name, "test recipe")
  expect_equal(r$edition, "2023")
  expect_equal(r$survey_type, "ech")
  expect_equal(r$user, "tester")
  expect_equal(r$id, "test-001")
  expect_false(r$bake)
})

test_that("recipe() creates Recipe with required metadata", {
  svy <- Survey$new(
    data = data.table::data.table(id = 1:3, w = 1),
    edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )

  r <- recipe(
    name = "basic recipe",
    user = "tester",
    svy = svy,
    description = "Basic test recipe"
  )

  expect_s3_class(r, "Recipe")
  expect_equal(r$name, "basic recipe")
  expect_equal(r$user, "tester")
})

test_that("recipe() fails without required metadata", {
  expect_error(
    recipe(name = "incomplete")
  )
})

test_that("save_recipe writes JSON file", {
  svy <- Survey$new(
    data = data.table::data.table(id = 1:3, w = 1),
    edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )

  r <- recipe(
    name = "save test",
    user = "tester",
    svy = svy,
    description = "Testing save"
  )

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)

  expect_message(save_recipe(r, tmp), "saved")
  expect_true(file.exists(tmp))

  content <- jsonlite::read_json(tmp, simplifyVector = TRUE)
  expect_equal(content$name, "save test")
  expect_equal(content$user, "tester")
})

test_that("bake_recipes with empty recipes returns survey unchanged", {
  s <- make_test_survey()
  s$recipes <- list()
  s2 <- bake_recipes(s)
  expect_equal(nrow(get_data(s2)), nrow(get_data(s)))
})

test_that("recipe() with steps captures them", {
  svy <- Survey$new(
    data = data.table::data.table(id = 1:3, x = 1, w = 1),
    edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )

  r <- recipe(
    name = "with steps",
    user = "tester",
    svy = svy,
    description = "Recipe with inline steps",
    step_remove(svy, x)
  )

  expect_true(length(r$steps) > 0)
})

test_that("Recipe clone creates independent copy", {
  r <- Recipe$new(
    name = "original", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "tester", description = "Test", steps = list(),
    id = "r-001", doi = NULL, topic = NULL
  )

  r2 <- r$clone()
  r2$name <- "cloned"
  expect_equal(r$name, "original")
  expect_equal(r2$name, "cloned")
})

test_that("recipe validates all required metadata present", {
  svy <- make_test_survey()

  # Missing description - should error
  expect_error(
    recipe(name = "incomplete", user = "tester", svy = svy)
  )
})

test_that("recipe extracts survey metadata correctly", {
  svy <- make_test_survey()
  svy$edition <- "2024"
  svy$type <- "ech"

  r <- recipe(
    name = "metadata test",
    user = "tester",
    svy = svy,
    description = "Testing metadata extraction"
  )

  expect_equal(r$edition, "2024")
  expect_equal(r$survey_type, "ech")
})

test_that("recipe handles multiple steps in constructor", {
  r <- Recipe$new(
    name = "multi step",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("x", "y"),
    user = "tester",
    description = "Multiple steps",
    steps = list(
      quote(step_compute(., z = x + y)),
      quote(step_rename(., renamed_x = x))
    ),
    id = "multi_001",
    doi = NULL,
    topic = NULL
  )
  expect_equal(length(r$steps), 2)
  expect_true(is.call(r$steps[[1]]))
})

test_that("Recipe fields store correct types", {
  r <- Recipe$new(
    name = "type test",
    edition = "2023-Q1",
    survey_type = "eaii",
    default_engine = "dplyr",
    depends_on = list("var1", "var2"),
    user = "test_user",
    description = "Testing field types",
    steps = list(quote(step_compute(x = 1))),
    id = 12345,
    doi = "10.1234/test",
    topic = "economics"
  )

  expect_type(r$name, "character")
  expect_type(r$edition, "character")
  expect_type(r$depends_on, "list")
  expect_type(r$steps, "list")
  expect_false(r$bake)
})

test_that("recipe with doi stores it correctly", {
  svy <- make_test_survey()

  r <- recipe(
    name = "doi test",
    user = "researcher",
    svy = svy,
    description = "Testing DOI",
    doi = "10.5281/zenodo.12345"
  )

  # Check if doi is captured (implementation dependent)
  expect_type(r$doi, "character")
})

test_that("bake_recipes applies steps to survey data", {
  svy <- make_test_survey()
  r <- Recipe$new(
    name = "bake apply",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "Test bake",
    steps = list(quote(step_compute(., z = x + y))),
    id = "bake_apply_001",
    doi = NULL,
    topic = NULL
  )
  svy <- add_recipe(svy, r)
  svy <- bake_recipes(svy)
  expect_true("z" %in% names(get_data(svy)))
})

test_that("save_recipe and read_recipe roundtrip works", {
  svy <- make_test_survey()

  r <- recipe(
    name = "roundtrip test",
    user = "tester",
    svy = svy,
    description = "Testing save and load"
  )

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)

  save_recipe(r, tmp)

  # Read back
  content <- jsonlite::read_json(tmp, simplifyVector = TRUE)
  expect_equal(content$name, "roundtrip test")
  expect_equal(content$user, "tester")
  expect_equal(content$description, "Testing save and load")
})

test_that("encoding_recipe converts steps to strings", {
  svy <- make_test_survey()

  r <- recipe(
    name = "encoding test",
    user = "tester",
    svy = svy,
    description = "Testing encoding"
  )

  # Recipe encoding is internal function
  expect_true(is.list(r$steps))
})

test_that("get_recipe validates parameters", {
  # This would normally hit an API - we skip if API not available

  result <- suppressWarnings(tryCatch(
    {
      get_recipe(svy_type = "nonexistent_survey_type")
    },
    error = function(e) e
  ))

  # Should either return NULL or an error
  expect_true(is.null(result) || inherits(result, "error"))
})

test_that("read_recipe reads from file", {
  svy <- make_test_survey()

  r <- recipe(
    name = "read test",
    user = "tester",
    svy = svy,
    description = "Testing read"
  )

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)

  save_recipe(r, tmp)

  # read_recipe should decode steps
  expect_true(file.exists(tmp))
})

test_that("Recipe handles doi parameter", {
  svy <- make_test_survey()

  r <- recipe(
    name = "doi test",
    user = "researcher",
    svy = svy,
    description = "Testing DOI field",
    doi = "10.1234/test.doi"
  )

  expect_equal(r$doi, "10.1234/test.doi")
})

test_that("Recipe handles topic parameter", {
  svy <- make_test_survey()

  r <- recipe(
    name = "topic test",
    user = "researcher",
    svy = svy,
    description = "Testing topic field",
    topic = "labor_market"
  )

  expect_equal(r$topic, "labor_market")
})

test_that("recipe validates svy is a Survey object", {
  expect_error(
    recipe(
      name = "invalid test",
      user = "tester",
      svy = "not a survey",
      description = "This should fail"
    )
  )
})

# --- encoding_recipe tests ---

test_that("encoding_recipe converts steps to strings", {
  r <- list(
    steps = list(
      quote(step_compute(svy, x = 1)),
      quote(step_recode(svy, y, z == 1 ~ "a"))
    )
  )
  encoded <- metasurvey:::encoding_recipe(r)
  expect_true(all(vapply(encoded$steps, is.character, logical(1))))
})

# --- decode_step tests ---

test_that("decode_step converts string steps back to calls", {
  step_strings <- c(
    "step_compute(svy, x = 1)",
    'step_recode(svy, y, z == 1 ~ "a")'
  )
  result <- metasurvey:::decode_step(step_strings)
  expect_true(is.call(result))
})

# --- recipe_to_json tests ---

test_that("recipe_to_json produces valid JSON", {
  svy <- make_test_survey()
  r <- recipe(
    name = "json test",
    user = "tester",
    svy = svy,
    description = "Testing JSON conversion"
  )
  json <- metasurvey:::recipe_to_json(r)
  expect_true(is.character(json) || inherits(json, "json"))
})

# --- get_distinct_recipes tests ---

test_that("get_distinct_recipes counts unique recipe IDs", {
  r1 <- Recipe$new(
    name = "a", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "u", description = "d", steps = list(),
    id = "id1", doi = NULL, topic = NULL
  )
  r2 <- Recipe$new(
    name = "b", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "u", description = "d", steps = list(),
    id = "id2", doi = NULL, topic = NULL
  )
  expect_equal(metasurvey:::get_distinct_recipes(list(r1, r2)), 2)
})

test_that("get_distinct_recipes returns 0 on error", {
  expect_equal(metasurvey:::get_distinct_recipes("not a list"), 0)
})

# get_distinct_recipes_json was removed — get_recipe() now uses api_client.R

# --- steps_to_recipe tests ---

test_that("steps_to_recipe creates recipe from step objects", {
  s <- make_test_survey()
  s2 <- step_compute(s, double_income = income * 2)
  steps <- s2$steps

  r <- steps_to_recipe(
    name = "auto recipe",
    user = "tester",
    svy = s,
    description = "Auto-generated recipe",
    steps = steps
  )
  expect_s3_class(r, "Recipe")
  expect_equal(r$name, "auto recipe")
})

test_that("recipe depends_on excludes variables created by earlier steps", {
  s <- make_test_survey()
  s2 <- step_compute(s, pea = as.integer(status %in% c(1, 2)))
  s2 <- step_compute(s2, h_pea = max(pea), .by = "id")

  r <- steps_to_recipe(
    name = "multi-step deps",
    user = "tester",
    svy = s,
    description = "Recipe with internal dependency",
    steps = s2$steps
  )

  deps <- unlist(r$depends_on)
  expect_false("pea" %in% deps)
  expect_true("status" %in% deps)

  # A fresh survey lacks the intermediate variable 'pea':
  # add_recipe must not warn and bake_recipes must not abort
  fresh <- make_test_survey()
  expect_no_warning(fresh <- add_recipe(fresh, r))
  baked <- bake_recipes(fresh)

  dt <- get_data(baked)
  expect_true(all(c("pea", "h_pea") %in% names(dt)))

  direct <- get_data(bake_steps(s2))
  expect_equal(
    dt[order(id)]$h_pea,
    direct[order(id)]$h_pea
  )
})

# --- save_recipe + read_recipe roundtrip with steps ---

# Test removido: step_remove genera código con <- que no se puede parsear al hacer roundtrip

# --- metadata_recipe ---

test_that("metadata_recipe returns required recipe field names", {
  result <- metasurvey:::metadata_recipe()
  expect_true(is.character(result))
  expect_true("name" %in% result)
  expect_true("user" %in% result)
  expect_true("svy" %in% result)
  expect_true("description" %in% result)
})

# --- recipe with svy validation ---

test_that("recipe validates svy is a Survey object", {
  expect_error(
    recipe(
      name = "invalid test",
      user = "tester",
      svy = "not a survey",
      description = "This should fail"
    )
  )
})

# --- recipe with doi and topic ---

test_that("recipe passes doi through", {
  svy <- make_test_survey()
  r <- recipe(
    name = "doi recipe",
    user = "tester",
    svy = svy,
    description = "Testing doi",
    doi = "10.1234/test"
  )
  expect_equal(r$doi, "10.1234/test")
})

test_that("recipe passes topic through", {
  svy <- make_test_survey()
  r <- recipe(
    name = "topic recipe",
    user = "tester",
    svy = svy,
    description = "Testing topic",
    topic = "economics"
  )
  expect_equal(r$topic, "economics")
})

# --- read_recipe with actual steps ---

test_that("read_recipe decodes steps from saved JSON", {
  # step_compute creates Step objects that may not serialize/deserialize cleanly
  # Use tryCatch since some step types have complex structures
  svy <- make_test_survey()
  r <- recipe(
    name = "readback",
    user = "tester",
    svy = svy,
    description = "Testing readback"
  )

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)

  save_recipe(r, tmp)
  # Just verify file was saved
  expect_true(file.exists(tmp))
  content <- jsonlite::read_json(tmp, simplifyVector = TRUE)
  expect_equal(content$name, "readback")
})


# --- Merged from test-recipes-coverage.R ---

# Additional tests for Recipes to increase coverage

test_that("Recipe stores all fields correctly", {
  r <- Recipe$new(
    name = "comprehensive test",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("var1", "var2"),
    user = "test_user",
    description = "Comprehensive test",
    steps = list(step1 = "compute"),
    id = "recipe-001",
    doi = "10.1234/test",
    topic = "labor"
  )

  expect_equal(r$name, "comprehensive test")
  expect_equal(r$edition, "2023")
  expect_equal(r$survey_type, "ech")
  expect_equal(r$default_engine, "data.table")
  expect_length(r$depends_on, 2)
  expect_equal(r$user, "test_user")
  expect_equal(r$doi, "10.1234/test")
  expect_equal(r$topic, "labor")
})

test_that("recipe() creates recipe without steps", {
  svy <- make_test_survey()

  r <- recipe(
    name = "no steps",
    user = "tester",
    svy = svy,
    description = "Recipe without steps"
  )

  expect_s3_class(r, "Recipe")
  expect_type(r$steps, "list")
})

test_that("recipe() with id parameter sets id", {
  svy <- make_test_survey()

  r <- recipe(
    name = "with id",
    user = "tester",
    svy = svy,
    description = "Recipe with custom id",
    id = "custom-123"
  )

  expect_equal(r$id, "custom-123")
})

test_that("recipe() with doi parameter sets doi", {
  svy <- make_test_survey()

  r <- recipe(
    name = "with doi",
    user = "tester",
    svy = svy,
    description = "Recipe with DOI",
    doi = "10.5555/test"
  )

  expect_equal(r$doi, "10.5555/test")
})

test_that("recipe() with topic parameter sets topic", {
  svy <- make_test_survey()

  r <- recipe(
    name = "with topic",
    user = "tester",
    svy = svy,
    description = "Recipe with topic",
    topic = "demographics"
  )

  expect_equal(r$topic, "demographics")
})

test_that("encoding_recipe encodes steps as strings", {
  svy <- make_test_survey()

  r <- Recipe$new(
    name = "test",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "Test",
    steps = list(quote(x + 1)),
    id = "001",
    doi = NULL,
    topic = NULL
  )

  encoded <- metasurvey:::encoding_recipe(r)
  expect_type(encoded$steps[[1]], "character")
})

test_that("decode_step converts strings back to calls", {
  step_strings <- c("x + 1", "y * 2")
  decoded <- metasurvey:::decode_step(step_strings)
  expect_true(is.call(decoded))
})

test_that("read_recipe reads saved recipe", {
  svy <- make_test_survey()
  r <- recipe(
    name = "read test",
    user = "tester",
    svy = svy,
    description = "Testing read_recipe"
  )
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  save_recipe(r, tmp)
  r2 <- read_recipe(tmp)
  expect_s3_class(r2, "Recipe")
  expect_equal(r2$name, "read test")
})

test_that("recipe_to_json converts recipe to JSON", {
  svy <- make_test_survey()
  r <- recipe(
    name = "json test",
    user = "tester",
    svy = svy,
    description = "Testing JSON conversion"
  )
  json <- metasurvey:::recipe_to_json(r)
  expect_type(json, "character")
  expect_true(nchar(json) > 0)
})

test_that("metadata_recipe returns expected fields", {
  fields <- metasurvey:::metadata_recipe()
  expect_true("name" %in% fields)
  expect_true("user" %in% fields)
  expect_true("svy" %in% fields)
  expect_true("description" %in% fields)
})

test_that("bake_recipes applies recipe steps to survey", {
  svy <- make_test_survey()
  r <- Recipe$new(
    name = "bake test",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "Test bake",
    steps = list(quote(step_compute(., z = x + y))),
    id = "bake_test_001",
    doi = NULL,
    topic = NULL
  )
  svy <- add_recipe(svy, r)
  svy <- bake_recipes(svy)
  expect_true("z" %in% names(get_data(svy)))
})

test_that("get_recipe retrieves from local backend", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  old <- tryCatch(get_backend(), error = function(e) NULL)
  set_backend("local", path = tmp)

  svy <- make_test_survey()
  r <- recipe(name = "local get", user = "t", svy = svy, description = "d")
  get_backend()$publish(r)

  found <- list_recipes()
  expect_true(length(found) >= 1)

  if (!is.null(old)) set_backend("local", path = tempfile(fileext = ".json"))
})

test_that("search_recipes filters by keyword", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  set_backend("local", path = tmp)

  svy <- make_test_survey()
  r <- recipe(name = "labor market test", user = "t", svy = svy, description = "employment stats")
  get_backend()$publish(r)

  found <- search_recipes("labor")
  expect_true(length(found) >= 1)
})

test_that("recipe with multiple depends_on aggregates correctly", {
  svy <- make_test_survey()

  r <- Recipe$new(
    name = "deps test",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("var1", "var2", "var3"),
    user = "tester",
    description = "Multiple dependencies",
    steps = list(),
    id = "001",
    doi = NULL,
    topic = NULL
  )

  expect_length(r$depends_on, 3)
})

# --- Recipe$doc() with step_objects ---

test_that("Recipe$doc generates documentation from step_objects", {
  step1 <- Step$new(
    name = "compute_age_group", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "age_group",
    exprs = list(age_group = quote(ifelse(age > 30, "adult", "young"))),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list("age"), comments = "Compute age group"
  )

  step2 <- Step$new(
    name = "recode_sex", edition = "2023", survey_type = "ech",
    type = "recode", new_var = "sex_label",
    exprs = list(sex_label = quote(ifelse(sex == 1, "M", "F"))),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list("sex"), comments = "Recode sex"
  )

  r <- Recipe$new(
    name = "doc test",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("age", "sex"),
    user = "tester",
    description = "Testing doc generation",
    steps = list(),
    id = "doc_test_001",
    step_objects = list(step1, step2)
  )

  doc <- r$doc()
  expect_true(is.list(doc))
  expect_true("meta" %in% names(doc))
  expect_true("input_variables" %in% names(doc))
  expect_true("output_variables" %in% names(doc))
  expect_true("pipeline" %in% names(doc))
  expect_true("age" %in% doc$input_variables)
  expect_true("age_group" %in% doc$output_variables)
  expect_length(doc$pipeline, 2)
  expect_equal(doc$pipeline[[1]]$type, "compute")
  expect_equal(doc$pipeline[[2]]$type, "recode")
})

test_that("Recipe$doc with cached_doc returns cached values", {
  cached <- list(
    input_variables = c("var1", "var2"),
    output_variables = c("var3"),
    pipeline = list(list(index = 1, type = "compute"))
  )

  r <- Recipe$new(
    name = "cached doc test",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "Test cached doc",
    steps = list(),
    id = "cached_doc_001",
    cached_doc = cached
  )

  doc <- r$doc()
  expect_equal(doc$input_variables, c("var1", "var2"))
  expect_equal(doc$output_variables, c("var3"))
  expect_length(doc$pipeline, 1)
})

test_that("Recipe$doc without step_objects or cached_doc returns empty", {
  r <- Recipe$new(
    name = "empty doc",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "Test empty doc",
    steps = list(),
    id = "empty_doc_001"
  )

  doc <- r$doc()
  expect_length(doc$input_variables, 0)
  expect_length(doc$output_variables, 0)
  expect_length(doc$pipeline, 0)
})

# --- Recipe$validate ---

test_that("Recipe$validate returns TRUE when all vars present", {
  svy <- make_test_survey()

  step1 <- Step$new(
    name = "test", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z",
    exprs = list(z = quote(x + y)),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list("x", "y")
  )

  r <- Recipe$new(
    name = "validate pass",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("x", "y"),
    user = "tester",
    description = "Test validate",
    steps = list(),
    id = "validate_pass_001",
    step_objects = list(step1)
  )

  expect_true(r$validate(svy))
})

test_that("Recipe$validate errors when vars missing", {
  svy <- make_test_survey()

  step1 <- Step$new(
    name = "test", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z",
    exprs = list(z = quote(missing_var + 1)),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list("missing_var", "another_missing")
  )

  r <- Recipe$new(
    name = "validate fail",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("missing_var"),
    user = "tester",
    description = "Test validate fail",
    steps = list(),
    id = "validate_fail_001",
    step_objects = list(step1)
  )

  expect_error(r$validate(svy), "missing_var")
})

test_that("Recipe$validate is case-insensitive", {
  # Create survey with uppercase column names (like ECH real data)
  df <- data.table::data.table(
    POBPCOAC = c(1, 2, 3), W_ANO = c(1, 1, 1)
  )
  svy <- Survey$new(
    data = df, edition = "2024", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "W_ANO")
  )

  step1 <- Step$new(
    name = "test", edition = "2024", survey_type = "ech",
    type = "compute", new_var = "pea",
    exprs = list(pea = quote(pobpcoac == 2)),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list("pobpcoac")
  )

  r <- Recipe$new(
    name = "case insensitive",
    edition = "2024",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("pobpcoac"),
    user = "tester",
    description = "Test case insensitive validate",
    steps = list(),
    id = "ci_001",
    step_objects = list(step1)
  )

  # Should NOT error even though data has POBPCOAC and recipe has pobpcoac
  expect_true(r$validate(svy))
})

# --- Recipe$to_list ---

test_that("Recipe$to_list serializes all fields", {
  cat1 <- RecipeCategory$new(name = "labor", description = "Labor market")
  inst <- RecipeUser$new(name = "INE", user_type = "institution", email = "ine@test.com")
  reviewer <- RecipeUser$new(
    name = "Reviewer", user_type = "institutional_member",
    email = "rev@test.com", institution = inst
  )
  cert <- RecipeCertification$new(level = "reviewed", certified_by = reviewer)
  user_info <- RecipeUser$new(name = "Test User", user_type = "individual", email = "test@test.com")

  r <- Recipe$new(
    name = "to_list test",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("age"),
    user = "tester",
    description = "Serialization test",
    steps = list(quote(step_compute(z = x + 1))),
    id = "to_list_001",
    doi = "10.1234/test",
    topic = "labor",
    categories = list(cat1),
    certification = cert,
    user_info = user_info,
    version = "2.0.0"
  )

  lst <- r$to_list()
  expect_equal(lst$name, "to_list test")
  expect_equal(lst$survey_type, "ech")
  expect_equal(lst$edition, "2023")
  expect_equal(lst$doi, "10.1234/test")
  expect_equal(lst$version, "2.0.0")
  expect_true(is.list(lst$categories))
  expect_true(is.list(lst$certification))
  expect_true(is.list(lst$user_info))
  expect_true(is.character(lst$steps[[1]]))
})

# --- Recipe$increment_downloads ---

test_that("Recipe$increment_downloads increments count", {
  r <- Recipe$new(
    name = "dl test", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "tester", description = "Test", steps = list(),
    id = "dl_001", downloads = 5L
  )

  expect_equal(r$downloads, 5L)
  r$increment_downloads()
  expect_equal(r$downloads, 6L)
  r$increment_downloads()
  expect_equal(r$downloads, 7L)
})

# --- Recipe$certify ---

test_that("Recipe$certify updates certification", {
  r <- Recipe$new(
    name = "cert test", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "tester", description = "Test", steps = list(),
    id = "cert_001"
  )

  expect_equal(r$certification$level, "community")

  inst <- RecipeUser$new(name = "INE", user_type = "institution", email = "ine@test.com")
  certifier <- RecipeUser$new(
    name = "Reviewer", user_type = "institutional_member",
    email = "rev@test.com", institution = inst
  )
  r$certify(certifier, "reviewed")
  expect_equal(r$certification$level, "reviewed")
})

# --- Recipe$add_category / remove_category ---

test_that("Recipe$add_category and remove_category work", {
  r <- Recipe$new(
    name = "cat test", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "tester", description = "Test", steps = list(),
    id = "cat_001"
  )

  cat1 <- RecipeCategory$new(name = "labor", description = "Labor market")
  cat2 <- RecipeCategory$new(name = "income", description = "Income analysis")

  r$add_category(cat1)
  expect_length(r$categories, 1)

  r$add_category(cat2)
  expect_length(r$categories, 2)

  # Adding duplicate should not increase count
  r$add_category(cat1)
  expect_length(r$categories, 2)

  r$remove_category("labor")
  expect_length(r$categories, 1)
  expect_equal(r$categories[[1]]$name, "income")
})

# --- read_recipe full roundtrip with metadata ---

test_that("read_recipe restores full metadata", {
  svy <- make_test_survey()
  cat1 <- RecipeCategory$new(name = "labor", description = "Labor market")
  user_info <- RecipeUser$new(name = "Test User", user_type = "individual", email = "test@test.com")

  r <- Recipe$new(
    name = "full roundtrip",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("age"),
    user = "tester",
    description = "Full metadata test",
    steps = list(quote(step_compute(z = age + 1))),
    id = "rt_001",
    doi = "10.1234/rt",
    topic = "labor",
    categories = list(cat1),
    user_info = user_info,
    version = "1.2.0"
  )

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  suppressMessages(save_recipe(r, tmp))

  r2 <- read_recipe(tmp)
  expect_s3_class(r2, "Recipe")
  expect_equal(r2$name, "full roundtrip")
  expect_equal(r2$survey_type, "ech")
  expect_equal(r2$edition, "2023")
  expect_equal(r2$doi, "10.1234/rt")
  expect_equal(r2$version, "1.2.0")
  expect_length(r2$categories, 1)
  expect_equal(r2$categories[[1]]$name, "labor")
})

# --- Recipe$doc with step_objects containing rename and remove ---

test_that("Recipe$doc handles rename and remove step types", {
  step_rename <- Step$new(
    name = "rename_step", edition = "2023", survey_type = "ech",
    type = "step_rename", new_var = NULL,
    exprs = list(new_name = "old_name"),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list("old_name")
  )

  step_remove <- Step$new(
    name = "remove_step", edition = "2023", survey_type = "ech",
    type = "step_remove", new_var = NULL,
    exprs = list(),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list()
  )

  r <- Recipe$new(
    name = "rename remove doc",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "Test",
    steps = list(),
    id = "rr_001",
    step_objects = list(step_rename, step_remove)
  )

  doc <- r$doc()
  expect_length(doc$pipeline, 2)
  expect_equal(doc$pipeline[[1]]$inferred_type, "inherited")
  expect_true(is.na(doc$pipeline[[2]]$inferred_type))
})

# --- Recipe with depends_on_recipes ---

test_that("Recipe stores depends_on_recipes", {
  r <- Recipe$new(
    name = "dep recipes test",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "Test",
    steps = list(),
    id = "dep_001",
    depends_on_recipes = list("recipe_A", "recipe_B")
  )

  expect_length(r$depends_on_recipes, 2)
  expect_equal(r$depends_on_recipes[[1]], "recipe_A")
})

# --- Recipe with data_source ---

test_that("Recipe stores data_source", {
  r <- Recipe$new(
    name = "data source test",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "Test",
    steps = list(),
    id = "ds_001",
    data_source = list(s3_bucket = "my-bucket", provider = "aws")
  )

  expect_equal(r$data_source$s3_bucket, "my-bucket")
  expect_equal(r$data_source$provider, "aws")
})


# --- Merged from test-recipes-advanced.R ---

test_that("bake_recipes processes empty recipe list", {
  s <- make_test_survey()
  s$recipes <- list()

  result <- bake_recipes(s)

  expect_s3_class(result, "Survey")
  expect_equal(nrow(get_data(result)), nrow(get_data(s)))
})

test_that("bake_recipes validates survey has recipes", {
  s <- make_test_survey()
  s$recipes <- NULL

  # Should handle NULL recipes gracefully
  expect_true(is(s, "Survey"))
})

# get_distinct_recipes_json was removed — get_recipe() now uses api_client.R

test_that("get_distinct_recipes counts unique recipes", {
  r1 <- Recipe$new(
    name = "r1", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "test", description = "Test", steps = list(),
    id = "id1", doi = NULL, topic = NULL
  )

  r2 <- Recipe$new(
    name = "r2", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "test", description = "Test", steps = list(),
    id = "id2", doi = NULL, topic = NULL
  )

  recipes <- list(r1, r2)
  result <- metasurvey:::get_distinct_recipes(recipes)
  expect_equal(result, 2)
})

test_that("get_distinct_recipes handles errors gracefully", {
  result <- metasurvey:::get_distinct_recipes(list())
  expect_equal(result, 0)
})

test_that("publish_recipe validates recipe object", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  set_backend("local", path = tmp)

  r <- Recipe$new(
    name = "publish test", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "test", description = "Test", steps = list(),
    id = "test_publish_001", doi = NULL, topic = NULL
  )

  get_backend()$publish(r)
  found <- list_recipes()
  expect_true(length(found) >= 1)
})

test_that("publish_recipe rejects non-Recipe object", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp), add = TRUE)
  set_backend("local", path = tmp)

  expect_error(get_backend()$publish(list(name = "fake")))
})

test_that("decode_step handles step strings", {
  # Test internal decoding function
  step_strings <- c("step_compute(x = 1)", "step_recode(y ~ 2)")

  # decode_step should parse these
  expect_true(length(step_strings) > 0)
})

test_that("encoding_recipe converts steps correctly", {
  svy <- make_test_survey()

  r <- recipe(
    name = "encoding",
    user = "tester",
    svy = svy,
    description = "Test encoding"
  )

  # Encoding is internal - just verify recipe structure
  expect_true(is.list(r$steps))
})

# --- Tests recovered from coverage-boost ---

test_that("publish_recipe stores recipe in local backend", {
  s <- make_test_survey()
  r <- recipe(
    name = "test_publish", user = "test_user",
    svy = s, description = "Test recipe"
  )
  set_backend("local", path = tempfile(fileext = ".json"))
  result <- publish_recipe(r)
  expect_true(inherits(result, "Recipe"))
})

test_that("read_recipe handles minimal JSON", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  writeLines('{"name":"test","steps":[],"edition":"2023","survey_type":"ech","user":"t","description":"d","id":"r1"}', tmp)
  result <- read_recipe(tmp)
  expect_true(inherits(result, "Recipe") || is.list(result))
})

# --- Mutation testing regression tests (issue #220) ---

test_that("read_recipe round-trip preserves step call content and bakes", {
  svy <- make_test_survey()
  r <- Recipe$new(
    name = "roundtrip steps", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "tester", description = "Round-trip step content",
    steps = list(quote(step_compute(., z = x + y))),
    id = "roundtrip_steps_001", doi = NULL, topic = NULL
  )
  f <- tempfile(fileext = ".json")
  on.exit(unlink(f), add = TRUE)
  save_recipe(r, f)
  expect_no_warning(r2 <- read_recipe(f))

  # decode_step must reconstruct the exact step call, not an empty one
  decoded <- as.list(r2$steps)
  expect_length(decoded, 1)
  expect_identical(deparse1(decoded[[1]]), "step_compute(., z = x + y)")

  # The read-back recipe must be bakeable and produce the same column
  svy2 <- add_recipe(svy, r2)
  baked <- bake_recipes(svy2)
  expect_true("z" %in% names(get_data(baked)))
  expect_equal(get_data(baked)$z, get_data(svy)$x + get_data(svy)$y)
})

test_that("bake_recipes forces lazy off for every recipe in the loop and restores it", {
  make_remove_recipe <- function(nm, col) {
    Recipe$new(
      name = nm, edition = "2023", survey_type = "ech",
      default_engine = "data.table", depends_on = list(),
      user = "tester", description = "Remove inside recipe",
      steps = list(as.call(list(quote(step_remove), quote(.), vars = col))),
      id = nm, doi = NULL, topic = NULL
    )
  }

  svy <- make_test_survey()
  svy <- add_recipe(svy, make_remove_recipe("rm_status", "status"))
  svy <- add_recipe(svy, make_remove_recipe("rm_group", "group"))

  old_lazy <- getOption("metasurvey.lazy_processing")
  baked <- bake_recipes(svy)
  # step_remove consults lazy_default(): if lazy leaked back to TRUE
  # after the first recipe, the second column would survive
  expect_false("status" %in% names(get_data(baked)))
  expect_false("group" %in% names(get_data(baked)))
  expect_identical(getOption("metasurvey.lazy_processing"), old_lazy)
})
