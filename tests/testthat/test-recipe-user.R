test_that("RecipeUser creates individual user", {
  user <- RecipeUser$new(
    name = "Juan Perez",
    email = "juan@example.com",
    user_type = "individual"
  )
  expect_s3_class(user, "RecipeUser")
  expect_equal(user$name, "Juan Perez")
  expect_equal(user$email, "juan@example.com")
  expect_equal(user$user_type, "individual")
  expect_null(user$institution)
  expect_null(user$url)
  expect_false(user$verified)
})

test_that("RecipeUser creates institution user", {
  inst <- RecipeUser$new(
    name = "Instituto de Economia",
    user_type = "institution",
    url = "https://iecon.edu.uy",
    verified = TRUE
  )
  expect_equal(inst$user_type, "institution")
  expect_equal(inst$url, "https://iecon.edu.uy")
  expect_true(inst$verified)
})

test_that("RecipeUser creates institutional_member linked to institution", {
  inst <- RecipeUser$new(
    name = "Instituto de Economia",
    user_type = "institution",
    url = "https://iecon.edu.uy"
  )
  member <- RecipeUser$new(
    name = "Maria Garcia",
    email = "maria@iecon.edu.uy",
    user_type = "institutional_member",
    institution = inst
  )
  expect_equal(member$user_type, "institutional_member")
  expect_equal(member$institution$name, "Instituto de Economia")
})

test_that("RecipeUser validates user_type values", {
  expect_error(RecipeUser$new(name = "test", user_type = "admin"))
  expect_error(RecipeUser$new(name = "test", user_type = ""))
  expect_error(RecipeUser$new(name = "test", user_type = NULL))
})

test_that("RecipeUser validates name is required", {
  expect_error(RecipeUser$new(name = "", user_type = "individual"))
  expect_error(RecipeUser$new(name = NULL, user_type = "individual"))
})

test_that("institutional_member requires institution", {
  expect_error(
    RecipeUser$new(name = "test", user_type = "institutional_member"),
    "institution"
  )
  expect_error(
    RecipeUser$new(name = "test", user_type = "institutional_member", institution = "not_a_user"),
    "institution"
  )
})

test_that("trust_level returns correct values", {
  individual <- RecipeUser$new(name = "A", user_type = "individual")
  inst <- RecipeUser$new(name = "B", user_type = "institution")
  member <- RecipeUser$new(name = "C", user_type = "institutional_member", institution = inst)

  expect_equal(individual$trust_level(), 1)
  expect_equal(member$trust_level(), 2)
  expect_equal(inst$trust_level(), 3)
})

test_that("can_certify checks trust level", {
  individual <- RecipeUser$new(name = "A", user_type = "individual")
  inst <- RecipeUser$new(name = "B", user_type = "institution")
  member <- RecipeUser$new(name = "C", user_type = "institutional_member", institution = inst)

  # Individual cannot certify anything above community
  expect_false(individual$can_certify("reviewed"))
  expect_false(individual$can_certify("official"))

  # Member can certify reviewed but not official
  expect_true(member$can_certify("reviewed"))
  expect_false(member$can_certify("official"))

  # Institution can certify anything
  expect_true(inst$can_certify("reviewed"))
  expect_true(inst$can_certify("official"))
})

test_that("to_list serializes individual user", {
  user <- RecipeUser$new(
    name = "Juan Perez",
    email = "juan@example.com",
    user_type = "individual",
    affiliation = "UdelaR"
  )
  lst <- user$to_list()
  expect_type(lst, "list")
  expect_equal(lst$name, "Juan Perez")
  expect_equal(lst$email, "juan@example.com")
  expect_equal(lst$user_type, "individual")
  expect_equal(lst$affiliation, "UdelaR")
  expect_null(lst$institution)
})

test_that("to_list serializes institutional_member with institution", {
  inst <- RecipeUser$new(name = "IECON", user_type = "institution")
  member <- RecipeUser$new(
    name = "Maria",
    user_type = "institutional_member",
    institution = inst
  )
  lst <- member$to_list()
  expect_equal(lst$institution$name, "IECON")
  expect_equal(lst$institution$user_type, "institution")
})

