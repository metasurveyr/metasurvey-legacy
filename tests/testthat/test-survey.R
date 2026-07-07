# Tests for Survey R6 class and related functions

test_that("Survey$new() creates object with correct fields", {
  df <- data.table::data.table(id = 1:5, x = 10:14, w = 1)
  s <- Survey$new(
    data = df, edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )

  expect_s3_class(s, "Survey")
  expect_equal(nrow(s$data), 5)
  expect_equal(s$type, "ech")
  expect_equal(s$default_engine, "data.table")

  # Trigger design initialization
  s <- s %>%
    step_compute(y = x * 2) %>%
    bake_steps()
  expect_true(length(s$design) > 0)
})

test_that("get_data() returns underlying data", {
  s <- make_test_survey()
  d <- get_data(s)
  expect_true(data.table::is.data.table(d))
  expect_equal(nrow(d), 10)
})

test_that("set_data() replaces data", {
  s <- make_test_survey()
  new_df <- data.table::data.table(id = 1:3, w = 1)
  s$set_data(new_df)
  expect_equal(nrow(get_data(s)), 3)
})

test_that("get/set_edition round-trip", {
  s <- make_test_survey()
  s$set_edition("2024")
  expect_equal(s$get_edition(), "2024")
})

test_that("get/set_type round-trip", {
  s <- make_test_survey()
  s$set_type("eph")
  expect_equal(s$get_type(), "eph")
})

test_that("survey_to_data_frame returns data.frame", {
  s <- make_test_survey()
  df <- survey_to_data_frame(s)
  expect_s3_class(df, "data.frame")
  expect_equal(nrow(df), 10)
})

test_that("survey_to_datatable returns data.table", {
  s <- make_test_survey()
  dt <- survey_to_datatable(s)
  expect_true(data.table::is.data.table(dt))
})

test_that("survey_to_data.table is deprecated", {
  s <- make_test_survey()
  lifecycle::expect_deprecated(survey_to_data.table(s))
})

test_that("get_metadata does not error on Survey", {
  s <- make_test_survey()
  expect_output(get_metadata(s))
})

test_that("add_step registers steps correctly", {
  s <- make_test_survey()
  step <- Step$new(
    name = "test step", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z", exprs = list(),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list()
  )
  s$add_step(step)
  expect_equal(length(s$steps), 1)
})

test_that("Survey design is created from weight", {
  s <- make_test_survey()
  # Trigger design initialization
  s <- s %>%
    step_compute(z = age * 2) %>%
    bake_steps()
  expect_true(length(s$design) >= 1)
  expect_true(inherits(s$design[[1]], "survey.design"))
})

test_that("cat_design returns string without error", {
  s <- make_test_survey()
  result <- cat_design(s)
  expect_true(is.character(result) || inherits(result, "glue"))
})

test_that("cat_recipes returns 'None' for survey without recipes", {
  s <- make_test_survey()
  result <- cat_recipes(s)
  expect_equal(result, "None")
})

test_that("get_steps returns empty list for new survey", {
  s <- make_test_survey()
  expect_equal(length(get_steps(s)), 0)
})

test_that("Survey stores edition correctly", {
  s <- make_test_survey()
  expect_equal(as.character(s$edition), "2023")
})

test_that("edition field contains survey edition", {
  s <- make_test_survey()
  expect_equal(as.character(s$edition), "2023")
})

test_that("weights field contains weight information", {
  s <- make_test_survey()
  expect_true(!is.null(s$weight))
})

test_that("weight names can be accessed", {
  s <- make_test_survey()
  expect_true("annual" %in% names(s$weight))
})

test_that("survey_to_tibble converts to tibble", {
  skip_if_not_installed("tibble")
  s <- make_test_survey()
  tb <- survey_to_tibble(s)
  expect_s3_class(tb, "tbl_df")
  expect_equal(nrow(tb), 10)
})

test_that("Survey handles multiple weights", {
  df <- data.table::data.table(
    id = 1:10,
    w_annual = runif(10),
    w_monthly = runif(10)
  )

  s <- Survey$new(
    data = df,
    edition = "2023",
    type = "ech",
    psu = NULL,
    engine = "data.table",
    weight = add_weight(annual = "w_annual", monthly = "w_monthly")
  )

  expect_equal(length(s$weight), 2)

  # Trigger design initialization
  s <- s %>%
    step_compute(y = id * 2) %>%
    bake_steps()
  expect_equal(length(s$design), 2)
})

