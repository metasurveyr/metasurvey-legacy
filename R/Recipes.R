#' Recipe R6 class
#'
#' R6 class representing a reproducible data transformation recipe for
#' surveys. It encapsulates metadata, declared dependencies, and a list of
#' transformation steps to be applied to a Survey object.
#'
#' @name Recipe-class
#' @aliases Recipe
#' @docType class
#' @format An R6 class generator (R6ClassGenerator)
#'
#' @field name Descriptive name of the recipe (character).
#' @field edition Target edition/period (character or Date).
#' @field survey_type Survey type (character), e.g., "ech", "eaii".
#' @field default_engine Default evaluation engine (character).
#' @field depends_on Vector/list of dependencies declared by the steps.
#' @field user Author/owner (character).
#' @field description Recipe description (character).
#' @field id Unique identifier (character/numeric).
#' @field steps List of step calls that make up the workflow.
#' @field doi DOI or external identifier (character|NULL).
#' @field bake Logical flag indicating whether it has been applied.
#' @field topic Recipe topic (character|NULL).
#' @field step_objects List of Step R6 objects (list|NULL),
#'   used for documentation generation.
#' @field categories List of RecipeCategory objects for classification.
#' @field downloads Integer download/usage count.
#' @field certification RecipeCertification object (default community).
#' @field user_info RecipeUser object or NULL.
#' @field version Recipe version string.
#' @field depends_on_recipes List of recipe IDs that must
#'   be applied before this one.
#' @field data_source List with S3 bucket info
#'   (s3_bucket, s3_prefix, file_pattern, provider)
#'   or NULL.
#' @field labels List with variable and value labels
#'   (var_labels, val_labels) or NULL.
#'
#' @section Methods:
#' \describe{
#'   \item{$new(name, edition, survey_type,
#'     default_engine, depends_on, user, description,
#'     steps, id, doi, topic)}{Class constructor.}
#'   \item{$doc()}{Auto-generate documentation from
#'     recipe steps. Returns a list with metadata,
#'     input_variables, output_variables, and pipeline
#'     information.}
#'   \item{$validate(svy)}{Validate that a survey
#'     object has all required input variables.}
#' }
#'
#' @return An object of class \code{Recipe}.
#'
#' @examples
#' # Use the recipe() constructor:
#' svy <- survey_empty(type = "ech", edition = "2023")
#' r <- recipe(
#'   name = "Example", user = "Test", svy = svy,
#'   description = "Example recipe"
#' )
#'
#' @seealso \code{\link{recipe}}, \code{\link{save_recipe}},
#'   \code{\link{read_recipe}}, \code{\link{bake_recipes}}
#' @keywords recipe
#' @family recipes
#' @export
Recipe <- R6Class("Recipe",
  public = list(
    name = NULL,
    edition = NULL,
    survey_type = NULL,
    default_engine = NULL,
    depends_on = list(),
    user = NULL,
    description = NULL,
    id = NULL,
    steps = list(),
    doi = NULL,
    bake = FALSE,
    topic = NULL,
    step_objects = NULL,
    categories = list(),
    downloads = 0L,
    certification = NULL,
    user_info = NULL,
    version = "1.0.0",
    depends_on_recipes = list(),
    data_source = NULL,
    labels = NULL,
    #' @description
    #' Create a Recipe object
    #' @param name Descriptive name of the recipe (character)
    #' @param edition Target edition/period (character or Date)
    #' @param survey_type Survey type (character), e.g., "ech", "eaii"
    #' @param default_engine Default evaluation engine (character)
    #' @param depends_on Vector or list of declared dependencies
    #' @param user Author or owner of the recipe (character)
    #' @param description Detailed description of the recipe (character)
    #' @param steps List of step calls that make up the workflow
    #' @param id Unique identifier (character or numeric)
    #' @param doi DOI or external identifier (character or NULL)
    #' @param topic Recipe topic (character or NULL)
    #' @param step_objects List of Step R6 objects
    #'   (optional, used for doc generation)
    #' @param cached_doc Pre-computed documentation
    #'   (optional, used when loading from JSON)
    #' @param categories List of RecipeCategory objects (optional)
    #' @param downloads Integer download count (default 0)
    #' @param certification RecipeCertification object
    #'   (optional, default community)
    #' @param user_info RecipeUser object (optional)
    #' @param version Recipe version string (default "1.0.0")
    #' @param depends_on_recipes List of recipe IDs
    #'   that must be applied before this one (optional)
    #' @param data_source List with S3 bucket info (optional)
    #' @param labels List with var_labels and val_labels (optional)
    initialize = function(name, edition, survey_type,
                          default_engine, depends_on,
                          user, description, steps, id,
                          doi = NULL, topic = NULL,
                          step_objects = NULL,
                          cached_doc = NULL,
                          categories = list(),
                          downloads = 0L,
                          certification = NULL,
                          user_info = NULL,
                          version = "1.0.0",
                          depends_on_recipes = list(),
                          data_source = NULL,
                          labels = NULL) {
      self$name <- name
      self$edition <- edition
      self$survey_type <- survey_type
      self$default_engine <- default_engine
      self$depends_on <- depends_on
      self$user <- user
      self$description <- description
      self$steps <- steps
      self$id <- id
      self$doi <- doi
      self$topic <- topic
      self$step_objects <- step_objects
      private$.cached_doc <- cached_doc
      self$categories <- categories
      self$downloads <- as.integer(downloads)
      self$certification <- certification %||%
        RecipeCertification$new(level = "community")
      self$user_info <- user_info
      self$version <- version
      self$depends_on_recipes <- depends_on_recipes
      self$data_source <- data_source
      self$labels <- labels
    },

    #' @description Increment the download counter
    increment_downloads = function() {
      self$downloads <- self$downloads + 1L
    },

    #' @description Certify the recipe at a given level
    #' @param user RecipeUser who is certifying
    #' @param level Character certification level ("reviewed" or "official")
    certify = function(user, level) {
      self$certification <- RecipeCertification$new(
        level = level, certified_by = user
      )
    },

    #' @description Add a category to the recipe
    #' @param category RecipeCategory to add
    add_category = function(category) {
      existing <- vapply(self$categories, function(c) c$name, character(1))
      if (!category$name %in% existing) {
        self$categories <- c(self$categories, list(category))
      }
    },

    #' @description Remove a category by name
    #' @param name Character category name to remove
    remove_category = function(name) {
      self$categories <- Filter(function(c) c$name != name, self$categories)
    },

    #' @description
    #' Serialize Recipe to a plain list suitable for JSON/API publishing.
    #' Steps are encoded as character strings via deparse().
    #' @return A named list with all recipe fields.
    to_list = function() {
      doc_info <- self$doc()
      list(
        name = self$name,
        user = self$user,
        survey_type = self$survey_type,
        edition = as.character(self$edition),
        description = self$description,
        topic = self$topic,
        doi = self$doi,
        id = self$id,
        version = self$version,
        downloads = self$downloads,
        depends_on = unique(unlist(self$depends_on)),
        depends_on_recipes = self$depends_on_recipes,
        data_source = self$data_source,
        categories = lapply(self$categories, function(c) c$to_list()),
        certification = self$certification$to_list(),
        user_info = if (!is.null(self$user_info)) {
          self$user_info$to_list()
        } else {
          NULL
        },
        doc = list(
          input_variables = doc_info$input_variables,
          output_variables = doc_info$output_variables,
          pipeline = doc_info$pipeline
        ),
        steps = unname(lapply(self$steps, function(s) {
          if (is.character(s)) {
            paste(s, collapse = " ")
          } else {
            paste(deparse(s), collapse = " ")
          }
        })),
        labels = self$labels,
        metasurvey_version = as.character(utils::packageVersion("metasurvey"))
      )
    },

    #' @description
    #' Auto-generate documentation from recipe steps
    #' @return A list with metadata, input_variables,
    #'   output_variables, and pipeline information
    doc = function() {
      cat_names <- vapply(self$categories, function(c) c$name, character(1))
      meta <- list(
        name = self$name,
        user = self$user,
        edition = self$edition,
        survey_type = self$survey_type,
        description = self$description,
        topic = self$topic,
        doi = self$doi,
        id = self$id,
        categories = if (length(cat_names) > 0) {
          paste(cat_names, collapse = ", ")
        } else {
          NULL
        },
        certification = self$certification$level,
        version = self$version,
        downloads = self$downloads
      )

      if (!is.null(self$step_objects) && length(self$step_objects) > 0) {
        all_outputs <- character(0)
        all_inputs <- character(0)
        pipeline <- list()

        for (i in seq_along(self$step_objects)) {
          step <- self$step_objects[[i]]

          step_outputs <- switch(step$type,
            "compute" = ,
            "ast_compute" = {
              var_names <- character(0)

              if (!is.null(names(step$exprs)) &&
                length(names(step$exprs)) > 0) {
                var_names <- setdiff(names(step$exprs), "")
              }

              if (length(var_names) == 0 && !is.null(step$new_var)) {
                var_names <- strsplit(step$new_var, ",\\s*")[[1]]
              }

              var_names
            },
            "recode" = step$new_var,
            "step_rename" = names(step$exprs),
            "step_remove" = character(0),
            "step_join" = character(0),
            character(0)
          )

          step_inputs <- unlist(step$depends_on)

          inferred_type <- switch(step$type,
            "recode" = "categorical",
            "compute" = ,
            "ast_compute" = "numeric",
            "step_rename" = "inherited",
            NA_character_
          )

          external_inputs <- setdiff(step_inputs, all_outputs)
          all_inputs <- union(all_inputs, external_inputs)
          all_outputs <- union(all_outputs, step_outputs)

          pipeline[[i]] <- list(
            index = i,
            type = step$type,
            outputs = step_outputs,
            inputs = step_inputs,
            inferred_type = inferred_type,
            comment = step$comment
          )
        }

        return(list(
          meta = meta,
          input_variables = all_inputs,
          output_variables = all_outputs,
          pipeline = pipeline
        ))
      }

      # If we have cached doc (loaded from JSON), return it with current meta
      if (!is.null(private$.cached_doc)) {
        return(list(
          meta = meta,
          input_variables =
            private$.cached_doc$input_variables %||%
              character(0),
          output_variables =
            private$.cached_doc$output_variables %||%
              character(0),
          pipeline = private$.cached_doc$pipeline %||% list()
        ))
      }

      list(
        meta = meta,
        input_variables = character(0),
        output_variables = character(0),
        pipeline = list()
      )
    },

    #' @description
    #' Validate that a survey has all required input variables
    #' @param svy A Survey object
    #' @return TRUE if valid, otherwise stops with
    #'   error listing missing variables
    validate = function(svy) {
      doc_info <- self$doc()
      required_vars <- doc_info$input_variables

      survey_vars <- names(get_data(svy))
      missing_vars <- required_vars[
        !tolower(required_vars) %in% tolower(survey_vars)
      ]

      if (length(missing_vars) > 0) {
        stop(
          sprintf(
            "Recipe '%s' requires variables not present in survey: %s",
            self$name,
            paste(missing_vars, collapse = ", ")
          ),
          call. = FALSE
        )
      }

      return(TRUE)
    }
  ),
  private = list(
    .cached_doc = NULL
  )
)

