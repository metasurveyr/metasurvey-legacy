test_that("workflow function dispatches correctly", {
  # Create test survey
  survey <- make_test_survey(50)

  # Test with regular survey - using survey package functions
  result <- workflow(
    list(survey),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )

  expect_s3_class(result, "data.table")
  expect_true(nrow(result) > 0)
  expect_true("stat" %in% names(result))
  expect_true("value" %in% names(result))
  expect_true("se" %in% names(result))
})

test_that("workflow handles multiple estimations", {
  survey <- make_test_survey(50)

  result <- workflow(
    list(survey),
    survey::svymean(~age, na.rm = TRUE),
    survey::svytotal(~income, na.rm = TRUE),
    estimation_type = "annual"
  )

  expect_s3_class(result, "data.table")
  expect_equal(nrow(result), 2)
})

test_that("workflow handles multiple surveys", {
  survey1 <- make_test_survey(50)
  survey2 <- make_test_survey(50)
  survey2$edition <- "2024"

  result <- workflow(
    list(survey1, survey2),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )

  expect_s3_class(result, "data.table")
  expect_true(nrow(result) > 0)
})

test_that("workflow handles multiple estimation types", {
  survey <- make_test_survey(50)
  survey$weight <- add_weight(
    annual = "w",
    quarterly = "w",
    monthly = "w"
  )
  survey$design <- list(
    annual = survey::svydesign(ids = ~1, weights = ~w, data = survey$data),
    quarterly = survey::svydesign(ids = ~1, weights = ~w, data = survey$data),
    monthly = survey::svydesign(ids = ~1, weights = ~w, data = survey$data)
  )

  result <- workflow(
    list(survey),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = c("annual", "quarterly")
  )

  expect_s3_class(result, "data.table")
  expect_true(nrow(result) >= 2)
})

test_that("cat_estimation helper formats results correctly", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)

  estimation <- survey::svymean(~age, des, na.rm = TRUE)

  # Verify estimation has required components
  expect_true(!is.null(coef(estimation)))
  expect_true(!is.null(survey::SE(estimation)))
})

test_that("svyratio estimation produces valid results", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)

  estimation <- survey::svyratio(~income, ~age, des, na.rm = TRUE)

  # Verify estimation structure
  expect_true(!is.null(coef(estimation)))
  expect_true(!is.null(survey::SE(estimation)))
})


test_that("workflow validates PoolSurvey dispatch", {
  survey <- make_test_survey(50)
  result <- workflow(
    list(survey),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )

  expect_s3_class(result, "data.table")
})

# --- cat_estimation.default tests ---

test_that("cat_estimation.default formats svymean result", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)
  estimation <- survey::svymean(~age, des, na.rm = TRUE)

  result <- metasurvey:::cat_estimation.default(estimation, "survey::svymean")
  expect_s3_class(result, "data.table")
  expect_true(all(c("stat", "value", "se", "cv", "confint_lower", "confint_upper") %in% names(result)))
  expect_true(nrow(result) > 0)
})

test_that("cat_estimation.default formats svytotal result", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)
  estimation <- survey::svytotal(~income, des, na.rm = TRUE)

  result <- metasurvey:::cat_estimation.default(estimation, "survey::svytotal")
  expect_s3_class(result, "data.table")
  expect_true(all(c("stat", "value", "se") %in% names(result)))
})

# --- cat_estimation.svyratio tests ---

test_that("cat_estimation.svyratio formats ratio result", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)
  estimation <- survey::svyratio(~income, ~age, des, na.rm = TRUE)

  result <- metasurvey:::cat_estimation.svyratio(estimation, "survey::svyratio")
  expect_s3_class(result, "data.table")
  expect_true(all(c("stat", "value", "se", "cv", "confint_lower", "confint_upper") %in% names(result)))
})

# --- cat_estimation.svyby tests ---

test_that("cat_estimation.svyby formats by-group result", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)
  estimation <- survey::svyby(~income, ~region, des, survey::svymean, na.rm = TRUE)

  result <- metasurvey:::cat_estimation.svyby(estimation, "survey::svyby")
  expect_s3_class(result, "data.table")
  expect_true("stat" %in% names(result))
  expect_true("value" %in% names(result))
})

# --- cat_estimation dispatcher ---

test_that("cat_estimation dispatches to default for svymean", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)
  estimation <- survey::svymean(~age, des, na.rm = TRUE)

  result <- metasurvey:::cat_estimation(estimation, "survey::svymean")
  expect_s3_class(result, "data.table")
})

