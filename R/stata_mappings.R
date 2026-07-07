# STATA expression and command mappings for metasurvey transpiler

#' Translate a STATA expression to an R expression string
#'
#' Converts STATA-specific syntax (inrange, inlist, missing values, etc.)
#' to equivalent R expressions suitable for data.table evaluation.
#'
#' @param expr STATA expression string
#' @return R expression string
#' @keywords internal
translate_stata_expr <- function(expr) {
  if (is.null(expr) || nchar(trimws(expr)) == 0) {
    return(expr)
  }
  expr <- trimws(expr)

  # inrange(var, a, b) -> (var >= a & var <= b)
  expr <- gsub(
    "inrange\\(([^,]+),\\s*([^,]+),\\s*([^)]+)\\)",
    "(\\1 >= \\2 & \\1 <= \\3)",
    expr,
    perl = TRUE
  )

  # inlist(var, a, b, c) -> (var %in% c(a, b, c))
  while (grepl("inlist\\(", expr)) {
    m <- regmatches(expr, regexec(
      "inlist\\(([^,]+),\\s*([^)]+)\\)", expr,
      perl = TRUE
    ))[[1]]
    if (length(m) >= 3) {
      var <- trimws(m[[2]])
      vals <- trimws(m[[3]])
      replacement <- paste0("(", var, " %in% c(", vals, "))")
      expr <- sub("inlist\\([^)]+\\)", replacement, expr, fixed = FALSE)
    } else {
      break
    }
  }

  # var==. -> is.na(var) (missing value comparison)
  expr <- gsub("(\\w+)\\s*==\\s*\\.", "is.na(\\1)", expr, perl = TRUE)

  # var!=. -> !is.na(var)
  expr <- gsub("(\\w+)\\s*!=\\s*\\.", "!is.na(\\1)", expr, perl = TRUE)

  # Standalone . as value -> NA (but not in decimal numbers like 4.3)
  # Match . that is: at start, after operator, after comma, or at end
  expr <- gsub("(?<=^|[=,+(\\s])\\.$", "NA", expr, perl = TRUE)
  expr <- gsub("(?<=^|[=,+(\\s])\\.(?=[,)\\s])", "NA", expr, perl = TRUE)

  # string(var) -> as.character(var)
  expr <- gsub("string\\(", "as.character(", expr, perl = TRUE)

  # substr() is the same in R, no change needed
  # trunc() is the same in R, no change needed

  # var[_n-1] -> shift(var, 1, type = "lag")
  # var[_n+1] -> shift(var, 1, type = "lead")
  expr <- gsub(
    "(\\w+)\\[_n-1\\]",
    'data.table::shift(\\1, 1, type = "lag")',
    expr,
    perl = TRUE
  )
  expr <- gsub(
    "(\\w+)\\[_n\\+1\\]",
    'data.table::shift(\\1, 1, type = "lead")',
    expr,
    perl = TRUE
  )
  # var[_n-k] -> shift(var, k, type = "lag") for arbitrary k
  expr <- gsub(
    "(\\w+)\\[_n-(\\d+)\\]",
    'data.table::shift(\\1, \\2, type = "lag")',
    expr,
    perl = TRUE
  )
  # var[_n+k] -> shift(var, k, type = "lead") for arbitrary k
  expr <- gsub(
    "(\\w+)\\[_n\\+(\\d+)\\]",
    'data.table::shift(\\1, \\2, type = "lead")',
    expr,
    perl = TRUE
  )

  # _N -> .N (total row count / group count in data.table)
  # Must not match inside variable names like _N_something
  expr <- gsub("(?<![\\w])_N(?![\\w])", ".N", expr, perl = TRUE)

  expr
}

