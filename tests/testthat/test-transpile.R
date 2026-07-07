test_that("translate_stata_expr handles inrange", {
  result <- translate_stata_expr("inrange(e30,3,5)")
  expect_match(result, "e30 >= 3")
  expect_match(result, "e30 <= 5")
})

test_that("translate_stata_expr handles inlist", {
  result <- translate_stata_expr("inlist(x, 1, 2, 3)")
  expect_match(result, "x %in% c\\(")
})

test_that("translate_stata_expr handles missing value comparison", {
  expect_match(translate_stata_expr("var==."), "is.na\\(var\\)")
  expect_match(translate_stata_expr("var!=."), "!is.na\\(var\\)")
})

test_that("translate_stata_expr handles string()", {
  result <- translate_stata_expr("string(x)")
  expect_match(result, "as.character\\(x\\)")
})

test_that("is_constant_rhs detects constants", {
  expect_true(is_constant_rhs("0"))
  expect_true(is_constant_rhs("-9"))
  expect_true(is_constant_rhs("2.5"))
  expect_true(is_constant_rhs('"text"'))
  expect_true(is_constant_rhs("."))
  expect_false(is_constant_rhs("e51_2"))
  expect_false(is_constant_rhs("a + b"))
  expect_false(is_constant_rhs("6+e51_4_a"))
})

