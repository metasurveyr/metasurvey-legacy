# metatable plan foundations (design/metatable-rfc.md, issue #214):
# classification table (RFC section 2.2), build_plan() (section 3)
# and explain().

mk_step <- function(type, new_var = NULL, exprs = NULL,
                    depends_on = NULL, by_vars = NULL, bake = FALSE) {
  Step$new(
    name = paste0("test-", type),
    edition = "2023",
    survey_type = "test",
    type = type,
    new_var = new_var,
    exprs = exprs,
    call = NULL,
    svy_before = NULL,
    default_engine = "data.table",
    depends_on = depends_on,
    by_vars = by_vars,
    bake = bake
  )
}

# ── classify_step: RFC section 2.2, all step types ─────────────────────

test_that("classify_step: compute without .by is narrow", {
  step <- mk_step("compute", new_var = "age2", depends_on = "age")
  cls <- classify_step(step)
  expect_equal(cls$kind, "narrow")
  expect_equal(cls$row_effect, "none")
})

test_that("classify_step: compute with .by is wide", {
  step <- mk_step(
    "compute",
    new_var = "mean_income",
    depends_on = c("income", "region"),
    by_vars = "region"
  )
  cls <- classify_step(step)
  expect_equal(cls$kind, "wide")
  expect_equal(cls$row_effect, "none")
})

test_that("classify_step: recode is narrow", {
  step <- mk_step("recode", new_var = "age_group", depends_on = "age")
  cls <- classify_step(step)
  expect_equal(cls$kind, "narrow")
  expect_equal(cls$row_effect, "none")
})

test_that("classify_step: join is wide with reshape row effect", {
  step <- mk_step(
    "step_join",
    exprs = list(
      x = data.table::data.table(id = 1:3, extra = 1:3),
      by = "id", type = "left", suffixes = c("", ".y")
    ),
    depends_on = "id"
  )
  cls <- classify_step(step)
  expect_equal(cls$kind, "wide")
  expect_equal(cls$row_effect, "reshape")
})

test_that("classify_step: remove and rename are meta", {
  remove_step <- mk_step("step_remove", exprs = list(vars = "y"))
  rename_step <- mk_step(
    "step_rename",
    exprs = list(mapping = c(edad = "age"))
  )
  expect_equal(classify_step(remove_step)$kind, "meta")
  expect_equal(classify_step(remove_step)$row_effect, "none")
  expect_equal(classify_step(rename_step)$kind, "meta")
  expect_equal(classify_step(rename_step)$row_effect, "none")
})

test_that("classify_step: filter without .by is filter", {
  step <- mk_step("filter", depends_on = "age")
  cls <- classify_step(step)
  expect_equal(cls$kind, "filter")
  expect_equal(cls$row_effect, "subset")
})

test_that("classify_step: filter with .by is wide", {
  step <- mk_step(
    "filter",
    depends_on = c("age", "region"),
    by_vars = "region"
  )
  cls <- classify_step(step)
  expect_equal(cls$kind, "wide")
  expect_equal(cls$row_effect, "subset")
})

test_that("classify_step: validate and weight are fences", {
  validate_step <- mk_step(
    "validate",
    exprs = list(checks = list(quote(age > 0)), .action = "stop"),
    depends_on = "age"
  )
  weight_step <- mk_step(
    "step_weight",
    new_var = ".weight",
    exprs = list(spec = NULL, weight_var = ".weight"),
    depends_on = character(0)
  )
  expect_equal(classify_step(validate_step)$kind, "fence")
  expect_equal(classify_step(validate_step)$row_effect, "none")
  expect_equal(classify_step(weight_step)$kind, "fence")
  expect_equal(classify_step(weight_step)$row_effect, "none")
})

test_that("classify_step: quantile and collapse are wide (post-RFC types)", {
  quantile_step <- mk_step(
    "step_quantile",
    new_var = "income_q",
    exprs = list(new_var = "income_q", x = "income", n = 5L),
    depends_on = c("income", "w")
  )
  collapse_step <- mk_step(
    "step_collapse",
    exprs = list(by = "hh", rule = "max"),
    depends_on = "hh"
  )
  expect_equal(classify_step(quantile_step)$kind, "wide")
  expect_equal(classify_step(quantile_step)$row_effect, "none")
  expect_equal(classify_step(collapse_step)$kind, "wide")
  expect_equal(classify_step(collapse_step)$row_effect, "reshape")
})

test_that("classify_step: unknown step type fails loudly", {
  step <- mk_step("step_teleport")
  expect_error(classify_step(step), "unknown step type 'step_teleport'")
})

# ── meta_node / meta_plan constructors ─────────────────────────────────

