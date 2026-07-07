# Internal input-validation helpers (issue #218).
#
# Exported functions validate their inputs on entry so misuse fails
# fast, close to the cause, with a message that names the function and
# the offending argument. Base R only.

#' Signal an input validation error
#'
#' @param fn Name of the user-facing function (without parentheses).
#' @param arg Name of the offending argument.
#' @param must Requirement description, continuing "`arg` in `fn()` ...".
#' @param got Optional description of what was received.
#' @noRd
stop_input <- function(fn, arg, must, got = NULL) {
  msg <- sprintf("`%s` in `%s()` %s", arg, fn, must)
  if (!is.null(got)) {
    msg <- sprintf("%s; got %s", msg, got)
  }
  stop(msg, call. = FALSE)
}

#' Describe the class of an object for error messages
#' @noRd
describe_class <- function(x) {
  sprintf("<%s>", paste(class(x), collapse = "/"))
}

#' Check that an argument inherits from (any of) the given classes
#' @noRd
check_inherits <- function(x, what, fn, arg) {
  if (!inherits(x, what)) {
    stop_input(
      fn, arg,
      sprintf(
        "must be a %s object",
        paste(sprintf("<%s>", what), collapse = " or ")
      ),
      got = describe_class(x)
    )
  }
  invisible(x)
}
