# STATA .do file parser for metasurvey transpiler
# Handles tokenization, comment stripping, loop expansion, and label parsing

#' Parse a STATA .do file into structured commands
#'
#' Reads a .do file and returns a list of parsed command objects.
#' Handles comment stripping, line continuation, loop expansion,
#' and command tokenization.
#'
#' @param do_file Path to a STATA .do file
#' @param encoding File encoding (default "latin1" for legacy STATA files)
#' @return A list of StataCommand lists, each with fields:
#'   cmd, args, if_clause, options, raw_line, line_num, capture
#' @examples
#' \donttest{
#' tf <- tempfile(fileext = ".do")
#' writeLines(c("gen age2 = edad^2", "replace sexo = 1 if sexo == ."), tf)
#' cmds <- parse_do_file(tf)
#' length(cmds)
#' cmds[[1]]$cmd
#' }
#' @family transpiler
#' @export
parse_do_file <- function(do_file, encoding = "latin1") {
  if (!file.exists(do_file)) {
    stop("File not found: ", do_file, call. = FALSE)
  }
  lines <- readLines(do_file, encoding = encoding, warn = FALSE)
  # Convert to UTF-8 for safe regex operations
  lines <- iconv(lines, from = encoding, to = "UTF-8", sub = "")
  lines <- strip_stata_comments(lines)
  lines <- join_continuation_lines(lines)
  lines <- join_broken_expressions(lines)
  lines <- expand_stata_loops(lines)

  commands <- list()
  for (i in seq_along(lines)) {
    line <- trimws(lines[[i]])
    if (nchar(line) == 0) next
    cmd <- parse_stata_command(line, line_num = i)
    if (!is.null(cmd)) {
      commands <- c(commands, list(cmd))
    }
  }
  commands
}

#' Strip STATA comments from source lines
#'
#' Removes single-line comments (// and * at start) and
#' multi-line block comments (/* ... */).
#'
#' @param lines Character vector of source lines
#' @return Character vector with comments removed
#' @keywords internal
strip_stata_comments <- function(lines) {
  # Pass 1: Remove block comments /* ... */
  # When /* at end of line and */ at start of next, join them (line continuation)
  in_block <- FALSE
  block_start_idx <- NA_integer_
  result <- character(length(lines))
  for (i in seq_along(lines)) {
    line <- lines[[i]]
    if (in_block) {
      close_pos <- regexpr("\\*/", line, useBytes = TRUE)
      if (close_pos > 0) {
        remainder <- trimws(substring(line, close_pos + 2))
        in_block <- FALSE
        # Append remainder to the line that opened the block (continuation)
        if (!is.na(block_start_idx) && nchar(remainder) > 0) {
          result[[block_start_idx]] <- paste(
            result[[block_start_idx]], remainder
          )
          result[[i]] <- ""
          next
        }
        line <- remainder
      } else {
        result[[i]] <- ""
        next
      }
    }
    # Handle multiple block comments on same line
    while (grepl("/\\*", line, useBytes = TRUE)) {
      open_pos <- regexpr("/\\*", line, useBytes = TRUE)
      close_pos <- regexpr("\\*/", substring(line, open_pos + 2),
        useBytes = TRUE
      )
      if (close_pos > 0) {
        before <- substring(line, 1, open_pos - 1)
        after <- substring(line, open_pos + 2 + close_pos + 1)
        line <- paste0(before, after)
      } else {
        line <- substring(line, 1, open_pos - 1)
        in_block <- TRUE
        block_start_idx <- i
        break
      }
    }
    result[[i]] <- line
  }

  # Pass 2: Remove inline // comments (but NOT ///) and * line comments
  for (i in seq_along(result)) {
    line <- result[[i]]
    if (nchar(trimws(line)) == 0) next
    # Lines starting with * are comments
    if (grepl("^\\s*\\*", line, useBytes = TRUE)) {
      result[[i]] <- ""
      next
    }
    # Remove // comments but preserve /// (line continuation)
    # First, temporarily replace /// with a placeholder
    line <- gsub("///", "\001CONT\001", line, fixed = TRUE)
    line <- sub("//.*$", "", line, useBytes = TRUE)
    # Restore /// continuations
    line <- gsub("\001CONT\001", "///", line, fixed = TRUE)
    result[[i]] <- line
  }
  result
}