metadata_recipe <- function() {
  return(
    c(
      "name",
      "user",
      "svy",
      "description"
    )
  )
}

#' Create a survey data transformation recipe
#'
#' Creates a Recipe object that encapsulates a sequence of data transformations
#' that can be applied to surveys in a reproducible manner. Recipes allow
#' documenting, sharing, and reusing data processing workflows.
#'
#' @param ... Required metadata and optional steps. Required parameters:
#'   \itemize{
#'     \item \code{name}: Descriptive name for the recipe
#'     \item \code{user}: User/author creating the recipe
#'     \item \code{svy}: Base Survey object
#'       (use \code{survey_empty()} for generic recipes)
#'     \item \code{description}: Detailed description of the recipe's purpose
#'   }
#'   Optional parameters include data transformation steps.
#'
#' @return A \code{Recipe} object containing metadata, transformation steps,
#'   dependency information, and default engine configuration.
#'
#' @details
#' Recipes are essential for:
#' \itemize{
#'   \item Reproducibility: Ensure transformations are applied consistently
#'   \item Documentation: Keep a record of what
#'     transformations are performed and why
#'   \item Collaboration: Share workflows between users and teams
#'   \item Versioning: Maintain different processing
#'     versions for different editions
#'   \item Automation: Apply complex transformations automatically
#' }
#'
#' Steps included in the recipe can be any combination of
#' \code{step_compute}, \code{step_recode}, or other transformation steps.
#'
#' Recipes can be saved with \code{save_recipe()}, loaded with
#' \code{read_recipe()}, and applied automatically with \code{bake_recipes()}.
#'
#' @examples
#' # Basic recipe without steps
#' r <- recipe(
#'   name = "Basic ECH Indicators",
#'   user = "Analyst",
#'   svy = survey_empty(type = "ech", edition = "2023"),
#'   description = "Basic labor indicators for ECH 2023"
#' )
#' r
#'
#' \donttest{
#' # Recipe with steps using local data
#' dt <- data.table::data.table(
#'   id = 1:50, age = sample(18:65, 50, TRUE),
#'   income = runif(50, 1000, 5000), w = runif(50, 0.5, 2)
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "demo",
#'   psu = NULL, engine = "data.table",
#'   weight = add_weight(annual = "w")
#' )
#' svy <- svy |>
#'   step_compute(income_cat = ifelse(income > 3000, "high", "low")) |>
#'   step_recode(age_group, age < 30 ~ "young", .default = "adult")
#' r2 <- recipe(
#'   name = "Demo", user = "test", svy = svy,
#'   description = "Demo recipe", steps = get_steps(svy)
#' )
#' r2
#' }
#'
#' @seealso
#' \code{\link{Recipe}} for class definition
#' \code{\link{save_recipe}} to save recipes
#' \code{\link{read_recipe}} to load recipes
#' \code{\link{get_recipe}} to retrieve recipes from repository
#' \code{\link{bake_recipes}} to apply recipes to data
#'
#' @keywords recipe
#' @family recipes
#' @export

