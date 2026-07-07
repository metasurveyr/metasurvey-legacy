# STATA .do file transpiler to metasurvey recipes

# Commands that are skipped (not data transformations)
SKIP_COMMANDS <- c(
  "use", "save", "clear", "set", "sort", "order", "browse",
  "tabulate", "summarize", "compare", "run", "do", "cd",
  "global", "local", "gl", "display", "log", "quietly", "noisily",
  "describe", "list", "assert", "count", "duplicates",
  "compress", "format", "append", "macro", "program", "exit",
  "preserve", "restore", "capture", "version", "adopath",
  "sysdir", "which", "net", "ssc", "findit", "search",
  "insheet", "outsheet", "import", "export", "type",
  "collapse", "gsort", "svmat", "matrix", "scalar",
  "total", "mean", "proportion", "ratio", "graph", "tabstat",
  "if", "else", "while", "continue", "break",
  "return", "args", "syntax", "tokenize", "confirm",
  "tempvar", "tempfile", "tempname"
)

#' Transpile a STATA .do file to metasurvey steps
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Parses a STATA .do file and translates its commands into
#' metasurvey step call strings suitable for use in Recipe objects.
#'
#' @param do_file Path to a STATA .do file
#' @param survey_type Survey type (default "ech")
#' @param user Author name for the recipe
#' @param strict If TRUE, stops on untranslatable commands;
#'   if FALSE, inserts MANUAL_REVIEW comments as warnings
#' @return A list with:
#'   \itemize{
#'     \item steps: character vector of step call strings
#'     \item labels: list with var_labels and val_labels (if label
#'       commands found)
#'     \item warnings: character vector of MANUAL_REVIEW items
#'     \item stats: list with command counts
#'   }
#' @examples
#' \donttest{
#' tf <- tempfile(fileext = ".do")
#' writeLines(c("gen age2 = edad^2", "replace sexo = 1 if sexo == ."), tf)
#' result <- transpile_stata(tf)
#' result$steps
#' result$stats
#' }
#' @family transpiler
#' @export
transpile_stata <- function(do_file, survey_type = "ech",
                            user = "iecon", strict = FALSE) {
  commands <- parse_do_file(do_file)

  # Also extract labels from the raw file
  raw_lines <- readLines(do_file, encoding = "latin1", warn = FALSE)
  raw_lines <- iconv(raw_lines, from = "latin1", to = "UTF-8", sub = "")
  labels <- parse_stata_labels(raw_lines)

  result <- translate_commands(commands, strict = strict)

  optimized <- optimize_steps(result$steps)

  list(
    steps = optimized,
    labels = labels,
    warnings = result$warnings,
    stats = result$stats
  )
}