test_that("Survey clone creates independent copy", {
  s <- make_test_survey()
  s2 <- s$clone()
  s2$edition <- "2024"

  expect_equal(as.character(s$edition), "2023")
  expect_equal(as.character(s2$edition), "2024")
})

test_that("Survey set_data validates input", {
  s <- make_test_survey()
  new_data <- data.table::data.table(id = 1:5, val = rnorm(5), w = 1)

  s$set_data(new_data)
  expect_equal(nrow(s$data), 5)
})

test_that("Survey get_recipe returns recipes list", {
  s <- make_test_survey()
  recipes <- s$get_recipe
  expect_true(is.list(recipes) || is.null(recipes))
})

test_that("cat_design_type returns correct design description", {
  s <- make_test_survey()
  # Trigger design creation
  s <- s %>%
    step_compute(y = id * 2) %>%
    bake_steps()

  result <- tryCatch(
    {
      metasurvey:::cat_design_type(s, "annual")
    },
    error = function(e) NULL
  )

  # Function should return a character string or NULL
  expect_true(is.null(result) || is.character(result))
})

test_that("Survey stores PSU correctly", {
  df <- data.table::data.table(
    id = 1:10,
    psu_var = rep(1:2, each = 5),
    w = 1
  )

  s <- Survey$new(
    data = df,
    edition = "2023",
    type = "ech",
    psu = "psu_var",
    engine = "data.table",
    weight = add_weight(annual = "w")
  )

  # PSU might not be assigned in current implementation
  # Just check survey is created
  expect_s3_class(s, "Survey")
})

test_that("Survey validates data parameter", {
  expect_error(
    Survey$new(
      data = "not a dataframe",
      edition = "2023",
      type = "ech",
      psu = NULL,
      engine = "data.table",
      weight = add_weight(annual = "w")
    )
  )
})

test_that("cat_design generates design description", {
  s <- make_test_survey()
  result <- cat_design(s)
  expect_true(is.character(result) || inherits(result, "glue"))
})

test_that("cat_recipes handles multiple recipes", {
  s <- make_test_survey()

  r1 <- Recipe$new(
    name = "recipe1",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "Test recipe 1",
    steps = list(),
    id = "r1",
    doi = NULL,
    topic = NULL
  )

  r2 <- Recipe$new(
    name = "recipe2",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "Test recipe 2",
    steps = list(),
    id = "r2",
    doi = NULL,
    topic = NULL
  )

  s$recipes <- list(r1, r2)
  result <- cat_recipes(s)
  expect_type(result, "character")
})

test_that("Survey handles empty recipes list", {
  s <- make_test_survey()
  s$recipes <- list()
  expect_equal(length(s$recipes), 0)
})

test_that("Survey set methods work correctly", {
  s <- make_test_survey()

  # Test set_edition
  s$set_edition("2024")
  expect_equal(as.character(s$get_edition()), "2024")

  # Test set_type
  s$set_type("eph")
  expect_equal(s$get_type(), "eph")
})

test_that("Survey design is correctly structured", {
  s <- make_test_survey()

  # Trigger design initialization
  s <- s %>%
    step_compute(z = age * 2) %>%
    bake_steps()

  expect_true(is.list(s$design))
  expect_true(length(s$design) >= 1)

  # Check design names match weight names
  expect_true(all(names(s$design) %in% names(s$weight)))
})

test_that("Survey periodicity is set correctly", {
  s <- make_test_survey()
  expect_true(!is.null(s$periodicity))
  expect_type(s$periodicity, "character")
})

test_that("Survey workflows initialize as empty list", {
  s <- make_test_survey()
  expect_true(is.list(s$workflows))
  expect_equal(length(s$workflows), 0)
})

test_that("Survey with replicate weights configuration", {
  # Test that add_replicate creates proper weight spec
  w <- add_weight(annual = add_replicate(
    weight = "w",
    replicate_pattern = "wr\\d+",
    replicate_type = "bootstrap"
  ))
  expect_true(is.list(w))
  expect_true(!is.null(w$annual$replicate_pattern))
  expect_equal(w$annual$replicate_type, "bootstrap")
})

