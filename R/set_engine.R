#' Configure the survey data engine
#' @keywords engine
#' @description Configures the engine to be used for
#' loading surveys. Checks if the provided engine is
#' supported, sets the default engine if none is specified,
#' and generates a message indicating the configured
#' engine. If the engine is not supported, it throws an
#' error.
#' @param .engine Character vector with the name of the
#'   engine to configure. By default, the engine returned
#'   by the `show_engines()` function is used.
#' @return Invisibly, the previous engine name (for restoring).
#' @examples
#' \donttest{
#' old <- set_engine("data.table")
#' get_engine()
#' }
#' @importFrom glue glue
#' @family options
#' @export

set_engine <- function(.engine = show_engines()) {
  .support_engine <- show_engines()
  old <- getOption("metasurvey.engine")

  # When called with no argument, .engine is the full vector — use default
  if (identical(.engine, .support_engine)) {
    default_engine()
  } else if (.engine %in% .support_engine) {
    options(metasurvey.engine = .engine)
  } else {
    stop(
      paste0(
        "Engine '", .engine, "' is not supported. Available: ",
        paste(.support_engine, collapse = ", ")
      ),
      call. = FALSE
    )
  }

  metasurvey_msg(
    cli::col_green(glue::glue("Engine: {.engine}", .engine = get_engine()))
  )

  engine_name <- get_engine()
  # "metatable" is an internal engine (plan layer over data.table,
  # see design/metatable-rfc.md), not an installable package
  needs_pkg <- engine_name != "metatable"
  if (needs_pkg && !requireNamespace(engine_name, quietly = TRUE)) {
    warning(
      "Package '", engine_name, "' is required. ",
      "Install it with: install.packages('", engine_name, "')",
      call. = FALSE
    )
  }

  invisible(old)
}

#' List available survey data engines
#' @description Returns a character vector of available
#' engines that can be used for loading surveys.
#' @importFrom glue glue
#' @export
#' @return Character vector with the names of the available engines.
#' @examples
#' show_engines()
#' @family options
show_engines <- function() {
  c(
    "data.table",
    "tidyverse",
    "dplyr",
    "metatable"
  )
}

#' Get the current survey data engine
#' @description Retrieves the currently configured engine
#' for loading surveys from system options or environment
#' variables.
#' @export
#' @return Character vector with the name of the configured engine.
#' @keywords engine
#' @examples
#' get_engine()
#' @family options
get_engine <- function() {
  Sys.getenv("metasurvey.engine") %@%
    getOption("metasurvey.engine")
}

#' Set default engine
#' @description Sets a default engine for loading surveys.
#' If an engine is already configured, it keeps it;
#' otherwise, it sets "data.table" as the default engine.
#' @param .engine Character vector with the name of the
#'   default engine. By default, "data.table" is used.
#' @keywords internal

default_engine <- function(.engine = "data.table") {
  engine_env <- get_engine()

  options(metasurvey.engine = engine_env %||% .engine)
  engine_env %||% .engine
}
