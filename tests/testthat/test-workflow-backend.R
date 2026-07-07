# Tests for R/WorkflowBackend.R — local + API delegation paths

# ── Constructor ────────────────────────────────────────────────────────────────

test_that("WorkflowBackend creates local backend", {
  backend <- WorkflowBackend$new("local")
  expect_equal(backend$type, "local")
})

test_that("WorkflowBackend accepts 'mongo' as alias for 'api'", {
  backend <- WorkflowBackend$new("mongo")
  expect_equal(backend$type, "api")
})

test_that("WorkflowBackend rejects invalid type", {
  expect_error(WorkflowBackend$new("redis"), "Backend type must be one of")
})

test_that("WorkflowBackend local loads existing file", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  # Create a backend with workflows, save it
  b1 <- WorkflowBackend$new("local", path = tmp)
  wf <- RecipeWorkflow$new(name = "Saved WF", survey_type = "ech", edition = "2023")
  b1$publish(wf)

  # Create a new backend from the saved file
  b2 <- WorkflowBackend$new("local", path = tmp)
  expect_length(b2$list_all(), 1)
})

# ── Local backend CRUD ─────────────────────────────────────────────────────────

test_that("WorkflowBackend local publish + get", {
  backend <- WorkflowBackend$new("local")
  wf <- RecipeWorkflow$new(name = "Test WF", survey_type = "ech", edition = "2023")
  backend$publish(wf)

  retrieved <- backend$get(wf$id)
  expect_false(is.null(retrieved))
  expect_equal(retrieved$name, "Test WF")
})

test_that("WorkflowBackend local search", {
  backend <- WorkflowBackend$new("local")
  backend$publish(RecipeWorkflow$new(name = "Labor Market WF", survey_type = "ech"))
  backend$publish(RecipeWorkflow$new(name = "Income WF", survey_type = "ech"))

  results <- backend$search("labor")
  expect_length(results, 1)
  expect_equal(results[[1]]$name, "Labor Market WF")
})

test_that("WorkflowBackend local list_all", {
  backend <- WorkflowBackend$new("local")
  backend$publish(RecipeWorkflow$new(name = "WF1"))
  backend$publish(RecipeWorkflow$new(name = "WF2"))
  backend$publish(RecipeWorkflow$new(name = "WF3"))

  all <- backend$list_all()
  expect_length(all, 3)
})

test_that("WorkflowBackend local increment_downloads", {
  backend <- WorkflowBackend$new("local")
  wf <- RecipeWorkflow$new(name = "DL WF")
  backend$publish(wf)

  backend$increment_downloads(wf$id)
  retrieved <- backend$get(wf$id)
  expect_equal(retrieved$downloads, 1L)
})

test_that("WorkflowBackend local find_by_recipe", {
  backend <- WorkflowBackend$new("local")
  wf1 <- RecipeWorkflow$new(name = "WF With Recipe", recipe_ids = c("r_abc"))
  wf2 <- RecipeWorkflow$new(name = "WF No Recipe", recipe_ids = character(0))
  backend$publish(wf1)
  backend$publish(wf2)

  results <- backend$find_by_recipe("r_abc")
  expect_length(results, 1)
  expect_equal(results[[1]]$name, "WF With Recipe")
})

test_that("WorkflowBackend local rank", {
  backend <- WorkflowBackend$new("local")
  wf1 <- RecipeWorkflow$new(name = "Low DL", downloads = 5L)
  wf2 <- RecipeWorkflow$new(name = "High DL", downloads = 50L)
  wf3 <- RecipeWorkflow$new(name = "Mid DL", downloads = 20L)
  backend$publish(wf1)
  backend$publish(wf2)
  backend$publish(wf3)

  top2 <- backend$rank(n = 2)
  expect_length(top2, 2)
  expect_equal(top2[[1]]$name, "High DL")
})

test_that("WorkflowBackend local filter by survey_type", {
  backend <- WorkflowBackend$new("local")
  backend$publish(RecipeWorkflow$new(name = "ECH WF", survey_type = "ech"))
  backend$publish(RecipeWorkflow$new(name = "EPH WF", survey_type = "eph"))

  results <- backend$filter(survey_type = "ech")
  expect_length(results, 1)
  expect_equal(results[[1]]$name, "ECH WF")
})

test_that("WorkflowBackend local save and load", {
  tmp <- tempfile(fileext = ".json")
  on.exit(unlink(tmp))

  backend <- WorkflowBackend$new("local", path = tmp)
  backend$publish(RecipeWorkflow$new(name = "Persist WF"))
  backend$save()
  expect_true(file.exists(tmp))

  backend2 <- WorkflowBackend$new("local", path = tmp)
  backend2$load()
  expect_length(backend2$list_all(), 1)
})

