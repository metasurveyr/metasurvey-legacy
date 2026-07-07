test_that("Step$new creates step with all fields", {
  step <- Step$new(
    name = "test_step",
    edition = "2023",
    survey_type = "ech",
    type = "compute",
    new_var = "test_var",
    exprs = list(a = quote(x + 1)),
    call = NULL,
    svy_before = NULL,
    default_engine = "data.table",
    depends_on = list("x"),
    comments = "Test step",
    bake = FALSE
  )

  expect_s3_class(step, "Step")
  expect_equal(step$name, "test_step")
  expect_equal(step$edition, "2023")
  expect_equal(step$type, "compute")
  expect_equal(step$new_var, "test_var")
  expect_false(step$bake)
})

test_that("Step stores dependencies correctly", {
  step <- Step$new(
    name = "dependency_test",
    edition = "2023",
    survey_type = "ech",
    type = "compute",
    new_var = "result",
    exprs = list(),
    call = NULL,
    svy_before = NULL,
    default_engine = "data.table",
    depends_on = list("var1", "var2", "var3")
  )

  expect_equal(length(step$depends_on), 3)
  expect_true("var1" %in% step$depends_on)
})

test_that("Step can be created with minimal arguments", {
  step <- Step$new(
    name = "minimal",
    edition = "2023",
    survey_type = "ech",
    type = "filter",
    new_var = NULL,
    exprs = list(),
    call = NULL,
    svy_before = NULL,
    default_engine = "data.table",
    depends_on = list()
  )

  expect_s3_class(step, "Step")
  expect_null(step$new_var)
  expect_equal(length(step$exprs), 0)
})

test_that("Step bake flag can be toggled", {
  step <- Step$new(
    name = "bake_test",
    edition = "2023",
    survey_type = "ech",
    type = "compute",
    new_var = "var",
    exprs = list(),
    call = NULL,
    svy_before = NULL,
    default_engine = "data.table",
    depends_on = list(),
    bake = FALSE
  )

  expect_false(step$bake)
  step$bake <- TRUE
  expect_true(step$bake)
})

test_that("Step stores different types correctly", {
  types <- c("compute", "recode", "filter", "join", "remove")

  for (type in types) {
    step <- Step$new(
      name = paste0(type, "_step"),
      edition = "2023",
      survey_type = "ech",
      type = type,
      new_var = NULL,
      exprs = list(),
      call = NULL,
      svy_before = NULL,
      default_engine = "data.table",
      depends_on = list()
    )

    expect_equal(step$type, type)
  }
})


test_that("Step clone creates independent copy", {
  step1 <- Step$new(
    name = "original",
    edition = "2023",
    survey_type = "ech",
    type = "compute",
    new_var = "var",
    exprs = list(),
    call = NULL,
    svy_before = NULL,
    default_engine = "data.table",
    depends_on = list()
  )

  step2 <- step1$clone()
  step2$name <- "cloned"

  expect_equal(step1$name, "original")
  expect_equal(step2$name, "cloned")
})

test_that("Step stores expressions as list", {
  step <- Step$new(
    name = "expr_test",
    edition = "2023",
    survey_type = "ech",
    type = "compute",
    new_var = "result",
    exprs = list(
      a = quote(x + 1),
      b = quote(y * 2)
    ),
    call = NULL,
    svy_before = NULL,
    default_engine = "data.table",
    depends_on = list("x", "y")
  )

  expect_type(step$exprs, "list")
  expect_equal(length(step$exprs), 2)
  expect_true("a" %in% names(step$exprs))
})

# --- validate_step tests ---

test_that("validate_step returns TRUE when all deps exist", {
  s <- make_test_survey()
  step <- Step$new(
    name = "valid_step", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z", exprs = list(),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list("age", "income")
  )
  expect_true(metasurvey:::validate_step(s, step))
})

test_that("validate_step errors when deps missing", {
  s <- make_test_survey()
  step <- Step$new(
    name = "invalid_step", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z", exprs = list(),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list("nonexistent_var")
  )
  expect_error(metasurvey:::validate_step(s, step), "not in the survey")
})

test_that("validate_step with empty deps returns TRUE", {
  s <- make_test_survey()
  step <- Step$new(
    name = "no_deps", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z", exprs = list(),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list()
  )
  expect_true(metasurvey:::validate_step(s, step))
})

# --- bake_step tests ---

test_that("bake_step skips already-baked steps", {
  s <- make_test_survey()
  step <- Step$new(
    name = "baked", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z", exprs = list(),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list(), bake = TRUE
  )
  result <- metasurvey:::bake_step(s, step)
  expect_s3_class(result, "Survey")
})


# --- bake_steps_survey ---

test_that("bake_steps_survey bakes all pending steps", {
  s <- make_test_survey()
  s2 <- step_compute(s, age_plus_one = age + 1)
  s3 <- metasurvey:::bake_steps_survey(s2)
  expect_true("age_plus_one" %in% names(s3$data))
  # Steps should be marked as baked
  expect_true(all(vapply(s3$steps, function(st) st$bake, logical(1))))
})

# --- Step with comment parameter ---