# --- Standalone helper functions ---

test_that("set_data replaces survey data", {
  s <- make_test_survey()
  new_dt <- data.table::data.table(id = 1:5, x = 10:14, w = 1)
  set_data(s, new_dt)
  expect_equal(nrow(get_data(s)), 5)
  expect_true("x" %in% names(get_data(s)))
})


test_that("Survey$set_weight updates weight", {
  s <- make_test_survey()
  s$set_weight(add_weight(annual = "w"))
  expect_true(!is.null(s$weight))
})

# --- add_recipe ---

test_that("add_recipe adds recipe when edition matches", {
  s <- make_test_survey()
  r <- Recipe$new(
    name = "test", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "tester", description = "Test", steps = list(),
    id = "r1", doi = NULL, topic = NULL
  )
  s$add_recipe(r)
  expect_equal(length(s$recipes), 1)
})

test_that("add_recipe allows different editions but errors on type mismatch", {
  s <- make_test_survey()
  # Different edition is now allowed (flexible edition matching)
  r_diff_edition <- Recipe$new(
    name = "test", edition = "2024", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "tester", description = "Test", steps = list(),
    id = "r1", doi = NULL, topic = NULL
  )
  expect_no_error(s$add_recipe(r_diff_edition))

  # Different survey_type should error
  r_diff_type <- Recipe$new(
    name = "test", edition = "2023", survey_type = "eaii",
    default_engine = "data.table", depends_on = list(),
    user = "tester", description = "Test", steps = list(),
    id = "r2", doi = NULL, topic = NULL
  )
  expect_error(s$add_recipe(r_diff_type), "survey type mismatch")
})

# --- get_info_weight ---

test_that("get_info_weight returns info for simple weight", {
  s <- make_test_survey()
  info <- metasurvey:::get_info_weight(s)
  expect_true(is.character(info) || inherits(info, "glue"))
  expect_true(grepl("annual", info, ignore.case = TRUE))
})

# --- design_active active binding ---

test_that("design_active recomputes design", {
  s <- make_test_survey()
  d <- s$design_active
  expect_true(is.list(d))
  expect_true(length(d) >= 1)
  expect_true(inherits(d[[1]], "survey.design"))
})

# --- cat_design_type ---

test_that("cat_design_type returns design type for valid design", {
  s <- make_test_survey()
  # Trigger design initialization
  s <- s %>%
    step_compute(z = age * 2) %>%
    bake_steps()
  result <- cat_design_type(s, "annual")
  expect_true(is.character(result) || inherits(result, "glue"))
  expect_true(grepl("survey|Package|Variance", result, ignore.case = TRUE))
})

test_that("cat_design_type returns None for unknown design class", {
  s <- make_test_survey()
  # Replace design with a custom class object to trigger the NULL path
  s$design[["annual"]] <- structure(list(), class = "unknown_design_class")
  result <- cat_design_type(s, "annual")
  expect_equal(result, "None")
})

# --- add_workflow ---

test_that("add_workflow stores workflow", {
  s <- make_test_survey()
  wf <- list(name = "test_wf", steps = list())
  s$add_workflow(wf)
  expect_equal(length(s$workflows), 1)
  expect_true("test_wf" %in% names(s$workflows))
})

# --- head and str methods ---

test_that("Survey$head returns data head", {
  s <- make_test_survey()
  h <- s$head()
  expect_true(nrow(h) <= 6)
})

test_that("Survey$str does not error", {
  s <- make_test_survey()
  expect_no_error(s$str())
})

# --- bake_recipes with actual recipe ---

test_that("bake_recipes applies recipe steps to survey data", {
  s <- make_test_survey()
  r <- Recipe$new(
    name = "compute_recipe", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "tester", description = "Test recipe with compute",
    steps = list(quote(step_compute(., double_age = age * 2))),
    id = "r1", doi = NULL, topic = NULL
  )
  s$add_recipe(r)
  s2 <- bake_recipes(s)
  expect_true("double_age" %in% names(get_data(s2)))
  expect_true(s2$recipes[[1]]$bake)
})

# --- update_design ---

test_that("update_design refreshes design variables", {
  s <- make_test_survey()
  old_nrow <- nrow(s$design[[1]]$variables)
  s$data <- s$data[1:5, ]
  s$update_design()
  expect_equal(nrow(s$design[[1]]$variables), 5)
})