#' Transpile and group do-files by thematic module
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Processes all do-files in a year directory and groups them
#' into thematic Recipe objects (demographics, income, etc.).
#'
#' @param year_dir Path to a year directory (e.g., "do_files_iecon/2022")
#' @param year Year of the edition (character or numeric)
#' @param user Author name
#' @param output_dir Directory to write JSON recipes (NULL = no file output)
#' @return A named list of Recipe objects, one per thematic module
#' @examples
#' \dontrun{
#' # Requires a directory of .do files organized by year
#' recipes <- transpile_stata_module("do_files_iecon/2022", year = 2022)
#' names(recipes)
#' }
#' @family transpiler
#' @export
transpile_stata_module <- function(year_dir, year, user = "iecon",
                                   output_dir = NULL) {
  if (!dir.exists(year_dir)) {
    stop("Directory not found: ", year_dir, call. = FALSE)
  }

  year <- as.character(year)

  # Map filename patterns to modules
  module_map <- list(
    data_prep = "2_correc",
    demographics = "3_compat",
    income_detail = c("4_ingreso", "5_descomp"),
    income_aggregate = "6_ingreso",
    cleanup = "8_arregla"
  )

  # Original do-file numbering (for display order)
  module_order <- list(
    data_prep = "2",
    demographics = "3",
    income_detail = "4-5",
    income_aggregate = "6",
    cleanup = "8"
  )

  module_topics <- list(
    data_prep = NULL,
    demographics = "demographics",
    income_detail = "income",
    income_aggregate = "income",
    cleanup = NULL
  )

  module_descriptions <- list(
    data_prep = "Data correction and merging for ECH microdata",
    demographics = paste0(
      "Harmonized demographic, health, education, and labor variables ",
      "(modules 1-4)"
    ),
    income_detail = paste0(
      "Detailed income decomposition by source and employment type"
    ),
    income_aggregate = paste0(
      "Aggregated income variables, household totals, and ",
      "per-capita income"
    ),
    cleanup = "Drop intermediate variables and final ordering"
  )

  # Find all .do files in the directory
  do_files <- list.files(year_dir,
    pattern = "\\.do$",
    full.names = TRUE, ignore.case = TRUE
  )

  # Extract labels from label files
  label_files <- do_files[grepl(
    "label",
    basename(do_files),
    ignore.case = TRUE
  )]
  all_labels <- list(var_labels = list(), val_labels = list())
  for (lf in label_files) {
    raw_lines <- readLines(lf, encoding = "latin1", warn = FALSE)
    raw_lines <- iconv(raw_lines, from = "latin1", to = "UTF-8", sub = "")
    lbl <- parse_stata_labels(raw_lines)
    all_labels$var_labels <- c(all_labels$var_labels, lbl$var_labels)
    all_labels$val_labels <- c(all_labels$val_labels, lbl$val_labels)
  }

  # Inter-module dependency chain (execution order)
  module_deps <- list(
    data_prep = character(0),
    demographics = "data_prep",
    income_detail = c("data_prep", "demographics"),
    income_aggregate = c("data_prep", "demographics", "income_detail"),
    cleanup = c(
      "data_prep", "demographics", "income_detail",
      "income_aggregate"
    )
  )

  # IECON institution user (shared across modules)
  iecon_user <- RecipeUser$new(
    name = "Instituto de Economia (IECON)",
    user_type = "institution",
    email = "iecon@fcea.edu.uy",
    url = "https://iecon.ccee.edu.uy"
  )

  recipes <- list()
  for (module_name in names(module_map)) {
    patterns <- module_map[[module_name]]
    matched_files <- character(0)
    for (pat in patterns) {
      matched <- do_files[grepl(pat, basename(do_files), ignore.case = TRUE)]
      matched_files <- c(matched_files, matched)
    }

    if (length(matched_files) == 0) next

    # Transpile each file and concatenate
    all_steps <- character(0)
    all_warnings <- character(0)
    for (mf in matched_files) {
      result <- transpile_stata(mf, survey_type = "ech", user = user)
      all_steps <- c(all_steps, result$steps)
      all_warnings <- c(all_warnings, result$warnings)
      # Merge file-specific labels
      all_labels$var_labels <- c(
        all_labels$var_labels,
        result$labels$var_labels
      )
      all_labels$val_labels <- c(
        all_labels$val_labels,
        result$labels$val_labels
      )
    }

    # Filter labels to only variables created in this module's steps
    module_vars <- extract_output_vars(all_steps)
    module_labels <- filter_labels(all_labels, module_vars)

    recipe_id <- paste0("ech_", year, "_", module_name)
    order_num <- module_order[[module_name]]
    recipe_name <- paste0(
      "ECH ", year, " [", order_num, "] ",
      gsub("_", " ", tools::toTitleCase(module_name))
    )

    # Build doc from step strings for pipeline graph display
    step_doc <- build_doc_from_steps(all_steps)

    # Source do-files for traceability
    source_files <- basename(matched_files)
    source_desc <- paste0(
      module_descriptions[[module_name]],
      "\n\nSource: ", paste(source_files, collapse = ", ")
    )

    # Inter-module dependencies (recipe IDs within same year)
    dep_modules <- module_deps[[module_name]]
    dep_recipe_ids <- paste0("ech_", year, "_", dep_modules)
    # Only keep deps for modules that actually exist this year
    dep_recipe_ids <- dep_recipe_ids[
      dep_modules %in% names(recipes)
    ]

    cert <- RecipeCertification$new(
      level = "official",
      certified_by = iecon_user,
      notes = paste(
        "Transpiled from official IECON do-files:",
        paste(source_files, collapse = ", ")
      )
    )

    rec <- Recipe$new(
      id = recipe_id,
      name = recipe_name,
      user = user,
      edition = year,
      survey_type = "ech",
      default_engine = "data.table",
      depends_on = step_doc$input_variables,
      description = source_desc,
      steps = all_steps,
      topic = module_topics[[module_name]],
      cached_doc = step_doc,
      certification = cert,
      user_info = iecon_user,
      depends_on_recipes = as.list(dep_recipe_ids),
      labels = if (length(module_labels$var_labels) > 0 || length(module_labels$val_labels) > 0) {
        module_labels
      } else {
        NULL
      }
    )

    recipes[[module_name]] <- rec

    if (!is.null(output_dir)) {
      if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)
      out_path <- file.path(output_dir, paste0(recipe_id, ".json"))
      save_recipe(rec, out_path)
    }
  }

  if (length(all_warnings) > 0) {
    metasurvey_msg(sprintf(
      paste0(
        "Transpilation completed with %d MANUAL_REVIEW items. ",
        "Use $warnings to see them."
      ),
      length(all_warnings)
    ))
  }

  recipes
}


