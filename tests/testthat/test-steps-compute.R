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

test_that("step_compute does not double-execute on bake_steps (non-idempotent expr)", {
  s <- make_test_survey()
  original_age <- data.table::copy(get_data(s)$age)

  s2 <- step_compute(s, age = age + 1)
  expect_equal(get_data(s2)$age, original_age + 1)

  s2 <- bake_steps(s2)
  # +1, never +2: bake_steps must skip the already-executed step
  expect_equal(get_data(s2)$age, original_age + 1)
})

test_that("step_compute records the step as already baked", {
  s <- make_test_survey()
  s2 <- step_compute(s, x2 = x * 2)
  expect_true(all(vapply(s2$steps, function(st) isTRUE(st$bake), logical(1))))
})

test_that("step_compute overwriting a column applies exactly once (deflation pattern)", {
  df <- data.table::data.table(id = 1:4, income = c(100, 200, 300, 400), ipc = 2, w = 1)
  s <- Survey$new(
    data = df, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )
  s2 <- bake_steps(step_compute(s, income = income / ipc))
  expect_equal(get_data(s2)$income, c(50, 100, 150, 200))
})

# --- Mutation testing regression tests (issue #220) ---

test_that("step_compute depends_on excludes temporaries assigned in { } blocks", {
  s <- make_test_survey()
  s2 <- step_compute(
    s,
    z = {
      tmp <- x + 1
      tmp * 2
    },
    .copy = TRUE
  )
  step <- s2$steps[[length(s2$steps)]]
  expect_setequal(step$depends_on, "x")
  expect_false("tmp" %in% step$depends_on)
  expect_equal(get_data(s2)$z, (get_data(s)$x + 1) * 2)
})

test_that("collect_assigned_vars finds all assignment forms in a { } block", {
  e <- quote({
    a <- x + 1
    b <- a * 2
    d <<- b + zz
    b
  })
  expect_setequal(metasurvey:::collect_assigned_vars(e), c("a", "b", "d"))
  expect_setequal(
    setdiff(all.vars(e), metasurvey:::collect_assigned_vars(e)),
    c("x", "zz")
  )
})

test_that("step_compute with .by recomputes an existing column without .x/.y suffixes", {
  s <- make_test_survey()
  dat_before <- data.table::copy(get_data(s))
  # "y" already exists: without the pre-merge column drop, merge()
  # would produce y.x/y.y suffixes instead of overwriting
  s2 <- step_compute(s, y = max(income), .by = "region", .copy = TRUE)
  dat <- get_data(s2)
  expect_true("y" %in% names(dat))
  expect_false(any(grepl("^y\\.(x|y)$", names(dat))))
  expected <- dat_before[, list(exp_y = max(income)), by = "region"]
  merged <- merge(dat_before[, list(id, region)], expected, by = "region")
  expect_equal(dat[order(id)]$y, merged[order(id)]$exp_y)
})