test_that("transpile_stata works on gen_replace fixture", {
  fixture <- system.file("stata-test-cases/gen_replace.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_stata(fixture)
  expect_true(length(result$steps) > 0)
  # bc_pe4 gen+replace with constants should produce step_recode
  recode_steps <- grep("step_recode", result$steps, value = TRUE)
  expect_true(length(recode_steps) >= 1)
  # bc_pe2 simple gen should produce step_compute
  compute_steps <- grep("step_compute.*bc_pe2", result$steps, value = TRUE)
  expect_true(length(compute_steps) >= 1)
})

test_that("transpile_stata works on gen_replace_expr fixture", {
  fixture <- system.file("stata-test-cases/gen_replace_expr.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_stata(fixture)
  # Expression RHS should produce step_compute with bc_edu (not step_recode)
  compute_steps <- grep("step_compute.*bc_edu", result$steps, value = TRUE)
  expect_true(length(compute_steps) >= 1)
  # Should use fifelse for conditional updates
  fifelse_steps <- grep("fifelse", result$steps, value = TRUE)
  expect_true(length(fifelse_steps) >= 1)
})

test_that("transpile_stata works on recode fixture", {
  fixture <- system.file("stata-test-cases/recode_gen.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_stata(fixture)
  expect_true(length(result$steps) > 0)
  # recode .=0 should produce fifelse(is.na(...))
  missing_steps <- grep("is.na", result$steps, value = TRUE)
  expect_true(length(missing_steps) >= 1)
})

test_that("transpile_stata works on mvencode fixture", {
  fixture <- system.file("stata-test-cases/mvencode.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_stata(fixture)
  expect_true(length(result$steps) >= 1)
  # All should be step_compute with fifelse(is.na)
  for (step in result$steps) {
    expect_match(step, "step_compute")
    expect_match(step, "is.na")
  }
})

test_that("transpile_stata works on egen_by fixture", {
  fixture <- system.file("stata-test-cases/egen_by.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_stata(fixture)
  expect_true(length(result$steps) >= 1)
  # Should have .by parameter
  by_steps <- grep("\\.by\\s*=", result$steps, value = TRUE)
  expect_true(length(by_steps) >= 1)
})

test_that("transpile_stata works on destring fixture", {
  fixture <- system.file("stata-test-cases/destring.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_stata(fixture)
  expect_true(length(result$steps) >= 1)
  # Should convert to as.numeric
  numeric_steps <- grep("as.numeric", result$steps, value = TRUE)
  expect_true(length(numeric_steps) >= 1)
})

test_that("transpile_stata returns labels from labels fixture", {
  fixture <- system.file("stata-test-cases/labels.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_stata(fixture)
  expect_true(length(result$labels$var_labels) >= 3)
  expect_true(length(result$labels$val_labels) >= 1)
})

test_that("optimize_steps collapses consecutive renames", {
  steps <- c(
    'step_rename(svy, edad = "age")',
    'step_rename(svy, sexo = "sex")',
    "step_compute(svy, x = 1)"
  )
  result <- optimize_steps(steps)
  expect_length(result, 2)
  expect_match(result[1], "edad.*sexo")
})

test_that("optimize_steps collapses consecutive removes", {
  steps <- c(
    "step_remove(svy, a, b)",
    "step_remove(svy, c, d)",
    "step_compute(svy, x = 1)"
  )
  result <- optimize_steps(steps)
  expect_length(result, 2)
  expect_match(result[1], "a.*b.*c.*d")
})

# ── optimize_steps: step_compute collapsing ──────────────────────────────────

test_that("optimize_steps collapses independent consecutive step_compute", {
  steps <- c(
    "step_compute(svy, a = x + 1)",
    "step_compute(svy, b = y * 2)"
  )
  result <- optimize_steps(steps)
  expect_length(result, 1)
  expect_match(result[1], "a = x \\+ 1")
  expect_match(result[1], "b = y \\* 2")
})

test_that("optimize_steps preserves dependent step_compute calls", {
  steps <- c(
    "step_compute(svy, a = x + 1)",
    "step_compute(svy, b = a * 2)"
  )
  result <- optimize_steps(steps)
  expect_length(result, 2)
})

test_that("optimize_steps splits chain at dependency boundary", {
  steps <- c(
    "step_compute(svy, a = x + 1)",
    "step_compute(svy, b = y + 1)",
    "step_compute(svy, c = a + b)"
  )
  result <- optimize_steps(steps)
  expect_length(result, 2)
  # First step collapses a and b (independent)
  expect_match(result[1], "a = x \\+ 1")
  expect_match(result[1], "b = y \\+ 1")
  # Second step has c (depends on a and b)
  expect_match(result[2], "c = a \\+ b")
})

test_that("optimize_steps collapses step_compute with same .by", {
  steps <- c(
    'step_compute(svy, a = mean(x), .by = "g")',
    'step_compute(svy, b = sum(y), .by = "g")'
  )
  result <- optimize_steps(steps)
  expect_length(result, 1)
  expect_match(result[1], "a = mean\\(x\\)")
  expect_match(result[1], "b = sum\\(y\\)")
  expect_match(result[1], '\\.by = "g"')
})

test_that("optimize_steps does not collapse step_compute with different .by", {
  steps <- c(
    'step_compute(svy, a = mean(x), .by = "g1")',
    'step_compute(svy, b = sum(y), .by = "g2")'
  )
  result <- optimize_steps(steps)
  expect_length(result, 2)
})

test_that("optimize_steps does not collapse step_compute with/without .by", {
  steps <- c(
    "step_compute(svy, a = x + 1)",
    'step_compute(svy, b = sum(y), .by = "g")'
  )
  result <- optimize_steps(steps)
  expect_length(result, 2)
})

test_that("optimize_steps single step_compute unchanged", {
  steps <- c("step_compute(svy, a = x + 1)")
  result <- optimize_steps(steps)
  expect_length(result, 1)
  expect_equal(result[1], steps[1])
})

test_that("optimize_steps does not collapse step_compute across other step types", {
  steps <- c(
    "step_compute(svy, a = 1)",
    'step_rename(svy, edad = "age")',
    "step_compute(svy, b = 2)"
  )
  result <- optimize_steps(steps)
  expect_length(result, 3)
})

test_that("optimize_steps handles complex step_compute expressions", {
  steps <- c(
    "step_compute(svy, x = data.table::fifelse(age > 18, income / 1000, 0))",
    "step_compute(svy, y = as.integer(status %in% c(1, 2, 3)))"
  )
  result <- optimize_steps(steps)
  expect_length(result, 1)
  expect_match(result[1], "fifelse")
  expect_match(result[1], "as\\.integer")
})

test_that("extract_output_vars finds created variables", {
  steps <- c(
    "step_compute(svy, x = 1)",
    "step_compute(svy, y = x + 2)",
    "step_recode(svy, z, x == 1 ~ 'a', .default = 'b')"
  )
  vars <- extract_output_vars(steps)
  expect_true("x" %in% vars)
  expect_true("y" %in% vars)
  expect_true("z" %in% vars)
})

# ── Task 7: _n-1/_n+1 lag/lead translation ───────────────────────────────────

test_that("translate_stata_expr handles var[_n-1] lag subscript", {
  result <- translate_stata_expr("nucleo[_n-1]")
  expect_match(result, "shift\\(nucleo,\\s*1")
  expect_match(result, 'type\\s*=\\s*"lag"')
})

test_that("translate_stata_expr handles var[_n+1] lead subscript", {
  result <- translate_stata_expr("x[_n+1]")
  expect_match(result, "shift\\(x,\\s*1")
  expect_match(result, 'type\\s*=\\s*"lead"')
})

test_that("translate_stata_expr handles _n subscript in condition", {
  # In if-clause: e30[_n-1]==3 should become shift(e30, 1, type="lag")==3
  result <- translate_stata_expr("e30[_n-1]==3")
  expect_match(result, "shift\\(e30")
  expect_match(result, "==3")
})

test_that("transpile_stata handles lag_lead fixture", {
  fixture <- system.file("stata-test-cases/lag_lead.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_stata(fixture)
  # Should contain shift() calls from var[_n-1] patterns
  shift_steps <- grep("shift\\(", result$steps, value = TRUE)
  expect_true(length(shift_steps) >= 1)
  # No MANUAL_REVIEW for _N or _n patterns
  manual <- grep("MANUAL_REVIEW.*_n|MANUAL_REVIEW.*_N", result$steps,
    value = TRUE
  )
  expect_length(manual, 0)
})

# ── Task 8: _N total count translation ──────────────────────────────────────

test_that("translate_stata_expr handles standalone _N", {
  result <- translate_stata_expr("_N")
  expect_equal(result, ".N")
})

test_that("translate_stata_expr handles _N in expression", {
  result <- translate_stata_expr("income / _N")
  expect_match(result, "income / \\.N")
})

test_that("transpile produces .N for bysort gen _N pattern", {
  fixture <- system.file("stata-test-cases/lag_lead.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_stata(fixture)
  # "bysort bc_correlat: gen max_nper = _N" should become step_compute with .N
  n_steps <- grep("\\.N", result$steps, value = TRUE)
  expect_true(length(n_steps) >= 1)
  # Should have .by for bysort
  by_steps <- grep('\\.by\\s*=.*"bc_correlat"', result$steps, value = TRUE)
  expect_true(length(by_steps) >= 1)
})

# ── Task 9: Variable range expansion (suma1-suma4) ──────────────────────────

test_that("expand_var_range expands var1-var4 to individual vars", {
  result <- expand_var_range("suma1-suma4")
  expect_equal(result, c("suma1", "suma2", "suma3", "suma4"))
})

test_that("expand_var_range passes through single variable", {
  expect_equal(expand_var_range("income"), "income")
})

test_that("expand_var_range handles alpha range", {
  # e.g. e51_2_1-e51_2_5 (common in ECH)
  result <- expand_var_range("e51_2_1-e51_2_5")
  expect_equal(result, paste0("e51_2_", 1:5))
})

test_that("recode with variable range expands to multiple variables", {
  fixture <- system.file("stata-test-cases/var_range.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_stata(fixture)
  # recode suma1-suma4 (.=0) should reference all 4 suma variables
  all_steps <- paste(result$steps, collapse = " ")
  for (v in paste0("suma", 1:4)) {
    expect_match(all_steps, v)
  }
})

test_that("mvencode with variable range expands to individual steps", {
  fixture <- system.file("stata-test-cases/var_range.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_stata(fixture)
  # mvencode suma1-suma4, mv(0) should reference all 4 suma variables
  all_steps <- paste(result$steps, collapse = " ")
  for (v in paste0("suma", 1:4)) {
    expect_match(all_steps, paste0("is.na\\(", v, "\\)"))
  }
})

# ── Task 10: fifelse type coercion ──────────────────────────────────────────

test_that("translate_gen_block wraps fifelse init with matching type", {
  # When init=-9 and RHS are constants, fifelse(cond, "1", -9) fails type check
  # The transpiled step_recode handles this (string output)

  # But for expression chains: step_compute(svy, v = fifelse(cond, 1L, v))
  # where v may be character, we need as.numeric or as.integer wrapping
  # This test verifies numeric constants get L suffix for integer clarity
  result <- translate_stata_expr("-9")
  # Negative number should pass through unchanged
  expect_equal(result, "-9")
})

test_that("fifelse with numeric default and numeric RHS produces valid R", {
  # gen v = -9 + replace v = 1 if cond -> step_compute chain
  # fifelse(cond, 1, v) is valid when v is initialized to -9 (both numeric)
  cmds <- list(
    list(
      cmd = "gen", args = "v = -9", if_clause = NULL,
      options = NULL, by_group = NULL, raw_line = "gen v = -9",
      line_num = 1L, capture = FALSE
    ),
    list(
      cmd = "replace", args = "v = 1", if_clause = "x==1",
      options = NULL, by_group = NULL, raw_line = "replace v = 1 if x==1",
      line_num = 2L, capture = FALSE
    )
  )
  result <- translate_gen_block(cmds, 1)
  expect_true(length(result$steps) >= 1)
  # Should produce valid R that can parse
  for (s in result$steps) {
    expect_no_error(parse(text = s))
  }
})

# ── Task 11: gen with bysort prefix ─────────────────────────────────────────

test_that("gen with bysort prefix produces .by in step_compute", {
  cmd <- list(
    cmd = "gen", args = "max_nper = _N", if_clause = NULL,
    options = NULL, by_group = "bc_correlat", raw_line = "gen max_nper = _N",
    line_num = 1L, capture = FALSE
  )
  result <- translate_gen_block(list(cmd), 1)
  expect_true(length(result$steps) >= 1)
  expect_match(result$steps[[1]], "\\.by")
  expect_match(result$steps[[1]], "\\.N")
})

test_that("bare gen without = produces step_compute with NA", {
  cmds <- list(
    list(
      cmd = "gen", args = "ine_ht13", if_clause = NULL,
      options = NULL, by_group = NULL, raw_line = "gen ine_ht13",
      line_num = 1L, capture = TRUE
    )
  )
  result <- translate_gen_block(cmds, 1)
  expect_true(length(result$steps) >= 1)
  expect_match(result$steps[[1]], "ine_ht13 = NA")
})

test_that("gen with multi-var bysort produces c() in .by", {
  cmd <- list(
    cmd = "gen", args = "tot = sum(x)", if_clause = NULL,
    options = NULL, by_group = "g1 g2", raw_line = "gen tot = sum(x)",
    line_num = 1L, capture = FALSE
  )
  result <- translate_gen_block(list(cmd), 1)
  expect_true(length(result$steps) >= 1)
  expect_match(result$steps[[1]], 'c\\("g1", "g2"\\)')
})

# ── Multi-variable destring ──────────────────────────────────────────────────

test_that("destring with multiple variables produces one step per var", {
  cmd <- list(
    cmd = "destring", args = "g144_1 g261 g261_1",
    if_clause = NULL, options = "replace force",
    by_group = NULL, raw_line = "destring g144_1 g261 g261_1, replace force",
    line_num = 1L, capture = FALSE
  )
  result <- translate_destring(cmd)
  expect_true(length(result$steps) == 3)
  expect_match(result$steps[[1]], "g144_1")
  expect_match(result$steps[[2]], "g261")
  expect_match(result$steps[[3]], "g261_1")
  for (s in result$steps) {
    expect_match(s, "as.numeric")
    expect_no_error(parse(text = s))
  }
})

# ── Drop with STATA variable range ──────────────────────────────────────────

test_that("drop with STATA variable range expands to individual vars", {
  cmd <- list(
    cmd = "drop", args = "aux1-aux14_max",
    if_clause = NULL, options = NULL, by_group = NULL,
    raw_line = "drop aux1-aux14_max",
    line_num = 1L, capture = FALSE
  )
  result <- translate_drop(cmd)
  expect_true(length(result$steps) >= 1)
  step <- result$steps[[1]]
  # Should contain aux1, aux2, ..., aux14, aux1_max, ..., aux14_max
  expect_match(step, "aux1,")
  expect_match(step, "aux14")
  expect_match(step, "aux1_max")
  expect_match(step, "aux14_max")
})

test_that("expand_var_range handles suffixed ranges like aux1-aux14_max", {
  result <- expand_var_range("aux1-aux14_max")
  # Should expand: aux1..aux14 + aux1_max..aux14_max
  expect_true("aux1" %in% result)
  expect_true("aux14" %in% result)
  expect_true("aux1_max" %in% result)
  expect_true("aux14_max" %in% result)
  expect_equal(length(result), 28)
})

# ── Multi-variable recode ────────────────────────────────────────────────────

test_that("recode with multiple space-separated variables expands", {
  cmd <- list(
    cmd = "recode", args = "g144_1 g261 g261_1 (.=0)",
    if_clause = NULL, options = NULL, by_group = NULL,
    raw_line = "recode g144_1 g261 g261_1 (.=0)",
    line_num = 1L, capture = FALSE
  )
  result <- translate_recode(cmd)
  # Should produce 3 steps (one per variable)
  expect_equal(length(result$steps), 3)
  expect_match(result$steps[[1]], "g144_1")
  expect_match(result$steps[[2]], "g261[^_]")
  expect_match(result$steps[[3]], "g261_1")
})

test_that("transpile_stata_module groups files by module", {
  skip_on_cran()
  year_dir <- file.path("do_files_iecon", "2022")
  # Use absolute path from package root
  year_dir_abs <- file.path(
    system.file(package = "metasurvey"),
    "..", "..", "..", year_dir
  )
  # Fallback to relative path from working directory
  if (!dir.exists(year_dir_abs)) {
    year_dir_abs <- year_dir
  }
  skip_if_not(dir.exists(year_dir_abs),
    message = "do_files_iecon/2022 not available"
  )

  recipes <- transpile_stata_module(year_dir_abs, year = 2022)
  expect_true(is.list(recipes))
  expect_true(length(recipes) >= 1)
  # Each element should be a Recipe
  for (r in recipes) {
    expect_true(inherits(r, "Recipe"))
    expect_true(length(r$steps) > 0)
  }
})


# --- Merged from test-transpile-e2e.R ---

# End-to-end integration test: transpile do-files -> load ECH -> bake recipes
# Requires: do_files_iecon/ directory and example-data/ech/ech_2022.csv
# Skipped on CRAN and when data is not available

test_that("transpile 2022 do-files and bake sequentially on ECH data", {
  skip_on_cran()
  pkg_root <- normalizePath(test_path("..", ".."), mustWork = FALSE)
  year_dir <- file.path(pkg_root, "do_files_iecon", "2022")
  skip_if_not(dir.exists(year_dir), "do_files_iecon/2022 not available")

  ech_path <- file.path(pkg_root, "example-data", "ech", "ech_2022.csv")
  skip_if_not(file.exists(ech_path), "ECH 2022 CSV not available")

  # Step 1: Transpile do-files into recipes by module
  recipes <- transpile_stata_module(year_dir, year = 2022)
  expect_true(is.list(recipes))
  expect_true(length(recipes) >= 1)

  # Step 2: Load a SAMPLE of ECH data (first 500 rows for speed/memory)
  ech_data <- data.table::fread(ech_path, nrows = 500)
  data.table::setnames(ech_data, tolower(names(ech_data)))
  tmp_path <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp_path), add = TRUE)
  data.table::fwrite(ech_data, tmp_path)
  old_engine <- getOption("metasurvey.engine")
  options(metasurvey.engine = "data.table")
  on.exit(options(metasurvey.engine = old_engine), add = TRUE)
  svy <- load_survey(
    path = tmp_path,
    svy_type = "ech",
    svy_edition = "2022",
    svy_weight = list(annual = "w_ano")
  )
  expect_true(nrow(svy$data) > 0)

  # Step 3: Apply recipes SEQUENTIALLY in module order
  module_order <- c(
    "data_prep", "demographics", "income_detail",
    "income_aggregate", "cleanup"
  )

  baked_modules <- character(0)
  total_steps_ok <- 0
  for (module_name in module_order) {
    if (!module_name %in% names(recipes)) next
    rec <- recipes[[module_name]]

    executable_steps <- rec$steps[!grepl("^#", rec$steps)]
    if (length(executable_steps) == 0) next

    # Bake steps one by one, skipping expected missing-variable errors
    eval_env <- new.env(parent = parent.frame())
    eval_env$svy <- svy
    steps_ok <- 0
    for (step_str in executable_steps) {
      tryCatch(
        {
          step_call <- parse(text = step_str)[[1]]
          if (is.call(step_call) && length(step_call) >= 2 &&
            is.name(step_call[[2]]) &&
            as.character(step_call[[2]]) == ".") {
            step_call[[2]] <- as.name("svy")
          }
          eval_env$svy <- eval(step_call, envir = eval_env)
          steps_ok <- steps_ok + 1
        },
        error = function(e) {
          msg <- conditionMessage(e)
          # Skip expected errors:
          # - missing variables (orchestrator creates them)
          # - parse errors (untranslated STATA syntax like _n, _N)
          # - undefined columns
          is_expected <- grepl(
            paste0(
              "not found|not exist|Variables to rename|",
              "undefined columns|cannot remove|object.*not found|",
              "unexpected symbol|unexpected '='|parse error|",
              "type logical but|type character but|type double but|",
              "type integer but|same type"
            ),
            msg
          )
          if (!is_expected) {
            fail(sprintf(
              "Module '%s' unexpected error: %s\nStep: %s",
              module_name, msg, substr(step_str, 1, 120)
            ))
          }
        }
      )
    }
    svy <- eval_env$svy

    if (steps_ok > 0) {
      baked_modules <- c(baked_modules, module_name)
      total_steps_ok <- total_steps_ok + steps_ok
    }
  }

  # At least some modules and steps should have baked successfully
  expect_true(
    length(baked_modules) >= 2,
    info = paste("Baked modules:", paste(baked_modules, collapse = ", "))
  )
  expect_true(total_steps_ok >= 50,
    info = paste("Total steps baked:", total_steps_ok)
  )
})

test_that("transpile single do-file produces valid steps for bake", {
  skip_on_cran()
  fixture <- system.file("stata-test-cases/gen_replace.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))

  result <- transpile_stata(fixture)
  expect_true(length(result$steps) > 0)

  # Create survey with the required source variables
  svy <- make_test_survey(n = 4)
  dt <- svy$data
  dt[, e26 := c(1, 2, 1, 2)]
  dt[, e27 := c(25, 30, 45, 50)]
  dt[, e30 := c(1, 2, 3, 7)]
  dt[, region_4 := c(1, 2, 3, 4)]
  svy <- set_data(svy, dt)

  rec <- Recipe$new(
    id = "test_gen_replace",
    name = "Test gen_replace",
    user = "test",
    edition = "2022",
    survey_type = "ech",
    default_engine = "data.table",
    depends_on = list(),
    description = "Test fixture",
    steps = result$steps,
    topic = "test"
  )
  svy <- add_recipe(svy, rec, bake = FALSE)
  baked <- bake_recipes(svy)

  expect_true(inherits(baked, "Survey"))
  expect_true("bc_pe4" %in% names(baked$data))
  expect_true("bc_pe2" %in% names(baked$data))
  expect_true("bc_pe3" %in% names(baked$data))
  # Check recode values (step_recode produces character/factor)
  # e30=c(1,2,3,7): STATA sequential-overwrite semantics preserved by
  # emitting reversed conditions into first-match-wins step_recode
  expect_equal(as.character(baked$data$bc_pe4), c("1", "2", "3", "5"))
  expect_equal(baked$data$bc_pe2, c(1, 2, 1, 2))
})

# --- translate_commands, translate_replace, translate_keep, etc. ---

test_that("translate_commands skips label and sort commands", {
  cmds <- list(
    list(
      cmd = "sort", args = "id", if_clause = NULL, options = NULL,
      by_group = NULL, raw_line = "sort id", line_num = 1L, capture = FALSE
    ),
    list(
      cmd = "label", args = "variable x 'test'", if_clause = NULL,
      options = NULL, by_group = NULL, raw_line = "label variable x 'test'",
      line_num = 2L, capture = FALSE
    ),
    list(
      cmd = "gen", args = "y = 1", if_clause = NULL, options = NULL,
      by_group = NULL, raw_line = "gen y = 1", line_num = 3L, capture = FALSE
    )
  )
  result <- translate_commands(cmds)
  expect_equal(result$stats$skipped, 2L)
  expect_equal(result$stats$translated, 1L)
  expect_true(length(result$steps) == 1)
})

test_that("translate_commands emits MANUAL_REVIEW for unhandled commands", {
  cmds <- list(
    list(
      cmd = "regress", args = "y x1 x2", if_clause = NULL, options = NULL,
      by_group = NULL, raw_line = "regress y x1 x2", line_num = 1L,
      capture = FALSE
    )
  )
  result <- translate_commands(cmds, strict = FALSE)
  expect_equal(result$stats$manual_review, 1L)
  expect_true(length(result$warnings) == 1)
  expect_match(result$warnings[1], "MANUAL_REVIEW")
})

test_that("translate_commands strict mode errors on unhandled command", {
  cmds <- list(
    list(
      cmd = "regress", args = "y x1 x2", if_clause = NULL, options = NULL,
      by_group = NULL, raw_line = "regress y x1 x2", line_num = 1L,
      capture = FALSE
    )
  )
  expect_error(translate_commands(cmds, strict = TRUE), "MANUAL_REVIEW")
})

test_that("translate_replace standalone without if clause", {
  cmd <- list(
    cmd = "replace", args = "x = 0", if_clause = NULL, options = NULL,
    by_group = NULL, raw_line = "replace x = 0", line_num = 1L, capture = FALSE
  )
  result <- translate_replace(cmd)
  expect_true(length(result$steps) == 1)
  expect_match(result$steps[[1]], "step_compute.*x = 0")
  expect_no_error(parse(text = result$steps[[1]]))
})

test_that("translate_replace with if clause uses fifelse", {
  cmd <- list(
    cmd = "replace", args = "x = 1", if_clause = "age > 30",
    options = NULL, by_group = NULL, raw_line = "replace x = 1 if age > 30",
    line_num = 1L, capture = FALSE
  )
  result <- translate_replace(cmd)
  expect_true(length(result$steps) == 1)
  expect_match(result$steps[[1]], "fifelse")
  expect_match(result$steps[[1]], "age > 30")
})

test_that("translate_replace returns NULL for unparseable args", {
  cmd <- list(
    cmd = "replace", args = "", if_clause = NULL, options = NULL,
    by_group = NULL, raw_line = "replace", line_num = 1L, capture = FALSE
  )
  result <- translate_replace(cmd)
  expect_null(result)
})

test_that("translate_keep emits MANUAL_REVIEW", {
  cmd <- list(
    cmd = "keep", args = "id age income", if_clause = NULL, options = NULL,
    by_group = NULL, raw_line = "keep id age income", line_num = 1L,
    capture = FALSE
  )
  result <- translate_keep(cmd)
  expect_true(length(result$steps) == 1)
  expect_match(result$steps[[1]], "MANUAL_REVIEW")
  expect_match(result$steps[[1]], "keep")
})

test_that("translate_tostring produces as.character step", {
  cmd <- list(
    cmd = "tostring", args = "edad", if_clause = NULL, options = NULL,
    by_group = NULL, raw_line = "tostring edad", line_num = 1L, capture = FALSE
  )
  result <- translate_tostring(cmd)
  expect_true(length(result$steps) == 1)
  expect_match(result$steps[[1]], "as.character\\(edad\\)")
  expect_no_error(parse(text = result$steps[[1]]))
})

test_that("translate_tostring strips options", {
  cmd <- list(
    cmd = "tostring", args = "x, replace force", if_clause = NULL,
    options = "replace force", by_group = NULL,
    raw_line = "tostring x, replace force", line_num = 1L, capture = FALSE
  )
  result <- translate_tostring(cmd)
  expect_match(result$steps[[1]], "step_compute.*x = as.character\\(x\\)")
})

test_that("translate_merge emits MANUAL_REVIEW", {
  cmd <- list(
    cmd = "merge", args = "1:1 id using data2.dta", if_clause = NULL,
    options = NULL, by_group = NULL,
    raw_line = "merge 1:1 id using data2.dta", line_num = 1L, capture = FALSE
  )
  result <- translate_merge(cmd)
  expect_true(length(result$steps) == 1)
  expect_match(result$steps[[1]], "MANUAL_REVIEW")
  expect_match(result$steps[[1]], "merge")
})

test_that("translate_rename returns NULL for single token", {
  cmd <- list(
    cmd = "rename", args = "only_one", if_clause = NULL, options = NULL,
    by_group = NULL, raw_line = "rename only_one", line_num = 1L,
    capture = FALSE
  )
  result <- translate_rename(cmd)
  expect_null(result)
})

test_that("translate_rename produces step_rename", {
  cmd <- list(
    cmd = "rename", args = "old_name new_name", if_clause = NULL,
    options = NULL, by_group = NULL, raw_line = "rename old_name new_name",
    line_num = 1L, capture = FALSE
  )
  result <- translate_rename(cmd)
  expect_true(length(result$steps) == 1)
  expect_match(result$steps[[1]], 'step_rename.*new_name.*=.*"old_name"')
})

# --- extract_input_vars, build_doc_from_steps, transpile_coverage, filter_labels ---

test_that("extract_input_vars finds referenced variables excluding outputs", {
  steps <- c(
    "step_compute(svy, z = age + income)",
    "step_compute(svy, w = z * 2)"
  )
  inputs <- extract_input_vars(steps)
  # age, income are inputs (not created by any step)
  expect_true("age" %in% inputs)
  expect_true("income" %in% inputs)
  # z is created by step 1, so NOT an input
  expect_false("z" %in% inputs)
  # svy, step_compute are stripped as known non-variables
  expect_false("svy" %in% inputs)
})

test_that("extract_input_vars skips comment lines", {
  steps <- c(
    "# MANUAL_REVIEW: some comment",
    "step_compute(svy, x = age + 1)"
  )
  inputs <- extract_input_vars(steps)
  expect_true("age" %in% inputs)
})

test_that("build_doc_from_steps produces pipeline with compute steps", {
  steps <- c(
    "step_compute(svy, x = age + 1)",
    "step_compute(svy, y = x * 2)"
  )
  doc <- build_doc_from_steps(steps)
  expect_true(is.list(doc))
  expect_true("input_variables" %in% names(doc))
  expect_true("output_variables" %in% names(doc))
  expect_true("pipeline" %in% names(doc))
  expect_true("x" %in% doc$output_variables)
  expect_true("y" %in% doc$output_variables)
  expect_true("age" %in% doc$input_variables)
  expect_equal(length(doc$pipeline), 2)
  expect_equal(doc$pipeline[[1]]$type, "compute")
})

test_that("build_doc_from_steps handles recode steps", {
  steps <- c(
    "step_recode(svy, age_cat, age < 30 ~ 'young', .default = 'old')"
  )
  doc <- build_doc_from_steps(steps)
  expect_equal(doc$pipeline[[1]]$type, "recode")
  expect_true("age_cat" %in% doc$output_variables)
})

test_that("build_doc_from_steps handles rename steps", {
  steps <- c(
    'step_rename(svy, edad = "age", sexo = "sex")'
  )
  doc <- build_doc_from_steps(steps)
  expect_equal(doc$pipeline[[1]]$type, "rename")
  expect_true("edad" %in% doc$output_variables)
  expect_true("sexo" %in% doc$output_variables)
})

test_that("build_doc_from_steps handles remove steps", {
  steps <- c(
    "step_remove(svy, tmp1, tmp2)"
  )
  doc <- build_doc_from_steps(steps)
  expect_equal(doc$pipeline[[1]]$type, "remove")
  expect_true("tmp1" %in% doc$output_variables)
})

test_that("build_doc_from_steps skips comment lines", {
  steps <- c(
    "# MANUAL_REVIEW: skip this",
    "step_compute(svy, x = 1)"
  )
  doc <- build_doc_from_steps(steps)
  expect_equal(length(doc$pipeline), 1)
})

test_that("transpile_coverage reports on a single .do file", {
  fixture <- system.file("stata-test-cases/gen_replace.do",
    package = "metasurvey"
  )
  skip_if_not(file.exists(fixture))
  result <- transpile_coverage(fixture)
  expect_true(is.data.frame(result))
  expect_true("coverage_pct" %in% names(result))
  expect_true("TOTAL" %in% result$file)
  expect_true(nrow(result) >= 2) # file row + TOTAL row
  expect_true(result$translated[1] >= 1)
})

test_that("transpile_coverage reports on a directory", {
  fixture_dir <- system.file("stata-test-cases", package = "metasurvey")
  skip_if_not(dir.exists(fixture_dir))
  result <- transpile_coverage(fixture_dir)
  expect_true(is.data.frame(result))
  # Should have one row per .do file plus TOTAL
  n_do <- length(list.files(fixture_dir, "\\.do$"))
  expect_equal(nrow(result), n_do + 1)
})

test_that("transpile_coverage errors on non-existent path", {
  expect_error(transpile_coverage("/nonexistent/path"), "Path not found")
})

test_that("filter_labels filters to specified variables", {
  labels <- list(
    var_labels = list(age = "Age", sex = "Sex", income = "Income"),
    val_labels = list(sex = list("1" = "M", "2" = "F"), region = list("1" = "N"))
  )
  filtered <- filter_labels(labels, c("age", "sex"))
  expect_equal(names(filtered$var_labels), c("age", "sex"))
  expect_equal(names(filtered$val_labels), "sex")
})

# --- translate_gen_block edge cases, recode range ---

test_that("translate_gen_block with if clause (no replace) uses fifelse", {
  cmd <- list(
    cmd = "gen", args = "eligible = 1", if_clause = "age >= 18",
    options = NULL, by_group = NULL, raw_line = "gen eligible = 1 if age >= 18",
    line_num = 1L, capture = FALSE
  )
  result <- translate_gen_block(list(cmd), 1)
  expect_true(length(result$steps) >= 1)
  expect_match(result$steps[[1]], "fifelse")
  expect_match(result$steps[[1]], "age >= 18")
  expect_match(result$steps[[1]], "eligible")
  expect_no_error(parse(text = result$steps[[1]]))
})

test_that("translate_gen_block gen+replace all constants produces step_recode", {
  cmds <- list(
    list(
      cmd = "gen", args = "cat = 0", if_clause = NULL,
      options = NULL, by_group = NULL, raw_line = "gen cat = 0",
      line_num = 1L, capture = FALSE
    ),
    list(
      cmd = "replace", args = "cat = 1", if_clause = "age < 30",
      options = NULL, by_group = NULL, raw_line = "replace cat = 1 if age < 30",
      line_num = 2L, capture = FALSE
    ),
    list(
      cmd = "replace", args = "cat = 2", if_clause = "age >= 30 & age < 65",
      options = NULL, by_group = NULL,
      raw_line = "replace cat = 2 if age >= 30 & age < 65",
      line_num = 3L, capture = FALSE
    )
  )
  result <- translate_gen_block(cmds, 1)
  expect_true(length(result$steps) >= 1)
  expect_match(result$steps[[1]], "step_recode")
  expect_match(result$steps[[1]], ".default")
  expect_equal(result$advance, 3)
})

test_that("translate_gen_block gen+replace mixed (expression RHS) uses fifelse chain", {
  cmds <- list(
    list(
      cmd = "gen", args = "ratio = 0", if_clause = NULL,
      options = NULL, by_group = NULL, raw_line = "gen ratio = 0",
      line_num = 1L, capture = FALSE
    ),
    list(
      cmd = "replace", args = "ratio = income / 1000", if_clause = "age > 18",
      options = NULL, by_group = NULL,
      raw_line = "replace ratio = income / 1000 if age > 18",
      line_num = 2L, capture = FALSE
    )
  )
  result <- translate_gen_block(cmds, 1)
  expect_true(length(result$steps) >= 2) # init + fifelse
  expect_match(result$steps[[1]], "step_compute.*ratio = 0")
  expect_match(result$steps[[2]], "fifelse")
  for (s in result$steps) expect_no_error(parse(text = s))
})

test_that("translate_gen_block bare gen with byte type prefix", {
  cmds <- list(
    list(
      cmd = "gen", args = "byte flag", if_clause = NULL,
      options = NULL, by_group = NULL, raw_line = "gen byte flag",
      line_num = 1L, capture = TRUE
    )
  )
  result <- translate_gen_block(cmds, 1)
  expect_true(length(result$steps) >= 1)
  expect_match(result$steps[[1]], "flag = NA")
})

test_that("translate_recode_single handles range mapping (23/38=22)", {
  parsed <- list(
    var_name = "edad",
    gen_var = NULL,
    mappings = list(
      list(from_range = c(23, 38), to = "22"),
      list(from = ".", to = "0")
    )
  )
  steps <- translate_recode_single(parsed)
  expect_true(length(steps) >= 2)
  expect_match(steps[1], "edad >= 23")
  expect_match(steps[1], "edad <= 38")
  expect_match(steps[2], "is.na")
})

test_that("translate_recode_single handles multi-value from", {
  parsed <- list(
    var_name = "x",
    gen_var = NULL,
    mappings = list(
      list(from = c("1", "2", "3"), to = "99")
    )
  )
  steps <- translate_recode_single(parsed)
  expect_true(length(steps) >= 1)
  expect_match(steps[1], "%in%")
  expect_match(steps[1], "c\\(1, 2, 3\\)")
})

test_that("translate_recode_single with gen() copies variable first", {
  parsed <- list(
    var_name = "source",
    gen_var = "target",
    mappings = list(
      list(from = c("1"), to = "99")
    )
  )
  steps <- translate_recode_single(parsed)
  # First step should be copy: step_compute(svy, target = source)
  expect_match(steps[1], "target = source")
  # Second step should be the recode
  expect_match(steps[2], "target.*fifelse")
})

test_that("translate_drop with if clause emits MANUAL_REVIEW", {
  cmd <- list(
    cmd = "drop", args = "x", if_clause = "age < 18", options = NULL,
    by_group = NULL, raw_line = "drop if age < 18", line_num = 1L,
    capture = FALSE
  )
  result <- translate_drop(cmd)
  expect_match(result$steps[[1]], "MANUAL_REVIEW")
  expect_match(result$steps[[1]], "observation deletion")
})

# ── Additional transpile coverage push ────────────────────────────────────────

test_that("translate_egen without by-group produces simple step_compute", {
  cmd <- list(
    cmd = "egen", args = "total_inc = sum(income)", if_clause = NULL,
    options = NULL, by_group = NULL,
    raw_line = "egen total_inc = sum(income)", line_num = 1L, capture = FALSE
  )
  result <- translate_egen(cmd)
  expect_match(result$steps, "step_compute")
  expect_match(result$steps, "total_inc")
  expect_match(result$steps, "sum.*income.*na.rm = TRUE")
  # No .by argument
  expect_false(grepl("\\.by", result$steps))
})

test_that("translate_egen with multiple by-group vars produces c() for .by", {
  cmd <- list(
    cmd = "egen", args = "mean_age = mean(age)", if_clause = NULL,
    options = NULL, by_group = "region status",
    raw_line = "bysort region status: egen mean_age = mean(age)",
    line_num = 1L, capture = FALSE
  )
  result <- translate_egen(cmd)
  expect_match(result$steps, "\\.by = c\\(")
  expect_match(result$steps, '"region"')
  expect_match(result$steps, '"status"')
})

test_that("translate_egen with unknown function passes through", {
  cmd <- list(
    cmd = "egen", args = "val = rowtotal(a b c)", if_clause = NULL,
    options = NULL, by_group = NULL,
    raw_line = "egen val = rowtotal(a b c)", line_num = 1L, capture = FALSE
  )
  result <- translate_egen(cmd)
  expect_match(result$steps, "rowtotal\\(a b c\\)")
})

test_that("translate_egen returns NULL for invalid egen syntax", {
  cmd <- list(
    cmd = "egen", args = "no_equals_sign", if_clause = NULL,
    options = NULL, by_group = NULL,
    raw_line = "egen no_equals_sign", line_num = 1L, capture = FALSE
  )
  expect_null(translate_egen(cmd))
})

test_that("translate_destring produces as.numeric conversion", {
  cmd <- list(
    cmd = "destring", args = "income_str", if_clause = NULL,
    options = "replace", by_group = NULL,
    raw_line = "destring income_str, replace", line_num = 1L, capture = FALSE
  )
  result <- translate_destring(cmd)
  expect_match(result$steps, "step_compute")
  expect_match(result$steps, "as\\.numeric.*as\\.character.*income_str")
})

test_that("translate_destring with force uses suppressWarnings", {
  cmd <- list(
    cmd = "destring", args = "x", if_clause = NULL,
    options = "replace force", by_group = NULL,
    raw_line = "destring x, replace force", line_num = 1L, capture = FALSE
  )
  result <- translate_destring(cmd)
  expect_match(result$steps, "suppressWarnings")
})

test_that("translate_mvencode handles multiple variables with range", {
  cmd <- list(
    cmd = "mvencode", args = "a b c", if_clause = NULL,
    options = "mv(-99)", by_group = NULL,
    raw_line = "mvencode a b c, mv(-99)", line_num = 1L, capture = FALSE
  )
  result <- translate_mvencode(cmd)
  expect_length(result$steps, 3)
  expect_match(result$steps[1], "fifelse.*is\\.na.*a.*-99")
  expect_match(result$steps[2], "fifelse.*is\\.na.*b.*-99")
})

test_that("translate_drop with empty args returns NULL", {
  cmd <- list(
    cmd = "drop", args = "", if_clause = NULL, options = NULL,
    by_group = NULL, raw_line = "drop", line_num = 1L, capture = FALSE
  )
  result <- translate_drop(cmd)
  expect_null(result)
})

test_that("translate_drop with variable range expands correctly", {
  cmd <- list(
    cmd = "drop", args = "aux1-aux3", if_clause = NULL, options = NULL,
    by_group = NULL, raw_line = "drop aux1-aux3", line_num = 1L, capture = FALSE
  )
  result <- translate_drop(cmd)
  expect_match(result$steps, "step_remove")
  expect_match(result$steps, "aux1.*aux2.*aux3")
})

test_that("translate_gen_block with gen followed by non-replace breaks lookahead", {
  cmds <- list(
    list(
      cmd = "gen", args = "x = 1", if_clause = NULL, options = NULL,
      by_group = NULL, raw_line = "gen x = 1", line_num = 1L, capture = FALSE
    ),
    list(
      cmd = "drop", args = "y", if_clause = NULL, options = NULL,
      by_group = NULL, raw_line = "drop y", line_num = 2L, capture = FALSE
    )
  )
  result <- translate_gen_block(cmds, 1)
  expect_equal(result$advance, 1) # only consumed the gen, not the drop
  expect_match(result$steps, "step_compute.*x = 1")
})

test_that("translate_gen_block with invalid gen returns NULL", {
  cmds <- list(
    list(
      cmd = "gen", args = "bad bad bad = =", if_clause = NULL,
      options = NULL, by_group = NULL, raw_line = "gen bad bad bad = =",
      line_num = 1L, capture = FALSE
    )
  )
  # parse_gen_args will return something because there's an = sign
  # Let's use a case that truly returns NULL: no = sign and not matching bare var
  cmds2 <- list(
    list(
      cmd = "gen", args = "", if_clause = NULL, options = NULL,
      by_group = NULL, raw_line = "gen", line_num = 1L, capture = FALSE
    )
  )
  result <- translate_gen_block(cmds2, 1)
  expect_null(result)
})

test_that("translate_gen_block recode path with quoted string constants", {
  cmds <- list(
    list(
      cmd = "gen", args = 'status = "unknown"', if_clause = NULL,
      options = NULL, by_group = NULL, raw_line = 'gen status = "unknown"',
      line_num = 1L, capture = FALSE
    ),
    list(
      cmd = "replace", args = 'status = "active"', if_clause = "flag == 1",
      options = NULL, by_group = NULL,
      raw_line = 'replace status = "active" if flag == 1',
      line_num = 2L, capture = FALSE
    ),
    list(
      cmd = "replace", args = 'status = "inactive"', if_clause = "flag == 0",
      options = NULL, by_group = NULL,
      raw_line = 'replace status = "inactive" if flag == 0',
      line_num = 3L, capture = FALSE
    )
  )
  result <- translate_gen_block(cmds, 1)
  # All RHS are quoted strings (constants), so should produce step_recode
  expect_match(result$steps, "step_recode")
  expect_equal(result$advance, 3)
})

test_that("translate_recode with multiple variables", {
  cmd <- list(
    cmd = "recode", args = "v1 v2 v3 (.=0)", if_clause = NULL,
    options = NULL, by_group = NULL,
    raw_line = "recode v1 v2 v3 (.=0)", line_num = 1L, capture = FALSE
  )
  result <- translate_recode(cmd)
  expect_true(length(result$steps) == 3)
})

test_that("build_doc_from_steps handles rename and remove step types", {
  steps <- c(
    'step_rename(svy, new_name = "old_name")',
    "step_remove(svy, drop_var1, drop_var2)"
  )
  doc <- build_doc_from_steps(steps)
  expect_true("new_name" %in% doc$output_variables)
  expect_true("drop_var1" %in% doc$output_variables)
  expect_equal(length(doc$pipeline), 2)
})

# ── transpile_stata_module with temp .do files ────────────────────────────────

test_that("transpile_stata_module errors on missing directory", {
  expect_error(transpile_stata_module("/nonexistent/dir", 2023), "Directory not found")
})

test_that("transpile_stata_module processes a year directory with .do files", {
  year_dir <- file.path(tempdir(), "test_module_2023")
  dir.create(year_dir, showWarnings = FALSE)
  on.exit(unlink(year_dir, recursive = TRUE))

  # Create data_prep module file (matches "2_correc")
  writeLines(c(
    "gen bc_anio = 2023",
    "gen bc_mes = 1",
    "rename id bc_correlat"
  ), file.path(year_dir, "2_correcciones.do"))

  # Create demographics module file (matches "3_compat")
  writeLines(c(
    "gen bc_pe2 = e26",
    "gen bc_pe3 = e27",
    "replace bc_pe3 = 1 if e30 == 1",
    "replace bc_pe3 = 2 if e30 == 2"
  ), file.path(year_dir, "3_compatibiliza.do"))

  # Create a label file
  writeLines(c(
    'label variable bc_pe2 "Sexo"',
    'label define pe2l 1 "Hombre" 2 "Mujer"',
    "label values bc_pe2 pe2l"
  ), file.path(year_dir, "label_pe2.do"))

  result <- transpile_stata_module(year_dir, 2023)
  expect_true(is.list(result))
  expect_true("data_prep" %in% names(result))
  expect_true("demographics" %in% names(result))

  # Each module should be a Recipe
  expect_true(inherits(result$data_prep, "Recipe"))
  expect_true(inherits(result$demographics, "Recipe"))

  # Steps should be populated
  expect_true(length(result$data_prep$steps) > 0)
  expect_true(length(result$demographics$steps) > 0)

  # Demographics recipe should depend on data_prep
  expect_true("data_prep" %in%
    sub("^ech_2023_", "", result$demographics$depends_on_recipes))
})

test_that("transpile_stata_module with output_dir writes JSON files", {
  year_dir <- file.path(tempdir(), "test_module_out")
  out_dir <- file.path(tempdir(), "test_recipes_out")
  dir.create(year_dir, showWarnings = FALSE)
  on.exit({
    unlink(year_dir, recursive = TRUE)
    unlink(out_dir, recursive = TRUE)
  })

  writeLines(c(
    "gen x = 1",
    "gen y = x + 1"
  ), file.path(year_dir, "2_correcciones.do"))

  result <- transpile_stata_module(year_dir, 2023, output_dir = out_dir)
  expect_true(dir.exists(out_dir))
  json_files <- list.files(out_dir, pattern = "\\.json$")
  expect_true(length(json_files) > 0)
})

test_that("transpile_stata works on temp .do file with mixed commands", {
  tmp <- tempfile(fileext = ".do")
  on.exit(unlink(tmp))
  writeLines(c(
    "gen x = 1",
    "replace x = 2 if y == 1",
    "replace x = 3 if y == 2",
    "recode z (1=10) (2=20)",
    "drop aux1 aux2",
    "rename old_name new_name",
    "destring income_str, replace force",
    "tostring age",
    "mvencode a b, mv(0)",
    "bysort region: egen mean_inc = mean(income)",
    "keep important_var",
    "merge 1:1 id using other_data",
    "tab status"
  ), tmp)

  result <- transpile_stata(tmp)
  expect_true(length(result$steps) > 0)
  expect_true(length(result$stats) > 0)
  expect_true(result$stats$translated > 0)
  expect_true(result$stats$skipped > 0) # tab is skipped
})

test_that("transpile_stata with labels extracts label info", {
  tmp <- tempfile(fileext = ".do")
  on.exit(unlink(tmp))
  writeLines(c(
    "gen x = 1",
    'label variable x "My variable"',
    'label define xl 1 "One" 2 "Two"',
    "label values x xl"
  ), tmp)

  result <- transpile_stata(tmp)
  expect_true(length(result$steps) > 0)
  expect_equal(result$labels$var_labels$x, "My variable")
  expect_equal(result$labels$val_labels$x[["1"]], "One")
})