#' Join STATA continuation lines
#'
#' STATA uses /// for line continuation. This function joins
#' continued lines into single commands.
#'
#' @param lines Character vector of source lines
#' @return Character vector with continuations joined
#' @keywords internal
join_continuation_lines <- function(lines) {
  result <- character(0)
  buffer <- ""
  for (line in lines) {
    if (grepl("///\\s*$", line)) {
      buffer <- paste0(buffer, sub("///\\s*$", " ", line))
    } else if (nchar(buffer) > 0) {
      buffer <- paste0(buffer, line)
      result <- c(result, buffer)
      buffer <- ""
    } else {
      result <- c(result, line)
    }
  }
  if (nchar(buffer) > 0) result <- c(result, buffer)
  result
}

#' Join broken expression lines after block comment removal
#'
#' After removing /* */ block comments, expressions can be split
#' across lines. This function re-joins lines where the previous
#' line ends with an operator or open paren, or the next line
#' starts with an operator or close paren.
#'
#' @param lines Character vector of source lines
#' @return Character vector with broken expressions re-joined
#' @keywords internal
join_broken_expressions <- function(lines) {
  if (length(lines) <= 1) {
    return(lines)
  }

  result <- character(0)
  buffer <- ""

  for (i in seq_along(lines)) {
    line <- lines[[i]]
    trimmed <- trimws(line)

    if (nchar(buffer) > 0) {
      # Check if this line is a continuation of the previous
      # A line is a continuation if it starts with operator/paren,
      # or if it doesn't start with a known STATA command (expression fragment)
      is_continuation <- grepl("^[(&|)\\-*/,+]", trimmed, perl = TRUE)
      if (!is_continuation) {
        # Also treat as continuation if previous ended with operator
        # and this doesn't look like a new command
        first_word <- sub("^(\\w+).*", "\\1", trimmed, perl = TRUE)
        first_word_lower <- tolower(first_word)
        stata_cmds <- c(
          "gen", "g", "ge", "replace", "recode", "rename", "ren",
          "drop", "keep", "egen", "destring", "tostring", "mvencode",
          "merge", "cap", "capture", "foreach", "forvalues",
          "use", "save", "clear", "set", "sort", "order",
          "global", "local", "gl", "lab", "label", "tab", "tabulate",
          "su", "sum", "summ", "br", "browse", "describe", "list",
          "collapse", "bysort", "bys", "by", "quietly", "noisily",
          "preserve", "restore", "insheet", "import", "export",
          "mat", "matrix", "scalar", "if", "else", "program",
          "compress", "format", "assert", "count", "duplicates",
          "tempvar", "tempfile", "display", "log"
        )
        if (!first_word_lower %in% stata_cmds && nchar(first_word) > 0) {
          is_continuation <- TRUE
        }
      }
      if (is_continuation) {
        buffer <- paste(buffer, trimmed)
        next
      } else {
        # New command — flush buffer
        result <- c(result, buffer)
        buffer <- ""
      }
    }

    # Check if this line ends with an operator or open paren
    # (suggesting the expression continues on next line)
    if (nchar(trimmed) > 0 && grepl("[&|+\\-*/( ,]\\s*$", trimmed, perl = TRUE)) {
      buffer <- trimmed
    } else {
      result <- c(result, line)
    }
  }

  if (nchar(buffer) > 0) result <- c(result, buffer)
  result
}

