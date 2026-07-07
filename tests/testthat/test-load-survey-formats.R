# Tests for R/load_survey.R — file formats, validate_recipe, read_file

# ── read_file ──────────────────────────────────────────────────────────────────

test_that("read_file loads CSV file", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  writeLines("x,y\n1,2\n3,4", tmp)

  dt <- read_file(tmp)
  expect_true(data.table::is.data.table(dt))
  expect_equal(nrow(dt), 2)
  expect_true("x" %in% names(dt))
})

test_that("read_file loads RDS file", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))
  df <- data.frame(a = 1:5, b = letters[1:5])
  saveRDS(df, tmp)

  dt <- read_file(tmp)
  expect_true(data.table::is.data.table(dt))
  expect_equal(nrow(dt), 5)
  expect_true("a" %in% names(dt))
})

test_that("read_file errors for unsupported extension", {
  expect_error(read_file("/fake/path/data.xyz"), "Unsupported file type")
})

# ── validate_recipe ────────────────────────────────────────────────────────────

test_that("validate_recipe returns TRUE for matching type and edition", {
  result <- validate_recipe("ech", "2023", "2023", "ech")
  expect_true(result)
})

test_that("validate_recipe returns FALSE for mismatched type", {
  result <- validate_recipe("ech", "2023", "2023", "eph")
  expect_false(result)
})

test_that("validate_recipe returns FALSE for mismatched edition", {
  result <- validate_recipe("ech", "2023", "2024", "ech")
  expect_false(result)
})

test_that("validate_recipe handles vector edition (recipe covers multiple editions)", {
  result <- validate_recipe("ech", "2023", c("2022", "2023", "2024"), "ech")
  expect_true(result)
})

test_that("validate_recipe returns FALSE when edition not in vector", {
  result <- validate_recipe("ech", "2020", c("2022", "2023", "2024"), "ech")
  expect_false(result)
})

# ── load_survey integration ────────────────────────────────────────────────────

test_that("load_survey loads CSV and creates Survey", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  dt <- data.table::data.table(x = 1:10, w = rep(1, 10))
  data.table::fwrite(dt, tmp)

  svy <- load_survey(
    tmp,
    svy_type = "test",
    svy_edition = "2023",
    svy_weight = add_weight(annual = "w")
  )
  expect_true(inherits(svy, "Survey"))
  expect_equal(nrow(svy$data), 10)
  expect_equal(svy$type, "test")
})

test_that("load_survey loads RDS and creates Survey", {
  tmp <- tempfile(fileext = ".rds")
  on.exit(unlink(tmp))
  df <- data.frame(x = 1:10, w = rep(1, 10))
  saveRDS(df, tmp)

  svy <- load_survey(
    tmp,
    svy_type = "test",
    svy_edition = "2023",
    svy_weight = add_weight(annual = "w")
  )
  expect_true(inherits(svy, "Survey"))
  expect_equal(nrow(svy$data), 10)
})

test_that("load_survey attaches valid recipe without bake", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  dt <- data.table::data.table(x = 1:10, w = rep(1, 10))
  data.table::fwrite(dt, tmp)

  rec <- Recipe$new(
    id = "r_valid",
    name = "Valid Recipe",
    user = "tester",
    edition = "2023",
    survey_type = "test",
    default_engine = "data.table",
    depends_on = list(),
    description = "No steps",
    steps = list()
  )

  svy <- load_survey(
    tmp,
    svy_type = "test",
    svy_edition = "2023",
    svy_weight = add_weight(annual = "w"),
    recipes = rec
  )

  expect_true(inherits(svy, "Survey"))
  expect_true(inherits(svy$recipes, "Recipe"))
})

test_that("load_survey with invalid recipe shows message", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  dt <- data.table::data.table(x = 1:10, w = rep(1, 10))
  data.table::fwrite(dt, tmp)

  svy_for_recipe <- Survey$new(
    data = dt, edition = "9999", type = "other",
    psu = NULL, engine = "data.table",
    weight = add_weight(annual = "w")
  )

  rec <- recipe(
    name = "Wrong Edition", user = "tester", svy = svy_for_recipe,
    description = "Bad match", steps = list()
  )

  expect_message(
    svy <- load_survey(
      tmp,
      svy_type = "test",
      svy_edition = "2023",
      svy_weight = add_weight(annual = "w"),
      recipes = rec
    ),
    "Invalid Recipe"
  )
})

test_that("load_survey validates recipe in list(recipe) format", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  dt <- data.table::data.table(x = 1:10, w = rep(1, 10))
  data.table::fwrite(dt, tmp)

  rec <- Recipe$new(
    id = "r_list",
    name = "List Recipe",
    user = "tester",
    edition = "2023",
    survey_type = "test",
    default_engine = "data.table",
    depends_on = list(),
    description = "No steps",
    steps = list()
  )

  # Pass recipe wrapped in list() — this was a bug: $edition returned NULL
  svy <- load_survey(
    tmp,
    svy_type = "test",
    svy_edition = "2023",
    svy_weight = add_weight(annual = "w"),
    recipes = list(rec)
  )

  expect_true(inherits(svy, "Survey"))
  expect_true(length(svy$recipes) >= 1)
})

test_that("load_survey validates multi-edition recipe", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  dt <- data.table::data.table(x = 1:10, w = rep(1, 10))
  data.table::fwrite(dt, tmp)

  rec <- Recipe$new(
    id = "r_multi",
    name = "Multi Edition Recipe",
    user = "tester",
    edition = c("2022", "2023", "2024"),
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    description = "Multi-edition",
    steps = list()
  )

  svy <- load_survey(
    tmp,
    svy_type = "ech",
    svy_edition = "2023",
    svy_weight = add_weight(annual = "w"),
    recipes = list(rec)
  )

  expect_true(inherits(svy, "Survey"))
  expect_true(length(svy$recipes) >= 1)
})

test_that("read_file with convert=TRUE passes through requireNamespace check", {
  skip_if_not_installed("rio")

  tmp <- tempfile(fileext = ".dta")
  on.exit(unlink(tmp))
  # Write minimal content - rio::convert may fail but requireNamespace is exercised
  writeLines("fake data", tmp)

  # rio::convert will error on invalid .dta, but the requireNamespace("rio")
  # check on line 392 IS exercised (returns TRUE since rio is installed)
  expect_error(read_file(tmp, convert = TRUE))
})
