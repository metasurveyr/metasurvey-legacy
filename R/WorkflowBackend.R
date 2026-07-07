#' @title WorkflowBackend
#' @description Backend-agnostic factory for workflow
#' storage and retrieval. Supports "local" (JSON-backed
#' WorkflowRegistry) and "api" (remote plumber API)
#' backends.
#'
#' @field type Character backend type ("local" or "api").
#'
#' @keywords internal
WorkflowBackend <- R6::R6Class(
  "WorkflowBackend",
  public = list(
    type = NULL,

    #' @description Create a new WorkflowBackend
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
        private$.registry <- WorkflowRegistry$new()
        if (!is.null(path) && file.exists(path)) {
          private$.registry$load(path)
        }
      }
    },

    #' @description Publish a workflow to the backend
    #' @param wf RecipeWorkflow object
    publish = function(wf) {
      if (self$type == "local") {
        private$.registry$register(wf)
        if (!is.null(private$.path)) {
          private$.registry$save(private$.path)
        }
      } else if (self$type == "api") {
        api_publish_workflow(wf)
      }
    },

    #' @description Search workflows
    #' @param query Character search string
    #' @return List of matching RecipeWorkflow objects
    search = function(query) {
      if (self$type == "local") {
        private$.registry$search(query)
      } else if (self$type == "api") {
        tryCatch(
          api_list_workflows(search = query),
          error = function(e) list()
        )
      }
    },

    #' @description Get a workflow by id
    #' @param id Workflow id
    #' @return RecipeWorkflow object or NULL
    get = function(id) {
      if (self$type == "local") {
        private$.registry$get(id)
      } else if (self$type == "api") {
        tryCatch(api_get_workflow(id), error = function(e) NULL)
      }
    },

    #' @description Increment download count for a workflow
    #' @param id Workflow id
    increment_downloads = function(id) {
      if (self$type == "local") {
        w <- private$.registry$get(id)
        if (!is.null(w)) {
          w$increment_downloads()
          if (!is.null(private$.path)) {
            private$.registry$save(private$.path)
          }
        }
      } else if (self$type == "api") {
        api_download_workflow(id)
      }
    },

    #' @description Find workflows that reference a specific recipe
    #' @param recipe_id Character recipe ID
    #' @return List of RecipeWorkflow objects
    find_by_recipe = function(recipe_id) {
      if (self$type == "local") {
        private$.registry$find_by_recipe(recipe_id)
      } else if (self$type == "api") {
        tryCatch(
          api_list_workflows(recipe_id = recipe_id),
          error = function(e) list()
        )
      }
    },

    #' @description Rank workflows by downloads
    #' @param n Integer max to return
    #' @return List of RecipeWorkflow objects
    rank = function(n = NULL) {
      if (self$type == "local") {
        private$.registry$rank_by_downloads(n)
      } else if (self$type == "api") {
        tryCatch(
          api_list_workflows(limit = n %||% 50),
          error = function(e) list()
        )
      }
    },

    #' @description Filter workflows by criteria
    #' @param survey_type Character or NULL
    #' @param edition Character or NULL
    #' @param recipe_id Character or NULL
    #' @param certification_level Character or NULL
    #' @return List of matching RecipeWorkflow objects
    filter = function(survey_type = NULL,
                      edition = NULL,
                      recipe_id = NULL,
                      certification_level = NULL) {
      if (self$type == "local") {
        private$.registry$filter(
          survey_type = survey_type, edition = edition,
          recipe_id = recipe_id, certification_level = certification_level
        )
      } else if (self$type == "api") {
        tryCatch(
          api_list_workflows(
            survey_type = survey_type,
            recipe_id = recipe_id
          ),
          error = function(e) list()
        )
      }
    },

    #' @description List all workflows
    #' @return List of RecipeWorkflow objects
    list_all = function() {
      if (self$type == "local") {
        private$.registry$list_all()
      } else if (self$type == "api") {
        tryCatch(api_list_workflows(), error = function(e) list())
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
      if (self$type == "local" && !is.null(private$.path) && file.exists(private$.path)) {
        private$.registry$load(private$.path)
      }
    }
  ),
  private = list(
    .registry = NULL,
    .path = NULL
  )
)

#' @title Set workflow backend
#' @description Configure the active workflow backend via
#'   options.
#' @param type Character. "local" or "api" (also accepts
#'   "mongo" for backward compat).
#' @param path Character. File path for local backend.
#' @return Invisibly, the WorkflowBackend object created.
#' @examples
#' set_workflow_backend("local", path = tempfile(fileext = ".json"))
#' @family backends
#' @export
set_workflow_backend <- function(type, path = NULL) {
  old <- getOption("metasurvey.workflow_backend")
  backend <- WorkflowBackend$new(type, path = path)
  options(metasurvey.workflow_backend = backend)
  invisible(old)
}

#' @title Get workflow backend
#' @description Returns the currently configured workflow backend.
#' Defaults to "local" if not configured.
#' @return WorkflowBackend object
#' @examples
#' backend <- get_workflow_backend()
#' @family backends
#' @export
get_workflow_backend <- function() {
  backend <- getOption("metasurvey.workflow_backend")
  if (is.null(backend)) {
    backend <- WorkflowBackend$new("local")
  }
  backend
}
