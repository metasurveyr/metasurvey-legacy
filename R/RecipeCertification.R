#' @title RecipeCertification
#' @description Quality certification for recipes with three tiers:
#' community (default), reviewed (peer-reviewed by institutional member),
#' and official (certified by institution).
#'
#' @field level Character. Certification level.
#' @field certified_by RecipeUser or NULL. The certifying user.
#' @field certified_at POSIXct. Timestamp of certification.
#' @field notes Character or NULL. Additional notes.
#'
#' @return An object of class \code{RecipeCertification}.
#'
#' @examples
#' # Use recipe_certification() for the public API:
#' cert <- recipe_certification()
#' inst <- recipe_user("IECON", type = "institution")
#' official <- recipe_certification("official", certified_by = inst)
#'
#' @family tidy-api
#' @export
RecipeCertification <- R6::R6Class(
  "RecipeCertification",
  public = list(
    level = NULL,
    certified_by = NULL,
    certified_at = NULL,
    notes = NULL,

    #' @description Create a new RecipeCertification
    #' @param level Character. One of "community", "reviewed", "official".
    #' @param certified_by RecipeUser or NULL. Required for reviewed/official.
    #' @param notes Character or NULL. Additional notes.
    #' @param certified_at POSIXct or NULL. Auto-set if NULL.
    initialize = function(level, certified_by = NULL,
                          notes = NULL,
                          certified_at = NULL) {
      valid_levels <- c("community", "reviewed", "official")
      if (is.null(level) || !is.character(level) || !(level %in% valid_levels)) {
        stop(
          "level must be one of: ",
          paste(valid_levels, collapse = ", "),
          call. = FALSE
        )
      }

      if (level == "official") {
        if (
          is.null(certified_by) || !inherits(certified_by, "RecipeUser") ||
            certified_by$user_type != "institution"
        ) {
          stop(
            "official certification requires a ",
            "RecipeUser of type 'institution'",
            call. = FALSE
          )
        }
      }

      if (level == "reviewed") {
        if (
          is.null(certified_by) || !inherits(certified_by, "RecipeUser") ||
            !certified_by$user_type %in%
              c("institutional_member", "institution")
        ) {
          stop(
            "reviewed certification requires a ",
            "RecipeUser of type 'institutional_member' ",
            "or 'institution'",
            call. = FALSE
          )
        }
      }

      self$level <- level
      self$certified_by <- certified_by
      self$notes <- notes
      self$certified_at <- certified_at %||% Sys.time()
    },

    #' @description Get numeric level for ordering
    #'   (1=community, 2=reviewed, 3=official)
    #' @return Integer
    numeric_level = function() {
      switch(self$level,
        "community" = 1L,
        "reviewed" = 2L,
        "official" = 3L
      )
    },

    #' @description Check if certification is at least a given level
    #' @param level Character. Level to compare against.
    #' @return Logical
    is_at_least = function(level) {
      target <- switch(level,
        "community" = 1L,
        "reviewed" = 2L,
        "official" = 3L
      )
      self$numeric_level() >= target
    },

    #' @description Serialize to list for JSON
    #' @return List representation
    to_list = function() {
      lst <- list(
        level = self$level,
        certified_at = as.character(self$certified_at)
      )
      if (!is.null(self$certified_by)) {
        lst$certified_by <- self$certified_by$to_list()
      }
      if (!is.null(self$notes)) {
        lst$notes <- self$notes
      }
      lst
    },

    #' @description Print certification badge
    #' @param ... Additional arguments (not used)
    print = function(...) {
      badge <- switch(self$level,
        "community" = cli::col_yellow("community"),
        "reviewed" = cli::col_cyan("reviewed"),
        "official" = cli::col_green("official")
      )
      cat(cli::style_bold("Certification:"), badge, "\n")
      if (!is.null(self$certified_by)) {
        cat("  Certified by:", self$certified_by$name, "\n")
      }
      cat(
        "  Date:",
        format(self$certified_at, "%Y-%m-%d"), "\n"
      )
      if (!is.null(self$notes)) {
        cat("  Notes:", self$notes, "\n")
      }
      invisible(self)
    }
  )
)

# Class-level from_list
RecipeCertification$from_list <- function(lst) {
  if (is.null(lst)) {
    return(NULL)
  }
  certified_by <- NULL
  if (!is.null(lst$certified_by)) {
    certified_by <- RecipeUser$from_list(lst$certified_by)
  }
  certified_at <- if (!is.null(lst$certified_at)) {
    as.POSIXct(lst$certified_at)
  } else {
    Sys.time()
  }
  RecipeCertification$new(
    level = lst$level,
    certified_by = certified_by,
    notes = lst$notes,
    certified_at = certified_at
  )
}