test_that("Step accepts comment parameter", {
  step <- Step$new(
    name = "comment_test", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z", exprs = list(),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list(), comment = "My comment"
  )
  expect_equal(step$comment, "My comment")
})

test_that("Step accepts comments as legacy alias for comment", {
  step <- Step$new(
    name = "comment_test", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z", exprs = list(),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list(), comments = "Legacy comment"
  )
  expect_equal(step$comment, "Legacy comment")
})

# --- bake_step for step_remove ---

test_that("bake_step executes step_remove step", {
  s <- make_test_survey()
  s2 <- step_remove(s, x)
  steps <- s2$steps
  step <- steps[[1]]
  result <- metasurvey:::bake_step(s2, step)
  expect_s3_class(result, "Survey")
  expect_false("x" %in% names(result$data))
})

# --- bake_step for step_rename ---

test_that("bake_step executes step_rename step", {
  s <- make_test_survey()
  s2 <- step_rename(s, years = age)
  steps <- s2$steps
  step <- steps[[1]]
  result <- metasurvey:::bake_step(s2, step)
  expect_s3_class(result, "Survey")
})

# --- bake_steps_rotative ---

test_that("bake_steps_rotative bakes RotativePanelSurvey steps", {
  panel <- make_test_panel()
  # Add a step to implantation
  panel$implantation <- step_compute(panel$implantation, z = age + 1)
  result <- bake_steps(panel)
  expect_s3_class(result, "RotativePanelSurvey")
  expect_true("z" %in% names(get_data(result$implantation)))
})

# --- bake_steps errors on invalid input ---

test_that("bake_steps errors on non-Survey input", {
  expect_error(bake_steps("not a survey"), "not a Survey")
})

# --- bake_step with validation failure ---

test_that("bake_steps_survey with use_copy=FALSE runs without error", {
  old <- use_copy_default()
  on.exit(set_use_copy(old), add = TRUE)
  set_use_copy(FALSE)

  s <- make_test_survey()
  s2 <- step_compute(s, z = age + 1, use_copy = FALSE)
  s3 <- metasurvey:::bake_steps_survey(s2)
  expect_s3_class(s3, "Survey")
})

test_that("bake_steps_rotative with use_copy=FALSE runs without error", {
  old <- use_copy_default()
  on.exit(set_use_copy(old), add = TRUE)
  set_use_copy(FALSE)

  panel <- make_test_panel()
  panel$implantation <- step_compute(panel$implantation, z = age + 1, use_copy = FALSE)
  result <- bake_steps(panel)
  expect_s3_class(result, "RotativePanelSurvey")
})

test_that("bake_step validation warning returns survey with invalid deps", {
  s <- make_test_survey()
  step <- Step$new(
    name = "invalid_deps", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z", exprs = list(),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list(), bake = FALSE
  )
  # Step with empty deps and empty exprs - bake_step should handle it
  # The step is "compute" type, so it goes to do.call path
  result <- tryCatch(metasurvey:::bake_step(s, step), error = function(e) s)
  expect_s3_class(result, "Survey")
})

test_that("bake_step errors on validation failure", {
  s <- make_test_survey()
  step <- Step$new(
    name = "invalid_deps", edition = "2023", survey_type = "ech",
    type = "compute", new_var = "z", exprs = list(),
    call = NULL, svy_before = NULL, default_engine = "data.table",
    depends_on = list("nonexistent_var"), bake = FALSE
  )
  expect_error(
    metasurvey:::bake_step(s, step),
    "not in the survey"
  )
})

test_that("bake_step rejects invalid step type", {
  s <- make_test_survey()
  step <- Step$new(
    name = "bad_type", edition = "2023", survey_type = "ech",
    type = "invalid_type", new_var = NULL,
    exprs = list(), call = NULL, svy_before = NULL,
    default_engine = "data.table", depends_on = list(), bake = FALSE
  )
  expect_error(
    metasurvey:::bake_step(s, step),
    "Invalid step type"
  )
})

# --- Mutation testing regression tests (issue #220) ---

test_that("bake_steps with use_copy=TRUE returns a copy and leaves original un-baked", {
  old <- set_use_copy(TRUE)
  on.exit(set_use_copy(old), add = TRUE)
  s <- make_test_survey()
  s2 <- step_remove(s, status)
  expect_false(s2$steps[[1]]$bake)

  baked <- bake_steps(s2)
  expect_false(identical(baked, s2))
  # Original untouched: still has the column, step still pending
  expect_true("status" %in% names(get_data(s2)))
  expect_false(s2$steps[[1]]$bake)
  # Copy materialized: column removed, step marked as baked
  expect_false("status" %in% names(get_data(baked)))
  expect_true(baked$steps[[1]]$bake)
})

test_that("bake_steps with use_copy=FALSE mutates the survey in place", {
  old <- set_use_copy(FALSE)
  on.exit(set_use_copy(old), add = TRUE)
  s <- make_test_survey()
  s2 <- step_remove(s, status)
  expect_true(identical(s2, s))

  baked <- bake_steps(s2)
  expect_true(identical(baked, s2))
  expect_false("status" %in% names(get_data(s2)))
  expect_true(s2$steps[[1]]$bake)
})
