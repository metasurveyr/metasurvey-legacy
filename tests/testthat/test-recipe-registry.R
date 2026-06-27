test_that("Create empty registry", {
  reg <- RecipeRegistry$new()
  expect_s3_class(reg, "RecipeRegistry")
  expect_equal(length(reg$list_all()), 0)
})

test_that("register adds recipe to catalog", {
  reg <- RecipeRegistry$new()
  r <- make_eco_recipe("test1", "user1")
  reg$register(r)
  expect_equal(length(reg$list_all()), 1)
})

test_that("register assigns id if missing", {
  reg <- RecipeRegistry$new()
  r <- make_eco_recipe("test1", "user1")
  reg$register(r)
  recipes <- reg$list_all()
  expect_true(!is.null(recipes[[1]]$id))
})

test_that("register rejects non-Recipe objects", {
  reg <- RecipeRegistry$new()
  expect_error(reg$register("not a recipe"))
  expect_error(reg$register(list(name = "fake")))
})

test_that("unregister removes recipe by id", {
  reg <- RecipeRegistry$new()
  r <- make_eco_recipe("test1", "user1")
  reg$register(r)
  id <- r$id
  reg$unregister(id)
  expect_equal(length(reg$list_all()), 0)
})

test_that("search by name/description", {
  reg <- RecipeRegistry$new()
  r1 <- make_eco_recipe("Labor Market Analysis", "user1")
  r2 <- make_eco_recipe("Income Distribution", "user2")
  r3 <- make_eco_recipe("Employment Stats", "user3")
  reg$register(r1)
  reg$register(r2)
  reg$register(r3)

  results <- reg$search("labor")
  expect_equal(length(results), 1)
  expect_equal(results[[1]]$name, "Labor Market Analysis")

  results2 <- reg$search("income")
  expect_equal(length(results2), 1)

  # Search in description
  results3 <- reg$search("Test recipe")
  expect_equal(length(results3), 3)
})

test_that("filter by svy_type", {
  reg <- RecipeRegistry$new()
  r1 <- make_eco_recipe("A", "u", svy_type = "ech")
  r2 <- make_eco_recipe("B", "u", svy_type = "eaii")
  r3 <- make_eco_recipe("C", "u", svy_type = "ech")
  reg$register(r1)
  reg$register(r2)
  reg$register(r3)

  results <- reg$filter(survey_type = "ech")
  expect_equal(length(results), 2)
})

test_that("filter by edition", {
  reg <- RecipeRegistry$new()
  r1 <- make_eco_recipe("A", "u", edition = "2023")
  r2 <- make_eco_recipe("B", "u", edition = "2022")
  reg$register(r1)
  reg$register(r2)

  results <- reg$filter(edition = "2023")
  expect_equal(length(results), 1)
  expect_equal(results[[1]]$name, "A")
})

test_that("filter by category", {
  reg <- RecipeRegistry$new()
  labor <- RecipeCategory$new("labor_market", "Labor")
  income <- RecipeCategory$new("income", "Income")
  r1 <- make_eco_recipe("A", "u", categories = list(labor))
  r2 <- make_eco_recipe("B", "u", categories = list(income))
  r3 <- make_eco_recipe("C", "u", categories = list(labor, income))
  reg$register(r1)
  reg$register(r2)
  reg$register(r3)

  results <- reg$filter(category = "labor_market")
  expect_equal(length(results), 2)

  results2 <- reg$filter(category = "income")
  expect_equal(length(results2), 2)
})

test_that("filter by certification_level", {
  reg <- RecipeRegistry$new()
  inst <- RecipeUser$new(name = "IECON", user_type = "institution")
  r1 <- make_eco_recipe("A", "u")
  r2 <- make_eco_recipe("B", "u", certification = RecipeCertification$new("official", certified_by = inst))
  reg$register(r1)
  reg$register(r2)

  results <- reg$filter(certification_level = "official")
  expect_equal(length(results), 1)
  expect_equal(results[[1]]$name, "B")
})

test_that("filter with multiple criteria", {
  reg <- RecipeRegistry$new()
  labor <- RecipeCategory$new("labor_market", "Labor")
  r1 <- make_eco_recipe("A", "u", svy_type = "ech", edition = "2023", categories = list(labor))
  r2 <- make_eco_recipe("B", "u", svy_type = "ech", edition = "2022", categories = list(labor))
  r3 <- make_eco_recipe("C", "u", svy_type = "eaii", edition = "2023")
  reg$register(r1)
  reg$register(r2)
  reg$register(r3)

  results <- reg$filter(survey_type = "ech", edition = "2023")
  expect_equal(length(results), 1)
  expect_equal(results[[1]]$name, "A")
})

test_that("rank_by_downloads returns top-N sorted", {
  reg <- RecipeRegistry$new()
  r1 <- make_eco_recipe("Low", "u", downloads = 10)
  r2 <- make_eco_recipe("High", "u", downloads = 100)
  r3 <- make_eco_recipe("Mid", "u", downloads = 50)
  reg$register(r1)
  reg$register(r2)
  reg$register(r3)

  ranked <- reg$rank_by_downloads(2)
  expect_equal(length(ranked), 2)
  expect_equal(ranked[[1]]$name, "High")
  expect_equal(ranked[[2]]$name, "Mid")
})