recipe <- function(...) {
  dots <- list(...)


  class_dots <- vapply(dots, function(x) class(x)[1], character(1))

  metadata_recipes_names <- metadata_recipe()

  check_args <- sum(metadata_recipes_names %in% names(dots))

  if (!(check_args == length(metadata_recipes_names))) {
    stop(
      paste0(
        "The recipe must have the following metadata: ",
        paste(metadata_recipe(), collapse = ", ")
      ),
      call. = FALSE
    )
  }

  index_steps <- which(names(dots) %in% metadata_recipe())

  if ("steps" %in% names(dots)) {
    new_recipe <- Recipe$new(
      id = dots$id %||% generate_id("r"),
      name = dots$name,
      user = dots$user,
      edition = dots$svy$edition,
      survey_type = dots$svy$type,
      default_engine = default_engine(),
      depends_on = list(),
      description = dots$description,
      steps = dots$steps_call,
      doi = dots$doi %||% NULL,
      topic = dots$topic,
      step_objects = dots$steps
    )

    # Only external inputs: doc() walks steps in order and excludes
    # variables produced by previous steps in the same recipe
    new_recipe$depends_on <- new_recipe$doc()$input_variables

    return(new_recipe)
  } else {
    return(
      Recipe$new(
        id = dots$id %||% generate_id("r"),
        name = dots$name,
        user = dots$user,
        edition = dots$svy$edition,
        survey_type = dots$svy$type,
        default_engine = default_engine(),
        depends_on = list(),
        description = dots$description,
        steps = dots[-index_steps],
        doi = dots$doi %||% NULL,
        topic = dots$topic
      )
    )
  }
}