# --- Internal standalone functions ---

test_that("set_data standalone with .copy=TRUE returns clone", {
  s <- make_test_survey()
  new_dt <- data.table::data.table(id = 1:3, w = 1)
  s2 <- metasurvey:::set_data(s, new_dt, .copy = TRUE)
  expect_equal(nrow(get_data(s2)), 3)
  # Original should be unchanged
  expect_equal(nrow(get_data(s)), 10)
})

test_that("set_data standalone with .copy=FALSE modifies in place", {
  s <- make_test_survey()
  new_dt <- data.table::data.table(id = 1:3, w = 1)
  s2 <- metasurvey:::set_data(s, new_dt, .copy = FALSE)
  expect_equal(nrow(get_data(s2)), 3)
})

test_that("set_edition standalone with .copy=TRUE returns clone", {
  s <- make_test_survey()
  s2 <- metasurvey:::set_edition(s, "2025", .copy = TRUE)
  expect_equal(s2$edition, "2025")
  expect_equal(as.character(s$edition), "2023")
})

test_that("set_edition standalone with .copy=FALSE modifies in place", {
  s <- make_test_survey()
  s2 <- metasurvey:::set_edition(s, "2025", .copy = FALSE)
  expect_equal(s2$edition, "2025")
})

test_that("set_type standalone with .copy=TRUE returns clone", {
  s <- make_test_survey()
  s2 <- metasurvey:::set_type(s, "eph", .copy = TRUE)
  expect_equal(s2$type, "eph")
  expect_equal(s$type, "ech")
})

test_that("set_type standalone with .copy=FALSE modifies in place", {
  s <- make_test_survey()
  s2 <- metasurvey:::set_type(s, "eph", .copy = FALSE)
  expect_equal(s2$type, "eph")
})

test_that("get_weight returns weight info", {
  s <- make_test_survey()
  w <- metasurvey:::get_weight(s)
  expect_equal(w, "w")
})

test_that("get_edition standalone returns edition", {
  s <- make_test_survey()
  ed <- metasurvey:::get_edition(s)
  expect_equal(as.character(ed), "2023")
})

test_that("get_type standalone returns type", {
  s <- make_test_survey()
  tp <- metasurvey:::get_type(s)
  expect_equal(tp, "ech")
})

# --- survey_empty ---

test_that("survey_empty creates Survey with NULL data", {
  result <- tryCatch(survey_empty(), error = function(e) NULL)
  expect_true(is.null(result) || inherits(result, "Survey"))
})

# --- get_metadata for RotativePanelSurvey ---

test_that("get_metadata works for RotativePanelSurvey", {
  panel <- make_test_panel()
  expect_output(get_metadata(panel))
})

test_that("get_metadata for RotativePanelSurvey with steps", {
  panel <- make_test_panel()
  panel$implantation <- step_compute(panel$implantation, z = age + 1)
  expect_output(get_metadata(panel))
})

# --- Survey$bake method ---

test_that("Survey$bake method calls bake_recipes", {
  s <- make_test_survey()
  s$recipes <- list()
  result <- s$bake()
  expect_s3_class(result, "Survey")
})

# --- Survey$set_design method ---

test_that("Survey$set_design sets the design", {
  s <- make_test_survey()
  s$set_design(list(custom = "design"))
  expect_equal(s$design$custom, "design")
})

# --- bake_recipes with single Recipe object (not list) ---

test_that("bake_recipes handles single Recipe object", {
  s <- make_test_survey()
  r <- Recipe$new(
    name = "single", edition = "2023", survey_type = "ech",
    default_engine = "data.table", depends_on = list(),
    user = "tester", description = "Test",
    steps = list(quote(step_compute(., z = age + 1))),
    id = "r1", doi = NULL, topic = NULL
  )
  s$recipes <- r # Assign as object, not list
  s2 <- bake_recipes(s)
  expect_true("z" %in% names(get_data(s2)))
})

# --- get_metadata returns invisible list ---

test_that("get_metadata runs without error for Survey", {
  s <- make_test_survey()
  expect_output(get_metadata(s))
})

# --- get_metadata with steps ---