# Internal: translate parsed commands to step strings
translate_commands <- function(commands, strict = FALSE) {
  steps <- character(0)
  warnings <- character(0)
  stats <- list(translated = 0L, skipped = 0L, manual_review = 0L)

  i <- 1
  while (i <= length(commands)) {
    cmd <- commands[[i]]

    # Skip non-transformation commands
    if (cmd$cmd %in% SKIP_COMMANDS) {
      stats$skipped <- stats$skipped + 1L
      i <- i + 1
      next
    }

    # Skip label commands (handled separately)
    if (cmd$cmd == "label") {
      stats$skipped <- stats$skipped + 1L
      i <- i + 1
      next
    }

    result <- switch(cmd$cmd,
      "gen" = ,
      "generate" = translate_gen_block(commands, i),
      "replace" = translate_replace(cmd),
      "recode" = translate_recode(cmd),
      "rename" = translate_rename(cmd),
      "drop" = translate_drop(cmd),
      "keep" = translate_keep(cmd),
      "destring" = translate_destring(cmd),
      "tostring" = translate_tostring(cmd),
      "mvencode" = translate_mvencode(cmd),
      "egen" = translate_egen(cmd),
      "merge" = translate_merge(cmd),
      NULL
    )

    if (!is.null(result)) {
      steps <- c(steps, result$steps)
      stats$translated <- stats$translated + length(result$steps)
      if (!is.null(result$advance)) {
        i <- i + result$advance
      } else {
        i <- i + 1
      }
    } else {
      # Unhandled command
      w <- sprintf(
        "# MANUAL_REVIEW: %s -- unhandled command '%s'",
        cmd$raw_line, cmd$cmd
      )
      if (strict) {
        stop(w, call. = FALSE)
      }
      warnings <- c(warnings, w)
      stats$manual_review <- stats$manual_review + 1L
      i <- i + 1
    }
  }

  list(steps = steps, warnings = warnings, stats = stats)
}

# Translate gen + subsequent replace sequence
translate_gen_block <- function(commands, start_idx) {
  cmd <- commands[[start_idx]]
  parsed <- parse_gen_args(cmd$args)
  if (is.null(parsed)) {
    # Bare gen var (no =) declares empty variable -> step_compute(svy, var = NA)
    bare_var <- trimws(cmd$args)
    bare_var <- sub("^(byte|int|long|float|double|str\\d*)\\s+", "", bare_var)
    if (grepl("^\\w+$", bare_var)) {
      step <- sprintf("step_compute(svy, %s = NA)", bare_var)
      return(list(steps = step, advance = 1))
    }
    return(NULL)
  }

  var_name <- parsed$var_name
  init_expr <- translate_stata_expr(parsed$expr)

  # Look ahead for replace commands targeting same variable
  replace_cmds <- list()
  j <- start_idx + 1
  while (j <= length(commands)) {
    next_cmd <- commands[[j]]
    if (next_cmd$cmd == "replace") {
      rep_parsed <- parse_replace_args(next_cmd$args)
      if (!is.null(rep_parsed) && rep_parsed$var_name == var_name && !is.null(next_cmd$if_clause)) {
        replace_cmds <- c(replace_cmds, list(list(
          expr = rep_parsed$expr,
          if_clause = next_cmd$if_clause
        )))
        j <- j + 1
      } else {
        break
      }
    } else {
      break
    }
  }

  advance <- j - start_idx

  # Build .by parameter from bysort prefix
  by_str <- NULL
  if (!is.null(cmd$by_group)) {
    by_vars <- strsplit(trimws(cmd$by_group), "\\s+")[[1]]
    if (length(by_vars) == 1) {
      by_str <- sprintf(', .by = "%s"', by_vars)
    } else {
      by_str <- sprintf(
        ", .by = c(%s)",
        paste(sprintf('"%s"', by_vars), collapse = ", ")
      )
    }
  }

  if (length(replace_cmds) == 0) {
    # Simple gen, possibly with if clause
    step <- if (!is.null(cmd$if_clause)) {
      cond <- translate_stata_expr(cmd$if_clause)
      sprintf(
        "step_compute(svy, %s = data.table::fifelse(%s, %s, NA)%s)",
        var_name, cond, init_expr, by_str %||% ""
      )
    } else {
      sprintf(
        "step_compute(svy, %s = %s%s)",
        var_name, init_expr, by_str %||% ""
      )
    }
    return(list(steps = step, advance = advance))
  }

  # Check if all replace RHS are constants -> step_recode
  all_constant <- all(vapply(replace_cmds, function(rc) {
    is_constant_rhs(rc$expr)
  }, logical(1)))

  if (all_constant && is_constant_rhs(init_expr)) {
    # Build step_recode (RHS must be quoted strings for step_recode)
    quote_recode_val <- function(val) {
      if (grepl('^"', val)) {
        val # already quoted
      } else if (val == "NA") {
        val # NA stays unquoted
      } else {
        paste0('"', val, '"')
      }
    }
    conditions <- vapply(replace_cmds, function(rc) {
      cond <- translate_stata_expr(rc$if_clause)
      val <- quote_recode_val(translate_stata_expr(rc$expr))
      sprintf("    %s ~ %s", cond, val)
    }, character(1))

    # STATA replace chains are sequential overwrites (last write wins);
    # step_recode is first-match-wins, so emit the conditions reversed
    # to preserve STATA semantics
    step <- sprintf(
      "step_recode(svy, %s,\n%s,\n    .default = %s)",
      var_name,
      paste(rev(conditions), collapse = ",\n"),
      quote_recode_val(init_expr)
    )
    return(list(steps = step, advance = advance))
  }

  # Mixed: use step_compute chain with fifelse
  step_init <- sprintf("step_compute(svy, %s = %s)", var_name, init_expr)
  steps <- step_init

  for (rc in replace_cmds) {
    cond <- translate_stata_expr(rc$if_clause)
    expr <- translate_stata_expr(rc$expr)
    step <- sprintf(
      "step_compute(svy, %s = data.table::fifelse(%s, %s, %s))",
      var_name, cond, expr, var_name
    )
    steps <- c(steps, step)
  }

  list(steps = steps, advance = advance)
}