#' Expand STATA foreach and forvalues loops
#'
#' Detects foreach/forvalues blocks and unrolls them by
#' substituting loop variables into body lines.
#'
#' @param lines Character vector of source lines
#' @return Character vector with loops expanded
#' @keywords internal
expand_stata_loops <- function(lines) {
  result <- character(0)
  i <- 1
  while (i <= length(lines)) {
    line <- trimws(lines[[i]])

    # Match foreach ... in/of local/of varlist ... {
    foreach_in <- regmatches(line, regexec(
      paste0(
        "^\\s*(?:cap(?:ture)?\\s+)?foreach\\s+(\\w+)\\s+",
        "(?:in|of\\s+local|of\\s+varlist|of\\s+var)\\s+(.+?)\\s*\\{\\s*$"
      ),
      line,
      perl = TRUE
    ))[[1]]

    # Match foreach ... of numlist ... {
    foreach_num <- regmatches(line, regexec(
      paste0(
        "^\\s*(?:cap(?:ture)?\\s+)?foreach\\s+(\\w+)\\s+",
        "of\\s+num(?:list)?\\s+(.+?)\\s*\\{\\s*$"
      ),
      line,
      perl = TRUE
    ))[[1]]

    # Match forvalues ... = .../... {
    forvalues <- regmatches(line, regexec(
      paste0(
        "^\\s*(?:cap(?:ture)?\\s+)?forval(?:ues)?\\s+",
        "(\\w+)\\s*=\\s*(.+?)\\s*\\{\\s*$"
      ),
      line,
      perl = TRUE
    ))[[1]]

    if (length(foreach_in) >= 3) {
      loopvar <- foreach_in[[2]]
      values <- strsplit(trimws(foreach_in[[3]]), "\\s+")[[1]]
      body_lines <- collect_loop_body(lines, i)
      expanded <- expand_loop_body(loopvar, values, body_lines$body)
      result <- c(result, expanded)
      i <- body_lines$end_idx + 1
    } else if (length(foreach_num) >= 3) {
      loopvar <- foreach_num[[2]]
      values <- expand_numlist(foreach_num[[3]])
      body_lines <- collect_loop_body(lines, i)
      expanded <- expand_loop_body(loopvar, values, body_lines$body)
      result <- c(result, expanded)
      i <- body_lines$end_idx + 1
    } else if (length(forvalues) >= 3) {
      loopvar <- forvalues[[2]]
      values <- expand_numlist(forvalues[[3]])
      body_lines <- collect_loop_body(lines, i)
      expanded <- expand_loop_body(loopvar, values, body_lines$body)
      result <- c(result, expanded)
      i <- body_lines$end_idx + 1
    } else {
      result <- c(result, lines[[i]])
      i <- i + 1
    }
  }

  # Recursively expand nested loops (inner foreach/forvalues inside expanded body)
  if (!identical(result, lines) && any(grepl(
    "^\\s*(?:cap(?:ture)?\\s+)?(?:foreach|forval)", result,
    perl = TRUE
  ))) {
    result <- expand_stata_loops(result)
  }

  result
}

#' Collect lines inside a loop body until closing brace
#' @param lines All source lines
#' @param start_idx Index of the line with opening brace
#' @return List with body (character vector) and end_idx
#' @keywords internal
collect_loop_body <- function(lines, start_idx) {
  depth <- 1
  body <- character(0)
  i <- start_idx + 1
  while (i <= length(lines) && depth > 0) {
    line <- lines[[i]]
    # Count braces (simplified: doesn't handle braces in strings)
    depth <- depth + nchar(gsub("[^{]", "", line)) -
      nchar(gsub("[^}]", "", line))
    if (depth > 0) {
      body <- c(body, line)
    } else {
      # Last line may have content before }
      before_brace <- sub("\\}\\s*$", "", line)
      if (nchar(trimws(before_brace)) > 0) {
        body <- c(body, before_brace)
      }
    }
    i <- i + 1
  }
  list(body = body, end_idx = i - 1)
}

#' Expand a numlist specification into numeric values
#' @param spec Numlist string like "1/14" or "81/89"
#' @return Character vector of values
#' @keywords internal
expand_numlist <- function(spec) {
  spec <- trimws(spec)
  # Split by spaces first, then expand each token
  tokens <- strsplit(spec, "\\s+")[[1]]
  result <- character(0)
  for (tok in tokens) {
    if (grepl("^\\d+/\\d+$", tok)) {
      # Range: a/b -> seq(a, b)
      parts <- strsplit(tok, "/")[[1]]
      result <- c(result, as.character(
        seq(as.integer(parts[1]), as.integer(parts[2]))
      ))
    } else {
      result <- c(result, tok)
    }
  }
  result
}

