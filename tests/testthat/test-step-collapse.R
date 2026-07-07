# Tests for step_collapse(): collapse to one row per group (household)

make_hh_survey <- function() {
  dt <- data.table::data.table(
    hh = c(1, 1, 1, 2, 2, 3),
    person = 1:6,
    receives = c(0, 1, 0, 0, 0, 1),
    name = c("a", "b", "c", "d", "e", "f"),
    w = c(2, 2, 2, 3, 3, 1.5)
  )
  Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )
}

test_that("step_collapse rule = 'first' keeps the first row per group", {
  svy <- step_collapse(make_hh_survey(), by = "hh", rule = "first")
  d <- get_data(svy)

  expect_equal(nrow(d), 3)
  expect_equal(d$hh, c(1, 2, 3))
  expect_equal(d$person, c(1L, 4L, 6L))
  expect_equal(d$receives, c(0, 0, 1))
  expect_equal(d$w, c(2, 3, 1.5))
})

test_that("step_collapse rule = 'max' propagates dummies to the household", {
  svy <- step_collapse(make_hh_survey(), by = "hh", rule = "max")
  d <- get_data(svy)

  expect_equal(nrow(d), 3)
  # household 1 has one member with receives = 1
  expect_equal(d[order(hh), receives], c(1, 0, 1))
  # weight is constant within household and preserved
  expect_equal(d[order(hh), w], c(2, 3, 1.5))
  # non-numeric columns take the first value of the group
  expect_equal(d[order(hh), name], c("a", "d", "f"))
})

test_that("step_collapse rule = 'min' aggregates numeric columns", {
  svy <- step_collapse(make_hh_survey(), by = "hh", rule = "min")
  d <- get_data(svy)
  expect_equal(d[order(hh), person], c(1L, 4L, 6L))
  expect_equal(d[order(hh), receives], c(0, 0, 1))
})

test_that("step_collapse handles all-NA groups without warnings", {
  dt <- data.table::data.table(
    hh = c(1, 1, 2), x = c(NA_real_, NA_real_, 5), w = 1
  )
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )
  expect_no_warning(svy <- step_collapse(svy, by = "hh", rule = "max"))
  d <- get_data(svy)
  expect_true(is.na(d[hh == 1, x]))
  expect_equal(d[hh == 2, x], 5)
})

test_that("step_collapse warns when the weight varies within a group", {
  dt <- data.table::data.table(
    hh = c(1, 1, 2), x = 1:3, w = c(2, 5, 3)
  )
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )
  expect_warning(
    step_collapse(svy, by = "hh", rule = "first"),
    "varies within some groups"
  )
})

test_that("step_collapse records an executed step and invalidates design", {
  svy <- make_hh_survey()
  svy <- step_collapse(svy, by = "hh", rule = "max", comment = "To household")

  steps <- get_steps(svy)
  expect_length(steps, 1)
  step <- steps[[1]]
  expect_equal(step$type, "step_collapse")
  expect_true(step$bake)
  expect_equal(step$depends_on, "hh")
  expect_equal(step$exprs, list(by = "hh", rule = "max"))
  expect_false(svy$design_initialized)

  # bake_steps skips executed steps: no double collapse
  svy <- bake_steps(svy)
  expect_equal(nrow(get_data(svy)), 3)
})

test_that("step_collapse can be re-baked from a lazy step (bake_step path)", {
  svy <- make_hh_survey()
  original <- data.table::copy(get_data(svy))
  svy <- step_collapse(svy, by = "hh", rule = "max")
  expected <- data.table::copy(get_data(svy))

  # simulate a deserialized step on the original person-level data
  svy$set_data(original)
  svy$steps[[1]]$bake <- FALSE

  svy <- bake_steps(svy)
  expect_equal(get_data(svy), expected)
  expect_length(get_steps(svy), 1)
})

test_that("household-level estimation after collapse uses household weights", {
  svy <- step_collapse(make_hh_survey(), by = "hh", rule = "max")
  d <- get_data(svy)

  # share of households receiving the transfer, weighted by household
  expected_share <- d[, sum(w * receives) / sum(w)]

  des <- survey::svydesign(ids = ~1, weights = ~w, data = d)
  est <- unname(coef(survey::svymean(~receives, des)))
  expect_equal(est, expected_share)

  # equals the UMAD pattern: propagate max per household + distinct
  svy2 <- make_hh_survey()
  svy2 <- step_compute(svy2, h_receives = max(receives), .by = "hh")
  d2 <- unique(get_data(svy2), by = "hh")
  expect_equal(d2[, sum(w * h_receives) / sum(w)], expected_share)
})

test_that("step_collapse validates its inputs", {
  svy <- make_hh_survey()
  expect_error(step_collapse(svy, by = character(0)), "non-empty character")
  expect_error(step_collapse(svy, by = 1), "non-empty character")
  expect_error(step_collapse(svy, by = "nope"), "not found")
  expect_error(step_collapse(svy, by = "hh", rule = "sum"))
})

test_that("step_collapse applies to RotativePanelSurvey levels", {
  panel <- make_test_panel()
  d0 <- get_data(panel$implantation)
  d0[, hh := rep(1:10, each = 2)]
  d0[, w := rep(round(runif(10, 1, 3), 2), each = 2)]
  panel$implantation$set_data(d0)

  panel <- step_collapse(panel, by = "hh", rule = "first")
  expect_equal(nrow(get_data(panel$implantation)), 10)
})

test_that("collapse + quantile: household income quintiles pipeline", {
  set.seed(11)
  n_hh <- 300
  sizes <- sample(1:5, n_hh, replace = TRUE)
  dt <- data.table::data.table(
    hh = rep(seq_len(n_hh), times = sizes),
    y = round(rlnorm(sum(sizes), 9, 0.7)),
    w = rep(round(runif(n_hh, 1, 40), 2), times = sizes)
  )
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )

  svy <- svy |>
    step_compute(persona = 1) |>
    step_compute(y_hh = sum(y), n_hh = sum(persona), .by = "hh") |>
    step_compute(y_pc = y_hh / n_hh) |>
    step_collapse(by = "hh", rule = "first") |>
    step_quantile(quintil, y_pc, n = 5)

  d <- get_data(svy)
  expect_equal(nrow(d), n_hh)
  shares <- d[, .(w = sum(w)), keyby = quintil][, w / sum(w)]
  expect_length(shares, 5)
  expect_true(all(abs(shares - 0.2) < 0.05))
})