test_that("meta_node validates kind and row_effect", {
  step <- mk_step("compute", new_var = "a")
  node <- meta_node(
    step_idx = 3L, step = step, kind = "narrow",
    produces = "a", consumes = "x"
  )
  expect_s3_class(node, "meta_node")
  expect_identical(node$step_idx, 3L)
  expect_identical(node$step, step)
  expect_equal(node$row_effect, "none")
  expect_null(node$group_vars)
  expect_error(
    meta_node(1L, step, kind = "diagonal"),
    "Invalid meta_node kind"
  )
  expect_error(
    meta_node(1L, step, kind = "narrow", row_effect = "explode"),
    "Invalid meta_node row_effect"
  )
})

test_that("meta_plan has the RFC section 2.1 structure", {
  plan <- meta_plan()
  expect_s3_class(plan, "meta_plan")
  expect_named(plan, c("nodes", "sinks", "schedule", "stats"))
  expect_length(plan$nodes, 0)
  expect_null(plan$sinks)
  expect_identical(plan$schedule, list())
  expect_identical(plan$stats, list())
})

# ── build_plan ─────────────────────────────────────────────────────────

test_that("build_plan: empty step list yields an empty plan", {
  plan <- build_plan(list())
  expect_s3_class(plan, "meta_plan")
  expect_length(plan$nodes, 0)
  expect_null(plan$sinks)
})

test_that("build_plan: nodes preserve effective order and sinks", {
  steps <- list(
    mk_step("compute", new_var = "a", depends_on = "x"),
    mk_step("filter", depends_on = "a")
  )
  plan <- build_plan(steps, sinks = c("a", "w"))
  expect_length(plan$nodes, 2)
  expect_equal(plan$nodes[[1]]$step_idx, 1L)
  expect_equal(plan$nodes[[2]]$step_idx, 2L)
  expect_equal(plan$nodes[[1]]$kind, "narrow")
  expect_equal(plan$nodes[[2]]$kind, "filter")
  expect_equal(plan$sinks, c("a", "w"))
})

test_that("build_plan: rename mapping applies to later consumes/produces", {
  steps <- list(
    mk_step("compute", new_var = "a", depends_on = "x"),
    mk_step("step_rename", exprs = list(mapping = c(b = "a"))),
    mk_step("compute", new_var = "c", depends_on = "b"),
    mk_step("filter", depends_on = c("b", "x"))
  )
  plan <- build_plan(steps)

  # the rename node itself consumes the old name, produces the new one
  expect_equal(plan$nodes[[2]]$kind, "meta")
  expect_equal(plan$nodes[[2]]$consumes, "a")
  expect_equal(plan$nodes[[2]]$produces, "b")

  # later nodes are expressed in the original naming space: "b" -> "a"
  expect_equal(plan$nodes[[3]]$consumes, "a")
  expect_equal(plan$nodes[[3]]$produces, "c")
  expect_equal(plan$nodes[[4]]$consumes, c("a", "x"))
})

test_that("build_plan: chained renames compose the mapping", {
  steps <- list(
    mk_step("step_rename", exprs = list(mapping = c(b = "a"))),
    mk_step("step_rename", exprs = list(mapping = c(d = "b"))),
    mk_step("filter", depends_on = "d")
  )
  plan <- build_plan(steps)
  # d -> b -> a
  expect_equal(plan$nodes[[3]]$consumes, "a")
})

test_that("compose_rename_map resolves origins against the pre-step snapshot", {
  # step_rename applies its mapping in ONE vectorized setnames() call:
  # every old name resolves in the naming space before the step, never
  # against entries added by the same step
  # swap in a single call
  expect_equal(
    compose_rename_map(character(0), c(a = "b", b = "a")),
    c(a = "b", b = "a")
  )
  # chain in a single call: new b comes from old a, new c from old b
  expect_equal(
    compose_rename_map(character(0), c(b = "a", c = "b")),
    c(b = "a", c = "b")
  )
  # composition across steps still follows the accumulated map
  expect_equal(compose_rename_map(c(x = "a"), c(y = "x")), c(y = "a"))
})

test_that("build_plan: swap rename in one call keeps setnames semantics", {
  steps <- list(
    mk_step("step_rename", exprs = list(mapping = c(a = "b", b = "a"))),
    mk_step("filter", depends_on = "a"),
    mk_step("filter", depends_on = "b")
  )
  plan <- build_plan(steps)
  expect_equal(plan$nodes[[1]]$consumes, c("b", "a"))
  expect_equal(plan$nodes[[1]]$produces, c("a", "b"))
  # after the atomic swap, new `a` holds old `b` and vice versa
  expect_equal(plan$nodes[[2]]$consumes, "b")
  expect_equal(plan$nodes[[3]]$consumes, "a")
})