# Translate standalone replace (not part of gen block)
translate_replace <- function(cmd) {
  parsed <- parse_replace_args(cmd$args)
  if (is.null(parsed)) {
    return(NULL)
  }

  expr <- translate_stata_expr(parsed$expr)
  var_name <- parsed$var_name

  if (!is.null(cmd$if_clause)) {
    cond <- translate_stata_expr(cmd$if_clause)
    step <- sprintf(
      "step_compute(svy, %s = data.table::fifelse(%s, %s, %s))",
      var_name, cond, expr, var_name
    )
  } else {
    step <- sprintf("step_compute(svy, %s = %s)", var_name, expr)
  }

  list(steps = step)
}

# Translate recode command
translate_recode <- function(cmd) {
  args_str <- cmd$args

  # Detect multiple variables before the first mapping pattern
  # recode g144_1 g261 g261_1 (.=0) or recode suma1-suma4 (.=0)
  # Split: everything before first ( or first token with = is the variable part
  paren_pos <- regexpr("\\(", args_str)
  eq_pos <- regexpr("=", args_str)
  split_pos <- if (paren_pos > 0 && (eq_pos < 0 || paren_pos < eq_pos)) {
    paren_pos
  } else if (eq_pos > 0) {
    # Find the token containing = to separate vars from mappings
    # e.g., "var1 var2 .=0" — last token has =
    eq_pos
  } else {
    nchar(args_str) + 1L
  }

  if (paren_pos > 0) {
    var_part <- trimws(substring(args_str, 1, paren_pos - 1))
    mapping_part <- substring(args_str, paren_pos)
  } else {
    # Inline: "var1 var2 .=0" — split on space, last tokens with = are mappings
    tokens <- strsplit(trimws(args_str), "\\s+")[[1]]
    var_tokens <- character(0)
    map_start <- length(tokens) + 1
    for (ti in seq_along(tokens)) {
      if (grepl("=", tokens[ti])) {
        map_start <- ti
        break
      }
      # Check for var range (contains -)
      var_tokens <- c(var_tokens, tokens[ti])
    }
    var_part <- paste(var_tokens, collapse = " ")
    mapping_part <- paste(tokens[map_start:length(tokens)], collapse = " ")
  }

  # Expand variable ranges and multi-var specifications
  var_specs <- strsplit(trimws(var_part), "\\s+")[[1]]
  all_vars <- unlist(lapply(var_specs, expand_var_range))

  if (length(all_vars) <= 1) {
    # Single variable — use standard parse
    parsed <- parse_recode_args(args_str, cmd$options)
    if (is.null(parsed)) {
      return(NULL)
    }
    return(list(steps = translate_recode_single(parsed)))
  }

  # Multiple variables — apply same mappings to each
  all_steps <- character(0)
  for (v in all_vars) {
    single_args <- paste(v, mapping_part)
    parsed <- parse_recode_args(single_args, cmd$options)
    if (!is.null(parsed)) {
      all_steps <- c(all_steps, translate_recode_single(parsed))
    }
  }
  list(steps = all_steps)
}

# Single-variable recode logic
translate_recode_single <- function(parsed) {
  target_var <- parsed$gen_var %||% parsed$var_name
  source_var <- parsed$var_name

  steps <- character(0)
  for (mapping in parsed$mappings) {
    if (!is.null(mapping$from_range)) {
      # Range recode: 23/38=22
      lo <- mapping$from_range[1]
      hi <- mapping$from_range[2]
      to <- translate_stata_expr(mapping$to)
      step <- sprintf(
        paste0(
          "step_compute(svy, %s = data.table::fifelse(",
          "%s >= %s & %s <= %s, %s, %s))"
        ),
        target_var, source_var, lo, source_var, hi, to, target_var
      )
      steps <- c(steps, step)
    } else if (length(mapping$from) == 1 && mapping$from == ".") {
      # Missing to value: .=0
      to <- translate_stata_expr(mapping$to)
      step <- sprintf(
        "step_compute(svy, %s = data.table::fifelse(is.na(%s), %s, %s))",
        target_var, source_var, to, source_var
      )
      steps <- c(steps, step)
    } else {
      # Value mapping: (old=new)
      from_vals <- mapping$from
      to <- translate_stata_expr(mapping$to)
      if (length(from_vals) == 1) {
        cond <- sprintf("%s == %s", source_var, from_vals[1])
      } else {
        cond <- sprintf(
          "%s %%in%% c(%s)", source_var,
          paste(from_vals, collapse = ", ")
        )
      }
      step <- sprintf(
        "step_compute(svy, %s = data.table::fifelse(%s, %s, %s))",
        target_var, cond, to, target_var
      )
      steps <- c(steps, step)
    }
  }

  # If gen() was used, we need to first copy the variable
  if (!is.null(parsed$gen_var)) {
    copy_step <- sprintf(
      "step_compute(svy, %s = %s)", parsed$gen_var, source_var
    )
    steps <- c(copy_step, steps)
  }

  steps
}

