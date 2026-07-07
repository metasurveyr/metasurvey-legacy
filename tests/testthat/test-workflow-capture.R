test_that(".capture_workflow returns NULL when no recipes", {
  dt <- data.table::data.table(x = 1:5, w = rep(1, 5))
  svy <- Survey$new(
    data = dt, edition = "2023", type = "test",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )

  # No recipes -> NULL
  .calls <- quote(list(svymean(~x, na.rm = TRUE)))
  wf <- metasurvey:::.capture_workflow(list(svy), .calls, "annual")
  expect_null(wf)
})

test_that(".capture_workflow builds RecipeWorkflow when recipes present", {
  dt <- data.table::data.table(x = 1:5, w = rep(1, 5))
  svy <- Survey$new(
    data = dt, edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )

  # Add a recipe to the survey
  rec <- Recipe$new(
    id = "test_r1", name = "Test Recipe", user = "Author",
    edition = "2023", survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(), description = "Test",
    steps = list()
  )
  svy$add_recipe(rec)

  .calls <- quote(list(svymean(~x, na.rm = TRUE), svytotal(~x, na.rm = TRUE)))
  wf <- metasurvey:::.capture_workflow(list(svy), .calls, "annual")

  expect_s3_class(wf, "RecipeWorkflow")
  expect_equal(wf$recipe_ids, "test_r1")
  expect_equal(wf$survey_type, "ech")
  expect_equal(as.character(wf$edition), "2023")
  expect_equal(wf$estimation_type, "annual")
  expect_equal(length(wf$calls), 2)
  expect_equal(length(wf$call_metadata), 2)
  expect_equal(wf$call_metadata[[1]]$type, "svymean")
  expect_equal(wf$call_metadata[[2]]$type, "svytotal")
})

test_that(".capture_workflow extracts multiple recipe IDs", {
  dt <- data.table::data.table(x = 1:5, w = rep(1, 5))
  svy <- Survey$new(
    data = dt, edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )

  rec1 <- Recipe$new(
    id = "r1", name = "R1", user = "A", edition = "2023",
    survey_type = "ech", default_engine = "data.table",
    depends_on = list(), description = "R1", steps = list()
  )
  rec2 <- Recipe$new(
    id = "r2", name = "R2", user = "B", edition = "2023",
    survey_type = "ech", default_engine = "data.table",
    depends_on = list(), description = "R2", steps = list()
  )
  svy$add_recipe(rec1)
  svy$add_recipe(rec2)

  .calls <- quote(list(svymean(~x, na.rm = TRUE)))
  wf <- metasurvey:::.capture_workflow(list(svy), .calls, "annual")

  expect_equal(sort(wf$recipe_ids), c("r1", "r2"))
})

test_that(".capture_workflow handles svyby calls", {
  dt <- data.table::data.table(x = 1:5, w = rep(1, 5))
  svy <- Survey$new(
    data = dt, edition = "2023", type = "ech",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )
  rec <- Recipe$new(
    id = "r1", name = "R1", user = "A", edition = "2023",
    survey_type = "ech", default_engine = "data.table",
    depends_on = list(), description = "R1", steps = list()
  )
  svy$add_recipe(rec)

  .calls <- quote(list(svyby(~x, ~group, svymean, na.rm = TRUE)))
  wf <- metasurvey:::.capture_workflow(list(svy), .calls, "annual")

  expect_equal(wf$call_metadata[[1]]$type, "svyby")
  expect_equal(wf$call_metadata[[1]]$by, "~group")
})

test_that(".capture_workflow handles multiple surveys with Date editions", {
  make_month <- function(month) {
    dt <- data.table::data.table(x = 1:5, w = rep(1, 5))
    Survey$new(
      data = dt, edition = sprintf("2023-%02d", month), type = "ech",
      psu = NULL, engine = "data.table",
      weight = add_weight(monthly = "w")
    )
  }
  s1 <- make_month(1)
  s2 <- make_month(2)
  expect_s3_class(s1$edition, "Date")

  rec <- Recipe$new(
    id = "r1", name = "R1", user = "A", edition = "2023",
    survey_type = "ech", default_engine = "data.table",
    depends_on = list(), description = "R1", steps = list()
  )
  s1$add_recipe(rec)
  s2$add_recipe(rec)

  .calls <- quote(list(svymean(~x, na.rm = TRUE)))
  wf <- metasurvey:::.capture_workflow(list(s1, s2), .calls, "monthly")

  expect_s3_class(wf, "RecipeWorkflow")
  expect_identical(as.character(wf$edition), as.character(s1$edition))
})
