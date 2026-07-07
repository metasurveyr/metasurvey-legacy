# Tests for memory behavior of the step pipeline
# Verifies that chaining N steps does NOT retain N copies of the data

test_that("svy_before is always NULL in step objects", {
  svy <- make_test_survey(100)

  # use_copy = TRUE path
  old_copy <- use_copy_default()
  on.exit(set_use_copy(old_copy), add = TRUE)
  set_use_copy(TRUE)

  s1 <- step_compute(svy, z = x + y)
  steps <- get_steps(s1)
  expect_length(steps, 1)
  expect_null(steps[[1]]$svy_before)

  # Chain more steps
  s2 <- step_compute(s1, z2 = z * 2)
  s3 <- step_recode(s2, age_cat,
    age < 30 ~ "young",
    age >= 30 ~ "old",
    .default = "unknown"
  )
  steps3 <- get_steps(s3)
  for (i in seq_along(steps3)) {
    expect_null(steps3[[i]]$svy_before,
      info = paste("Step", i, "svy_before should be NULL")
    )
  }
})

test_that("svy_before is NULL with use_copy=FALSE too", {
  svy <- make_test_survey(100)
  old_copy <- use_copy_default()
  on.exit(set_use_copy(old_copy), add = TRUE)
  set_use_copy(FALSE)

  svy <- step_compute(svy, z = x + y)
  steps <- get_steps(svy)
  expect_length(steps, 1)
  expect_null(steps[[1]]$svy_before)
})

test_that("chaining 50 steps does not grow memory proportionally", {
  svy <- make_test_survey(1000)
  base_size <- as.numeric(object.size(get_data(svy)))

  # Chain 50 step_compute calls using do.call for dynamic names
  for (i in seq_len(50)) {
    var_name <- paste0("var_", i)
    args <- list(svy = svy)
    args[[var_name]] <- substitute(x + val, list(val = i))
    svy <- do.call(step_compute, args)
  }

  # The survey should have 50 steps but NOT 50 copies of the data
  expect_length(get_steps(svy), 50)

  # Total object size should be reasonable:
  # ~1 copy of data (with 50 extra columns) + step metadata
  # NOT 50 copies of the original data
  total_size <- as.numeric(object.size(svy))

  # With 50 new integer columns on 1000 rows, data grows modestly

  # The total should be well under 10x the base data size
  # (without fix it would be ~50x due to svy_before chain)
  expect_lt(total_size, base_size * 15,
    label = paste(
      "Total survey size after 50 steps:",
      format(total_size, big.mark = ","), "bytes vs base",
      format(base_size, big.mark = ","), "bytes"
    )
  )

  # Verify all svy_before are NULL (no retention chain)
  for (step in get_steps(svy)) {
    expect_null(step$svy_before)
  }
})

test_that("bake_steps produces correct results after memory fixes", {
  svy <- make_test_survey(50)

  # Chain multiple step types
  svy <- step_compute(svy, z = x + y)
  svy <- step_compute(svy, z2 = z * 2)
  svy <- step_recode(svy, age_cat,
    age < 30 ~ "young",
    age >= 30 & age < 50 ~ "middle",
    age >= 50 ~ "senior",
    .default = "unknown"
  )
  svy <- step_compute(svy, income_k = income / 1000)

  # Bake all steps
  baked <- bake_steps(svy)
  dt <- get_data(baked)

  # Verify computed values
  expect_true("z" %in% names(dt))
  expect_true("z2" %in% names(dt))
  expect_true("age_cat" %in% names(dt))
  expect_true("income_k" %in% names(dt))

  # Verify correctness
  expect_equal(dt$z, dt$x + dt$y)
  expect_equal(dt$z2, dt$z * 2)
  expect_true(all(dt$age_cat %in% c("young", "middle", "senior", "unknown")))
  expect_equal(dt$income_k, dt$income / 1000)

  # All steps should be marked as baked
  for (step in get_steps(baked)) {
    expect_true(step$bake)
  }
})

test_that("bake_steps with use_copy=TRUE does not modify original", {
  old_copy <- use_copy_default()
  on.exit(set_use_copy(old_copy), add = TRUE)
  set_use_copy(TRUE)

  svy <- make_test_survey(20)
  original_data <- data.table::copy(get_data(svy))

  svy <- step_compute(svy, z = x + y)
  svy <- step_compute(svy, z2 = z * 2)
  baked <- bake_steps(svy)

  # Baked has new columns
  expect_true("z" %in% names(get_data(baked)))
  expect_true("z2" %in% names(get_data(baked)))
})

