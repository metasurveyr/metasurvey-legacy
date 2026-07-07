# Annual aggregator for rotating panels (issue #223):
# workflow() on a RotativePanelSurvey with monthly follow-ups estimates
# each month with the monthly weight, averages the point estimates and
# combines the SEs assuming independence between months (UMAD annual
# estimator for ECH 2021+).

make_panel_month <- function(month, n = 200, year = 2023) {
  dt <- data.table::data.table(
    x = stats::rnorm(n, mean = 50),
    w = rep(1, n)
  )
  Survey$new(
    data = dt,
    edition = sprintf("%d-%02d", year, month),
    type = "ech",
    psu = NULL,
    engine = "data.table",
    weight = add_weight(monthly = "w")
  )
}

make_panel_with_months <- function(months = 1:3, n = 200, year = 2023) {
  panel <- make_test_panel()
  panel$follow_up <- lapply(
    months,
    make_panel_month,
    n = n,
    year = year
  )
  panel
}

test_that("workflow on panel averages monthly estimates into annual", {
  set.seed(223)
  k <- 4L
  panel <- make_panel_with_months(seq_len(k), n = 500)

  annual <- workflow(
    panel,
    survey::svymean(~x, na.rm = TRUE),
    estimation_type = "annual:mean_of_months"
  )

  per_month <- data.table::rbindlist(
    lapply(panel$follow_up, function(s) {
      workflow(
        list(s),
        survey::svymean(~x, na.rm = TRUE),
        estimation_type = "monthly"
      )
    })
  )

  expect_s3_class(annual, "data.table")
  expect_equal(nrow(annual), 1L)
  expect_equal(annual$type, "2023")
  expect_equal(annual$value, mean(per_month$value))
  # Independence between months: se = sqrt(mean(var) / k)
  expect_equal(annual$se, sqrt(mean(per_month$se^2) / k))
  expect_equal(annual$cv, annual$se / annual$value)

  z <- stats::qnorm(0.975)
  expect_equal(annual$confint_lower, annual$value - z * annual$se)
  expect_equal(annual$confint_upper, annual$value + z * annual$se)
  expect_true("evaluate" %in% names(annual))
  expect_true(annual$evaluate %in% c(
    "Excellent", "Very good", "Good", "Acceptable",
    "Use with caution", "Do not publish"
  ))
})

test_that("workflow on panel groups follow-ups by year", {
  set.seed(224)
  panel <- make_test_panel()
  panel$follow_up <- c(
    lapply(1:2, make_panel_month, n = 200, year = 2023),
    lapply(1:2, make_panel_month, n = 200, year = 2024)
  )

  result <- workflow(
    panel,
    survey::svymean(~x, na.rm = TRUE),
    estimation_type = "annual:mean_of_months"
  )

  expect_equal(nrow(result), 2L)
  expect_setequal(result$type, c("2023", "2024"))
})

test_that("workflow on panel accepts rho for correlated months", {
  set.seed(225)
  k <- 3L
  panel <- make_panel_with_months(seq_len(k))

  annual_rho <- workflow(
    panel,
    survey::svymean(~x, na.rm = TRUE),
    rho = 0.5,
    estimation_type = "annual:mean_of_months"
  )
  annual_iid <- workflow(
    panel,
    survey::svymean(~x, na.rm = TRUE),
    estimation_type = "annual:mean_of_months"
  )

  expect_equal(
    annual_rho$se,
    annual_iid$se * sqrt(1 + 0.5 * (k - 1))
  )
})

test_that("workflow on panel respects the confidence level", {
  set.seed(226)
  panel <- make_panel_with_months(1:3)

  result <- workflow(
    panel,
    survey::svymean(~x, na.rm = TRUE),
    estimation_type = "annual:mean_of_months",
    level = 0.90
  )

  z <- stats::qnorm(0.95)
  expect_equal(result$confint_lower, result$value - z * result$se)
  expect_equal(result$confint_upper, result$value + z * result$se)
})

test_that("workflow on panel rejects unsupported estimation types", {
  panel <- make_panel_with_months(1:2)

  expect_error(
    workflow(
      panel,
      survey::svymean(~x, na.rm = TRUE),
      estimation_type = "monthly"
    ),
    "annual:mean_of_months"
  )
  expect_error(
    workflow(
      panel,
      survey::svymean(~x, na.rm = TRUE),
      estimation_type = "annual:quarterly"
    ),
    "annual:mean_of_months"
  )
})

test_that("workflow on panel without follow-ups errors clearly", {
  panel <- make_test_panel()

  expect_error(
    workflow(
      panel,
      survey::svymean(~x, na.rm = TRUE),
      estimation_type = "annual:mean_of_months"
    ),
    "follow-up"
  )
})

test_that("annual:mean_of_months alias works on PoolSurvey", {
  set.seed(227)
  surveys <- lapply(1:3, make_panel_month, n = 300)
  pool <- PoolSurvey$new(list(annual = list("2023" = surveys)))

  via_alias <- workflow(
    pool,
    survey::svymean(~x, na.rm = TRUE),
    estimation_type = "annual:mean_of_months"
  )
  via_monthly <- workflow(
    pool,
    survey::svymean(~x, na.rm = TRUE),
    estimation_type = "annual:monthly"
  )

  expect_equal(via_alias$value, via_monthly$value)
  expect_equal(via_alias$se, via_monthly$se)
})

test_that(".edition_year handles Date, partial and plain editions", {
  expect_equal(metasurvey:::.edition_year(as.Date("2023-05-01")), "2023")
  expect_equal(metasurvey:::.edition_year("2024-11-01"), "2024")
  expect_equal(metasurvey:::.edition_year("2023"), "2023")
  expect_equal(metasurvey:::.edition_year("ech_2022"), "2022")
})