#' Encoding and decoding recipes
#' @param recipe A Recipe object
#' @return A Recipe object
#' @keywords internal
#' @noRd

encoding_recipe <- function(recipe) {
  recipe$steps <- lapply(recipe$steps, function(step) {
    step_string <- deparse(step)
    return(step_string)
  })

  return(recipe)
}

#' Encoding and decoding recipes
#' @param recipe A Recipe object
#' @return A Recipe object
#' @keywords internal
#' @noRd

decode_step <- function(steps) {
  steps <- as.call(
    lapply(
      steps,
      function(step_string) as.call(parse(text = step_string))[[1]]
    )
  )

  return(
    steps
  )
}

#' @title Save Recipe
#' @description Saves a Recipe object to a file in JSON format.
#' @param recipe A Recipe object.
#' @param file A character string specifying the file path.
#' @return NULL.
#' @keywords utils
#' @details This function encodes the Recipe object
#'   and writes it to a JSON file.
#' @examples
#' r <- recipe(
#'   name = "Example", user = "Test",
#'   svy = survey_empty(type = "ech", edition = "2023"),
#'   description = "Example recipe"
#' )
#' f <- tempfile(fileext = ".json")
#' save_recipe(r, f)
#' @family recipes
#' @export

save_recipe <- function(recipe, file) {
  # Auto-generate documentation
  doc_info <- recipe$doc()

  recipe_data <- list(
    name = recipe$name,
    user = recipe$user,
    survey_type = recipe$survey_type,
    edition = recipe$edition,
    description = recipe$description,
    topic = recipe$topic,
    doi = recipe$doi,
    id = recipe$id,
    version = recipe$version,
    downloads = recipe$downloads,
    categories = lapply(recipe$categories, function(c) c$to_list()),
    certification = recipe$certification$to_list(),
    user_info = if (!is.null(recipe$user_info)) {
      recipe$user_info$to_list()
    } else {
      NULL
    },
    doc = list(
      input_variables = doc_info$input_variables,
      output_variables = doc_info$output_variables,
      pipeline = doc_info$pipeline
    ),
    steps = recipe$steps,
    labels = recipe$labels
  )

  recipe_data |>
    encoding_recipe() |>
    jsonlite::write_json(
      path = file, simplifyVector = TRUE,
      auto_unbox = TRUE, pretty = TRUE
    )

  metasurvey_msg(
    glue::glue("The recipe has been saved in {file}")
  )
}

