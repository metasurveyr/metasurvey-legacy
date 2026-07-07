# Differential tests for the metatable passthrough executor
# (design/metatable-rfc.md, section 5, issue #214): the same pipeline
# executed with the data.table engine and with the metatable engine
# must be identical() on get_data() and on the workflow() result.
# make_test_survey() is deterministic (set.seed inside), so each run
# starts from byte-identical data.

run_with_engine <- function(engine, pipeline) {
  old_engine <- getOption("metasurvey.engine")
  on.exit(options(metasurvey.engine = old_engine), add = TRUE)
  options(metasurvey.engine = engine)
  pipeline()
}

# Timestamps and duration_ms in the provenance / captured workflow
# attributes are non-deterministic between runs and explicitly outside
# the byte-to-byte contract (RFC section 5, point 4)
strip_estimation_attrs <- function(result) {
  attr(result, "provenance") <- NULL
  attr(result, "workflow") <- NULL
  result
}

# Deterministic view of the provenance entries (drop timing fields)
provenance_core <- function(svy) {
  lapply(svy$provenance$steps, function(s) {
    s[c("type", "name", "expression", "n_before", "n_after")]
  })
}

expect_engine_parity <- function(pipeline) {
  ref <- run_with_engine("data.table", pipeline)
  alt <- run_with_engine("metatable", pipeline)
  expect_identical(get_data(alt), get_data(ref))
  expect_identical(provenance_core(alt), provenance_core(ref))
  expect_identical(
    vapply(alt$steps, function(s) s$bake, logical(1)),
    vapply(ref$steps, function(s) s$bake, logical(1))
  )
  invisible(list(ref = ref, alt = alt))
}

test_that("metatable is in the engine whitelist and sets cleanly", {
  expect_true("metatable" %in% show_engines())
  old <- getOption("metasurvey.engine")
  on.exit(options(metasurvey.engine = old), add = TRUE)
  # internal engine: no requireNamespace() warning expected
  expect_no_warning(
    expect_message(set_engine("metatable"), "Engine: metatable")
  )
  expect_identical(get_engine(), "metatable")
})

test_that("parity: pipeline mixing every step type", {
  pipeline <- function() {
    lookup <- data.table::data.table(
      region = 1:4,
      income = c(10, 20, 30, 40), # overlaps with survey column
      region_name = c("N", "S", "E", "W")
    )
    svy <- make_test_survey(n = 30)
    svy <- step_compute(svy, income_pc = income / 2)
    svy <- step_recode(
      svy, age_group,
      age < 30 ~ "young",
      age < 50 ~ "adult",
      .default = "senior",
      .to_factor = TRUE
    )
    svy <- step_join(
      svy, lookup,
      by = "region", type = "left", suffixes = c("", "_r")
    )
    svy <- step_rename(svy, edad = age)
    svy <- step_remove(svy, status)
    svy <- step_filter(svy, edad >= 20)
    svy <- step_validate(svy, edad >= 20)
    bake_steps(svy)
  }
  res <- expect_engine_parity(pipeline)
  dat <- get_data(res$alt)
  # join suffix resolved the overlap, meta steps applied
  expect_true(all(c("income", "income_r", "region_name") %in% names(dat)))
  expect_true("edad" %in% names(dat))
  expect_false("status" %in% names(dat))
  expect_s3_class(dat$age_group, "factor")
})

test_that("parity: trap case filter + compute(.by =) (RFC section 4.3)", {
  pipeline <- function() {
    svy <- make_test_survey(n = 40)
    svy <- step_filter(svy, age >= 30) # deferred (bake = FALSE)
    # eager: runs at creation, BEFORE the pending filter
    svy <- step_compute(svy, mean_income = mean(income), .by = "region")
    bake_steps(svy)
  }
  res <- expect_engine_parity(pipeline)
  dat <- get_data(res$alt)
  expect_true(all(dat$age >= 30))
  # documented semantics of the current engine, reproduced byte to
  # byte: the grouped mean is computed over the UNFILTERED population
  # (expect_equal: the oracle recomputation may differ in the last
  # floating-point bits from compute()'s eval() path; the byte-to-byte
  # contract between engines is asserted by expect_engine_parity above)
  full <- get_data(make_test_survey(n = 40))
  expected <- full[, list(expected = mean(income)), by = "region"]
  merged <- merge(dat, expected, by = "region")
  expect_equal(merged$mean_income, merged$expected)
})

