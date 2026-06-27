#' @title RecipeRegistry
#' @description Local JSON-backed catalog for recipe
#'   discovery, ranking, and filtering.
#'
#' @keywords internal
RecipeRegistry <- R6::R6Class(
  "RecipeRegistry",
  public = list(
    #' @description Create a new empty RecipeRegistry
    initialize = function() {
      private$.recipes <- list()
    },

    #' @description Register a recipe in the catalog
    #' @param recipe Recipe object to register
    register = function(recipe) {
      if (!inherits(recipe, "Recipe")) {
        stop("Can only register Recipe objects", call. = FALSE)
      }
      id <- as.character(recipe$id)
      private$.recipes[[id]] <- recipe
    },

    #' @description Remove a recipe from the catalog by id
    #' @param recipe_id Recipe id to remove
    unregister = function(recipe_id) {
      id <- as.character(recipe_id)
      private$.recipes[[id]] <- NULL
    },

    #' @description Search recipes by name or description (case-insensitive)
    #' @param query Character search query
    #' @return List of matching Recipe objects
    search = function(query) {
      pattern <- tolower(query)
      Filter(function(r) {
        grepl(pattern, tolower(r$name)) ||
          grepl(pattern, tolower(r$description))
      }, private$.recipes)
    },

    #' @description Filter recipes by criteria
    #' @param survey_type Character survey type or NULL
    #' @param edition Character edition or NULL
    #' @param category Character category name or NULL
    #' @param certification_level Character certification level or NULL
    #' @param topic Character topic name or NULL
    #' @return List of matching Recipe objects
    filter = function(survey_type = NULL, edition = NULL,
                      category = NULL,
                      certification_level = NULL,
                      topic = NULL) {
      results <- private$.recipes
      if (!is.null(survey_type)) {
        results <- Filter(function(r) r$survey_type == survey_type, results)
      }
      if (!is.null(edition)) {
        results <- Filter(function(r) r$edition == edition, results)
      }
      if (!is.null(category)) {
        results <- Filter(function(r) {
          cat_names <- vapply(r$categories, function(c) c$name, character(1))
          category %in% cat_names
        }, results)
      }
      if (!is.null(certification_level)) {
        results <- Filter(function(r) {
          r$certification$level == certification_level
        }, results)
      }
      if (!is.null(topic)) {
        results <- Filter(function(r) {
          identical(r$topic, topic)
        }, results)
      }
      results
    },

    #' @description Rank recipes by download count (descending)
    #' @param n Integer max number to return, or NULL for all
    #' @return List of Recipe objects sorted by downloads
    rank_by_downloads = function(n = NULL) {
      recipes <- private$.recipes
      if (length(recipes) == 0) {
        return(list())
      }
      downloads <- vapply(recipes, function(r) r$downloads, integer(1))
      ordered <- recipes[order(downloads, decreasing = TRUE)]
      if (!is.null(n)) {
        ordered <- ordered[seq_len(min(n, length(ordered)))]
      }
      ordered
    },

    #' @description Rank recipes by certification level then downloads
    #' @param n Integer max number to return, or NULL for all
    #' @return List of Recipe objects sorted by cert level then downloads
    rank_by_certification = function(n = NULL) {
      recipes <- private$.recipes
      if (length(recipes) == 0) {
        return(list())
      }
      cert_levels <- vapply(
        recipes,
        function(r) r$certification$numeric_level(),
        integer(1)
      )
      downloads <- vapply(recipes, function(r) r$downloads, integer(1))
      ordered <- recipes[order(cert_levels, downloads, decreasing = TRUE)]
      if (!is.null(n)) {
        ordered <- ordered[seq_len(min(n, length(ordered)))]
      }
      ordered
    },

    #' @description Get a single recipe by id
    #' @param recipe_id Recipe id
    #' @return Recipe object or NULL
    get = function(recipe_id) {
      id <- as.character(recipe_id)
      private$.recipes[[id]]
    },

    #' @description List all registered recipes
    #' @return List of all Recipe objects
    list_all = function() {
      private$.recipes
    },

    #' @description Save the registry catalog to a JSON file
    #' @param path Character file path
    save = function(path) {
      recipes_data <- lapply(private$.recipes, function(r) {
        list(
          name = r$name,
          user = r$user,
          survey_type = r$survey_type,
          edition = r$edition,
          description = r$description,
          topic = r$topic,
          doi = r$doi,
          id = r$id,
          version = r$version,
          downloads = r$downloads,
          categories = lapply(r$categories, function(c) c$to_list()),
          certification = r$certification$to_list(),
          user_info = if (!is.null(r$user_info)) {
            r$user_info$to_list()
          } else {
            NULL
          },
          steps = r$steps
        )
      })
      jsonlite::write_json(
        recipes_data, path,
        auto_unbox = TRUE, pretty = TRUE
      )
    },

    #' @description Load a registry catalog from a JSON file
    #' @param path Character file path
    load = function(path) {
      json_data <- jsonlite::read_json(path)
      private$.recipes <- list()
      for (item in json_data) {
        # Reconstruct categories
        categories <- list()
        if (!is.null(item$categories)) {
          categories <- lapply(item$categories, RecipeCategory$from_list)
        }
        # Reconstruct certification
        certification <- NULL
        if (!is.null(item$certification)) {
          certification <- tryCatch(
            RecipeCertification$from_list(item$certification),
            error = function(e) NULL
          )
        }
        # Reconstruct user_info
        user_info <- NULL
        if (!is.null(item$user_info)) {
          user_info <- tryCatch(
            RecipeUser$from_list(item$user_info),
            error = function(e) NULL
          )
        }
        steps <- tryCatch(
          decode_step(item$steps),
          error = function(e) as.list(item$steps %||% list())
        )
        recipe <- Recipe$new(
          name = item$name %||% "Unnamed",
          user = item$user %||% "Unknown",
          edition = item$edition %||% "Unknown",
          survey_type = item$survey_type %||% "Unknown",
          default_engine = default_engine(),
          depends_on = item$depends_on %||% list(),
          description = item$description %||% "",
          steps = steps,
          id = item$id %||% generate_id("r"),
          doi = item$doi,
          topic = item$topic,
          categories = categories,
          downloads = as.integer(item$downloads %||% 0),
          certification = certification,
          user_info = user_info,
          version = item$version %||% "1.0.0"
        )
        self$register(recipe)
      }
    },

    #' @description List recipes by author user name
    #' @param user_name Character user name
    #' @return List of matching Recipe objects
    list_by_user = function(user_name) {
      Filter(function(r) r$user == user_name, private$.recipes)
    },

    #' @description List recipes by institution (including members)
    #' @param institution_name Character institution name
    #' @return List of matching Recipe objects
    list_by_institution = function(institution_name) {
      Filter(function(r) {
        if (is.null(r$user_info)) {
          return(FALSE)
        }
        is_institution <- r$user_info$user_type == "institution" &&
          r$user_info$name == institution_name
        if (is_institution) {
          return(TRUE)
        }
        is_member <- r$user_info$user_type == "institutional_member" &&
          !is.null(r$user_info$institution) &&
          r$user_info$institution$name == institution_name
        if (is_member) {
          return(TRUE)
        }
        FALSE
      }, private$.recipes)
    },

    #' @description Get registry statistics
    #' @return List with total, by_category, by_certification counts
    stats = function() {
      recipes <- private$.recipes
      total <- length(recipes)

      # Count by category
      by_category <- list()
      for (r in recipes) {
        for (cat in r$categories) {
          nm <- cat$name
          by_category[[nm]] <- (by_category[[nm]] %||% 0L) + 1L
        }
      }

      # Count by certification
      by_certification <- list()
      for (r in recipes) {
        lvl <- r$certification$level
        by_certification[[lvl]] <- (by_certification[[lvl]] %||% 0L) + 1L
      }

      list(
        total = total,
        by_category = by_category,
        by_certification = by_certification
      )
    },

    #' @description Print registry summary
    #' @param ... Additional arguments (not used)
    print = function(...) {
      s <- self$stats()
      cat(
        cli::style_bold("RecipeRegistry"),
        paste0("(", s$total, " recipes)\n")
      )
      if (length(s$by_category) > 0) {
        cat(
          "  Categories:",
          paste(names(s$by_category), collapse = ", "),
          "\n"
        )
      }
      if (length(s$by_certification) > 0) {
        cat("  Certification:", paste(
          vapply(
            names(s$by_certification),
            function(k) {
              paste0(k, ": ", s$by_certification[[k]])
            },
            character(1)
          ),
          collapse = ", "
        ), "\n")
      }
      invisible(self)
    }
  ),
  private = list(
    .recipes = list()
  )
)