#' recipe to json
#' @param recipe A Recipe object
#' @return A JSON object
#' @keywords internal

recipe_to_json <- function(recipe) {
  recipe <- list(
    name = recipe$name,
    user = recipe$user,
    survey_type = recipe$survey_type,
    edition = recipe$edition,
    description = recipe$description,
    steps = recipe$steps
  )

  recipe |>
    encoding_recipe() |>
    jsonlite::toJSON(simplifyVector = TRUE, raw = "mongo")
}

#' @title Read Recipe
#' @description Reads a Recipe object from a JSON file.
#' @param file A character string specifying the file path.
#' @return A Recipe object.
#' @details This function reads a JSON file and
#'   decodes it into a Recipe object.
#' @keywords utils
#' @examples
#' r <- recipe(
#'   name = "Example", user = "Test",
#'   svy = survey_empty(type = "ech", edition = "2023"),
#'   description = "Example recipe"
#' )
#' f <- tempfile(fileext = ".json")
#' save_recipe(r, f)
#' r2 <- read_recipe(f)
#' r2
#' @family recipes
#' @export

read_recipe <- function(file) {
  json_data <- jsonlite::read_json(file, simplifyVector = TRUE)

  steps <- tryCatch(
    decode_step(json_data$steps),
    error = function(e) {
      warning("Failed to parse recipe steps: ", e$message,
        ". Using raw strings as fallback.",
        call. = FALSE
      )
      as.list(json_data$steps)
    }
  )

  if ("name" %in% names(json_data)) {
    cached_doc <- NULL
    if (!is.null(json_data$doc)) {
      pipeline <- list()
      raw_pipeline <- json_data$doc$pipeline
      if (!is.null(raw_pipeline)) {
        if (is.data.frame(raw_pipeline)) {
          for (i in seq_len(nrow(raw_pipeline))) {
            row <- as.list(raw_pipeline[i, ])
            row$outputs <- as.character(unlist(row$outputs))
            row$inputs <- as.character(unlist(row$inputs))
            pipeline[[i]] <- row
          }
        } else if (is.list(raw_pipeline)) {
          pipeline <- raw_pipeline
        }
      }
      cached_doc <- list(
        input_variables = as.character(unlist(json_data$doc$input_variables)),
        output_variables = as.character(unlist(json_data$doc$output_variables)),
        pipeline = pipeline
      )
    }

    # Reconstruct categories
    categories <- list()
    if (!is.null(json_data$categories)) {
      raw_cats <- json_data$categories
      if (is.data.frame(raw_cats)) {
        for (i in seq_len(nrow(raw_cats))) {
          row <- as.list(raw_cats[i, ])
          # Handle empty data.frame parents from simplifyVector
          if (is.data.frame(row$parent) &&
            (nrow(row$parent) == 0 ||
              ncol(row$parent) == 0)) {
            row$parent <- NULL
          }
          categories[[i]] <- RecipeCategory$from_list(row)
        }
      } else if (is.list(raw_cats)) {
        categories <- lapply(raw_cats, RecipeCategory$from_list)
      }
    }

    # Reconstruct certification
    certification <- NULL
    if (!is.null(json_data$certification)) {
      certification <- tryCatch(
        RecipeCertification$from_list(json_data$certification),
        error = function(e) NULL
      )
    }

    # Reconstruct user_info
    user_info <- NULL
    if (!is.null(json_data$user_info)) {
      user_info <- tryCatch(
        RecipeUser$from_list(json_data$user_info),
        error = function(e) NULL
      )
    }

    Recipe$new(
      name = json_data$name %||% "Unnamed Recipe",
      user = json_data$user %||% "Unknown",
      edition = json_data$edition %||% json_data$svy_edition %||% "Unknown",
      survey_type = json_data$survey_type %||%
        json_data$svy_type %||% "Unknown",
      default_engine = default_engine(),
      depends_on = json_data$depends_on %||% list(),
      description = json_data$description %||% "",
      steps = steps,
      id = json_data$id %||% generate_id("r"),
      doi = json_data$doi %||% NULL,
      topic = json_data$topic %||% NULL,
      cached_doc = cached_doc,
      categories = categories,
      downloads = as.integer(json_data$downloads %||% 0),
      certification = certification,
      user_info = user_info,
      version = json_data$version %||% "1.0.0",
      labels = json_data$labels
    )
  } else {
    steps
  }
}