# ── API backend delegation (mocked) ───────────────────────────────────────────

test_that("WorkflowBackend api search delegates to api_list_workflows", {
  local_mocked_bindings(
    api_list_workflows = function(search = NULL, ...) {
      list(RecipeWorkflow$new(name = "API WF"))
    }
  )

  backend <- WorkflowBackend$new("api")
  results <- backend$search("test")
  expect_length(results, 1)
  expect_equal(results[[1]]$name, "API WF")
})

test_that("WorkflowBackend api get delegates to api_get_workflow", {
  local_mocked_bindings(
    api_get_workflow = function(id) {
      RecipeWorkflow$new(name = "Got WF", id = id)
    }
  )

  backend <- WorkflowBackend$new("api")
  result <- backend$get("w_123")
  expect_false(is.null(result))
  expect_equal(result$name, "Got WF")
})

test_that("WorkflowBackend api publish delegates to api_publish_workflow", {
  called <- FALSE
  local_mocked_bindings(
    api_publish_workflow = function(wf) {
      called <<- TRUE
      invisible(list(ok = TRUE))
    }
  )

  backend <- WorkflowBackend$new("api")
  wf <- RecipeWorkflow$new(name = "Pub WF")
  backend$publish(wf)
  expect_true(called)
})

test_that("WorkflowBackend api increment_downloads delegates", {
  called_id <- NULL
  local_mocked_bindings(
    api_download_workflow = function(id) {
      called_id <<- id
      invisible(NULL)
    }
  )

  backend <- WorkflowBackend$new("api")
  backend$increment_downloads("w_456")
  expect_equal(called_id, "w_456")
})

test_that("WorkflowBackend api find_by_recipe delegates", {
  local_mocked_bindings(
    api_list_workflows = function(recipe_id = NULL, ...) {
      if (!is.null(recipe_id) && recipe_id == "r_target") {
        list(RecipeWorkflow$new(name = "Found WF"))
      } else {
        list()
      }
    }
  )

  backend <- WorkflowBackend$new("api")
  results <- backend$find_by_recipe("r_target")
  expect_length(results, 1)
})

test_that("WorkflowBackend api filter delegates", {
  local_mocked_bindings(
    api_list_workflows = function(survey_type = NULL, recipe_id = NULL, ...) {
      if (!is.null(survey_type) && survey_type == "ech") {
        list(RecipeWorkflow$new(name = "ECH API WF"))
      } else {
        list()
      }
    }
  )

  backend <- WorkflowBackend$new("api")
  results <- backend$filter(survey_type = "ech")
  expect_length(results, 1)
})

test_that("WorkflowBackend api list_all delegates", {
  local_mocked_bindings(
    api_list_workflows = function(...) {
      list(RecipeWorkflow$new(name = "WF1"), RecipeWorkflow$new(name = "WF2"))
    }
  )

  backend <- WorkflowBackend$new("api")
  results <- backend$list_all()
  expect_length(results, 2)
})

test_that("WorkflowBackend api search returns empty on error", {
  local_mocked_bindings(
    api_list_workflows = function(...) {
      stop("Network error")
    }
  )

  backend <- WorkflowBackend$new("api")
  results <- backend$search("test")
  expect_length(results, 0)
})

test_that("WorkflowBackend api get returns NULL on error", {
  local_mocked_bindings(
    api_get_workflow = function(id) {
      stop("Not found")
    }
  )

  backend <- WorkflowBackend$new("api")
  result <- backend$get("nonexistent")
  expect_null(result)
})

# ── set/get workflow backend ───────────────────────────────────────────────────

test_that("set_workflow_backend sets option", {
  old <- getOption("metasurvey.workflow_backend")
  on.exit(options(metasurvey.workflow_backend = old))

  set_workflow_backend("local")
  backend <- getOption("metasurvey.workflow_backend")
  expect_true(inherits(backend, "WorkflowBackend"))
  expect_equal(backend$type, "local")
})

test_that("get_workflow_backend returns default local", {
  old <- getOption("metasurvey.workflow_backend")
  on.exit(options(metasurvey.workflow_backend = old))

  options(metasurvey.workflow_backend = NULL)
  backend <- get_workflow_backend()
  expect_true(inherits(backend, "WorkflowBackend"))
  expect_equal(backend$type, "local")
})