#' Expand a STATA variable range to individual variable names
#'
#' STATA allows variable ranges like suma1-suma4 which means
#' suma1 suma2 suma3 suma4. This function detects and expands
#' such ranges by incrementing the trailing numeric suffix.
#'
#' @param spec Variable specification (may contain ranges with -)
#' @return Character vector of individual variable names
#' @keywords internal
expand_var_range <- function(spec) {
  spec <- trimws(spec)
  # Check for simple range: prefix<num>-prefix<num> (e.g., suma1-suma4)
  m <- regmatches(spec, regexec(
    "^(.+?)(\\d+)-(\\1)(\\d+)$", spec,
    perl = TRUE
  ))[[1]]
  if (length(m) >= 5) {
    prefix <- m[[2]]
    from <- as.integer(m[[3]])
    to <- as.integer(m[[5]])
    return(paste0(prefix, seq(from, to)))
  }
  # Suffix pattern: prefix_num-prefix_num (like e51_2_1-e51_2_5)
  m <- regmatches(spec, regexec(
    "^(.+_)(\\d+)-(.+_)(\\d+)$", spec,
    perl = TRUE
  ))[[1]]
  if (length(m) >= 5 && m[[2]] == m[[4]]) {
    prefix <- m[[2]]
    from <- as.integer(m[[3]])
    to <- as.integer(m[[5]])
    return(paste0(prefix, seq(from, to)))
  }
  # STATA positional range with different endpoints: aux1-aux14_max
  # Expand by generating all variants: prefix<N> and prefix<N>_suffix
  m <- regmatches(spec, regexec(
    "^(\\w+?)(\\d+)-(\\w+?)(\\d+)(_.+)$", spec,
    perl = TRUE
  ))[[1]]
  if (length(m) >= 6 && m[[2]] == m[[4]]) {
    prefix <- m[[2]]
    from <- as.integer(m[[3]])
    to <- as.integer(m[[5]])
    suffix <- m[[6]]
    nums <- seq(from, to)
    base_vars <- paste0(prefix, nums)
    suffix_vars <- paste0(prefix, nums, suffix)
    return(c(base_vars, suffix_vars))
  }
  # No range detected — return as-is
  spec
}

#' Detect if a STATA replace RHS is a constant value
#'
#' Returns TRUE if the expression is a simple numeric constant,
#' string literal, or negative number. Used to decide between
#' step_recode (constants) and step_compute (expressions).
#'
#' @param expr STATA expression string
#' @return Logical
#' @keywords internal
is_constant_rhs <- function(expr) {
  expr <- trimws(expr)
  # Numeric (including negative): -9, 0, 1, 2.5
  if (grepl("^-?\\d+(\\.\\d+)?$", expr)) {
    return(TRUE)
  }
  # String literal: "text"
  if (grepl('^"[^"]*"$', expr)) {
    return(TRUE)
  }
  # Missing value
  if (expr == ".") {
    return(TRUE)
  }
  FALSE
}

#' Parse a STATA gen command into variable name and expression
#'
#' @param args The arguments part of a gen command (after "gen")
#' @return List with var_name and expr
#' @keywords internal
parse_gen_args <- function(args) {
  # Handle type prefix: gen byte/int/float/double/str var = expr
  args <- sub(
    "^(byte|int|long|float|double|str\\d*)\\s+",
    "",
    args,
    perl = TRUE
  )
  # Split on first =
  eq_pos <- regexpr("=", args)
  if (eq_pos < 0) {
    return(NULL)
  }
  var_name <- trimws(substring(args, 1, eq_pos - 1))
  expr <- trimws(substring(args, eq_pos + 1))
  # Strip outer parentheses if the whole expression is wrapped: (expr) -> expr
  if (grepl("^\\(.*\\)$", expr, perl = TRUE)) {
    # Verify parens are balanced (not just coincidental open/close)
    inner <- substring(expr, 2, nchar(expr) - 1)
    depth <- 0
    balanced <- TRUE
    for (ch in strsplit(inner, "")[[1]]) {
      if (ch == "(") {
        depth <- depth + 1
      } else if (ch == ")") {
        depth <- depth - 1
      }
      if (depth < 0) {
        balanced <- FALSE
        break
      }
    }
    if (balanced && depth == 0) expr <- inner
  }
  list(var_name = var_name, expr = expr)
}

#' Parse a STATA replace command into variable name and expression
#'
#' @param args The arguments part of a replace command
#' @return List with var_name and expr
#' @keywords internal
parse_replace_args <- function(args) {
  parse_gen_args(args) # Same syntax: var = expr
}