#' Get recipe from repository or API
#'
#' This function retrieves data transformation recipes from the metasurvey
#' repository or API, based on specific criteria such as survey type, edition,
#' and topic. It is the primary way to access predefined and community-validated
#' recipes.
#'
#' @param svy_type String specifying the survey type. Examples:
#'   "ech", "eaii", "eai", "eph"
#' @param svy_edition String specifying the survey edition.
#'   Supported formats: "YYYY", "YYYYMM", "YYYY-YYYY"
#' @param topic String specifying the recipe topic. Examples:
#'   "labor_market", "poverty", "income", "demographics"
#' @param allowMultiple Logical indicating whether
#'   multiple recipes are allowed.
#'   If FALSE and multiple matches exist, returns the most recent one
#'
#' @return `Recipe` object or list of `Recipe` objects according to the
#'   specified criteria and the value of \code{allowMultiple}
#'
#' @details
#' This function is essential for:
#' \itemize{
#'   \item Accessing official recipes: Get validated and maintained recipes
#'     by specialized teams
#'   \item Reproducibility: Ensure different users apply the same standard
#'     transformations
#'   \item Automation: Integrate recipes into automatic pipelines
#'   \item Collaboration: Share methodologies between teams and organizations
#'   \item Versioning: Access different recipe versions according to edition
#' }
#'
#' The function queries the metasurvey API to retrieve recipes. **Internet
#' connection is required**. If the API is unavailable or you need to work
#' offline:
#'
#' \strong{Working Offline:}
#' \itemize{
#'   \item Don't call \code{get_recipe()} - work directly with steps
#'   \item Set \code{options(metasurvey.skip_recipes = TRUE)}
#'     to disable API calls
#'   \item Load recipes from local files using \code{read_recipe()}
#'   \item Create custom recipes with \code{recipe()}
#' }
#'
#' Search criteria are combined with AND operator, so all specified criteria
#' must match for a recipe to be returned.
#'
#' @examples
#' \dontrun{
#' # Get specific recipe for ECH 2023
#' ech_recipe <- get_recipe(
#'   svy_type = "ech",
#'   svy_edition = "2023"
#' )
#'
#' # Recipe for specific topic
#' labor_recipe <- get_recipe(
#'   svy_type = "ech",
#'   svy_edition = "2023",
#'   topic = "labor_market"
#' )
#'
#' # Allow multiple recipes
#' available_recipes <- get_recipe(
#'   svy_type = "eaii",
#'   svy_edition = "2019-2021",
#'   allowMultiple = TRUE
#' )
#'
#' # Use recipe in load_survey
#' ech_with_recipe <- load_survey(
#'   path = "ech_2023.dta",
#'   svy_type = "ech",
#'   svy_edition = "2023",
#'   recipes = get_recipe("ech", "2023"),
#'   bake = TRUE
#' )
#'
#' # Working offline - don't use recipes
#' ech_offline <- load_survey(
#'   path = "ech_2023.dta",
#'   svy_type = "ech",
#'   svy_edition = "2023",
#'   svy_weight = add_weight(annual = "PESOANO")
#' )
#'
#' # Disable recipe API globally
#' options(metasurvey.skip_recipes = TRUE)
#' # Now get_recipe() will return NULL with a warning
#'
#' # For year ranges
#' panel_recipe <- get_recipe(
#'   svy_type = "ech_panel",
#'   svy_edition = "2020-2023"
#' )
#' }
#'
#' @seealso
#' \code{\link{recipe}} to create custom recipes
#' \code{\link{save_recipe}} to save recipes locally
#' \code{\link{read_recipe}} to read recipes from file
#' \code{\link{publish_recipe}} to publish recipes to the repository
#' \code{\link{load_survey}} where recipes are used
#'
#' @keywords utils
#' @family recipes
#' @export