test_that("build_plan: chained mapping inside one rename call", {
  # setnames renames old a -> b and old b -> c atomically: the new `c`
  # column holds old `b`, NOT old `a`
  steps <- list(
    mk_step("step_rename", exprs = list(mapping = c(b = "a", c = "b"))),
    mk_step("filter", depends_on = "c"),
    mk_step("filter", depends_on = "b")
  )
  plan <- build_plan(steps)
  expect_equal(plan$nodes[[2]]$consumes, "b")
  expect_equal(plan$nodes[[3]]$consumes, "a")
})

test_that("build_plan: consumes includes grouping and join keys", {
  steps <- list(
    mk_step(
      "compute",
      new_var = "mean_income",
      depends_on = "income",
      by_vars = "region"
    ),
    mk_step(
      "step_join",
      exprs = list(
        x = data.table::data.table(id = 1:3, extra = 4:6),
        by = "id", type = "left", suffixes = c("", ".y")
      ),
      depends_on = "id"
    )
  )
  plan <- build_plan(steps)
  expect_true(all(c("income", "region") %in% plan$nodes[[1]]$consumes))
  expect_equal(plan$nodes[[1]]$group_vars, "region")
  # join consumes its keys and produces the RHS columns
  expect_equal(plan$nodes[[2]]$consumes, "id")
  expect_equal(plan$nodes[[2]]$produces, c("id", "extra"))
})

test_that("build_plan: compute with several outputs splits new_var", {
  steps <- list(
    mk_step("compute", new_var = "a, b", depends_on = "x")
  )
  plan <- build_plan(steps)
  expect_equal(plan$nodes[[1]]$produces, c("a", "b"))
})

test_that("build_plan: remove produces its vars (anti-dependency)", {
  steps <- list(
    mk_step("step_remove", exprs = list(vars = c("y", "z")))
  )
  plan <- build_plan(steps)
  expect_equal(plan$nodes[[1]]$produces, c("y", "z"))
  expect_equal(plan$nodes[[1]]$kind, "meta")
})

# ── explain ────────────────────────────────────────────────────────────

test_that("explain returns the plan of pending steps without executing", {
  svy <- make_test_survey(n = 10)
  svy <- step_rename(svy, edad = age)
  svy <- step_filter(svy, edad >= 20)
  svy <- step_validate(svy, edad > 0)
  svy <- step_remove(svy, y)

  n_before <- nrow(get_data(svy))
  plan <- explain(svy)

  expect_s3_class(plan, "meta_plan")
  expect_length(plan$nodes, 4)
  expect_equal(
    vapply(plan$nodes, function(n) n$kind, character(1)),
    c("meta", "filter", "fence", "meta")
  )
  # nothing was executed: data and pending steps are untouched
  expect_equal(nrow(get_data(svy)), n_before)
  expect_true("age" %in% names(get_data(svy)))
  expect_true("y" %in% names(get_data(svy)))
  expect_false(any(vapply(svy$steps, function(s) s$bake, logical(1))))
})

test_that("explain skips already baked steps", {
  svy <- make_test_survey(n = 10)
  # eager: recorded with bake = TRUE, must not enter the plan
  svy <- step_compute(svy, age2 = age * 2)
  svy <- step_filter(svy, age2 >= 40)
  plan <- explain(svy)
  expect_length(plan$nodes, 1)
  expect_equal(plan$nodes[[1]]$kind, "filter")
})

test_that("explain rejects non-Survey objects", {
  expect_error(explain(list()), "requires a Survey object")
})

test_that("explain prints classification, segments and pass counts", {
  svy <- make_test_survey(n = 10)
  svy <- step_rename(svy, edad = age)
  svy <- step_filter(svy, edad >= 20)
  svy <- step_validate(svy, edad > 0)
  svy <- step_remove(svy, y)

  expect_output(print(explain(svy)), "4 pending steps")
  expect_output(print(explain(svy)), "-- segment 1")
  expect_output(print(explain(svy)), "-- segment 2")
  expect_output(print(explain(svy)), "fence")
  expect_output(
    print(explain(svy)),
    "Passes over the data: 2 \\(current engine\\) -> 2"
  )
})

test_that("explain output snapshot", {
  svy <- make_test_survey(n = 10)
  svy <- step_rename(svy, edad = age)
  svy <- step_filter(svy, edad >= 20)
  svy <- step_validate(svy, edad > 0)
  svy <- step_remove(svy, y)
  expect_snapshot(print(explain(svy)))
})

test_that("explain with no pending steps says so", {
  svy <- make_test_survey(n = 5)
  expect_output(
    print(explain(svy)),
    "no pending steps: nothing to plan"
  )
  # baked pipelines also have nothing to plan
  svy <- step_filter(svy, age >= 18)
  svy <- bake_steps(svy)
  expect_output(
    print(explain(svy)),
    "no pending steps: nothing to plan"
  )
})
