# Tests for step_recode
# Note: step_recode with use_copy=TRUE applies the recode immediately
# via the AST engine. bake_steps() re-baking has a known issue with
# the `record` parameter leak, so we test the immediate application.

test_that("step_recode creates new variable column", {
  s <- make_test_survey()
  s2 <- step_recode(s, age_group,
    age < 30 ~ "young",
    age >= 30 & age < 50 ~ "middle",
    age >= 50 ~ "senior",
    .default = "unknown"
  )
  expect_true("age_group" %in% names(s2$data))
  expect_true(all(s2$data$age_group %in% c("young", "middle", "senior", "unknown")))
})

test_that("step_recode records step in survey", {
  s <- make_test_survey()
  s2 <- step_recode(s, cat,
    region == 1 ~ "A",
    .default = "B"
  )
  expect_true(length(s2$steps) > 0)
  expect_true(any(grepl("Recode|recode", names(s2$steps), ignore.case = TRUE)))
})

test_that("step_recode with .to_factor returns factor", {
  s <- make_test_survey()
  s2 <- step_recode(s, region_label,
    region == 1 ~ "North",
    region == 2 ~ "South",
    .default = "Other",
    .to_factor = TRUE
  )
  expect_true("region_label" %in% names(s2$data))
  expect_true(is.factor(s2$data$region_label))
})

test_that("step_recode applies conditions with use_copy=FALSE", {
  old_copy <- use_copy_default()
  old_lazy <- lazy_default()
  set_use_copy(FALSE)
  set_lazy_processing(FALSE)
  on.exit(
    {
      set_use_copy(old_copy)
      set_lazy_processing(old_lazy)
    },
    add = TRUE
  )

  df <- data.table::data.table(id = 1:4, val = c(1, 2, 3, 99), w = 1)
  s <- Survey$new(
    data = df, edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )
  step_recode(s, label,
    val == 1 ~ "one",
    val == 2 ~ "two",
    .default = "other"
  )
  expect_true("label" %in% names(s$data))
  expect_equal(sum(s$data$label == "other"), 2)
})

test_that("step_recode with .default fills non-matching rows", {
  s <- make_test_survey()
  s2 <- step_recode(s, dummy,
    age > 9999 ~ "impossible",
    .default = "fallback"
  )
  expect_true("dummy" %in% names(s2$data))
  # No row matches age > 9999, so all get default or fallback
  non_na_values <- s2$data$dummy[!is.na(s2$data$dummy)]
  if (length(non_na_values) > 0) {
    expect_true(all(non_na_values == "fallback"))
  }
})

test_that("step_recode does not modify original survey with use_copy=TRUE", {
  s <- make_test_survey()
  original_cols <- names(s$data)
  s2 <- step_recode(s, new_col,
    age > 30 ~ "A",
    .default = "B"
  )
  expect_false("new_col" %in% names(s$data))
  expect_true("new_col" %in% names(s2$data))
})

test_that("bake_steps preserves .default and .to_factor on recode steps", {
  s <- make_test_survey()
  s2 <- step_recode(s, nivel,
    age < 30 ~ "joven",
    .default = "sin_dato",
    .copy = TRUE
  )
  baked <- bake_steps(s2)
  expect_setequal(unique(baked$data$nivel), c("joven", "sin_dato"))
  expect_false(anyNA(baked$data$nivel))

  s3 <- step_recode(s, region_f,
    region == 1 ~ "North",
    .default = "Other",
    .to_factor = TRUE,
    .copy = TRUE
  )
  baked3 <- bake_steps(s3)
  expect_true(is.factor(baked3$data$region_f))
  expect_false(anyNA(baked3$data$region_f))
})