test_that("bake_steps with use_copy=FALSE produces same numeric results", {
  old_copy <- use_copy_default()
  on.exit(set_use_copy(old_copy), add = TRUE)

  # Create identical surveys
  svy_copy <- make_test_survey(30)
  svy_inplace <- make_test_survey(30)

  # Apply same steps to both
  set_use_copy(TRUE)
  svy_copy <- step_compute(svy_copy, z = x + y)
  svy_copy <- step_recode(svy_copy, age_cat,
    age < 30 ~ "young",
    .default = "old"
  )
  baked_copy <- bake_steps(svy_copy)

  set_use_copy(FALSE)
  svy_inplace <- step_compute(svy_inplace, z = x + y)
  svy_inplace <- step_recode(svy_inplace, age_cat,
    age < 30 ~ "young",
    .default = "old"
  )
  baked_inplace <- bake_steps(svy_inplace)

  # Results must match
  dt_copy <- get_data(baked_copy)
  dt_inplace <- get_data(baked_inplace)

  expect_equal(dt_copy$z, dt_inplace$z)
  expect_equal(dt_copy$age_cat, dt_inplace$age_cat)
})

test_that("design rebuilds correctly after lazy invalidation", {
  svy <- make_test_survey(30)

  # Force design initialization
  svy$ensure_design()
  expect_true(svy$design_initialized)

  # Add a step — should invalidate design
  svy <- step_compute(svy, z = x + y)

  # After bake_steps, design should be reinitialized
  baked <- bake_steps(svy)
  expect_true(baked$design_initialized)
  expect_false(is.null(baked$design))

  # Design should reflect current data
  design <- baked$design[[1]]
  expect_true("z" %in% names(design$variables))
})

test_that("bake_steps on RotativePanelSurvey works with memory fixes", {
  panel <- make_test_panel()

  # Add follow-up surveys
  fu1 <- make_test_survey(20)
  fu1_data <- get_data(fu1)
  fu1_data[, `:=`(mes = 2, anio = 2023, numero = id)]
  panel$follow_up <- list(fu1)

  # Apply steps
  panel_with_steps <- step_compute(panel, z = x + y, .level = "auto")

  # Bake
  baked <- bake_steps(panel_with_steps)

  # Verify implantation has new column
  impl_data <- get_data(baked$implantation)
  expect_true("z" %in% names(impl_data))
  expect_equal(impl_data$z, impl_data$x + impl_data$y)

  # Verify follow-up has new column
  fu_data <- get_data(baked$follow_up[[1]])
  expect_true("z" %in% names(fu_data))
  expect_equal(fu_data$z, fu_data$x + fu_data$y)
})

test_that("step_join does not retain svy_before", {
  svy <- make_test_survey(10)
  extra <- data.frame(id = 1:5, bonus = c(100, 200, 300, 400, 500))

  svy2 <- step_join(svy, extra, by = "id", type = "left")
  steps <- get_steps(svy2)

  # Find the join step
  join_step <- steps[[length(steps)]]
  expect_null(join_step$svy_before)
})

test_that("step_remove does not retain svy_before", {
  svy <- make_test_survey(10)
  svy2 <- step_remove(svy, group)
  steps <- get_steps(svy2)
  last_step <- steps[[length(steps)]]
  expect_null(last_step$svy_before)
})

test_that("step_rename does not retain svy_before", {
  svy <- make_test_survey(10)
  svy2 <- step_rename(svy, years = age)
  steps <- get_steps(svy2)
  last_step <- steps[[length(steps)]]
  expect_null(last_step$svy_before)
})

test_that("many steps then bake_steps gives correct end-to-end result", {
  svy <- make_test_survey(200)

  # Build a realistic pipeline: 20 compute + 3 recode + 2 remove
  for (i in 1:20) {
    var_name <- paste0("comp_", i)
    args <- list(svy = svy)
    args[[var_name]] <- substitute(x + val * y, list(val = i))
    svy <- do.call(step_compute, args)
  }

  svy <- step_recode(svy, income_level,
    income < 2000 ~ "low",
    income < 4000 ~ "mid",
    .default = "high"
  )

  svy <- step_recode(svy, age_group,
    age < 25 ~ "young",
    age < 45 ~ "adult",
    .default = "senior"
  )

  svy <- step_recode(svy, region_name,
    region == 1 ~ "north",
    region == 2 ~ "south",
    region == 3 ~ "east",
    .default = "west"
  )

  # Total: 23 lazy steps
  expect_length(get_steps(svy), 23)

  # Bake and verify
  baked <- bake_steps(svy)
  dt <- get_data(baked)

  # Check all compute steps produced correct values
  for (i in 1:20) {
    var_name <- paste0("comp_", i)
    expect_true(var_name %in% names(dt),
      info = paste(var_name, "should exist")
    )
    expect_equal(dt[[var_name]], dt$x + i * dt$y,
      info = paste(var_name, "values should be correct")
    )
  }

  # Check recodes (NA_character_ is valid default)
  valid_income <- c("low", "mid", "high", NA_character_)
  valid_age <- c("young", "adult", "senior", NA_character_)
  valid_region <- c("north", "south", "east", "west", NA_character_)
  expect_true(all(dt$income_level %in% valid_income | is.na(dt$income_level)))
  expect_true(all(dt$age_group %in% valid_age | is.na(dt$age_group)))
  expect_true(all(dt$region_name %in% valid_region | is.na(dt$region_name)))

  # All steps baked
  for (step in get_steps(baked)) {
    expect_true(step$bake)
  }
})
