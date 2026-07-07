# Tests for step_compute

test_that("step_compute creates a new variable", {
  s <- make_test_survey()
  s2 <- step_compute(s, total = income + age)
  expect_true(any(grepl("Compute", names(s2$steps))))
})

test_that("step_compute result available after bake_steps", {
  s <- make_test_survey()
  s2 <- step_compute(s, double_income = income * 2)
  s2 <- bake_steps(s2)
  expect_true("double_income" %in% names(s2$data))
  expect_equal(s2$data$double_income, s2$data$income * 2)
})

test_that("step_compute with multiple variables", {
  s <- make_test_survey()
  s2 <- step_compute(s, sum_val = income + age, prod_val = income * age)
  s2 <- bake_steps(s2)
  expect_true("sum_val" %in% names(s2$data))
  expect_true("prod_val" %in% names(s2$data))
})

test_that("step_compute records step in survey", {
  s <- make_test_survey()
  s2 <- step_compute(s, z = income + 1)
  expect_true(length(s2$steps) > 0)
})

test_that("step_compute fails on missing variable", {
  s <- make_test_survey()
  expect_error(
    step_compute(s, z = nonexistent_column + 1),
    "Missing variables|not found|Dependency"
  )
})

test_that("bake_steps with no steps returns survey unchanged", {
  s <- make_test_survey()
  s2 <- bake_steps(s)
  expect_equal(nrow(get_data(s2)), nrow(get_data(s)))
  expect_equal(names(get_data(s2)), names(get_data(s)))
})

test_that("multiple step_compute calls chain correctly", {
  s <- make_test_survey()
  s2 <- step_compute(s, a_plus_b = income + age)
  s2 <- bake_steps(s2)
  s3 <- step_compute(s2, triple = a_plus_b * 3)
  s3 <- bake_steps(s3)
  expect_true("triple" %in% names(s3$data))
})

test_that("step_compute accepts a braced multi-statement expression", {
  s <- make_test_survey()
  s2 <- step_compute(s, age_c = {
    tmp <- age - 40
    tmp / 10
  })
  expect_true("age_c" %in% names(s2$data))
  expect_equal(s2$data$age_c, (s2$data$age - 40) / 10)
  expect_false("tmp" %in% names(s2$data))
})