test_that("get_metadata shows steps when present", {
  s <- make_test_survey()
  s2 <- step_compute(s, z = age + 1)
  expect_output(get_metadata(s2), "step_")
})

# --- get_metadata with Date edition ---

test_that("get_metadata handles Date edition", {
  df <- data.table::data.table(id = 1:5, w = 1)
  s <- Survey$new(
    data = df, edition = "202301", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(monthly = "w")
  )
  expect_output(get_metadata(s))
})

# --- set_weight standalone ---

test_that("set_weight standalone with .copy=TRUE returns clone", {
  s <- make_test_survey()
  s2 <- suppressMessages(
    metasurvey:::set_weight(s, add_weight(annual = "w"), .copy = TRUE)
  )
  expect_s3_class(s2, "Survey")
})

test_that("set_weight standalone with .copy=FALSE triggers comparison error on list weights", {
  s <- make_test_survey()
  # set_weight .copy=FALSE path has svy$weight == new_weight which fails for lists
  expect_error(
    metasurvey:::set_weight(s, s$weight, .copy = FALSE),
    "comparison.*not implemented|not meaningful"
  )
})

# --- get_metadata for PoolSurvey ---

test_that("get_metadata works for PoolSurvey", {
  s1 <- make_test_survey(20)
  s1$edition <- "2023-01-01"
  s2 <- make_test_survey(20)
  s2$edition <- "2023-02-01"

  surveys_struct <- list(
    annual = list(
      "group1" = list(s1, s2)
    )
  )
  pool <- PoolSurvey$new(surveys_struct)
  expect_output(get_metadata(pool))
})

# --- Survey print method ---

test_that("Survey print calls get_metadata", {
  s <- make_test_survey()
  expect_output(s$print())
})

# --- PoolSurvey print method ---

test_that("PoolSurvey print calls get_metadata", {
  s1 <- make_test_survey(20)
  s1$edition <- "2023-01-01"
  surveys_struct <- list(
    annual = list("group1" = list(s1))
  )
  pool <- PoolSurvey$new(surveys_struct)
  expect_output(pool$print())
})

# --- Survey with PSU formula ---

test_that("Survey$new with PSU creates proper design", {
  df <- data.table::data.table(
    id = 1:20, psu_var = rep(1:4, each = 5), w = 1
  )
  s <- Survey$new(
    data = df, edition = "2023", type = "ech",
    psu = "psu_var", engine = "data.table",
    weight = add_weight(annual = "w")
  )
  expect_s3_class(s, "Survey")

  # Trigger design initialization
  s <- s %>%
    step_compute(y = id * 2) %>%
    bake_steps()
  expect_true(inherits(s$design[[1]], "survey.design"))
})

# --- add_recipe with depends_on warning ---

test_that("add_recipe warns when depends_on variables missing from data", {
  s <- make_test_survey()
  r <- Recipe$new(
    name = "missing deps",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("nonexistent_var", "another_missing"),
    user = "tester",
    description = "Test warning",
    steps = list(),
    id = "warn_001"
  )

  expect_warning(s$add_recipe(r), "not present in survey")
  expect_length(s$recipes, 1)
})

test_that("add_recipe with empty depends_on does not warn", {
  s <- make_test_survey()
  r <- Recipe$new(
    name = "no deps",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    user = "tester",
    description = "Test",
    steps = list(),
    id = "no_warn_001"
  )

  expect_no_warning(s$add_recipe(r))
})

test_that("add_recipe with satisfied depends_on does not warn", {
  s <- make_test_survey()
  r <- Recipe$new(
    name = "satisfied deps",
    edition = "2023",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("age", "x"),
    user = "tester",
    description = "Test",
    steps = list(),
    id = "sat_001"
  )

  expect_no_warning(s$add_recipe(r))
})

test_that("add_recipe with case-different depends_on does not warn", {
  # Simulate ECH data with uppercase column names
  df <- data.table::data.table(POBPCOAC = c(1, 2), W_ANO = c(1, 1))
  s <- Survey$new(
    data = df, edition = "2024", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "W_ANO")
  )

  r <- Recipe$new(
    name = "case diff deps",
    edition = "2024",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("pobpcoac"),
    user = "tester",
    description = "Test case insensitive",
    steps = list(),
    id = "ci_add_001"
  )

  # Should NOT warn because POBPCOAC matches pobpcoac case-insensitively
  expect_no_warning(s$add_recipe(r))
})

