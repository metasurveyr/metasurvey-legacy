# Regression tests: recorded step calls must be portable regardless of
# how the pipeline was written (|>, %>% or step-by-step assignment).
# The svy argument is canonicalized to the placeholder `.` so that
# bake_recipes() substitutes the receiving survey instead of re-evaluating
# objects from the recipe author's session.

make_portability_survey <- function(seed = 1, n = 20) {
  set.seed(seed)
  dt <- data.table::data.table(
    id = seq_len(n),
    e28 = sample(10:80, n, replace = TRUE),
    w = runif(n, 0.5, 2)
  )
  Survey$new(
    data = dt, edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )
}

test_that("assignment-style pipelines record svy as placeholder", {
  ech0 <- make_portability_survey()
  ech0 <- step_compute(ech0, pea = as.integer(e28 >= 14))

  recorded <- get_steps(ech0)[[1]]$call
  expect_identical(recorded[["svy"]], quote(.))
  expect_false(grepl("ech0", deparse1(recorded), fixed = TRUE))
})

test_that("native pipe pipelines record svy as placeholder in every step", {
  svy <- make_portability_survey() |>
    step_compute(pea = as.integer(e28 >= 14)) |>
    step_compute(pea2 = pea * 2L)

  calls <- lapply(get_steps(svy), function(s) s$call)
  for (recorded in calls) {
    expect_identical(recorded[["svy"]], quote(.))
  }
  # No nested pipeline re-evaluation in the second step
  expect_false(grepl(
    "step_compute(svy = step_compute",
    deparse1(calls[[2]]),
    fixed = TRUE
  ))
})

test_that("recipes from |> pipelines bake on the receiving survey", {
  author_svy <- make_portability_survey(seed = 2) |>
    step_compute(pea = as.integer(e28 >= 14)) |>
    step_compute(pea2 = pea * 2L)

  rec <- steps_to_recipe(
    name = "portable", user = "test", svy = author_svy,
    description = "portability round-trip",
    steps = get_steps(author_svy)
  )

  file <- tempfile(fileext = ".json")
  suppressMessages(save_recipe(rec, file))
  rec2 <- read_recipe(file)

  target <- make_portability_survey(seed = 99)
  target_data <- data.table::copy(get_data(target))
  target <- add_recipe(target, rec2)

  # Simulate a fresh session: no author objects are reachable
  rm(author_svy)
  baked <- bake_recipes(target)
  baked_data <- get_data(baked)

  expect_true(all(c("pea", "pea2") %in% names(baked_data)))
  expect_equal(nrow(baked_data), nrow(target_data))
  # Values come from the RECEIVING survey's data, not the author's
  expect_identical(baked_data$pea, as.integer(target_data$e28 >= 14))
  expect_identical(baked_data$pea2, as.integer(target_data$e28 >= 14) * 2L)
})

test_that("assignment-style recipes bake without the author's objects", {
  author <- make_portability_survey(seed = 3)
  author <- step_compute(author, pea = as.integer(e28 >= 14))

  rec <- steps_to_recipe(
    name = "assign_style", user = "test", svy = author,
    description = "assignment-style portability",
    steps = get_steps(author)
  )

  target <- make_portability_survey(seed = 7)
  target_data <- data.table::copy(get_data(target))
  target <- add_recipe(target, rec)

  rm(author)
  baked <- bake_recipes(target)
  baked_data <- get_data(baked)

  expect_identical(baked_data$pea, as.integer(target_data$e28 >= 14))
  expect_length(get_steps(baked), 1)
})