# Translate rename
translate_rename <- function(cmd) {
  args <- trimws(cmd$args)
  parts <- strsplit(args, "\\s+")[[1]]
  if (length(parts) < 2) {
    return(NULL)
  }

  old_name <- parts[1]
  new_name <- parts[2]

  step <- sprintf("step_rename(svy, %s = \"%s\")", new_name, old_name)
  list(steps = step)
}

# Translate drop
translate_drop <- function(cmd) {
  args <- trimws(cmd$args)
  # Handle if clause (drop observations vs variables)
  if (!is.null(cmd$if_clause)) {
    # drop if condition = row deletion, not translatable to step_remove
    return(list(steps = sprintf(
      "# MANUAL_REVIEW: drop if %s -- observation deletion not supported",
      cmd$if_clause
    )))
  }
  vars <- strsplit(args, "\\s+")[[1]]
  if (length(vars) == 0) {
    return(NULL)
  }

  # Expand variable ranges (e.g., aux1-aux14_max -> aux1..aux14, aux1_max..aux14_max)
  expanded <- unlist(lapply(vars, expand_var_range))

  step <- sprintf("step_remove(svy, %s)", paste(expanded, collapse = ", "))
  list(steps = step)
}

# Translate keep (inverse of drop)
translate_keep <- function(cmd) {
  # keep = drop everything except these variables
  # Can't implement without knowing all columns; emit MANUAL_REVIEW
  list(steps = sprintf(
    "# MANUAL_REVIEW: keep %s -- requires known column list to invert",
    cmd$args
  ))
}

# Translate destring (supports multiple space-separated variables)
translate_destring <- function(cmd) {
  parsed <- parse_destring_args(cmd$args, cmd$options)
  if (is.null(parsed)) {
    return(NULL)
  }

  # destring can take multiple variables: destring v1 v2 v3, replace
  var_names <- strsplit(trimws(parsed$var_name), "\\s+")[[1]]

  steps <- vapply(var_names, function(v) {
    target <- parsed$gen_var %||% v
    conv_expr <- if (parsed$force) {
      sprintf("suppressWarnings(as.numeric(as.character(%s)))", v)
    } else {
      sprintf("as.numeric(as.character(%s))", v)
    }
    sprintf("step_compute(svy, %s = %s)", target, conv_expr)
  }, character(1))

  list(steps = unname(steps))
}

# Translate tostring
translate_tostring <- function(cmd) {
  var_name <- trimws(cmd$args)
  # Strip type options
  var_name <- sub(",.*$", "", var_name)
  var_name <- trimws(var_name)
  step <- sprintf(
    "step_compute(svy, %s = as.character(%s))",
    var_name,
    var_name
  )
  list(steps = step)
}

# Translate mvencode
translate_mvencode <- function(cmd) {
  parsed <- parse_mvencode_args(cmd$args, cmd$options)
  if (is.null(parsed)) {
    return(NULL)
  }

  # Expand variable ranges (e.g., suma1-suma4 -> suma1 suma2 suma3 suma4)
  expanded <- unlist(lapply(parsed$var_names, expand_var_range))

  steps <- vapply(expanded, function(v) {
    sprintf(
      "step_compute(svy, %s = data.table::fifelse(is.na(%s), %s, %s))",
      v, v, parsed$mv_value, v
    )
  }, character(1))

  list(steps = unname(steps))
}

# Translate egen
translate_egen <- function(cmd) {
  parsed <- parse_egen_args(
    cmd$args,
    by_group = cmd$by_group,
    options = cmd$options
  )
  if (is.null(parsed)) {
    return(NULL)
  }

  # Map STATA egen functions to R
  r_func <- switch(parsed$func,
    "sum" = sprintf("sum(%s, na.rm = TRUE)", parsed$func_arg),
    "max" = sprintf("max(%s, na.rm = TRUE)", parsed$func_arg),
    "min" = sprintf("min(%s, na.rm = TRUE)", parsed$func_arg),
    "mean" = sprintf("mean(%s, na.rm = TRUE)", parsed$func_arg),
    "count" = sprintf("sum(!is.na(%s))", parsed$func_arg),
    "sd" = sprintf("sd(%s, na.rm = TRUE)", parsed$func_arg),
    # Default: pass through
    sprintf("%s(%s)", parsed$func, parsed$func_arg)
  )

  if (!is.null(parsed$by_group)) {
    # Split multiple by-group variables: "var1 var2" -> c("var1", "var2")
    by_vars <- strsplit(trimws(parsed$by_group), "\\s+")[[1]]
    if (length(by_vars) == 1) {
      by_str <- sprintf('"%s"', by_vars)
    } else {
      by_str <- sprintf(
        "c(%s)",
        paste(sprintf('"%s"', by_vars), collapse = ", ")
      )
    }
    step <- sprintf(
      "step_compute(svy, %s = %s, .by = %s)",
      parsed$var_name, r_func, by_str
    )
  } else {
    step <- sprintf("step_compute(svy, %s = %s)", parsed$var_name, r_func)
  }

  list(steps = step)
}