get_recipe <- function(
    svy_type = NULL,
    svy_edition = NULL,
    topic = NULL,
    allowMultiple = TRUE) {
  # Check if recipes should be skipped (offline mode)
  if (isTRUE(getOption("metasurvey.skip_recipes", FALSE))) {
    warning(
      paste0(
        "Recipe API is disabled ",
        "(metasurvey.skip_recipes = TRUE). ",
        "Returning NULL."
      ),
      call. = FALSE
    )
    return(NULL)
  }

  tryCatch(
    {
      recipes <- api_list_recipes(
        survey_type = svy_type,
        search = topic
      )

      if (length(recipes) == 0) {
        metasurvey_msg("The API returned no recipes for the specified criteria")
        return(NULL)
      }

      metasurvey_msg(glue::glue("The API returned {length(recipes)} recipes"))

      if (!allowMultiple) {
        return(recipes[[1]])
      }

      recipes
    },
    error = function(e) {
      warning(
        "Failed to retrieve recipes from API: ", e$message, "\n",
        "  You can:\n",
        "    - Work without recipes by not calling get_recipe()\n",
        "    - Set options(metasurvey.skip_recipes",
        " = TRUE) to disable recipe API calls\n",
        "    - Check your internet connection and try again",
        call. = FALSE
      )
      return(NULL)
    }
  )
}

#' Convert a list of steps to a recipe
#' @param name A character string with the name of the recipe
#' @param user A character string with the user of the recipe
#' @param svy A Survey object
#' @param description A character string with the description of the recipe
#' @param steps A list with the steps of the recipe
#' @param doi A character string with the DOI of the recipe
#' @param topic A character string with the topic of the recipe
#' @keywords step
#' @keywords survey
#' @return A Recipe object
#' @keywords recipe
#' @examples
#' \donttest{
#' dt <- data.table::data.table(
#'   id = 1:20, age = sample(18:65, 20, TRUE),
#'   w = runif(20, 0.5, 2)
#' )
#' svy <- Survey$new(
#'   data = dt, edition = "2023", type = "demo",
#'   psu = NULL, engine = "data.table",
#'   weight = add_weight(annual = "w")
#' )
#' svy <- step_compute(svy, age2 = age^2)
#' my_recipe <- steps_to_recipe(
#'   name = "age_vars", user = "analyst",
#'   svy = svy, description = "Age-derived variables",
#'   steps = get_steps(svy)
#' )
#' my_recipe
#' }
#' @family recipes
#' @export

steps_to_recipe <- function(
    name,
    user,
    svy = survey_empty(type = "eaii", edition = "2019-2021"),
    description,
    steps, doi = NULL, topic = NULL) {
  return(
    recipe(
      name = name,
      user = user,
      svy = svy,
      description = description,
      steps = steps,
      steps_call = eval(lapply(
        steps,
        function(step) {
          paste(deparse(step$call, width.cutoff = 500L), collapse = " ")
        }
      )),
      doi = doi,
      topic = topic
    )
  )
}


# Legacy helpers kept for backward compatibility with external code
# that may call get_distinct_recipes() directly
get_distinct_recipes <- function(recipe) {
  tryCatch(
    length(unique(vapply(
      seq_along(recipe),
      function(x) recipe[[x]]$id, character(1)
    ))),
    error = function(e) 0
  )
}

#' @title Publish Recipe
#' @description
#' Publishes a Recipe object to the active backend
#'   (local JSON registry or remote API).
#' @param recipe A Recipe object.
#' @return The Recipe object (invisibly).
#' @examples
#' set_backend("local", path = tempfile(fileext = ".json"))
#' r <- recipe(
#'   name = "Example", user = "Test",
#'   svy = survey_empty(type = "ech", edition = "2023"),
#'   description = "Example recipe"
#' )
#' publish_recipe(r)
#' length(list_recipes())
#' @keywords utils
#' @family recipes
#' @export

publish_recipe <- function(recipe) {
  if (!inherits(recipe, "Recipe")) {
    stop("recipe must be a Recipe object", call. = FALSE)
  }
  get_backend()$publish(recipe)
  invisible(recipe)
}