test_that("rank_by_downloads returns all if n is NULL", {
  reg <- RecipeRegistry$new()
  r1 <- make_eco_recipe("Low", "u", downloads = 10)
  r2 <- make_eco_recipe("High", "u", downloads = 100)
  reg$register(r1)
  reg$register(r2)

  ranked <- reg$rank_by_downloads()
  expect_equal(length(ranked), 2)
  expect_equal(ranked[[1]]$name, "High")
})

test_that("rank_by_certification sorts by cert then downloads", {
  reg <- RecipeRegistry$new()
  inst <- RecipeUser$new(name = "IECON", user_type = "institution")
  member <- RecipeUser$new(name = "M", user_type = "institutional_member", institution = inst)

  r1 <- make_eco_recipe("Community_High", "u", downloads = 200)
  r2 <- make_eco_recipe("Official_Low", "u",
    downloads = 10,
    certification = RecipeCertification$new("official", certified_by = inst)
  )
  r3 <- make_eco_recipe("Reviewed_Mid", "u",
    downloads = 50,
    certification = RecipeCertification$new("reviewed", certified_by = member)
  )
  reg$register(r1)
  reg$register(r2)
  reg$register(r3)

  ranked <- reg$rank_by_certification()
  expect_equal(ranked[[1]]$name, "Official_Low")
  expect_equal(ranked[[2]]$name, "Reviewed_Mid")
  expect_equal(ranked[[3]]$name, "Community_High")
})

test_that("get retrieves single recipe by id", {
  reg <- RecipeRegistry$new()
  r <- make_eco_recipe("Target", "u")
  id <- r$id
  reg$register(r)

  found <- reg$get(id)
  expect_equal(found$name, "Target")
})

test_that("get returns NULL for unknown id", {
  reg <- RecipeRegistry$new()
  expect_null(reg$get("nonexistent"))
})

test_that("list_all returns all recipes", {
  reg <- RecipeRegistry$new()
  r1 <- make_eco_recipe("A", "u")
  r2 <- make_eco_recipe("B", "u")
  reg$register(r1)
  reg$register(r2)
  expect_equal(length(reg$list_all()), 2)
})

test_that("save and load round-trip", {
  reg <- RecipeRegistry$new()
  labor <- RecipeCategory$new("labor_market", "Labor")
  inst <- RecipeUser$new(name = "IECON", user_type = "institution")
  r1 <- make_eco_recipe("Saved", "u",
    downloads = 42, categories = list(labor),
    certification = RecipeCertification$new("official", certified_by = inst)
  )
  reg$register(r1)

  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))
  reg$save(tmp)
  expect_true(file.exists(tmp))

  reg2 <- RecipeRegistry$new()
  reg2$load(tmp)
  expect_equal(length(reg2$list_all()), 1)
  loaded <- reg2$list_all()[[1]]
  expect_equal(loaded$name, "Saved")
  expect_equal(loaded$downloads, 42L)
})

test_that("list_by_user filters by author name", {
  reg <- RecipeRegistry$new()
  r1 <- make_eco_recipe("A", "Juan")
  r2 <- make_eco_recipe("B", "Maria")
  r3 <- make_eco_recipe("C", "Juan")
  reg$register(r1)
  reg$register(r2)
  reg$register(r3)

  results <- reg$list_by_user("Juan")
  expect_equal(length(results), 2)
})

test_that("list_by_institution filters by institution", {
  reg <- RecipeRegistry$new()
  inst <- RecipeUser$new(name = "IECON", user_type = "institution")
  member <- RecipeUser$new(name = "Maria", user_type = "institutional_member", institution = inst)
  individual <- RecipeUser$new(name = "Juan", user_type = "individual")

  r1 <- make_eco_recipe("A", "IECON", user_info = inst)
  r2 <- make_eco_recipe("B", "Maria", user_info = member)
  r3 <- make_eco_recipe("C", "Juan", user_info = individual)
  reg$register(r1)
  reg$register(r2)
  reg$register(r3)

  results <- reg$list_by_institution("IECON")
  expect_equal(length(results), 2)
})

test_that("stats returns summary", {
  reg <- RecipeRegistry$new()
  labor <- RecipeCategory$new("labor_market", "Labor")
  income <- RecipeCategory$new("income", "Income")
  inst <- RecipeUser$new(name = "I", user_type = "institution")

  r1 <- make_eco_recipe("A", "u", categories = list(labor))
  r2 <- make_eco_recipe("B", "u",
    categories = list(income),
    certification = RecipeCertification$new("official", certified_by = inst)
  )
  r3 <- make_eco_recipe("C", "u", categories = list(labor, income))
  reg$register(r1)
  reg$register(r2)
  reg$register(r3)

  s <- reg$stats()
  expect_equal(s$total, 3)
  expect_true("by_category" %in% names(s))
  expect_true("by_certification" %in% names(s))
  expect_equal(s$by_category[["labor_market"]], 2)
  expect_equal(s$by_category[["income"]], 2)
  expect_equal(s$by_certification[["community"]], 2)
  expect_equal(s$by_certification[["official"]], 1)
})

test_that("print method works", {
  reg <- RecipeRegistry$new()
  r1 <- make_eco_recipe("A", "u")
  reg$register(r1)
  expect_output(print(reg), "RecipeRegistry")
})
