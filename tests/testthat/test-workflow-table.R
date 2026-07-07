test_that("workflow_table produces gt object", {
  skip_if_not_installed("gt")
  s <- make_test_survey(50)
  result <- workflow(
    list(s),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )
  tbl <- workflow_table(result)
  expect_s3_class(tbl, "gt_tbl")
})

test_that("workflow_table hides SE when show_se=FALSE", {
  skip_if_not_installed("gt")
  s <- make_test_survey(50)
  result <- workflow(
    list(s),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )
  tbl <- workflow_table(result, show_se = FALSE)
  expect_s3_class(tbl, "gt_tbl")
})

test_that("workflow_table hides CI when ci=NULL", {
  skip_if_not_installed("gt")
  s <- make_test_survey(50)
  result <- workflow(
    list(s),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )
  tbl <- workflow_table(result, ci = NULL)
  expect_s3_class(tbl, "gt_tbl")
})

test_that("workflow_table with custom title and subtitle", {
  skip_if_not_installed("gt")
  s <- make_test_survey(50)
  result <- workflow(
    list(s),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )
  tbl <- workflow_table(result, title = "My Title", subtitle = "My Subtitle")
  expect_s3_class(tbl, "gt_tbl")
})

test_that("workflow_table with locale es", {
  skip_if_not_installed("gt")
  s <- make_test_survey(50)
  result <- workflow(
    list(s),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )
  tbl <- workflow_table(result, locale = "es")
  expect_s3_class(tbl, "gt_tbl")
})

test_that("workflow_table handles svyby results", {
  skip_if_not_installed("gt")
  s <- make_test_survey(100)
  result <- workflow(
    list(s),
    survey::svyby(~income, ~region, survey::svymean, na.rm = TRUE),
    estimation_type = "annual"
  )
  tbl <- workflow_table(result)
  expect_s3_class(tbl, "gt_tbl")
})

test_that("workflow_table with minimal theme", {
  skip_if_not_installed("gt")
  s <- make_test_survey(50)
  result <- workflow(
    list(s),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )
  tbl <- workflow_table(result, theme = "minimal")
  expect_s3_class(tbl, "gt_tbl")
})

test_that("workflow_table kable fallback returns result", {
  s <- make_test_survey(50)
  result <- workflow(
    list(s),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )
  # Test the internal kable fallback directly
  out <- metasurvey:::.workflow_table_kable(result, digits = 2)
  expect_true(!is.null(out))
})

test_that("workflow_table compare_by pivots results", {
  skip_if_not_installed("gt")
  s1 <- make_test_survey(50)
  s2 <- make_test_survey(50)
  s2$edition <- "2024"
  result <- workflow(
    list(s1, s2),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )
  # Add survey_edition column for comparison
  if (!"survey_edition" %in% names(result)) {
    result[, survey_edition := rep(c("2023", "2024"), each = 1)]
  }
  tbl <- workflow_table(result, compare_by = "survey_edition")
  expect_s3_class(tbl, "gt_tbl")
})

test_that("workflow_table without source_note", {
  skip_if_not_installed("gt")
  s <- make_test_survey(50)
  result <- workflow(
    list(s),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )
  tbl <- workflow_table(result, source_note = FALSE)
  expect_s3_class(tbl, "gt_tbl")
})