#' Print method for Recipe objects
#'
#' Displays a formatted recipe card showing metadata, required variables,
#' pipeline steps, and produced variables.
#'
#' @param x A Recipe object
#' @param ... Additional arguments (currently unused)
#' @return Invisibly returns the Recipe object
#' @examples
#' rec <- Recipe$new(
#'   id = "r1", name = "Example", user = "tester",
#'   edition = "2023", survey_type = "test",
#'   default_engine = "data.table", depends_on = list(),
#'   description = "Demo recipe", steps = list()
#' )
#' print(rec)
#' @keywords recipe
#' @family recipes
#' @export
print.Recipe <- function(x, ...) {
  doc_info <- x$doc()

  # Header
  cat(cli::style_bold(cli::col_blue(paste0(
    "\n\u2500\u2500 Recipe: ", x$name, " \u2500\u2500\n"
  ))))

  # Metadata
  cat(cli::col_silver("Author:  "), x$user, "\n", sep = "")
  ed_str <- paste(as.character(unlist(x$edition)), collapse = ", ")
  cat(cli::col_silver("Survey:  "),
    x$survey_type, " / ", ed_str, "\n",
    sep = ""
  )
  cat(cli::col_silver("Version: "), x$version, "\n", sep = "")
  if (!is.null(x$topic)) {
    cat(cli::col_silver("Topic:   "), x$topic, "\n", sep = "")
  }
  if (!is.null(x$doi)) {
    cat(cli::col_silver("DOI:     "), x$doi, "\n", sep = "")
  }
  if (!is.null(x$description) && nzchar(x$description)) {
    cat(cli::col_silver("Description: "), x$description, "\n", sep = "")
  }
  # Certification badge
  cert_label <- switch(x$certification$level,
    "community" = cli::col_yellow("community"),
    "reviewed" = cli::col_cyan("reviewed"),
    "official" = cli::col_green("official"),
    x$certification$level
  )
  cat(cli::col_silver("Certification: "), cert_label, "\n", sep = "")
  # Downloads
  if (x$downloads > 0) {
    cat(cli::col_silver("Downloads: "), x$downloads, "\n", sep = "")
  }
  # Categories
  if (length(x$categories) > 0) {
    cat_names <- vapply(x$categories, function(c) c$name, character(1))
    cat(cli::col_silver("Categories: "),
      paste(cat_names, collapse = ", "), "\n",
      sep = ""
    )
  }

  # Input variables
  if (length(doc_info$input_variables) > 0) {
    cat(cli::style_bold(cli::col_blue(paste0(
      "\n\u2500\u2500 Requires (",
      length(doc_info$input_variables),
      " variables) \u2500\u2500\n"
    ))))
    cat("  ", paste(doc_info$input_variables, collapse = ", "), "\n", sep = "")
  }

  # Pipeline
  if (length(doc_info$pipeline) > 0) {
    cat(cli::style_bold(cli::col_blue(paste0(
      "\n\u2500\u2500 Pipeline (",
      length(doc_info$pipeline),
      " steps) \u2500\u2500\n"
    ))))
    for (step_info in doc_info$pipeline) {
      outputs_str <- if (length(step_info$outputs) > 0) {
        paste(step_info$outputs, collapse = ", ")
      } else {
        "(no output)"
      }

      comment_str <- ""
      if (!is.null(step_info$comment) && length(step_info$comment) == 1 &&
        nzchar(step_info$comment)) {
        comment_str <- paste0("  \"", step_info$comment, "\"")
      }

      step_type <- step_info$type %||% "unknown"
      cat(sprintf(
        "  %d. [%s] -> %s%s\n",
        step_info$index,
        step_type,
        outputs_str,
        comment_str
      ))
    }
  }

  # Output variables
  if (length(doc_info$output_variables) > 0) {
    cat(cli::style_bold(cli::col_blue(paste0(
      "\n\u2500\u2500 Produces (",
      length(doc_info$output_variables),
      " variables) \u2500\u2500\n"
    ))))

    output_details <- lapply(doc_info$pipeline, function(step) {
      if (length(step$outputs) > 0 && !is.null(step$inferred_type) &&
        !is.na(step$inferred_type)) {
        data.frame(
          var = step$outputs,
          type = step$inferred_type,
          stringsAsFactors = FALSE
        )
      } else {
        NULL
      }
    })
    output_details <- do.call(rbind, output_details)

    if (!is.null(output_details) && nrow(output_details) > 0) {
      vars_by_type <- split(output_details$var, output_details$type)
      output_parts <- lapply(names(vars_by_type), function(type) {
        vars <- vars_by_type[[type]]
        paste0(vars, " [", type, "]")
      })
      cat("  ", paste(unlist(output_parts), collapse = ", "), "\n", sep = "")
    } else {
      cat(
        "  ",
        paste(
          doc_info$output_variables,
          collapse = ", "
        ),
        "\n",
        sep = ""
      )
    }
  }

  if (length(doc_info$pipeline) == 0 && length(x$steps) > 0) {
    cat(cli::col_silver(paste0("\n  (", length(x$steps), " steps)\n")))
  }

  cat("\n")
  invisible(x)
}