#' Parse a STATA recode command
#'
#' Handles patterns like:
#' - recode var (old=new) (old=new)
#' - recode var (old=new), gen(newvar)
#' - recode var .=0
#' - recode var 23/38=22
#'
#' @param args Arguments string after "recode"
#' @param options Options string (may contain gen())
#' @return List with var_name, gen_var (or NULL), and mappings list
#' @keywords internal
parse_recode_args <- function(args, options = NULL) {
  parts <- strsplit(trimws(args), "\\s+", perl = TRUE)[[1]]
  if (length(parts) == 0) {
    return(NULL)
  }

  var_name <- parts[[1]]
  rest <- paste(parts[-1], collapse = " ")

  # Check for gen() in options
  gen_var <- NULL
  if (!is.null(options)) {
    gen_match <- regmatches(options, regexec("gen\\((\\w+)\\)", options))[[1]]
    if (length(gen_match) >= 2) {
      gen_var <- gen_match[[2]]
    }
  }

  mappings <- list()

  # Pattern: (old=new) groups
  paren_matches <- gregexpr("\\(([^)]+)\\)", rest, perl = TRUE)
  paren_strs <- regmatches(rest, paren_matches)[[1]]
  if (length(paren_strs) > 0) {
    for (ps in paren_strs) {
      inner <- gsub("[()]", "", ps)
      # Handle multiple values: (0 3 4=-15)
      eq_pos <- regexpr("=", inner)
      if (eq_pos > 0) {
        from_str <- trimws(substring(inner, 1, eq_pos - 1))
        to_str <- trimws(substring(inner, eq_pos + 1))
        from_vals <- strsplit(from_str, "\\s+")[[1]]
        mappings <- c(mappings, list(list(from = from_vals, to = to_str)))
      }
    }
  } else {
    # Inline format: .=0 or 23/38=22
    inline_parts <- strsplit(rest, "\\s+")[[1]]
    for (ip in inline_parts) {
      eq_pos <- regexpr("=", ip)
      if (eq_pos > 0) {
        from_str <- substring(ip, 1, eq_pos - 1)
        to_str <- substring(ip, eq_pos + 1)
        # Handle range: 23/38
        if (grepl("/", from_str)) {
          range_parts <- strsplit(from_str, "/")[[1]]
          mappings <- c(mappings, list(list(
            from_range = as.numeric(range_parts),
            to = to_str
          )))
        } else {
          mappings <- c(mappings, list(list(from = from_str, to = to_str)))
        }
      }
    }
  }

  list(var_name = var_name, gen_var = gen_var, mappings = mappings)
}

#' Parse a STATA egen command
#'
#' @param args Arguments string after "egen"
#' @param by_group By-group from bysort prefix or by() option
#' @param options Options string
#' @return List with var_name, func, func_arg, by_group
#' @keywords internal
parse_egen_args <- function(args, by_group = NULL, options = NULL) {
  # egen new_var = func(arg)
  eq_pos <- regexpr("=", args)
  if (eq_pos < 0) {
    return(NULL)
  }

  var_name <- trimws(substring(args, 1, eq_pos - 1))
  rest <- trimws(substring(args, eq_pos + 1))

  # Handle optional space between func and ( e.g. "sum (var)"
  func_match <- regmatches(rest, regexec("(\\w+)\\s*\\(([^)]+)\\)", rest))[[1]]
  if (length(func_match) < 3) {
    return(NULL)
  }

  # Check for by() in options (with optional spaces)
  if (is.null(by_group) && !is.null(options)) {
    by_match <- regmatches(
      options,
      regexec("by\\s*\\(([^)]+)\\)", options)
    )[[1]]
    if (length(by_match) >= 2) {
      by_group <- trimws(by_match[[2]])
    }
  }

  list(
    var_name = var_name,
    func = func_match[[2]],
    func_arg = func_match[[3]],
    by_group = by_group
  )
}

#' Parse a STATA mvencode command
#'
#' @param args Arguments string after "mvencode"
#' @param options Options string
#' @return List with var_names and mv_value
#' @keywords internal
parse_mvencode_args <- function(args, options = NULL) {
  var_names <- strsplit(trimws(args), "[\\s,]+", perl = TRUE)[[1]]
  var_names <- var_names[nchar(var_names) > 0]

  mv_value <- "0"
  if (!is.null(options)) {
    mv_match <- regmatches(options, regexec("mv\\(([^)]+)\\)", options))[[1]]
    if (length(mv_match) >= 2) {
      mv_value <- mv_match[[2]]
    }
  }

  list(var_names = var_names, mv_value = mv_value)
}

#' Parse a STATA destring command
#'
#' @param args Arguments string after "destring"
#' @param options Options string
#' @return List with var_name, replace (logical), force (logical), gen_var
#' @keywords internal
parse_destring_args <- function(args, options = NULL) {
  var_name <- trimws(args)

  do_replace <- FALSE
  do_force <- FALSE
  gen_var <- NULL

  if (!is.null(options)) {
    do_replace <- grepl("replace", options)
    do_force <- grepl("force", options)
    gen_match <- regmatches(
      options,
      regexec("gen(?:erate)?\\((\\w+)\\)", options)
    )[[1]]
    if (length(gen_match) >= 2) {
      gen_var <- gen_match[[2]]
    }
  }

  list(
    var_name = var_name,
    replace = do_replace,
    force = do_force,
    gen_var = gen_var
  )
}
