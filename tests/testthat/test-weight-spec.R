# TDD: Tests for weight_spec reproducibility system

# --- .serialize_weight_spec ---

test_that(".serialize_weight_spec handles simple weights", {
  w <- list(annual = "W_ANO", monthly = "pesomes")
  spec <- .serialize_weight_spec(w, "2023")

  expect_equal(spec$annual$type, "simple")
  expect_equal(spec$annual$variable, "W_ANO")
  expect_equal(spec$monthly$type, "simple")
  expect_equal(spec$monthly$variable, "pesomes")
})

test_that(".serialize_weight_spec handles replicate weights", {
  w <- list(
    monthly = list(
      weight = "W",
      replicate_pattern = "wr[0-9]+",
      replicate_path = "/tmp/Pesos replicados Bootstrap mensuales enero_junio 2023.rar",
      replicate_id = c("ID" = "ID"),
      replicate_type = "bootstrap"
    )
  )
  spec <- .serialize_weight_spec(w, "2023")

  expect_equal(spec$monthly$type, "replicate")
  expect_equal(spec$monthly$variable, "W")
  expect_equal(spec$monthly$replicate_pattern, "wr[0-9]+")
  expect_equal(spec$monthly$replicate_type, "bootstrap")
  expect_equal(spec$monthly$replicate_source$provider, "anda")
  expect_equal(spec$monthly$replicate_source$resource, "bootstrap_monthly")
  expect_equal(spec$monthly$replicate_source$edition, "2023")
  expect_equal(spec$monthly$replicate_id$survey_key, "ID")
  expect_equal(spec$monthly$replicate_id$replicate_key, "ID")
})

test_that(".serialize_weight_spec handles mixed simple + replicate", {
  w <- list(
    annual = "W_ANO",
    quarterly = "W_TRI",
    monthly = list(
      weight = "W",
      replicate_pattern = "wr[0-9]+",
      replicate_path = "/data/bootstrap_annual_2023.xlsx",
      replicate_id = c("numero" = "ID_HOGAR"),
      replicate_type = "bootstrap"
    )
  )
  spec <- .serialize_weight_spec(w, "2023")

  expect_equal(spec$annual$type, "simple")
  expect_equal(spec$quarterly$type, "simple")
  expect_equal(spec$monthly$type, "replicate")
  expect_equal(length(spec), 3)
})

# --- .path_to_source ---

test_that(".path_to_source detects ANDA bootstrap monthly", {
  src <- .path_to_source(
    "/tmp/Pesos replicados Bootstrap mensuales enero_junio 2023.rar",
    "2023"
  )
  expect_equal(src$provider, "anda")
  expect_equal(src$resource, "bootstrap_monthly")
  expect_equal(src$edition, "2023")
})

test_that(".path_to_source detects ANDA bootstrap annual", {
  src <- .path_to_source("/data/pesos replicados Bootstrap anual 2023.xlsx", "2023")
  expect_equal(src$provider, "anda")
  expect_equal(src$resource, "bootstrap_annual")
})

test_that(".path_to_source detects ANDA bootstrap quarterly", {
  src <- .path_to_source("/data/Pesos replicados Bootstrap trimestrales 2023.rar", "2023")
  expect_equal(src$provider, "anda")
  expect_equal(src$resource, "bootstrap_quarterly")
})

test_that(".path_to_source detects ANDA bootstrap semestral", {
  src <- .path_to_source("/data/Pesos replicados Bootstrap semestrales 2023.rar", "2023")
  expect_equal(src$provider, "anda")
  expect_equal(src$resource, "bootstrap_semestral")
})

test_that(".path_to_source falls back to local for unknown paths", {
  src <- .path_to_source("/data/my_custom_weights.csv", "2023")
  expect_equal(src$provider, "local")
  expect_true(!is.null(src$path_hint))
})

test_that(".path_to_source handles NULL path", {
  expect_null(.path_to_source(NULL, "2023"))
})

# --- RecipeWorkflow weight_spec field ---

test_that("RecipeWorkflow accepts weight_spec in constructor", {
  ws <- list(annual = list(type = "simple", variable = "W_ANO"))
  wf <- RecipeWorkflow$new(name = "Test WF", weight_spec = ws)

  expect_false(is.null(wf$weight_spec))
  expect_equal(wf$weight_spec$annual$variable, "W_ANO")
})

test_that("RecipeWorkflow weight_spec defaults to NULL", {
  wf <- RecipeWorkflow$new(name = "Test WF")
  expect_null(wf$weight_spec)
})

test_that("RecipeWorkflow$to_list() includes weight_spec", {
  ws <- list(
    annual = list(type = "simple", variable = "W_ANO"),
    monthly = list(
      type = "replicate", variable = "W",
      replicate_pattern = "wr[0-9]+",
      replicate_source = list(provider = "anda", resource = "bootstrap_monthly", edition = "2023"),
      replicate_id = list(survey_key = "ID", replicate_key = "ID"),
      replicate_type = "bootstrap"
    )
  )
  wf <- RecipeWorkflow$new(name = "Test WF", weight_spec = ws)
  lst <- wf$to_list()

  expect_true("weight_spec" %in% names(lst))
  expect_equal(lst$weight_spec$annual$variable, "W_ANO")
  expect_equal(lst$weight_spec$monthly$replicate_source$provider, "anda")
})