test_that("parity: recode with non-literal .default and .to_factor", {
  pipeline <- function() {
    fallback <- "other"
    svy <- make_test_survey(n = 25)
    svy <- step_recode(
      svy, status_rec,
      status == 1 ~ "active",
      status == 2 ~ "inactive",
      .default = fallback,
      .to_factor = TRUE
    )
    svy <- step_filter(svy, x >= 3)
    bake_steps(svy)
  }
  res <- expect_engine_parity(pipeline)
  dat <- get_data(res$alt)
  expect_s3_class(dat$status_rec, "factor")
  expect_true("other" %in% levels(dat$status_rec))
})

test_that("parity: lazy remove/rename with a filter on the new name", {
  pipeline <- function() {
    svy <- make_test_survey(n = 20)
    svy <- step_rename(svy, edad = age, ingreso = income)
    svy <- step_remove(svy, y, group)
    svy <- step_filter(svy, edad < 60)
    bake_steps(svy)
  }
  res <- expect_engine_parity(pipeline)
  dat <- get_data(res$alt)
  expect_true(all(c("edad", "ingreso") %in% names(dat)))
  expect_false(any(c("y", "group", "age", "income") %in% names(dat)))
  expect_true(all(dat$edad < 60))
})

test_that("parity: workflow() estimations are identical between engines", {
  pipeline <- function() {
    svy <- make_test_survey(n = 50)
    svy <- step_compute(svy, log_income = log(income))
    svy <- step_filter(svy, age >= 25)
    svy <- bake_steps(svy)
    workflow(
      list(svy),
      survey::svymean(~log_income, na.rm = TRUE),
      survey::svytotal(~income, na.rm = TRUE),
      estimation_type = "annual"
    )
  }
  ref <- strip_estimation_attrs(run_with_engine("data.table", pipeline))
  alt <- strip_estimation_attrs(run_with_engine("metatable", pipeline))
  expect_identical(alt, ref)
})

test_that("parity: unknown step type errors at the same node with the same state", {
  # A step type outside the bake_step() whitelist must produce the SAME
  # error message, at the SAME node position (after the previous
  # pending steps ran) and leave the SAME partial state in both engines
  # (contract section 5.2): the metatable plan must not abort the bake
  # at plan time with the classify_step() error.
  make_unknown_step <- function() {
    Step$new(
      name = "weird", edition = "2023", survey_type = "test",
      type = "frobnicate", new_var = NULL, exprs = list(), call = NULL,
      svy_before = NULL, default_engine = "data.table",
      depends_on = list(), comment = NULL, bake = FALSE
    )
  }
  run <- function(engine) {
    run_with_engine(engine, function() {
      old_copy <- set_use_copy(FALSE)
      on.exit(options(metasurvey.use_copy = old_copy), add = TRUE)
      svy <- make_test_survey(n = 10)
      svy <- step_filter(svy, age >= 20)
      svy$add_step(make_unknown_step())
      err <- tryCatch(
        {
          bake_steps(svy)
          NULL
        },
        error = function(e) conditionMessage(e)
      )
      list(
        error = err,
        data = get_data(svy),
        bakes = vapply(svy$steps, function(s) s$bake, logical(1)),
        provenance = provenance_core(svy)
      )
    })
  }
  ref <- run("data.table")
  alt <- run("metatable")
  # same message (bake_step whitelist), not the plan-time classify one
  expect_match(ref$error, "Invalid step type: 'frobnicate'")
  expect_identical(alt$error, ref$error)
  # same partial state: the pending filter ran BEFORE the error in both
  expect_identical(alt$data, ref$data)
  expect_true(all(alt$data$age >= 20))
  expect_identical(alt$bakes, ref$bakes)
  expect_identical(alt$provenance, ref$provenance)
  expect_length(alt$provenance, 1L)
})

test_that("metatable bake marks steps and leaves no pending plan", {
  res <- run_with_engine("metatable", function() {
    svy <- make_test_survey(n = 15)
    svy <- step_filter(svy, age >= 18)
    svy <- step_validate(svy, age >= 18)
    bake_steps(svy)
  })
  expect_true(all(vapply(res$steps, function(s) s$bake, logical(1))))
  expect_length(explain(res)$nodes, 0)
})

test_that("bake_steps with no pending steps is a no-op under metatable", {
  res <- run_with_engine("metatable", function() {
    svy <- make_test_survey(n = 10)
    svy <- step_compute(svy, age2 = age * 2) # eager, already baked
    bake_steps(svy)
  })
  ref <- run_with_engine("data.table", function() {
    svy <- make_test_survey(n = 10)
    svy <- step_compute(svy, age2 = age * 2)
    bake_steps(svy)
  })
  expect_identical(get_data(res), get_data(ref))
})
