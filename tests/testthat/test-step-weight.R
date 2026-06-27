# Tests for step_weight() — weightflow integration

make_weighted_survey <- function(n = 100) {
  set.seed(42)
  dt <- data.table::data.table(
    id = seq_len(n),
    x = rnorm(n),
    sex = sample(c("M", "F"), n, replace = TRUE),
    pw = runif(n, 0.5, 2)
  )
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    engine = "data.table",
    weight = add_weight(annual = "pw")
  )
  list(svy = svy, data = dt)
}

test_that("step_weight requires weightflow package", {
  skip_if_not_installed("weightflow")
  expect_true(requireNamespace("weightflow", quietly = TRUE))
})

test_that("step_weight rejects non-weighting_spec input", {
  skip_if_not_installed("weightflow")
  svy <- make_test_survey(20)
  expect_error(
    step_weight(svy, spec = data.frame(x = 1)),
    "weighting_spec"
  )
})

test_that("step_weight records a lazy step", {
  skip_if_not_installed("weightflow")

  env <- make_weighted_survey()
  spec <- weightflow::weighting_spec(env$data, base_weights = pw)

  result <- step_weight(env$svy, spec, .copy = TRUE)

  steps <- get_steps(result)
  expect_length(steps, 1)
  expect_equal(steps[[1]]$type, "step_weight")
  expect_false(steps[[1]]$bake)

  # Weight column should NOT exist yet (lazy)
  expect_false(".weight" %in% names(get_data(result)))
})

test_that("step_weight applies weights after bake_steps", {
  skip_if_not_installed("weightflow")

  env <- make_weighted_survey()
  spec <- weightflow::weighting_spec(env$data, base_weights = pw)

  svy <- step_weight(env$svy, spec, .copy = TRUE)
  svy <- bake_steps(svy)

  expect_true(".weight" %in% names(get_data(svy)))
  expect_equal(svy$weight$annual, ".weight")

  steps <- get_steps(svy)
  expect_true(steps[[1]]$bake)
})

test_that("step_weight works with calibration", {
  skip_if_not_installed("weightflow")

  env <- make_weighted_survey(200)
  pop_margins <- list(sex = c(M = 5000, F = 5200))

  spec <- weightflow::weighting_spec(env$data, base_weights = pw) |>
    weightflow::step_calibrate(
      method = "raking",
      margins = pop_margins
    )

  svy <- step_weight(env$svy, spec, .copy = TRUE)
  svy <- bake_steps(svy)

  result_data <- get_data(svy)
  expect_false(all(result_data$.weight == result_data$pw))
  expect_equal(svy$weight$annual, ".weight")
})

test_that("step_weight with .copy returns new survey", {
  skip_if_not_installed("weightflow")

  env <- make_weighted_survey(50)
  spec <- weightflow::weighting_spec(env$data, base_weights = pw)

  result <- step_weight(env$svy, spec, .copy = TRUE)

  expect_false(identical(env$svy, result))
  expect_length(get_steps(env$svy), 0)
  expect_length(get_steps(result), 1)
})

test_that("step_weight with custom weight_var", {
  skip_if_not_installed("weightflow")

  env <- make_weighted_survey(50)
  spec <- weightflow::weighting_spec(env$data, base_weights = pw)

  svy <- step_weight(env$svy, spec, weight_var = "final_weight", .copy = TRUE)
  svy <- bake_steps(svy)

  expect_true("final_weight" %in% names(get_data(svy)))
  expect_equal(svy$weight$annual, "final_weight")
})

test_that("step_weight works in pipeline with other steps", {
  skip_if_not_installed("weightflow")

  env <- make_weighted_survey()
  spec <- weightflow::weighting_spec(env$data, base_weights = pw)

  svy <- env$svy |>
    step_weight(spec, .copy = TRUE) |>
    step_compute(x_squared = x^2) |>
    bake_steps()

  result_data <- get_data(svy)
  expect_true(".weight" %in% names(result_data))
  expect_true("x_squared" %in% names(result_data))
  expect_equal(svy$weight$annual, ".weight")
})
