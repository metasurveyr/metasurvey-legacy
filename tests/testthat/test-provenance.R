test_that("provenance is initialized on Survey creation", {
  s <- make_test_survey()
  expect_true(!is.null(s$provenance))
  expect_s3_class(s$provenance, "metasurvey_provenance")
  expect_equal(s$provenance$source$initial_n, 10)
  expect_true(!is.null(s$provenance$source$timestamp))
  expect_true(!is.null(s$provenance$environment$metasurvey_version))
  expect_true(!is.null(s$provenance$environment$r_version))
})

test_that("provenance records step history after bake", {
  s <- make_test_survey(50)
  s <- step_compute(s, age2 = age * 2)
  s <- step_filter(s, age >= 30)
  s <- bake_steps(s)
  expect_equal(length(s$provenance$steps), 2)
  expect_equal(s$provenance$steps[[1]]$type, "compute")
  expect_equal(s$provenance$steps[[2]]$type, "filter")
})

test_that("provenance tracks row count changes from filter", {
  s <- make_test_survey(100)
  s <- step_filter(s, age >= 40)
  s <- bake_steps(s)
  prov_step <- s$provenance$steps[[1]]
  expect_equal(prov_step$n_before, 100)
  expect_true(prov_step$n_after < 100)
  expect_true(prov_step$n_after > 0)
})

test_that("provenance compute step has same N before and after", {
  s <- make_test_survey(50)
  s <- step_compute(s, x2 = x * 2)
  s <- bake_steps(s)
  prov_step <- s$provenance$steps[[1]]
  expect_equal(prov_step$n_before, prov_step$n_after)
})

test_that("provenance records duration", {
  s <- make_test_survey(50)
  s <- step_compute(s, x2 = x * 2)
  s <- bake_steps(s)
  expect_true(!is.null(s$provenance$steps[[1]]$duration_ms))
  expect_true(is.numeric(s$provenance$steps[[1]]$duration_ms))
})

test_that("provenance() generic works for Survey", {
  s <- make_test_survey()
  expect_identical(provenance(s), s$provenance)
})

test_that("provenance() generic returns NULL for unknown objects", {
  expect_null(provenance(42))
})

test_that("provenance_to_json returns valid JSON", {
  s <- make_test_survey()
  json <- provenance_to_json(s$provenance)
  parsed <- jsonlite::fromJSON(json)
  expect_true(!is.null(parsed$source))
  expect_true(!is.null(parsed$environment))
})

test_that("provenance_to_json writes to file", {
  s <- make_test_survey()
  path <- tempfile(fileext = ".json")
  provenance_to_json(s$provenance, path)
  expect_true(file.exists(path))
  parsed <- jsonlite::fromJSON(path)
  expect_equal(parsed$source$initial_n, 10)
})

test_that("provenance_diff detects differences", {
  s1 <- make_test_survey(50)
  s1 <- step_filter(s1, age >= 30)
  s1 <- bake_steps(s1)

  s2 <- make_test_survey(100)
  s2 <- step_filter(s2, age >= 30)
  s2 <- bake_steps(s2)

  diff_result <- provenance_diff(s1$provenance, s2$provenance)
  expect_s3_class(diff_result, "metasurvey_provenance_diff")
  expect_true(!is.null(diff_result$final_n))
})

test_that("provenance print method works", {
  s <- make_test_survey()
  s <- step_compute(s, age2 = age * 2)
  s <- bake_steps(s)
  expect_output(print(s$provenance), "Provenance")
  expect_output(print(s$provenance), "Pipeline")
})

test_that("print.metasurvey_provenance_diff shows comparison output", {
  s1 <- make_test_survey(50)
  s1 <- step_filter(s1, age >= 30)
  s1 <- bake_steps(s1)

  s2 <- make_test_survey(100)
  s2 <- step_filter(s2, age >= 30)
  s2 <- bake_steps(s2)

  diff_result <- provenance_diff(s1$provenance, s2$provenance)
  expect_output(print(diff_result), "Provenance Diff")
  expect_output(print(diff_result), "Final N")
  expect_output(print(diff_result), "Steps")
})

test_that("provenance survives shallow_clone", {
  s <- make_test_survey()
  s2 <- s$shallow_clone()
  expect_true(!is.null(s2$provenance))
  expect_s3_class(s2$provenance, "metasurvey_provenance")
})

test_that("workflow result has provenance attribute", {
  s <- make_test_survey(50)
  result <- workflow(
    list(s),
    survey::svymean(~age, na.rm = TRUE),
    estimation_type = "annual"
  )
  prov <- provenance(result)
  expect_true(!is.null(prov))
  expect_true(!is.null(prov$estimation$timestamp))
  expect_equal(prov$estimation$estimation_type, "annual")
})
