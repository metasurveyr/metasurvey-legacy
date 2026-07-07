# Tests for step_validate()

test_that("step_validate records a lazy step", {
  svy <- make_test_survey(10)
  svy2 <- step_validate(svy, income > 0)
  expect_true(has_steps(svy2))
  steps <- get_steps(svy2)
  expect_equal(length(steps), 1)
  expect_equal(steps[[1]]$type, "validate")
  expect_false(steps[[1]]$bake)
})

test_that("step_validate passes when all checks succeed", {
  svy <- make_test_survey(10)
  # income and age are always positive in test data
  svy2 <- svy |>
    step_validate(income > 0, age > 0) |>
    bake_steps()
  expect_true(is_baked(svy2))
})

test_that("step_validate stops on failure by default", {
  svy <- make_test_survey(10)
  # age is never > 1000
  svy2 <- step_validate(svy, age > 1000)
  expect_error(bake_steps(svy2), "Validation failed")
})

test_that("step_validate warns instead of stopping with .action = 'warn'", {
  svy <- make_test_survey(10)
  svy2 <- step_validate(svy, age > 1000, .action = "warn")
  expect_warning(bake_steps(svy2), "Validation failed")
})

test_that("step_validate reports which check failed", {
  svy <- make_test_survey(10)
  svy2 <- step_validate(svy, age > 1000)
  expect_error(bake_steps(svy2), "age > 1000")
})

test_that("step_validate reports number of failing rows", {
  svy <- make_test_survey(10)
  svy2 <- step_validate(svy, age > 1000)
  expect_error(bake_steps(svy2), "10.*row")
})

test_that("step_validate supports multiple checks (first failure stops)", {
  svy <- make_test_survey(10)
  svy2 <- step_validate(svy, income > 0, age > 1000)
  # First check passes, second fails
  expect_error(bake_steps(svy2), "age > 1000")
})

test_that("step_validate supports .min_n check", {
  svy <- make_test_survey(5)
  svy2 <- step_validate(svy, .min_n = 100)
  expect_error(bake_steps(svy2), "min_n")
})

test_that("step_validate .min_n passes with enough rows", {
  svy <- make_test_survey(20)
  svy2 <- svy |>
    step_validate(.min_n = 10) |>
    bake_steps()
  expect_true(is_baked(svy2))
})

test_that("step_validate works in pipeline with other steps", {
  svy <- make_test_survey(10)
  svy2 <- svy |>
    step_compute(income2 = income * 2) |>
    step_validate(income2 > 0) |>
    bake_steps()
  expect_true("income2" %in% names(get_data(svy2)))
  expect_true(is_baked(svy2))
})

test_that("step_validate detects issues after preceding steps", {
  svy <- make_test_survey(10)
  # Compute a variable that will be NA, then validate it
  svy2 <- svy |>
    step_compute(bad = NA_real_) |>
    step_validate(!is.na(bad))
  expect_error(bake_steps(svy2), "Validation failed")
})

test_that("step_validate stores comment", {
  svy <- make_test_survey(10)
  svy2 <- step_validate(svy, income > 0, comment = "Check positive income")
  steps <- get_steps(svy2)
  expect_equal(steps[[1]]$comment, "Check positive income")
})

test_that("step_validate with .copy = TRUE returns new object", {
  svy <- make_test_survey(10)
  svy2 <- step_validate(svy, income > 0, .copy = TRUE)
  expect_false(identical(svy, svy2))
})

test_that("step_validate with .copy = FALSE modifies in place", {
  old <- options(metasurvey.use_copy = FALSE)
  on.exit(options(old))
  svy <- make_test_survey(10)
  svy2 <- step_validate(svy, income > 0)
  # In-place: svy is same R6 ref as svy2
  expect_true(has_steps(svy))
})

test_that("step_validate does not mutate data", {
  svy <- make_test_survey(10)
  data_before <- data.table::copy(get_data(svy))
  svy2 <- svy |>
    step_validate(income > 0) |>
    bake_steps()
  data_after <- get_data(svy2)
  expect_equal(data_before, data_after)
})

test_that("step_validate .action must be 'stop' or 'warn'", {
  svy <- make_test_survey(10)
  expect_error(
    step_validate(svy, income > 0, .action = "skip"),
    "should be one of"
  )
})

test_that("step_validate requires at least one check or .min_n", {
  svy <- make_test_survey(10)
  expect_error(step_validate(svy), "at least one")
})

test_that("step_validate works with RotativePanelSurvey", {
  panel <- make_test_panel()
  panel2 <- step_validate(panel, age > 0)
  expect_true(has_steps(panel2$implantation))
})

test_that("step_validate named checks use name in error", {
  svy <- make_test_survey(10)
  svy2 <- step_validate(svy, positive_age = age > 1000)
  expect_error(bake_steps(svy2), "positive_age")
})