# Translate merge (limited support)
translate_merge <- function(cmd) {
  # Merge requires external data reference; emit MANUAL_REVIEW
  list(steps = sprintf(
    "# MANUAL_REVIEW: merge %s -- requires external dataset reference",
    cmd$args
  ))
}


# Step optimization pass
optimize_steps <- function(steps) {
  if (length(steps) == 0) {
    return(steps)
  }

  result <- character(0)
  i <- 1

  while (i <= length(steps)) {
    step <- steps[[i]]

    # Collapse consecutive step_rename into one with mapping
    if (grepl("^step_rename\\(", step)) {
      rename_steps <- step
      j <- i + 1
      while (j <= length(steps) && grepl("^step_rename\\(", steps[[j]])) {
        rename_steps <- c(rename_steps, steps[[j]])
        j <- j + 1
      }
      if (length(rename_steps) > 1) {
        # Extract all new = "old" pairs
        pairs <- character(0)
        for (rs in rename_steps) {
          m <- regmatches(rs, regexec(
            'step_rename\\(svy,\\s*(\\w+)\\s*=\\s*"(\\w+)"\\)', rs
          ))[[1]]
          if (length(m) >= 3) {
            pairs <- c(pairs, sprintf('%s = "%s"', m[[2]], m[[3]]))
          }
        }
        if (length(pairs) > 0) {
          step <- sprintf(
            "step_rename(svy, %s)",
            paste(pairs, collapse = ", ")
          )
        }
      }
      result <- c(result, step)
      i <- j
      next
    }

    # Collapse consecutive step_remove into one
    if (grepl("^step_remove\\(", step)) {
      remove_steps <- step
      j <- i + 1
      while (j <= length(steps) && grepl("^step_remove\\(", steps[[j]])) {
        remove_steps <- c(remove_steps, steps[[j]])
        j <- j + 1
      }
      if (length(remove_steps) > 1) {
        all_vars <- character(0)
        for (rs in remove_steps) {
          m <- regmatches(rs, regexec(
            "step_remove\\(svy,\\s*(.+)\\)", rs
          ))[[1]]
          if (length(m) >= 2) {
            all_vars <- c(all_vars, strsplit(m[[2]], ",\\s*")[[1]])
          }
        }
        all_vars <- unique(trimws(all_vars))
        step <- sprintf(
          "step_remove(svy, %s)",
          paste(all_vars, collapse = ", ")
        )
      }
      result <- c(result, step)
      i <- j
      next
    }

    # Collapse consecutive step_compute with dependency analysis
    if (grepl("^step_compute\\(", step)) {
      compute_steps <- step
      j <- i + 1
      while (j <= length(steps) && grepl("^step_compute\\(", steps[[j]])) {
        compute_steps <- c(compute_steps, steps[[j]])
        j <- j + 1
      }
      if (length(compute_steps) > 1) {
        result <- c(result, collapse_compute_steps(compute_steps))
      } else {
        result <- c(result, step)
      }
      i <- j
      next
    }

    result <- c(result, step)
    i <- i + 1
  }

  result
}

#' Parse a step_compute string into body and .by components
#' @param step A step_compute string
#' @return A list with `body` (the variable assignments) and `by` (the .by
#'   value or NULL)
#' @noRd
parse_compute_step <- function(step) {
  # Remove "step_compute(svy, " prefix and trailing ")"
  inner <- sub("^step_compute\\(svy,\\s*", "", step)
  inner <- sub("\\)$", "", inner)

  # Split off .by parameter if present
  # Match , .by = ... at the end, being careful with nested parens
  by_match <- regmatches(inner, regexec(
    ",\\s*\\.by\\s*=\\s*(.+)$", inner
  ))[[1]]

  if (length(by_match) >= 2) {
    by_val <- trimws(by_match[[2]])
    body <- sub(",\\s*\\.by\\s*=\\s*.+$", "", inner)
  } else {
    by_val <- NULL
    body <- inner
  }

  list(body = trimws(body), by = by_val)
}