#' Substitute loop variable in body lines
#' @param loopvar Loop variable name
#' @param values Character vector of values
#' @param body Character vector of body lines
#' @return Character vector of expanded lines
#' @keywords internal
expand_loop_body <- function(loopvar, values, body) {
  result <- character(0)
  pattern <- paste0("`", loopvar, "'")
  for (val in values) {
    for (line in body) {
      result <- c(result, gsub(pattern, val, line, fixed = TRUE))
    }
  }
  result
}

#' Parse a single STATA command line into structured data
#'
#' @param line A single STATA command string
#' @param line_num Original line number (for error reporting)
#' @return A list with cmd, args, if_clause, options, raw_line,
#'   line_num, capture, or NULL for empty/skippable lines
#' @keywords internal
parse_stata_command <- function(line, line_num = NA_integer_) {
  line <- trimws(line)
  if (nchar(line) == 0) {
    return(NULL)
  }

  # Skip orphan expression fragments (broken multi-line continuations)
  # These start with &, |, ), +, or ( (expression fragments from block comments)
  if (grepl("^[&|)+]", line, perl = TRUE)) {
    return(NULL)
  }
  # Lines starting with ( that aren't commands — bare expressions from commented blocks
  if (grepl("^\\(", line, perl = TRUE)) {
    return(NULL)
  }

  # Strip capture prefix
  capture <- FALSE
  if (grepl("^cap(?:ture)?\\s+", line, perl = TRUE)) {
    capture <- TRUE
    line <- sub("^cap(?:ture)?\\s+", "", line, perl = TRUE)
  }

  # Strip bysort/bys/by prefix
  by_group <- NULL
  by_match <- regmatches(line, regexec(
    "^(?:bysort|bys|by)\\s+([\\w\\s]+?)\\s*:\\s*(.+)$", line,
    perl = TRUE
  ))[[1]]
  if (length(by_match) >= 3) {
    by_group <- trimws(by_match[[2]])
    line <- trimws(by_match[[3]])
  }

  # Extract STATA options (after last comma not inside parens)
  options_str <- NULL
  # Simple approach: split on , that's followed by option-like text
  opt_match <- regmatches(line, regexec(
    paste0(
      "^(.+),\\s*((?:gen|replace|force|override|mv|by)\\s*\\(.+?\\).*",
      "|replace.*|force.*|override.*|gen\\s*\\(\\w+\\).*)$"
    ),
    line,
    perl = TRUE
  ))[[1]]
  if (length(opt_match) >= 3) {
    line <- trimws(opt_match[[2]])
    options_str <- trimws(opt_match[[3]])
  }

  # Extract if clause
  if_clause <- NULL
  if_match <- regmatches(line, regexec(
    "^(.+?)\\s+if\\s+(.+)$", line,
    perl = TRUE
  ))[[1]]
  if (length(if_match) >= 3) {
    # Make sure this isn't part of an expression like "ifelse" or inside parens
    before_if <- trimws(if_match[[2]])
    after_if <- trimws(if_match[[3]])
    # Verify this is a real STATA if clause (comes after a complete expression)
    if (!grepl("ifelse|if_", before_if)) {
      line <- before_if
      if_clause <- after_if
    }
  }

  # Identify command
  parts <- strsplit(line, "\\s+", perl = TRUE)[[1]]
  if (length(parts) == 0) {
    return(NULL)
  }

  cmd <- tolower(parts[[1]])
  args <- if (length(parts) > 1) {
    paste(parts[2:length(parts)], collapse = " ")
  } else {
    ""
  }

  # Normalize abbreviated commands
  cmd <- switch(cmd,
    "g" = "gen",
    "ge" = "gen",
    "ren" = "rename",
    "u" = "use",
    "sa" = "save",
    "su" = "summarize",
    "br" = "browse",
    "tab" = "tabulate",
    "lab" = "label",
    "mat" = "matrix",
    "matr" = "matrix",
    "matri" = "matrix",
    "sum" = "summarize",
    "summ" = "summarize",
    "summa" = "summarize",
    cmd
  )

  list(
    cmd = cmd,
    args = trimws(args),
    if_clause = if_clause,
    options = options_str,
    by_group = by_group,
    raw_line = paste(
      line,
      if (!is.null(if_clause)) paste("if", if_clause) else "",
      if (!is.null(options_str)) paste(",", options_str) else ""
    ),
    line_num = line_num,
    capture = capture
  )
}