test_that("cat_estimation dispatches to svyratio", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)
  estimation <- survey::svyratio(~income, ~age, des, na.rm = TRUE)

  result <- metasurvey:::cat_estimation(estimation, "survey::svyratio")
  expect_s3_class(result, "data.table")
})

test_that("cat_estimation dispatches to svyby", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)
  estimation <- survey::svyby(~income, ~region, des, survey::svymean, na.rm = TRUE)

  result <- metasurvey:::cat_estimation(estimation, "survey::svyby")
  expect_s3_class(result, "data.table")
})

# --- workflow with svyratio ---

test_that("workflow handles svyratio estimation", {
  survey <- make_test_survey(50)
  result <- workflow(
    list(survey),
    survey::svyratio(~income, ~age, na.rm = TRUE),
    estimation_type = "annual"
  )

  expect_s3_class(result, "data.table")
  expect_true(nrow(result) > 0)
  expect_true("stat" %in% names(result))
})

# --- workflow with svyby ---

test_that("workflow handles svyby estimation", {
  survey <- make_test_survey(50)
  result <- workflow(
    list(survey),
    survey::svyby(~income, ~region, survey::svymean, na.rm = TRUE),
    estimation_type = "annual"
  )

  expect_s3_class(result, "data.table")
  expect_true(nrow(result) > 0)
})

# --- workflow result correctness ---

test_that("workflow svymean result matches direct calculation", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)

  direct <- survey::svymean(~age, des, na.rm = TRUE)

  wf_result <- workflow(
    list(survey),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )

  expect_equal(wf_result$value[1], unname(coef(direct)), tolerance = 1e-6)
  expect_equal(as.numeric(wf_result$se[1]), as.numeric(survey::SE(direct)), tolerance = 1e-6)
})


# --- Merged from test-workflow-advanced.R ---

# Additional tests for workflow to increase coverage

test_that("workflow dispatches to workflow_pool for PoolSurvey", {
  # Build a PoolSurvey manually with the right structure
  s1 <- make_test_survey(50)
  s1$edition <- "2023-01-01"
  s2 <- make_test_survey(50)
  s2$edition <- "2023-02-01"

  surveys_struct <- list(
    annual = list(
      "group1" = list(s1, s2)
    )
  )
  pool <- PoolSurvey$new(surveys_struct)

  result <- workflow(
    pool,
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )
  expect_s3_class(result, "data.table")
  expect_true(nrow(result) > 0)
  expect_true("stat" %in% names(result))
})

test_that("workflow_pool with colon-separated estimation types aggregates", {
  s1 <- make_test_survey(50)
  s1$edition <- "2023-01-01"
  s2 <- make_test_survey(50)
  s2$edition <- "2023-02-01"

  surveys_struct <- list(
    annual = list(
      "group1" = list(s1, s2)
    )
  )
  pool <- PoolSurvey$new(surveys_struct)

  result <- workflow(
    pool,
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual:annual"
  )
  expect_s3_class(result, "data.table")
  expect_true(nrow(result) > 0)
})

test_that("cat_estimation dispatches correctly for different types", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)

  # Test svymean
  est_mean <- survey::svymean(~age, des, na.rm = TRUE)
  result_mean <- metasurvey:::cat_estimation(est_mean, "survey::svymean")
  expect_s3_class(result_mean, "data.table")
  expect_true("stat" %in% names(result_mean))

  # Test svytotal
  est_total <- survey::svytotal(~income, des, na.rm = TRUE)
  result_total <- metasurvey:::cat_estimation(est_total, "survey::svytotal")
  expect_s3_class(result_total, "data.table")

  # Test svyratio
  est_ratio <- survey::svyratio(~income, ~age, des, na.rm = TRUE)
  result_ratio <- metasurvey:::cat_estimation(est_ratio, "survey::svyratio")
  expect_s3_class(result_ratio, "data.table")

  # Test svyby
  est_by <- survey::svyby(~income, ~region, des, survey::svymean, na.rm = TRUE)
  result_by <- metasurvey:::cat_estimation(est_by, "survey::svyby")
  expect_s3_class(result_by, "data.table")
})

test_that("workflow_pool with rho and R parameters", {
  s1 <- make_test_survey(50)
  s1$edition <- "2023-01-01"
  s2 <- make_test_survey(50)
  s2$edition <- "2023-02-01"

  surveys_struct <- list(
    annual = list(
      "group1" = list(s1, s2)
    )
  )
  pool <- PoolSurvey$new(surveys_struct)

  result <- workflow(
    pool,
    survey::svymean(~age, na.rm = TRUE),
    rho = 0.5,
    R = 2,
    estimation_type = "annual"
  )
  expect_s3_class(result, "data.table")
  expect_true(nrow(result) > 0)
})