test_that("from_list deserializes individual user", {
  lst <- list(
    name = "Juan Perez",
    email = "juan@example.com",
    user_type = "individual",
    affiliation = "UdelaR"
  )
  user <- RecipeUser$from_list(lst)
  expect_s3_class(user, "RecipeUser")
  expect_equal(user$name, "Juan Perez")
  expect_equal(user$user_type, "individual")
})

test_that("from_list deserializes institutional_member", {
  lst <- list(
    name = "Maria",
    user_type = "institutional_member",
    institution = list(
      name = "IECON",
      user_type = "institution",
      verified = TRUE
    )
  )
  user <- RecipeUser$from_list(lst)
  expect_equal(user$user_type, "institutional_member")
  expect_equal(user$institution$name, "IECON")
})

test_that("to_list/from_list round-trip", {
  inst <- RecipeUser$new(name = "IECON", user_type = "institution", url = "https://iecon.edu.uy", verified = TRUE)
  member <- RecipeUser$new(
    name = "Maria Garcia", email = "m@iecon.edu.uy",
    user_type = "institutional_member", institution = inst
  )

  restored <- RecipeUser$from_list(member$to_list())
  expect_equal(restored$name, "Maria Garcia")
  expect_equal(restored$user_type, "institutional_member")
  expect_equal(restored$institution$name, "IECON")
  expect_true(restored$institution$verified)
})

test_that("from_list with NULL returns NULL", {
  expect_null(RecipeUser$from_list(NULL))
})

test_that("print method works for individual", {
  user <- RecipeUser$new(name = "Juan", user_type = "individual", email = "j@test.com")
  expect_output(print(user), "Juan")
})

test_that("print method works for institution", {
  inst <- RecipeUser$new(name = "IECON", user_type = "institution", verified = TRUE)
  expect_output(print(inst), "IECON")
})

test_that("affiliation field works", {
  user <- RecipeUser$new(name = "Juan", user_type = "individual", affiliation = "UdelaR")
  expect_equal(user$affiliation, "UdelaR")
})

test_that("email defaults to NULL", {
  user <- RecipeUser$new(name = "Juan", user_type = "individual")
  expect_null(user$email)
})

# ── Batch 10: RecipeUser print edges, review_status, can_certify edge ─────────

test_that("RecipeUser print shows institutional_member with institution", {
  inst <- RecipeUser$new(name = "IECON", user_type = "institution")
  member <- RecipeUser$new(
    name = "Maria", user_type = "institutional_member",
    email = "m@iecon.edu.uy", institution = inst
  )
  expect_output(print(member), "Maria")
  expect_output(print(member), "Institution")
})

test_that("RecipeUser print shows URL for institution", {
  inst <- RecipeUser$new(
    name = "IECON", user_type = "institution",
    url = "https://iecon.edu.uy"
  )
  expect_output(print(inst), "URL")
})

test_that("RecipeUser print shows pending review_status", {
  user <- RecipeUser$new(
    name = "Pending User", user_type = "individual",
    review_status = "pending"
  )
  expect_output(print(user), "pending")
})

test_that("RecipeUser print shows rejected review_status", {
  user <- RecipeUser$new(
    name = "Rejected User", user_type = "individual",
    review_status = "rejected"
  )
  expect_output(print(user), "rejected")
})

test_that("can_certify with community level always allowed", {
  individual <- RecipeUser$new(name = "A", user_type = "individual")
  # Community level requires trust_level >= 0
  expect_true(individual$can_certify("community"))
})

test_that("to_list includes URL and review_status", {
  inst <- RecipeUser$new(
    name = "IECON", user_type = "institution",
    url = "https://iecon.edu.uy", verified = TRUE,
    review_status = "pending"
  )
  lst <- inst$to_list()
  expect_equal(lst$url, "https://iecon.edu.uy")
  expect_true(lst$verified)
  expect_equal(lst$review_status, "pending")
})

test_that("from_list uses defaults for missing optional fields", {
  lst <- list(name = "Simple", user_type = "individual")
  user <- RecipeUser$from_list(lst)
  expect_null(user$email)
  expect_null(user$affiliation)
  expect_false(user$verified)
  expect_equal(user$review_status, "approved")
})
