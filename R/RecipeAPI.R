#' @title RecipeBackend
#' @description Backend-agnostic factory for recipe storage
#' and retrieval. Supports "local" (JSON-backed
#' RecipeRegistry) and "api" (remote plumber API) backends.
#'
#' @field type Character backend type ("local" or "api").
#'
#' @keywords internal
RecipeBackend <- R6::R6Class(
  "RecipeBackend",
  public = list(
    type = NULL,

    #' @description Create a new RecipeBackend
    #' @param type Character. "local" or "api".
    #' @param path Character. File path for local backend (optional).
    initialize = function(type, path = NULL) {
      # Accept "mongo" as alias for "api" (backward compat)
      if (type == "mongo") type <- "api"
      valid_types <- c("local", "api")
      if (!(type %in% valid_types)) {
        stop(
          "Backend type must be one of: ",
          paste(valid_types, collapse = ", "),
          call. = FALSE
        )
      }
      self$type <- type
      if (type == "local") {
        private$.path <- path
        private$.registry <- RecipeRegistry$new()
        if (!is.null(path) && file.exists(path)) {
          private$.registry$load(path)
        }
      }
    },

    #' @description Publish a recipe to the backend
    #' @param recipe Recipe object
    publish = function(recipe) {
      if (self$type == "local") {
        private$.registry$register(recipe)
        if (!is.null(private$.path)) {
          private$.registry$save(private$.path)
        }
      } else if (self$type == "api") {
        api_publish_recipe(recipe)
      }
    },

    #' @description Search recipes
    #' @param query Character search string
    #' @return List of matching Recipe objects
    search = function(query) {
      if (self$type == "local") {
        private$.registry$search(query)
      } else if (self$type == "api") {
        tryCatch(
          api_list_recipes(search = query),
          error = function(e) list()
        )
      }
    },

    #' @description Get a recipe by id
    #' @param id Recipe id
    #' @return Recipe object or NULL
    get = function(id) {
      if (self$type == "local") {
        private$.registry$get(id)
      } else if (self$type == "api") {
        tryCatch(api_get_recipe(id), error = function(e) NULL)
      }
    },

    #' @description Increment download count for a recipe
    #' @param id Recipe id
    increment_downloads = function(id) {
      if (self$type == "local") {
        r <- private$.registry$get(id)
        if (!is.null(r)) {
          r$increment_downloads()
          if (!is.null(private$.path)) {
            private$.registry$save(private$.path)
          }
        }
      } else if (self$type == "api") {
        api_download_recipe(id)
      }
    },

    #' @description Rank recipes by downloads
    #' @param n Integer max to return
    #' @return List of Recipe objects
    rank = function(n = NULL) {
      if (self$type == "local") {
        private$.registry$rank_by_downloads(n)
      } else if (self$type == "api") {
        tryCatch(
          api_list_recipes(limit = n %||% 50),
          error = function(e) list()
        )
      }
    },

    #' @description Filter recipes by criteria
    #' @param survey_type Character or NULL
    #' @param edition Character or NULL
    #' @param category Character or NULL
    #' @param certification_level Character or NULL
    #' @param topic Character or NULL
    #' @return List of matching Recipe objects
    filter = function(survey_type = NULL,
                      edition = NULL,
                      category = NULL,
                      certification_level = NULL,
                      topic = NULL) {
      if (self$type == "local") {
        private$.registry$filter(
          survey_type = survey_type, edition = edition,
          category = category, certification_level = certification_level,
          topic = topic
        )
      } else if (self$type == "api") {
        tryCatch(
          api_list_recipes(
            survey_type = survey_type, topic = topic %||% category,
            certification = certification_level
          ),
          error = function(e) list()
        )
      }
    },

    #' @description List all recipes
    #' @return List of Recipe objects
    list_all = function() {
      if (self$type == "local") {
        private$.registry$list_all()
      } else if (self$type == "api") {
        tryCatch(api_list_recipes(), error = function(e) list())
      }
    },

    #' @description Save local backend to disk
    save = function() {
      if (self$type == "local" && !is.null(private$.path)) {
        private$.registry$save(private$.path)
      }
    },

    #' @description Load local backend from disk
    load = function() {
      is_local_with_path <- self$type == "local" &&
        !is.null(private$.path) && file.exists(private$.path)
      if (is_local_with_path) {
        private$.registry$load(private$.path)
      }
    }
  ),
  private = list(
    .registry = NULL,
    .path = NULL
  )
)

#' @title Set recipe backend
#' @description Configure the active recipe backend via options.
#' @param type Character. "local" or "api" (also accepts
#'   "mongo" for backward compat).
#' @param path Character. File path for local backend.
#' @return Invisibly, the RecipeBackend object created.
#' @examples
#' set_backend("local", path = tempfile(fileext = ".json"))
#' @family backends
#' @export
set_backend <- function(type, path = NULL) {
  old <- getOption("metasurvey.backend")
  backend <- RecipeBackend$new(type, path = path)
  options(metasurvey.backend = backend)
  invisible(old)
}

#' @title Get recipe backend
#' @description Returns the currently configured recipe backend.
#' Defaults to "api" if not configured.
#' @return RecipeBackend object
#' @examples
#' set_backend("local", path = tempfile(fileext = ".json"))
#' backend <- get_backend()
#' backend
#' @family backends
#' @export
get_backend <- function() {
  backend <- getOption("metasurvey.backend")
  if (is.null(backend)) {
    backend <- RecipeBackend$new("local")
  }
  backend
}