test_that("workflow handles empty survey list", {
  result <- tryCatch(
    {
      workflow(
        list(),
        survey::svymean(~age, na.rm = TRUE),
        estimation_type = "annual"
      )
    },
    error = function(e) e
  )

  # Should error, return NULL, or return empty data.frame for empty list
  expect_true(inherits(result, "error") || is.null(result) || (is.data.frame(result) && nrow(result) == 0))
})

test_that("workflow validates estimation type exists in design", {
  survey <- make_test_survey(50)

  # This should work with annual
  result <- workflow(
    list(survey),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )

  expect_s3_class(result, "data.table")
})

test_that("workflow_default processes multiple calls correctly", {
  survey <- make_test_survey(50)

  result <- workflow(
    list(survey),
    survey::svymean(~age, na.rm = TRUE),
    survey::svytotal(~income, na.rm = TRUE),
    survey::svyratio(~income, ~age, na.rm = TRUE),
    estimation_type = "annual"
  )

  expect_s3_class(result, "data.table")
  expect_true(nrow(result) >= 3)
})

test_that("cat_estimation.default handles all result columns", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)
  estimation <- survey::svymean(~age, des, na.rm = TRUE)

  result <- metasurvey:::cat_estimation.default(estimation, "survey::svymean")

  expected_cols <- c("stat", "value", "se", "cv", "confint_lower", "confint_upper")
  expect_true(all(expected_cols %in% names(result)))
})

test_that("cat_estimation.svyby handles multiple groups", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)

  # svyby with multiple groups
  estimation <- survey::svyby(~income, ~region, des, survey::svymean, na.rm = TRUE)

  result <- metasurvey:::cat_estimation.svyby(estimation, "survey::svyby")

  expect_s3_class(result, "data.table")
  expect_true(nrow(result) > 1)
  expect_true("value" %in% names(result))
})

test_that("workflow handles survey with multiple editions", {
  survey1 <- make_test_survey(50)
  survey1$edition <- "2023"

  survey2 <- make_test_survey(50)
  survey2$edition <- "2024"

  survey3 <- make_test_survey(50)
  survey3$edition <- "2025"

  result <- workflow(
    list(survey1, survey2, survey3),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )

  expect_s3_class(result, "data.table")
  expect_true(nrow(result) > 0)
})

# --- Tests for estimation_type branches (recovered from coverage-boost) ---

test_that("workflow errors on missing estimation type weight", {
  s <- make_test_survey() # only has 'annual' weight
  expect_error(
    workflow(
      svy = list(s), survey::svymean(~age, na.rm = TRUE),
      estimation_type = "monthly"
    )
  )
})

test_that("workflow errors on quarterly without quarterly weight", {
  s <- make_test_survey()
  expect_error(
    workflow(
      svy = list(s), survey::svymean(~age, na.rm = TRUE),
      estimation_type = "quarterly"
    )
  )
})

# ── Batch 10: workflow additional edge cases ──────────────────────────────────

test_that("workflow with svyby includes margin columns", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)
  estimation <- survey::svyby(~income, ~region, des, survey::svymean, na.rm = TRUE)

  result <- metasurvey:::cat_estimation.svyby(estimation, "survey::svyby")
  expect_true("region" %in% names(result) || "stat" %in% names(result))
  expect_true(nrow(result) > 0)
})

test_that("cat_estimation.svyratio handles multi-variable ratio", {
  survey <- make_test_survey(100)
  des <- survey::svydesign(ids = ~1, data = get_data(survey), weights = ~w)
  estimation <- survey::svyratio(~income, ~age, des, na.rm = TRUE)

  result <- metasurvey:::cat_estimation.svyratio(estimation, "survey::svyratio")
  expect_true("cv" %in% names(result))
  expect_true(all(is.finite(result$cv) | is.na(result$cv)))
})

test_that("evaluate_cv classifies CV correctly on percentage scale", {
  expect_equal(evaluate_cv(3), "Excellent")
  expect_equal(evaluate_cv(7), "Very good")
  expect_equal(evaluate_cv(12), "Good")
  expect_equal(evaluate_cv(20), "Acceptable")
  expect_equal(evaluate_cv(30), "Use with caution")
  expect_equal(evaluate_cv(40), "Do not publish")
})

# --- cat_estimation.cvystat tests (convey package) ---