#' Collapse a vector of step_compute strings respecting dependencies
#' @param steps Character vector of step_compute strings
#' @return Character vector of collapsed step_compute strings
#' @noRd
collapse_compute_steps <- function(steps) {
  parsed <- lapply(steps, parse_compute_step)

  result <- character(0)
  group_bodies <- character(0)
  group_by <- NULL
  created_vars <- character(0)

  flush_group <- function() {
    if (length(group_bodies) > 0) {
      body <- paste(group_bodies, collapse = ", ")
      if (!is.null(group_by)) {
        result <<- c(result, sprintf(
          "step_compute(svy, %s, .by = %s)", body, group_by
        ))
      } else {
        result <<- c(result, sprintf("step_compute(svy, %s)", body))
      }
      group_bodies <<- character(0)
      group_by <<- NULL
      created_vars <<- character(0)
    }
  }

  for (p in parsed) {
    # Extract output variable name(s) and referenced variables
    expr <- tryCatch(
      parse(text = paste0("list(", p$body, ")")),
      error = function(e) NULL
    )

    if (is.null(expr)) {
      # Can't parse: flush and emit as-is
      flush_group()
      if (!is.null(p$by)) {
        result <- c(result, sprintf(
          "step_compute(svy, %s, .by = %s)", p$body, p$by
        ))
      } else {
        result <- c(result, sprintf("step_compute(svy, %s)", p$body))
      }
      next
    }

    expr_list <- expr[[1]]
    out_vars <- names(expr_list)[-1] # skip 'list'
    ref_vars <- all.vars(expr_list)
    # ref_vars includes out_vars; remove them to get only referenced
    ref_vars <- setdiff(ref_vars, out_vars)

    # Check .by compatibility
    by_matches <- identical(p$by, group_by)
    if (length(group_bodies) > 0 && !by_matches) {
      flush_group()
    }

    # Check dependency: does this step reference any created var?
    has_dep <- length(intersect(ref_vars, created_vars)) > 0

    if (has_dep) {
      flush_group()
    }

    group_bodies <- c(group_bodies, p$body)
    group_by <- p$by
    created_vars <- c(created_vars, out_vars)
  }

  flush_group()
  result
}


# Helper: extract output variable names from step strings
extract_output_vars <- function(steps) {
  vars <- character(0)
  for (step in steps) {
    if (grepl("^#", step)) next # Skip comments
    # step_compute(svy, VAR = ...)
    m <- regmatches(
      step,
      gregexpr("step_compute\\(svy,\\s*(\\w+)\\s*=", step, perl = TRUE)
    )
    if (length(m[[1]]) > 0) {
      for (match in m[[1]]) {
        v <- regmatches(
          match,
          regexec("step_compute\\(svy,\\s*(\\w+)", match)
        )[[1]]
        if (length(v) >= 2) vars <- c(vars, v[[2]])
      }
    }
    # step_recode(svy, VAR, ...)
    m <- regmatches(step, regexec("step_recode\\(svy,\\s*(\\w+)", step))[[1]]
    if (length(m) >= 2) vars <- c(vars, m[[2]])
  }
  unique(vars)
}

# Helper: extract input variable names from step strings
extract_input_vars <- function(steps) {
  # Use all.vars on parsed expressions to find referenced variables
  all_vars <- character(0)
  output_vars <- extract_output_vars(steps)

  for (step in steps) {
    if (grepl("^#", step)) next
    # Try to parse the step and extract variable names
    parsed <- tryCatch(parse(text = step), error = function(e) NULL)
    if (!is.null(parsed)) {
      step_vars <- tryCatch(all.vars(parsed), error = function(e) character(0))
      all_vars <- c(all_vars, step_vars)
    }
  }

  # Input vars = referenced vars that are NOT created by steps
  # Remove known non-variables
  remove <- c(
    "svy", "data.table", "fifelse", "fcase", "TRUE", "FALSE",
    "NA", "NULL", "is.na", "sum", "max", "min", "mean", "sd",
    "as.numeric", "as.character", "suppressWarnings",
    "step_compute", "step_recode", "step_rename", "step_remove"
  )
  all_vars <- setdiff(unique(all_vars), c(output_vars, remove))
  all_vars
}