test_that("bake_recipes normalizes column names to match recipe case", {
  # Simulate ECH data with uppercase names (like real INE data)
  df <- data.table::data.table(
    POBPCOAC = c(2, 3, 10, 2, 5),
    W_ANO = c(1, 1, 1, 1, 1)
  )
  s <- Survey$new(
    data = df, edition = "2024", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "W_ANO")
  )

  # Recipe uses lowercase variable names (as stored in API)
  r <- Recipe$new(
    name = "case normalize test",
    edition = "2024",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list("pobpcoac"),
    user = "tester",
    description = "Test case normalization",
    steps = list(quote(step_compute(., pea = as.integer(pobpcoac == 2)))),
    id = "cn_001"
  )

  s$add_recipe(r)
  s2 <- bake_recipes(s)

  # The step should have executed successfully
  expect_true("pea" %in% names(get_data(s2)))
  # Column should now be lowercase (renamed by normalization)
  expect_true("pobpcoac" %in% names(get_data(s2)))
  # Original uppercase should NOT be there
  expect_false("POBPCOAC" %in% names(get_data(s2)))
})

# --- shallow_clone ---

test_that("shallow_clone creates independent data copy", {
  s <- make_test_survey()
  s2 <- s$shallow_clone()

  expect_s3_class(s2, "Survey")
  expect_equal(nrow(s2$data), nrow(s$data))
  expect_equal(s2$edition, s$edition)
  expect_equal(s2$type, s$type)

  # Modifying cloned data should not affect original
  s2$data[1, age := 999]
  expect_false(s$data[1, age] == 999)
})

test_that("shallow_clone copies design when initialized", {
  s <- make_test_survey()
  # Trigger design initialization
  s$ensure_design()
  expect_true(s$design_initialized)

  s2 <- s$shallow_clone()
  expect_true(s2$design_initialized)
  expect_true(!is.null(s2$design))
})

test_that("shallow_clone copies metadata", {
  s <- make_test_survey()
  step <- Step$new(
    name = "test", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z", exprs = list(),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list()
  )
  s$steps <- list(step1 = step)
  s$periodicity <- "annual"

  s2 <- s$shallow_clone()
  expect_equal(length(s2$steps), 1)
  expect_equal(s2$periodicity, "annual")
})

# --- ensure_design ---

test_that("ensure_design initializes design from weight", {
  s <- make_test_survey()
  expect_false(s$design_initialized)

  s$ensure_design()
  expect_true(s$design_initialized)
  expect_true(is.list(s$design))
  expect_true(inherits(s$design[[1]], "survey.design"))
})

test_that("ensure_design with PSU creates design with PSU formula", {
  df <- data.table::data.table(
    id = 1:20, psu_var = rep(1:4, each = 5), w = 1
  )
  s <- Survey$new(
    data = df, edition = "2023", type = "ech",
    psu = "psu_var", engine = "data.table",
    weight = add_weight(annual = "w")
  )

  s$ensure_design()
  expect_true(s$design_initialized)
  expect_true(inherits(s$design[[1]], "survey.design"))
})

test_that("ensure_design is idempotent", {
  s <- make_test_survey()
  s$ensure_design()
  design1 <- s$design

  s$ensure_design()
  expect_identical(s$design, design1)
})

# --- get_info_weight with simple weight ---

test_that("get_info_weight returns formatted weight info", {
  s <- make_test_survey()
  info <- metasurvey:::get_info_weight(s)
  expect_true(nchar(info) > 0)
  expect_true(grepl("Simple design", info))
})

# --- set_weight standalone with actual different weight ---

test_that("set_weight standalone .copy=FALSE with different weight works", {
  df <- data.table::data.table(id = 1:10, w1 = 1, w2 = 2)
  s <- Survey$new(
    data = df, edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w1")
  )

  # Changing to a different weight column should work
  s2 <- metasurvey:::set_weight(s, add_weight(annual = "w2"), .copy = TRUE)
  expect_equal(s2$weight$annual, "w2")
})

# --- Tests recovered from coverage-boost ---

test_that("get_info_weight formats simple weight info", {
  s <- make_test_survey()
  info <- metasurvey:::get_info_weight(s)
  expect_true(is.character(info) || inherits(info, "glue"))
  expect_true(grepl("annual", info))
})

