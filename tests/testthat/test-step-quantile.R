# Tests for step_quantile(): weighted quantile groups

test_that("weighted_quantile matches the weight-expansion workaround", {
  set.seed(1)
  x <- round(runif(200, 100, 5000), 2)
  w <- sample(1:50, 200, replace = TRUE)
  probs <- c(0.2, 0.4, 0.6, 0.8)

  direct <- weighted_quantile(x, w, probs)
  expanded <- unname(quantile(rep(x, times = w), probs = probs, type = 1))

  expect_equal(unname(direct), expanded)
})

test_that("weighted_quantile matches survey::svyquantile (qrule = math)", {
  set.seed(2)
  d <- data.frame(
    x = round(runif(500, 100, 5000), 2),
    w = round(runif(500, 0.5, 30), 4)
  )
  probs <- c(0.25, 0.5, 0.75)

  des <- survey::svydesign(ids = ~1, weights = ~w, data = d)
  svyq <- survey::svyquantile(~x, des, quantiles = probs, qrule = "math")
  expected <- unname(coef(svyq))

  direct <- unname(weighted_quantile(d$x, d$w, probs))

  expect_equal(direct, expected)
})

test_that("weighted_quantile drops NAs and non-positive weights", {
  x <- c(1, 2, 3, 4, NA, 100)
  w <- c(1, 1, 1, 1, 1, 0)
  expect_equal(unname(weighted_quantile(x, w, 0.5)), 2)
  expect_equal(weighted_quantile(NA_real_, 1, c(0.2, 0.8)), rep(NA_real_, 2))
})

test_that("step_quantile assigns balanced groups with uniform weights", {
  dt <- data.table::data.table(id = 1:100, income = 1:100, w = 1)
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )

  svy <- step_quantile(svy, income_q, income, n = 5)
  d <- get_data(svy)

  expect_true("income_q" %in% names(d))
  expect_equal(sort(unique(d$income_q)), 1:5)
  expect_equal(unname(table(d$income_q)), rep(20L, 5), ignore_attr = TRUE)
  # group boundaries: 1-20 -> 1, 21-40 -> 2, ...
  expect_equal(d$income_q, rep(1:5, each = 20))
})

test_that("step_quantile respects the weights", {
  # heavy weights on low values shift the breaks down
  dt <- data.table::data.table(
    id = 1:10, x = 1:10, w = c(rep(10, 5), rep(1, 5))
  )
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )
  svy <- step_quantile(svy, xq, x, n = 2)
  d <- get_data(svy)

  # weighted median = 3 (cumw/55 = 0.545 at x = 3)
  expect_equal(d$xq, c(1, 1, 1, 2, 2, 2, 2, 2, 2, 2))
})

test_that("step_quantile works with .by groups", {
  dt <- data.table::data.table(
    id = 1:20,
    g = rep(c("a", "b"), each = 10),
    x = c(1:10, 101:110),
    w = 1
  )
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )
  svy <- step_quantile(svy, xq, x, n = 2, .by = "g")
  d <- get_data(svy)

  # each group has its own median: both halves split 5/5
  expect_equal(d[g == "a", xq], rep(1:2, each = 5))
  expect_equal(d[g == "b", xq], rep(1:2, each = 5))
})

test_that("step_quantile propagates NA in x to NA group", {
  dt <- data.table::data.table(id = 1:6, x = c(1, 2, 3, 4, 5, NA), w = 1)
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )
  svy <- step_quantile(svy, xq, x, n = 2)
  d <- get_data(svy)
  expect_true(is.na(d$xq[6]))
  expect_false(anyNA(d$xq[1:5]))
})

test_that("step_quantile accepts character new_var/x and explicit weight", {
  dt <- data.table::data.table(id = 1:10, x = 1:10, w2 = 1, w = 99)
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )
  svy <- step_quantile(svy, "xq", "x", n = 2, weight = "w2")
  d <- get_data(svy)
  expect_equal(d$xq, rep(1:2, each = 5))
})

test_that("step_quantile records an executed step (bake = TRUE)", {
  svy <- make_test_survey(50)
  svy <- step_quantile(svy, income_q, income, n = 4, comment = "Quartiles")

  steps <- get_steps(svy)
  expect_length(steps, 1)
  step <- steps[[1]]
  expect_equal(step$type, "step_quantile")
  expect_true(step$bake)
  expect_equal(step$new_var, "income_q")
  expect_true(all(c("income", "w") %in% step$depends_on))
  expect_equal(step$comment, "Quartiles")

  # bake_steps skips executed steps: data unchanged
  before <- data.table::copy(get_data(svy))
  svy <- bake_steps(svy)
  expect_equal(get_data(svy), before)
})