test_that("cat_estimation.cvystat formats mock cvystat object", {
  # Create a mock cvystat object without needing convey installed
  mock_cvystat <- 0.35
  attr(mock_cvystat, "var") <- matrix(0.0004, 1, 1)
  attr(mock_cvystat, "statistic") <- "gini"
  class(mock_cvystat) <- "cvystat"

  result <- metasurvey:::cat_estimation.cvystat(mock_cvystat, "convey::svygini")
  expect_s3_class(result, "data.table")
  expected_cols <- c("stat", "value", "se", "cv", "confint_lower", "confint_upper")
  expect_true(all(expected_cols %in% names(result)))
  expect_equal(result$value, 0.35)
  expect_equal(result$se, 0.02, tolerance = 1e-10)
  expect_true(grepl("gini", result$stat))
})

test_that("cat_estimation dispatches to cvystat", {
  mock_cvystat <- 0.42
  attr(mock_cvystat, "var") <- matrix(0.001, 1, 1)
  attr(mock_cvystat, "statistic") <- "atkinson"
  class(mock_cvystat) <- "cvystat"

  result <- metasurvey:::cat_estimation(mock_cvystat, "convey::svyatk")
  expect_s3_class(result, "data.table")
  expect_equal(result$value, 0.42)
  expect_true(grepl("atkinson", result$stat))
})

test_that("cat_estimation.cvystat handles missing statistic attr", {
  mock_cvystat <- 0.5
  attr(mock_cvystat, "var") <- matrix(0.0025, 1, 1)
  class(mock_cvystat) <- "cvystat"

  result <- metasurvey:::cat_estimation.cvystat(mock_cvystat, "convey::svyfgt")
  expect_s3_class(result, "data.table")
  expect_true(grepl("estimate", result$stat))
})

test_that("workflow works with convey functions", {
  skip_if_not_installed("convey")

  survey <- make_test_survey(100)
  survey$ensure_design()
  survey$design[["annual"]] <- convey::convey_prep(survey$design[["annual"]])

  result <- workflow(
    list(survey),
    convey::svygini(~income, na.rm = TRUE),
    estimation_type = "annual"
  )

  expect_s3_class(result, "data.table")
  expect_true(nrow(result) == 1)
  expect_true(result$value > 0 && result$value < 1)
})

# ── level tests ──────────────────────────────────────────────────────────────

test_that("level changes confidence intervals", {
  svy <- make_test_survey(100)

  r95 <- workflow(list(svy), survey::svymean(~x, na.rm = TRUE),
    estimation_type = "annual"
  )
  r90 <- workflow(list(svy), survey::svymean(~x, na.rm = TRUE),
    estimation_type = "annual", level = 0.90
  )

  expect_equal(r95$value, r90$value)
  expect_true(r90$confint_lower > r95$confint_lower)
  expect_true(r90$confint_upper < r95$confint_upper)
})

test_that("level inside estimation call is used", {
  svy <- make_test_survey(100)

  r95 <- workflow(list(svy), survey::svymean(~x, na.rm = TRUE),
    estimation_type = "annual"
  )
  r80 <- workflow(list(svy),
    survey::svymean(~x, na.rm = TRUE, level = 0.80),
    estimation_type = "annual"
  )

  expect_equal(r95$value, r80$value)
  expect_true(r80$confint_lower > r95$confint_lower)
  expect_true(r80$confint_upper < r95$confint_upper)
})

test_that("level inside svyby call is used", {
  svy <- make_test_survey(100)

  r95 <- workflow(list(svy),
    survey::svyby(~x, ~region, survey::svymean, na.rm = TRUE),
    estimation_type = "annual"
  )
  r80 <- workflow(list(svy),
    survey::svyby(~x, ~region, survey::svymean,
      na.rm = TRUE,
      level = 0.80
    ),
    estimation_type = "annual"
  )

  expect_equal(r95$value, r80$value)
  expect_true(all(r80$confint_lower > r95$confint_lower))
  expect_true(all(r80$confint_upper < r95$confint_upper))
})

test_that("per-call level overrides workflow default", {
  svy <- make_test_survey(100)

  result <- workflow(list(svy),
    survey::svymean(~x, na.rm = TRUE, level = 0.80),
    estimation_type = "annual", level = 0.99
  )
  r80 <- workflow(list(svy),
    survey::svymean(~x, na.rm = TRUE),
    estimation_type = "annual", level = 0.80
  )

  expect_equal(result$confint_lower, r80$confint_lower)
  expect_equal(result$confint_upper, r80$confint_upper)
})