# Build doc (pipeline, inputs, outputs) from step strings
# This allows save_recipe and the Shiny app to show pipeline graphs
build_doc_from_steps <- function(steps) {
  pipeline <- list()
  all_outputs <- character(0)
  all_inputs <- character(0)

  for (i in seq_along(steps)) {
    step <- steps[[i]]
    if (grepl("^#", step)) next

    # Detect step type
    step_type <- if (grepl("^step_compute\\(", step)) {
      "compute"
    } else if (grepl("^step_recode\\(", step)) {
      "recode"
    } else if (grepl("^step_rename\\(", step)) {
      "rename"
    } else if (grepl("^step_remove\\(", step)) {
      "remove"
    } else {
      "unknown"
    }

    # Extract output variables
    outputs <- character(0)
    if (step_type == "compute") {
      m <- regmatches(step, regexec(
        "step_compute\\(svy,\\s*(\\w+)\\s*=", step
      ))[[1]]
      if (length(m) >= 2) outputs <- m[[2]]
    } else if (step_type == "recode") {
      m <- regmatches(step, regexec(
        "step_recode\\(svy,\\s*(\\w+)", step
      ))[[1]]
      if (length(m) >= 2) outputs <- m[[2]]
    } else if (step_type == "rename") {
      # step_rename(svy, new = "old", new2 = "old2")
      m <- gregexpr("(\\w+)\\s*=\\s*\"", step, perl = TRUE)
      if (length(m[[1]]) > 0 && m[[1]][1] > 0) {
        matches <- regmatches(step, m)[[1]]
        outputs <- sub("\\s*=\\s*\"", "", matches)
      }
    } else if (step_type == "remove") {
      # step_remove(svy, var1, var2)
      inner <- sub("^step_remove\\(svy,\\s*", "", step)
      inner <- sub("\\)$", "", inner)
      outputs <- trimws(strsplit(inner, ",")[[1]])
    }

    # Extract inputs via parsing
    step_inputs <- tryCatch(
      {
        parsed <- parse(text = step)
        refs <- all.vars(parsed)
        remove_names <- c(
          "svy", "data.table", "fifelse", "fcase", "TRUE", "FALSE",
          "NA", "NULL", "is.na", "sum", "max", "min", "mean", "sd",
          "as.numeric", "as.character", "suppressWarnings", "nchar",
          "step_compute", "step_recode", "step_rename", "step_remove",
          "shift", "lag", "lead"
        )
        setdiff(refs, remove_names)
      },
      error = function(e) character(0)
    )

    # Track cumulative inputs/outputs
    external_inputs <- setdiff(step_inputs, all_outputs)
    all_inputs <- union(all_inputs, external_inputs)
    all_outputs <- union(all_outputs, outputs)

    # Extract expression for display
    expr_txt <- if (step_type == "compute") {
      m <- regmatches(step, regexec(
        "step_compute\\(svy,\\s*\\w+\\s*=\\s*(.+?)\\s*(?:,\\s*\\.by|\\))$",
        step,
        perl = TRUE
      ))[[1]]
      if (length(m) >= 2) m[[2]] else ""
    } else {
      ""
    }

    pipeline[[length(pipeline) + 1]] <- list(
      index = i,
      type = step_type,
      outputs = outputs,
      inputs = step_inputs,
      expression = expr_txt
    )
  }

  list(
    input_variables = all_inputs,
    output_variables = all_outputs,
    pipeline = pipeline
  )
}

# Helper: filter labels to only include relevant variables
filter_labels <- function(labels, vars) {
  list(
    var_labels = labels$var_labels[names(labels$var_labels) %in% vars],
    val_labels = labels$val_labels[names(labels$val_labels) %in% vars]
  )
}


#' Analyze transpilation coverage for STATA do-files
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reports what percentage of commands in a .do file (or directory
#' of files) can be automatically transpiled vs require manual review.
#'
#' @param path Path to a .do file or directory of .do files
#' @param recursive If TRUE and path is a directory, search subdirectories
#' @return A data.frame with columns: file, total_commands, translated,
#'   skipped, manual_review, coverage_pct
#' @examples
#' \donttest{
#' tf <- tempfile(fileext = ".do")
#' writeLines(c("gen x = 1", "replace x = 2 if y == 3", "drop z"), tf)
#' transpile_coverage(tf)
#' }
#' @family transpiler
#' @export
transpile_coverage <- function(path, recursive = TRUE) {
  if (dir.exists(path)) {
    do_files <- list.files(path,
      pattern = "\\.do$",
      full.names = TRUE, recursive = recursive
    )
  } else if (file.exists(path)) {
    do_files <- path
  } else {
    stop("Path not found: ", path, call. = FALSE)
  }

  results <- lapply(do_files, function(f) {
    tryCatch(
      {
        commands <- parse_do_file(f)
        result <- translate_commands(commands, strict = FALSE)
        total <- result$stats$translated + result$stats$skipped +
          result$stats$manual_review
        coverage <- if (total > 0) {
          round(
            (result$stats$translated + result$stats$skipped) / total * 100,
            1
          )
        } else {
          100
        }
        data.frame(
          file = basename(f),
          path = f,
          total_commands = total,
          translated = result$stats$translated,
          skipped = result$stats$skipped,
          manual_review = result$stats$manual_review,
          coverage_pct = coverage,
          stringsAsFactors = FALSE
        )
      },
      error = function(e) {
        data.frame(
          file = basename(f),
          path = f,
          total_commands = NA_integer_,
          translated = NA_integer_,
          skipped = NA_integer_,
          manual_review = NA_integer_,
          coverage_pct = NA_real_,
          stringsAsFactors = FALSE
        )
      }
    )
  })

  df <- do.call(rbind, results)

  # Summary row
  totals <- data.frame(
    file = "TOTAL",
    path = path,
    total_commands = sum(df$total_commands, na.rm = TRUE),
    translated = sum(df$translated, na.rm = TRUE),
    skipped = sum(df$skipped, na.rm = TRUE),
    manual_review = sum(df$manual_review, na.rm = TRUE),
    coverage_pct = NA_real_,
    stringsAsFactors = FALSE
  )
  total_cmds <- totals$total_commands
  if (total_cmds > 0) {
    totals$coverage_pct <- round(
      (totals$translated + totals$skipped) / total_cmds * 100, 1
    )
  }

  rbind(df, totals)
}