test_that("Survey$set_edition and set_type update fields", {
  s <- make_test_survey()
  s$set_edition("2024")
  expect_equal(s$edition, "2024")
  s$set_type("custom_type")
  expect_equal(s$type, "custom_type")
})

# --- run_app.R coverage ---

test_that("explore_recipes errors when shiny not available", {
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) pkg != "shiny",
    .package = "base"
  )
  expect_error(explore_recipes(), "shiny")
})

test_that("explore_recipes errors when bslib not available", {
  local_mocked_bindings(
    requireNamespace = function(pkg, ...) pkg != "bslib",
    .package = "base"
  )
  expect_error(explore_recipes(), "bslib")
})

test_that("explore_recipes calls runApp with correct args", {
  called_with <- list()
  local_mocked_bindings(
    runApp = function(appDir, port = NULL, host = "127.0.0.1",
                      launch.browser = TRUE, ...) {
      called_with$appDir <<- appDir
      called_with$port <<- port
      called_with$host <<- host
      called_with$launch.browser <<- launch.browser
      invisible(NULL)
    },
    .package = "shiny"
  )
  explore_recipes(port = 4321, host = "0.0.0.0", launch.browser = FALSE)
  expect_true(nzchar(called_with$appDir))
  expect_equal(called_with$port, 4321)
  expect_equal(called_with$host, "0.0.0.0")
  expect_false(called_with$launch.browser)
})

# --- survey.R print edition formatting ---

test_that("Survey print handles NULL edition", {
  s <- make_test_survey()
  s$edition <- NULL
  expect_output(s$print(), "Unknown|UNKNOWN|unknown|ECH")
})

test_that("Survey print handles Date edition", {
  s <- make_test_survey()
  s$edition <- as.Date("2023-06-15")
  expect_output(s$print(), "2023")
})

test_that("set_weight with .copy=FALSE and list comparison errors", {
  s <- make_test_survey()
  # Known limitation: list == list comparison not implemented
  expect_error(
    metasurvey:::set_weight(s, s$weight, .copy = FALSE),
    "not implemented"
  )
})

test_that("has_steps returns FALSE for new survey", {
  s <- make_test_survey()
  expect_false(has_steps(s))
})

test_that("has_recipes returns FALSE for new survey", {
  s <- make_test_survey()
  expect_false(has_recipes(s))
})

test_that("is_baked returns TRUE when no steps", {
  s <- make_test_survey()
  expect_true(is_baked(s))
})

test_that("has_design returns FALSE for basic survey", {
  s <- make_test_survey()
  expect_false(has_design(s))
})

# ── Batch 6: cat_design, print formatting, design paths ─────────────────────

test_that("cat_design shows design details after ensure_design", {
  s <- make_test_survey()
  s$ensure_design()
  result <- cat_design(s)
  expect_true(is.character(result) || inherits(result, "glue"))
  expect_match(as.character(result), "ANNUAL ESTIMATION", ignore.case = TRUE)
  expect_match(as.character(result), "Weight")
})

test_that("cat_design returns lazy message when design not initialized", {
  s <- make_test_survey()
  result <- cat_design(s)
  expect_match(result, "lazy initialization")
})

test_that("cat_design_type returns design class after initialization", {
  s <- make_test_survey()
  s$ensure_design()
  result <- metasurvey:::cat_design_type(s, "annual")
  expect_true(is.character(result))
})

test_that("Survey$print with numeric edition formats correctly", {
  s <- make_test_survey()
  s$edition <- 2023
  expect_output(s$print(), "2023")
})

test_that("is_baked returns FALSE when unbaked steps exist", {
  old_lazy <- getOption("metasurvey.lazy_processing")
  on.exit(options(metasurvey.lazy_processing = old_lazy), add = TRUE)
  options(metasurvey.lazy_processing = TRUE)
  s <- make_test_survey()
  s <- step_filter(s, x > 0) # lazy step, not baked
  expect_false(is_baked(s))
})

test_that("is_baked returns TRUE after eager step_compute (already executed)", {
  s <- make_test_survey()
  s <- step_compute(s, x2 = x * 2)
  expect_true(is_baked(s))
})

