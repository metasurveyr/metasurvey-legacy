# Tests for R/workflow_tidy_api.R — tidy wrapper functions

# All wrappers delegate to get_workflow_backend()$method()
# Test with a local backend populated with test data

test_that("search_workflows finds matching workflows", {
  old <- getOption("metasurvey.workflow_backend")
  on.exit(options(metasurvey.workflow_backend = old))

  set_workflow_backend("local")
  backend <- get_workflow_backend()
  backend$publish(RecipeWorkflow$new(name = "Labor Market Analysis", survey_type = "ech"))
  backend$publish(RecipeWorkflow$new(name = "Income Distribution", survey_type = "ech"))

  results <- search_workflows("labor")
  expect_length(results, 1)
  expect_equal(results[[1]]$name, "Labor Market Analysis")
})

test_that("search_workflows returns empty for no match", {
  old <- getOption("metasurvey.workflow_backend")
  on.exit(options(metasurvey.workflow_backend = old))

  set_workflow_backend("local")
  results <- search_workflows("nonexistent_query")
  expect_length(results, 0)
})

test_that("rank_workflows returns top N", {
  old <- getOption("metasurvey.workflow_backend")
  on.exit(options(metasurvey.workflow_backend = old))

  set_workflow_backend("local")
  backend <- get_workflow_backend()
  backend$publish(RecipeWorkflow$new(name = "Low", downloads = 1L))
  backend$publish(RecipeWorkflow$new(name = "High", downloads = 100L))
  backend$publish(RecipeWorkflow$new(name = "Mid", downloads = 50L))

  top2 <- rank_workflows(n = 2)
  expect_length(top2, 2)
  expect_equal(top2[[1]]$name, "High")
})

test_that("filter_workflows filters by survey_type", {
  old <- getOption("metasurvey.workflow_backend")
  on.exit(options(metasurvey.workflow_backend = old))

  set_workflow_backend("local")
  backend <- get_workflow_backend()
  backend$publish(RecipeWorkflow$new(name = "ECH WF", survey_type = "ech"))
  backend$publish(RecipeWorkflow$new(name = "EPH WF", survey_type = "eph"))

  results <- filter_workflows(survey_type = "ech")
  expect_length(results, 1)
  expect_equal(results[[1]]$name, "ECH WF")
})

test_that("list_workflows returns all", {
  old <- getOption("metasurvey.workflow_backend")
  on.exit(options(metasurvey.workflow_backend = old))

  set_workflow_backend("local")
  backend <- get_workflow_backend()
  backend$publish(RecipeWorkflow$new(name = "WF1"))
  backend$publish(RecipeWorkflow$new(name = "WF2"))

  all <- list_workflows()
  expect_length(all, 2)
})

test_that("find_workflows_for_recipe cross-references", {
  old <- getOption("metasurvey.workflow_backend")
  on.exit(options(metasurvey.workflow_backend = old))

  set_workflow_backend("local")
  backend <- get_workflow_backend()
  backend$publish(RecipeWorkflow$new(name = "Uses R1", recipe_ids = c("r_001")))
  backend$publish(RecipeWorkflow$new(name = "Uses R2", recipe_ids = c("r_002")))

  results <- find_workflows_for_recipe("r_001")
  expect_length(results, 1)
  expect_equal(results[[1]]$name, "Uses R1")
})

test_that("publish_workflow adds to backend", {
  old <- getOption("metasurvey.workflow_backend")
  on.exit(options(metasurvey.workflow_backend = old))

  set_workflow_backend("local")
  wf <- RecipeWorkflow$new(name = "Published WF")
  publish_workflow(wf)

  all <- list_workflows()
  expect_length(all, 1)
  expect_equal(all[[1]]$name, "Published WF")
})