test_that("RecipeWorkflow$to_list() with NULL weight_spec includes it as NULL", {
  wf <- RecipeWorkflow$new(name = "Test WF")
  lst <- wf$to_list()
  expect_true("weight_spec" %in% names(lst))
  expect_null(lst$weight_spec)
})

# --- Round-trip: to_list / workflow_from_list ---

test_that("weight_spec round-trips through to_list/workflow_from_list", {
  ws <- list(
    annual = list(type = "simple", variable = "W_ANO"),
    quarterly = list(type = "simple", variable = "W_TRI"),
    monthly = list(
      type = "replicate", variable = "W",
      replicate_pattern = "wr[0-9]+",
      replicate_source = list(provider = "anda", resource = "bootstrap_monthly", edition = "2023"),
      replicate_id = list(survey_key = "ID", replicate_key = "ID"),
      replicate_type = "bootstrap"
    )
  )
  wf <- RecipeWorkflow$new(name = "Round Trip", weight_spec = ws)
  lst <- wf$to_list()
  wf2 <- workflow_from_list(lst)

  expect_equal(wf2$weight_spec$annual$type, "simple")
  expect_equal(wf2$weight_spec$annual$variable, "W_ANO")
  expect_equal(wf2$weight_spec$quarterly$variable, "W_TRI")
  expect_equal(wf2$weight_spec$monthly$type, "replicate")
  expect_equal(wf2$weight_spec$monthly$replicate_source$provider, "anda")
  expect_equal(wf2$weight_spec$monthly$replicate_source$resource, "bootstrap_monthly")
})

test_that("workflow_from_list handles missing weight_spec (backward compat)", {
  lst <- list(name = "Old WF", survey_type = "ech", edition = "2020")
  wf <- workflow_from_list(lst)
  expect_null(wf$weight_spec)
})

# --- .capture_workflow extracts weight_spec ---

test_that(".capture_workflow extracts weight_spec from survey", {
  dt <- data.table::data.table(x = 1:10, w = rep(1, 10))
  svy <- Survey$new(
    data = dt, edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )

  rec <- recipe(
    name = "R1", user = "Test", svy = svy,
    description = "Test", steps = list()
  )
  svy <- add_recipe(svy, rec)

  .calls <- list(quote(survey::svymean(~x, na.rm = TRUE)))
  wf <- .capture_workflow(list(svy), .calls, "annual")

  expect_false(is.null(wf))
  expect_false(is.null(wf$weight_spec))
  expect_equal(wf$weight_spec$annual$type, "simple")
  expect_equal(wf$weight_spec$annual$variable, "w")
})

test_that(".capture_workflow returns NULL weight_spec when no weights", {
  dt <- data.table::data.table(x = 1:10)
  svy <- Survey$new(
    data = dt, edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = list()
  )

  rec <- recipe(
    name = "R2", user = "Test", svy = svy,
    description = "Test", steps = list()
  )
  svy <- add_recipe(svy, rec)

  .calls <- list(quote(survey::svymean(~x, na.rm = TRUE)))
  wf <- .capture_workflow(list(svy), .calls, "annual")

  expect_false(is.null(wf))
  expect_null(wf$weight_spec)
})

# --- resolve_weight_spec ---

test_that("resolve_weight_spec resolves simple weights", {
  ws <- list(
    annual = list(type = "simple", variable = "W_ANO"),
    quarterly = list(type = "simple", variable = "W_TRI")
  )
  resolved <- resolve_weight_spec(ws)

  expect_equal(resolved$annual, "W_ANO")
  expect_equal(resolved$quarterly, "W_TRI")
})

test_that("resolve_weight_spec returns NULL for NULL input", {
  expect_null(resolve_weight_spec(NULL))
})

test_that("resolve_weight_spec warns for local-only replicate source", {
  ws <- list(
    monthly = list(
      type = "replicate", variable = "W",
      replicate_pattern = "wr[0-9]+",
      replicate_source = list(provider = "local", path_hint = "custom.csv", edition = "2023"),
      replicate_id = list(survey_key = "ID", replicate_key = "ID"),
      replicate_type = "bootstrap"
    )
  )
  expect_warning(resolve_weight_spec(ws), "local-only")
})

# --- print.RecipeWorkflow with weight_spec ---

test_that("print.RecipeWorkflow shows weight info when present", {
  ws <- list(
    annual = list(type = "simple", variable = "W_ANO"),
    monthly = list(
      type = "replicate", variable = "W",
      replicate_pattern = "wr[0-9]+",
      replicate_source = list(provider = "anda", resource = "bootstrap_monthly", edition = "2023"),
      replicate_id = list(survey_key = "ID", replicate_key = "ID"),
      replicate_type = "bootstrap"
    )
  )
  wf <- RecipeWorkflow$new(name = "Print Test", weight_spec = ws)

  output <- capture.output(print(wf))
  output_text <- paste(output, collapse = "\n")

  expect_true(grepl("W_ANO", output_text))
  expect_true(grepl("Weight", output_text, ignore.case = TRUE))
})

test_that("print.RecipeWorkflow does not show weight section when NULL", {
  wf <- RecipeWorkflow$new(name = "Plain WF")
  output <- capture.output(print(wf))
  output_text <- paste(output, collapse = "\n")
  expect_false(grepl("Weights", output_text))
})