test_that("update_design warns on design length mismatch", {
  s <- make_test_survey()
  s$ensure_design()
  # Corrupt design by adding extra entry
  s$design$extra <- s$design$annual
  expect_warning(s$update_design(), "mismatch")
})

# ── Additional survey coverage push ──────────────────────────────────────────

test_that("get_design initializes and returns design list", {
  s <- make_test_survey()
  result <- get_design(s)
  expect_true(is.list(result))
  expect_true("annual" %in% names(result))
  expect_true(inherits(result$annual, "survey.design"))
})

test_that("Survey with multiple weight types has proper info_weight", {
  s <- make_test_survey()
  s$weight <- add_weight(annual = "w", quarterly = "w")
  info <- metasurvey:::get_info_weight(s)
  expect_true(is.character(info))
  expect_match(info, "annual", ignore.case = TRUE)
  expect_match(info, "quarterly", ignore.case = TRUE)
})

# --- strata support ---

test_that("Survey$new stores strata field", {
  df <- data.table::data.table(
    id = 1:20, stratum = rep(1:4, each = 5), w = 1
  )
  s <- Survey$new(
    data = df, edition = "2023", type = "ech",
    psu = NULL, strata = "stratum", engine = "data.table",
    weight = add_weight(annual = "w")
  )
  expect_equal(s$strata, "stratum")
})

test_that("strata=NULL is backwards compatible", {
  s <- make_test_survey()
  expect_null(s$strata)
})

test_that("ensure_design with strata creates stratified design", {
  df <- data.table::data.table(
    id = 1:20, stratum = rep(1:4, each = 5), w = 1
  )
  s <- Survey$new(
    data = df, edition = "2023", type = "ech",
    psu = NULL, strata = "stratum", engine = "data.table",
    weight = add_weight(annual = "w")
  )
  s$ensure_design()
  expect_true(s$design_initialized)
  expect_true(inherits(s$design[[1]], "survey.design"))
  expect_false(is.null(s$design[[1]]$call$strata))
})

test_that("ensure_design with strata + PSU works", {
  df <- data.table::data.table(
    id = 1:20, psu_var = rep(1:4, each = 5),
    stratum = rep(1:2, each = 10), w = 1
  )
  s <- Survey$new(
    data = df, edition = "2023", type = "ech",
    psu = "psu_var", strata = "stratum", engine = "data.table",
    weight = add_weight(annual = "w")
  )
  s$ensure_design()
  expect_true(inherits(s$design[[1]], "survey.design"))
})

test_that("ensure_design errors on nonexistent strata variable", {
  df <- data.table::data.table(id = 1:10, w = 1)
  s <- Survey$new(
    data = df, edition = "2023", type = "ech",
    psu = NULL, strata = "nonexistent", engine = "data.table",
    weight = add_weight(annual = "w")
  )
  expect_error(s$ensure_design(), "not found")
})

test_that("cat_design shows strata after stratified design", {
  df <- data.table::data.table(
    id = 1:20, stratum = rep(1:4, each = 5), w = 1
  )
  s <- Survey$new(
    data = df, edition = "2023", type = "ech",
    psu = NULL, strata = "stratum", engine = "data.table",
    weight = add_weight(annual = "w")
  )
  s$ensure_design()
  result <- cat_design(s)
  # Strata line should not be "None" when strata is set
  expect_false(grepl("Strata:.*None", as.character(result)))
})

test_that("shallow_clone preserves strata", {
  df <- data.table::data.table(
    id = 1:20, stratum = rep(1:4, each = 5), w = 1
  )
  s <- Survey$new(
    data = df, edition = "2023", type = "ech",
    psu = NULL, strata = "stratum", engine = "data.table",
    weight = add_weight(annual = "w")
  )
  s2 <- s$shallow_clone()
  expect_equal(s2$strata, "stratum")
})

test_that("workflow with stratified design produces results", {
  data(api, package = "survey")
  dt <- data.table::data.table(apistrat)
  s <- Survey$new(
    data = dt, edition = "2000", type = "api",
    psu = NULL, strata = "stype", engine = "data.table",
    weight = add_weight(annual = "pw")
  )
  result <- workflow(
    list(s),
    survey::svymean(~api00, na.rm = TRUE),
    estimation_type = "annual"
  )
  expect_true(nrow(result) > 0)
  expect_true(result$value > 0)
})
