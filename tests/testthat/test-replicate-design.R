# Regression tests for svrepdesign construction in ensure_design():
# the design must use ALL replicate columns (scale/rscales computed with
# the real B), not a hardcoded subset of the replicate file.

make_replicate_survey <- function(n = 200, B = 50, seed = 42) {
  set.seed(seed)
  dt <- data.table::data.table(
    id = seq_len(n),
    x = rnorm(n),
    w = runif(n, 0.5, 2)
  )
  rep_dt <- data.table::data.table(id = seq_len(n))
  for (b in seq_len(B)) {
    rep_dt[[paste0("wr", b)]] <- dt$w * rexp(n)
  }
  rep_path <- tempfile(fileext = ".csv")
  data.table::fwrite(rep_dt, rep_path)

  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = add_replicate(
      weight = "w",
      replicate_pattern = "wr[0-9]+",
      replicate_path = rep_path,
      replicate_id = c("id" = "id"),
      replicate_type = "bootstrap"
    ))
  )
  list(svy = svy, data = dt, replicates = rep_dt)
}

test_that("ensure_design uses all replicate columns (B > 10)", {
  B <- 50
  obj <- make_replicate_survey(B = B)
  obj$svy$ensure_design()
  design <- obj$svy$design$annual

  reference <- survey::svrepdesign(
    weights = ~w,
    data = merge(obj$data, obj$replicates, by = "id"),
    repweights = "wr[0-9]+",
    type = "bootstrap"
  )

  expect_equal(ncol(design$repweights), B)
  expect_length(design$rscales, B)
  expect_equal(design$scale, reference$scale)
  expect_equal(design$rscales, reference$rscales)
})

test_that("replicate design SEs match a direct svrepdesign", {
  obj <- make_replicate_survey(B = 50)
  obj$svy$ensure_design()
  design <- obj$svy$design$annual

  reference <- survey::svrepdesign(
    weights = ~w,
    data = merge(obj$data, obj$replicates, by = "id"),
    repweights = "wr[0-9]+",
    type = "bootstrap"
  )

  est <- survey::svymean(~x, design)
  est_ref <- survey::svymean(~x, reference)

  expect_equal(as.numeric(coef(est)), as.numeric(coef(est_ref)))
  expect_equal(
    as.numeric(survey::SE(est)),
    as.numeric(survey::SE(est_ref))
  )
})

test_that("ensure_design works with fewer than 10 replicates", {
  B <- 5
  obj <- make_replicate_survey(B = B)

  expect_no_error(obj$svy$ensure_design())
  design <- obj$svy$design$annual
  expect_equal(ncol(design$repweights), B)
  expect_length(design$rscales, B)
  expect_no_error(survey::svymean(~x, design))
})
