#' @title RecipeUser
#' @description User identity for the recipe ecosystem.
#' Supports three account types: individual,
#' institutional_member, and institution.
#'
#' @field name Character. User or institution name.
#' @field email Character or NULL. Email address.
#' @field user_type Character. One of "individual",
#'   "institutional_member", "institution".
#' @field affiliation Character or NULL. Organizational affiliation.
#' @field institution RecipeUser or NULL. Parent institution
#'   (for institutional_member).
#' @field url Character or NULL. Institution URL.
#' @field verified Logical. Whether the account is verified.
#' @field review_status Character. One of "approved",
#'   "pending", "rejected".
#'
#' @return An object of class \code{RecipeUser}.
#'
#' @examples
#' # Use recipe_user() for the public API:
#' user <- recipe_user("Juan Perez", email = "juan@example.com")
#' inst <- recipe_user("IECON", type = "institution")
#' member <- recipe_user(
#'   "Maria",
#'   type = "institutional_member",
#'   institution = inst
#' )
#'
#' @family tidy-api
#' @export
RecipeUser <- R6::R6Class(
  "RecipeUser",
  public = list(
    name = NULL,
    email = NULL,
    user_type = NULL,
    affiliation = NULL,
    institution = NULL,
    url = NULL,
    verified = FALSE,
    review_status = "approved",

    #' @description Create a new RecipeUser
    #' @param name Character. User or institution name.
    #' @param user_type Character. One of "individual",
    #'   "institutional_member", "institution".
    #' @param email Character or NULL. Email address.
    #' @param affiliation Character or NULL. Organizational affiliation.
    #' @param institution RecipeUser or NULL. Parent
    #'   institution for institutional_member.
    #' @param url Character or NULL. Institution URL.
    #' @param verified Logical. Whether account is verified.
    #' @param review_status Character. "approved", "pending",
    #'   or "rejected".
    initialize = function(name, user_type, email = NULL, affiliation = NULL,
                          institution = NULL, url = NULL, verified = FALSE,
                          review_status = "approved") {
      if (is.null(name) || !is.character(name) || nchar(name) == 0) {
        stop("User name must be a non-empty character string", call. = FALSE)
      }
      valid_types <- c("individual", "institutional_member", "institution")
      if (is.null(user_type) || !is.character(user_type) || !(user_type %in% valid_types)) {
        stop(
          "user_type must be one of: ",
          paste(valid_types, collapse = ", "),
          call. = FALSE
        )
      }
      if (user_type == "institutional_member") {
        if (is.null(institution) || !inherits(institution, "RecipeUser")) {
          stop("institutional_member requires a valid RecipeUser institution",
            call. = FALSE
          )
        }
      }
      self$name <- name
      self$email <- email
      self$user_type <- user_type
      self$affiliation <- affiliation
      self$institution <- institution
      self$url <- url
      self$verified <- verified
      self$review_status <- review_status
    },

    #' @description Get trust level (1=individual, 2=member, 3=institution)
    #' @return Integer trust level
    trust_level = function() {
      switch(self$user_type,
        "individual" = 1L,
        "institutional_member" = 2L,
        "institution" = 3L
      )
    },

    #' @description Check if user can certify at a given level
    #' @param level Character. Certification level
    #'   ("reviewed" or "official").
    #' @return Logical
    can_certify = function(level) {
      required <- switch(level,
        "reviewed" = 2L,
        "official" = 3L,
        0L
      )
      self$trust_level() >= required
    },

    #' @description Serialize to list for JSON
    #' @return List representation
    to_list = function() {
      lst <- list(
        name = self$name,
        user_type = self$user_type
      )
      if (!is.null(self$email)) lst$email <- self$email
      if (!is.null(self$affiliation)) lst$affiliation <- self$affiliation
      if (!is.null(self$url)) lst$url <- self$url
      lst$verified <- self$verified
      lst$review_status <- self$review_status
      if (!is.null(self$institution)) {
        lst$institution <- self$institution$to_list()
      }
      lst
    },

    #' @description Print user card
    #' @param ... Additional arguments (not used)
    print = function(...) {
      type_label <- switch(self$user_type,
        "individual" = "Individual",
        "institutional_member" = "Institutional Member",
        "institution" = "Institution"
      )
      cat(
        cli::style_bold(self$name),
        paste0("(", type_label, ")"), "\n"
      )
      if (!is.null(self$email)) cat("  Email:", self$email, "\n")
      if (!is.null(self$affiliation)) {
        cat("  Affiliation:", self$affiliation, "\n")
      }
      if (!is.null(self$institution)) {
        cat(
          "  Institution:",
          self$institution$name, "\n"
        )
      }
      if (!is.null(self$url)) cat("  URL:", self$url, "\n")
      if (self$verified) cat("  ", cli::col_green("Verified"), "\n")
      if (self$review_status != "approved") {
        status_col <- if (self$review_status == "pending") {
          cli::col_yellow
        } else {
          cli::col_red
        }
        cat(
          "  ",
          status_col(paste0("Review: ", self$review_status)),
          "\n"
        )
      }
      invisible(self)
    }
  )
)

# Class-level from_list
RecipeUser$from_list <- function(lst) {
  if (is.null(lst)) {
    return(NULL)
  }
  inst <- NULL
  if (!is.null(lst$institution)) {
    inst <- RecipeUser$from_list(lst$institution)
  }
  RecipeUser$new(
    name = lst$name,
    user_type = lst$user_type,
    email = lst$email,
    affiliation = lst$affiliation,
    institution = inst,
    url = lst$url,
    verified = isTRUE(lst$verified),
    review_status = lst$review_status %||% "approved"
  )
}