#' Parse STATA label commands from source lines
#'
#' Extracts variable labels, value label definitions, and
#' value label assignments from label commands.
#'
#' @param lines Character vector of source lines
#'    (already comment-stripped)
#' @return A list with var_labels (named list) and val_labels
#'    (named list of named lists)
#' @examples
#' \donttest{
#' lines <- c(
#'   'label variable edad "Age in years"',
#'   'label define sexo_lbl 1 "Male" 2 "Female"',
#'   "label values sexo sexo_lbl"
#' )
#' labels <- parse_stata_labels(lines)
#' labels$var_labels
#' labels$val_labels
#' }
#' @family transpiler
#' @export
parse_stata_labels <- function(lines) {
  var_labels <- list()
  val_defs <- list() # label name -> list of value-label pairs
  val_assigns <- list() # variable name -> label name

  for (line in lines) {
    line <- trimws(line)
    if (nchar(line) == 0) next

    # Strip comments first
    line <- sub("//.*$", "", line)

    # lab var varname "label"
    m <- regmatches(line, regexec(
      '^\\s*lab(?:el)?\\s+var(?:iable)?\\s+(\\w+)\\s+"([^"]*)"',
      line,
      perl = TRUE
    ))[[1]]
    if (length(m) >= 3) {
      var_labels[[m[[2]]]] <- m[[3]]
      next
    }

    # lab def labelname val1 "label1" val2 "label2" ...
    m <- regmatches(line, regexec(
      "^\\s*lab(?:el)?\\s+def(?:ine)?\\s+(\\w+)\\s+(.+)$",
      line,
      perl = TRUE
    ))[[1]]
    if (length(m) >= 3) {
      label_name <- m[[2]]
      pairs_str <- m[[3]]
      # Remove trailing options like ", add" or ", replace"
      pairs_str <- sub(",\\s*(add|replace|modify)\\s*$", "", pairs_str)
      # Extract val "label" pairs
      pair_matches <- gregexpr(
        '(\\-?\\d+)\\s+"([^"]*)"',
        pairs_str,
        perl = TRUE
      )
      pair_strs <- regmatches(pairs_str, pair_matches)[[1]]
      if (length(pair_strs) > 0) {
        pairs <- list()
        for (ps in pair_strs) {
          pm <- regmatches(
            ps,
            regexec('(\\-?\\d+)\\s+"([^"]*)"', ps, perl = TRUE)
          )[[1]]
          if (length(pm) >= 3) {
            pairs[[pm[[2]]]] <- pm[[3]]
          }
        }
        val_defs[[label_name]] <- pairs
      }
      next
    }

    # lab val varname labelname
    m <- regmatches(line, regexec(
      "^\\s*lab(?:el)?\\s+val(?:ues)?\\s+(\\w+)\\s+(\\w+)",
      line,
      perl = TRUE
    ))[[1]]
    if (length(m) >= 3) {
      val_assigns[[m[[2]]]] <- m[[3]]
      next
    }
  }

  # Resolve val_labels: variable -> value labels
  val_labels <- list()
  for (var_name in names(val_assigns)) {
    label_name <- val_assigns[[var_name]]
    if (label_name %in% names(val_defs)) {
      val_labels[[var_name]] <- val_defs[[label_name]]
    }
  }

  list(
    var_labels = var_labels,
    val_labels = val_labels
  )
}