test_that("step_quantile can be re-baked from a lazy step (bake_step path)", {
  svy <- make_test_survey(50)
  svy <- step_quantile(svy, income_q, income, n = 5)
  expected <- get_data(svy)$income_q

  # simulate a deserialized step: drop the column and mark as not baked
  d <- get_data(svy)
  d[, income_q := NULL]
  svy$set_data(d)
  svy$steps[[1]]$bake <- FALSE

  svy <- bake_steps(svy)
  expect_equal(get_data(svy)$income_q, expected)
  # no duplicate step was recorded
  expect_length(get_steps(svy), 1)
})

test_that("step_quantile validates its inputs", {
  svy <- make_test_survey(10)
  expect_error(step_quantile(svy, xq, nope, n = 5), "not found")
  expect_error(step_quantile(svy, xq, income, n = 1), "integer >= 2")
  expect_error(step_quantile(svy, xq, income, n = 2.5), "integer >= 2")
  expect_error(
    step_quantile(svy, xq, income, n = 5, weight = "nope"),
    "not found"
  )
})

test_that("step_quantile errors on non-numeric x", {
  dt <- data.table::data.table(id = 1:5, x = letters[1:5], w = 1)
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )
  expect_error(step_quantile(svy, xq, x, n = 2), "must be numeric")
})

test_that("step_quantile applies to RotativePanelSurvey levels", {
  panel <- make_test_panel()
  panel <- step_quantile(panel, income_q, income, n = 4)
  d <- get_data(panel$implantation)
  expect_true("income_q" %in% names(d))
  expect_equal(sort(unique(d$income_q)), 1:4)
})

test_that("step_quantile with tied breaks yields fewer groups without error", {
  dt <- data.table::data.table(id = 1:10, x = rep(1, 10), w = 1)
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )
  svy <- step_quantile(svy, xq, x, n = 5)
  expect_equal(unique(get_data(svy)$xq), 1L)
})

test_that("step_quantile quintiles have ~20% weighted share each", {
  set.seed(7)
  dt <- data.table::data.table(
    id = 1:2000,
    y = rlnorm(2000, 10, 0.8),
    w = round(runif(2000, 0.5, 30), 4)
  )
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "w")
  )
  svy <- step_quantile(svy, yq, y, n = 5)
  d <- get_data(svy)
  shares <- d[, .(w = sum(w)), keyby = yq][, w / sum(w)]
  expect_length(shares, 5)
  expect_true(all(abs(shares - 0.2) < 0.01))
})

test_that("step_quantile matches svyquantile on ECH 2023 data", {
  skip_on_cran()
  pkg_root <- normalizePath(test_path("..", ".."), mustWork = FALSE)
  ech_path <- file.path(
    pkg_root, "example-data", "ech", "ech_2023",
    "ECH_implantacion_2023.rds"
  )
  skip_if_not(file.exists(ech_path), "ECH 2023 data not available")

  d <- data.table::as.data.table(readRDS(ech_path))
  d <- d[, .(ID, W_ANO, y_pc = HT11 / HT19)]
  hh <- unique(d, by = "ID")

  svy <- Survey$new(
    data = data.table::copy(hh), edition = "2023", type = "ech",
    psu = NULL, engine = "data.table", weight = add_weight(annual = "W_ANO")
  )
  svy <- step_quantile(svy, quintil, y_pc, n = 5)

  probs <- c(0.2, 0.4, 0.6, 0.8)
  des <- survey::svydesign(ids = ~1, weights = ~W_ANO, data = hh)
  expected <- unname(coef(
    survey::svyquantile(~y_pc, des, quantiles = probs, qrule = "math")
  ))
  direct <- unname(weighted_quantile(hh$y_pc, hh$W_ANO, probs))
  expect_equal(direct, expected)

  # each quintile holds ~20% of the household weight
  dq <- get_data(svy)
  shares <- dq[, .(w = sum(W_ANO)), keyby = quintil][, w / sum(w)]
  expect_true(all(abs(shares - 0.2) < 0.002))
})
