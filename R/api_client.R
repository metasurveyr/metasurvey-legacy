#' @title API Client for metasurvey
#' @description HTTP client for the metasurvey REST API (plumber).
#'
#' The metasurvey API is a server deployed separately (Docker, Cloud Run, etc.).
#' Users of the R package interact with it through these client functions.
#'
#' @section Setup:
#' \preformatted{
#' # 1. Point to the deployed API
#' configure_api(url = "https://metasurvey-api.example.com")
#'
#' # 2. Register or login
#' api_register("Ana Garcia", "ana@example.com", "password123")
#' api_login("ana@example.com", "password123")
#'
#' # 3. Use the API
#' api_list_recipes(survey_type = "ech")
#' api_publish_recipe(my_recipe)
#' }
#' @name api_client
#' @keywords internal
NULL

# ── Internal option getters ──────────────────────────────────────────────────

api_url <- function() {
  url <- getOption("metasurvey.api_url", default = NULL)
  if (is.null(url)) {
    env <- Sys.getenv("METASURVEY_API_URL", "")
    if (nzchar(env)) {
      url <- sub("/$", "", env)
      options(metasurvey.api_url = url)
    }
  }
  url
}

api_token <- function() {
  token <- getOption("metasurvey.api_token", default = NULL)
  if (is.null(token)) {
    env <- Sys.getenv("METASURVEY_TOKEN", "")
    if (nzchar(env)) {
      token <- env
      options(metasurvey.api_token = token)
    }
  }
  token
}

#' @keywords internal
store_token <- function(token) {
  options(metasurvey.api_token = token)
  invisible(token)
}

#' @keywords internal
token_expires_soon <- function(token, margin_secs = 300) {
  if (is.null(token)) {
    return(TRUE)
  }
  tryCatch(
    {
      parts <- strsplit(token, "\\.")[[1]]
      if (length(parts) < 2) {
        return(TRUE)
      }
      payload <- jsonlite::fromJSON(
        rawToChar(jsonlite::base64url_dec(parts[2]))
      )
      exp <- as.numeric(payload$exp)
      if (is.na(exp)) {
        return(TRUE)
      }
      (exp - as.numeric(Sys.time())) < margin_secs
    },
    error = function(e) TRUE
  )
}

# ── Configuration ────────────────────────────────────────────────────────────

#' @title Configure metasurvey API
#' @description Set API base URL and optionally load stored credentials.
#'   The URL can also be set via the
#'   \code{METASURVEY_API_URL} environment variable, and
#'   the token via \code{METASURVEY_TOKEN}.
#' @param url API base URL
#'   (e.g., \code{"https://metasurvey-api.example.com"})
#' @return Invisibly, the previous URL (for restoring).
#' @export
#' @examples
#' \donttest{
#' configure_api(url = "https://metasurvey-api.example.com")
#' }
#' @family api-auth
configure_api <- function(url) {
  # Remove trailing slash
  url <- sub("/$", "", url)
  old <- getOption("metasurvey.api_url")
  options(metasurvey.api_url = url)
  metasurvey_msg("API configured: ", url)
  invisible(old)
}

# ── Internal HTTP helper ─────────────────────────────────────────────────────

#' @keywords internal
api_request <- function(endpoint, method = "GET",
                        body = NULL, params = NULL) {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("Package 'httr2' is required for API operations. ",
      "Install it with: install.packages('httr2')",
      call. = FALSE
    )
  }

  base_url <- api_url()

  if (is.null(base_url)) {
    stop(
      "API not configured. Use configure_api() first:\n",
      "  configure_api(url = 'https://metasurvey-api.example.com')",
      call. = FALSE
    )
  }

  url <- paste0(base_url, "/", endpoint)

  # Query parameters
  if (!is.null(params)) {
    params <- params[!vapply(params, is.null, logical(1))]
    if (length(params) > 0) {
      query_string <- paste(
        names(params),
        vapply(params, function(v) {
          utils::URLencode(as.character(v), reserved = TRUE)
        }, character(1)),
        sep = "=",
        collapse = "&"
      )
      url <- paste0(url, "?", query_string)
    }
  }

  # Headers — auto-refresh token if close to expiry
  headers <- c("Content-Type" = "application/json")
  token <- api_token()
  if (!is.null(token) && token_expires_soon(token) && endpoint != "auth/refresh") {
    tryCatch(
      {
        refreshed <- api_refresh_token()
        if (!is.null(refreshed)) token <- refreshed
      },
      error = function(e) NULL
    )
  }
  if (!is.null(token)) {
    headers <- c(headers, "Authorization" = paste("Bearer", token))
  }

  # Build request
  req <- httr2::request(url)
  req <- httr2::req_user_agent(req, metasurvey_user_agent())
  req <- httr2::req_headers(req, !!!as.list(headers))
  req <- httr2::req_timeout(req, 15)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)

  # Dispatch
  resp <- switch(method,
    GET = httr2::req_perform(req),
    POST = ,
    PUT = {
      req <- httr2::req_method(req, method)
      if (!is.null(body)) {
        req <- httr2::req_body_raw(
          req,
          jsonlite::toJSON(body, auto_unbox = TRUE, null = "null"),
          type = "application/json"
        )
      }
      httr2::req_perform(req)
    },
    DELETE = {
      req <- httr2::req_method(req, "DELETE")
      httr2::req_perform(req)
    },
    stop("Unsupported HTTP method: ", method, call. = FALSE)
  )

  # Parse
  txt <- httr2::resp_body_string(resp)

  if (httr2::resp_status(resp) >= 400) {
    parsed <- tryCatch(
      jsonlite::fromJSON(txt, simplifyVector = FALSE),
      error = function(e) NULL
    )
    msg <- if (!is.null(parsed$error) && is.character(parsed$error)) {
      substr(parsed$error, 1, 200)
    } else {
      paste("HTTP", httr2::resp_status(resp))
    }
    stop(
      "API error (", httr2::resp_status(resp), "): ",
      msg,
      call. = FALSE
    )
  }

  jsonlite::fromJSON(txt, simplifyVector = FALSE)
}

# ══════════════════════════════════════════════════════════════════════════════
# AUTH — POST /auth/register, POST /auth/login, GET /auth/me
# ══════════════════════════════════════════════════════════════════════════════

#' @title Register a new user
#' @description Create an account on the metasurvey API. On success the JWT
#'   token is stored automatically via \code{options(metasurvey.api_token)}.
#' @param name Display name
#' @param email Email address
#' @param password Password
#' @param user_type One of \code{"individual"},
#'   \code{"institutional_member"}, \code{"institution"}
#' @param institution Institution name
#'   (required for \code{"institutional_member"})
#' @return Invisibly, the API response (list with \code{ok},
#'   \code{token}, \code{user}).
#' @export
#' @examples
#' \dontrun{
#' configure_api("https://metasurvey-api.example.com")
#' api_register("Ana Garcia", "ana@example.com", "s3cret")
#' }
#' @family api-auth
api_register <- function(name, email, password,
                         user_type = "individual", institution = NULL) {
  if (!is.character(password) || nchar(password) < 8 || nchar(password) > 128) {
    stop(
      "Password must be between 8 and 128 characters.",
      call. = FALSE
    )
  }
  body <- list(
    name = name, email = email, password = password,
    user_type = user_type
  )
  if (!is.null(institution)) body$institution <- institution

  result <- api_request("auth/register", method = "POST", body = body)

  if (!is.null(result$token)) {
    store_token(result$token)
    metasurvey_msg("Registered and logged in as: ", email)
  }
  invisible(result)
}

#' @title Login
#' @description Authenticate with the metasurvey API. On success the JWT
#'   token is stored automatically.
#' @param email Email address
#' @param password Password
#' @return Invisibly, the API response.
#' @export
#' @examples
#' \dontrun{
#' api_login("ana@example.com", "s3cret")
#' }
#' @family api-auth
api_login <- function(email, password) {
  result <- api_request("auth/login",
    method = "POST",
    body = list(email = email, password = password)
  )

  if (!is.null(result$token)) {
    store_token(result$token)
    metasurvey_msg("Logged in as: ", email)
  }
  invisible(result)
}

#' @title Get current user profile
#' @description Returns profile info for the currently authenticated user.
#' @return List with user fields (name, email, user_type, etc.)
#' @export
#' @examples
#' \dontrun{
#' api_me()
#' }
#' @family api-auth
api_me <- function() {
  api_request("auth/me", method = "GET")
}

#' @title Refresh JWT token
#' @description Request a new JWT token using the current (still valid) token.
#'   The new token is stored automatically. This is called internally by
#'   \code{api_request()} when the current token is close to expiry (within 5
#'   minutes).
#' @return The new token string (invisibly), or NULL if refresh fails.
#' @export
#' @examples
#' \dontrun{
#' api_refresh_token()
#' }
#' @family api-auth
api_refresh_token <- function() {
  result <- tryCatch(
    api_request("auth/refresh", method = "POST"),
    error = function(e) NULL
  )
  if (!is.null(result) && !is.null(result$token)) {
    store_token(result$token)
    metasurvey_msg("Token refreshed successfully.")
    return(invisible(result$token))
  }
  invisible(NULL)
}

#' @title Logout
#' @description Clear the stored API token from memory and the environment.
#' @return Invisibly, NULL.
#' @export
#' @examples
#' \donttest{
#' api_logout()
#' }
#' @family api-auth
api_logout <- function() {
  options(metasurvey.api_token = NULL)
  metasurvey_msg("Logged out.")
  invisible(NULL)
}

# ── ID validation ──────────────────────────────────────────────────────────

#' @keywords internal
validate_api_id <- function(id) {
  if (!is.character(id) || length(id) != 1L || !grepl("^[a-zA-Z0-9_.-]+$", id)) {
    stop(
      "Invalid API ID: must be a single ",
      "alphanumeric string (a-z, 0-9, _, ., -)",
      call. = FALSE
    )
  }
  invisible(id)
}

# ════════════════════════════════════════════════════════════════
# RECIPES — GET /recipes, GET /recipes/:id,
#   POST /recipes, POST /recipes/:id/download
# ════════════════════════════════════════════════════════════════

#' @title List recipes from API
#' @description Fetch recipes with optional search and filters.
#' @param search Text search (matches name/description)
#' @param survey_type Filter by survey type (e.g., \code{"ech"})
#' @param topic Filter by topic
#' @param certification Filter by certification level
#' @param user Filter by author email
#' @param limit Maximum results (default 50)
#' @param offset Skip first N results (default 0)
#' @return List of Recipe objects
#' @export
#' @examples
#' \dontrun{
#' configure_api("https://metasurvey-api.example.com")
#' recipes <- api_list_recipes(survey_type = "ech")
#' }
#' @family api-recipes
api_list_recipes <- function(search = NULL, survey_type = NULL, topic = NULL,
                             certification = NULL, user = NULL,
                             limit = 50, offset = 0) {
  params <- list(
    search = search, survey_type = survey_type, topic = topic,
    certification = certification, user = user,
    limit = limit, offset = offset
  )

  result <- api_request("recipes", method = "GET", params = params)

  lapply(result$recipes %||% list(), function(doc) {
    tryCatch(parse_recipe_from_json(doc), error = function(e) {
      warning("Failed to parse recipe: ", e$message, call. = FALSE)
      NULL
    })
  }) |> Filter(f = Negate(is.null))
}

#' @title Get recipe(s) by ID
#' @description Retrieve one or more recipes from the API by their IDs.
#' @param id Character vector of recipe ID(s). If length > 1, returns a list.
#' @return A single Recipe object (or NULL) when \code{length(id) == 1}.
#'   A list of Recipe objects when \code{length(id) > 1} (NULLs are dropped).
#' @export
#' @examples
#' \dontrun{
#' api_get_recipe("r_1739654400_742")
#' }
#' @family api-recipes
api_get_recipe <- function(id) {
  fetch_one <- function(single_id) {
    validate_api_id(single_id)
    result <- tryCatch(
      api_request(paste0("recipes/", single_id), method = "GET"),
      error = function(e) {
        if (grepl("404", e$message)) {
          return(NULL)
        }
        stop(e)
      }
    )
    if (is.null(result) || is.null(result$recipe)) {
      return(NULL)
    }
    tryCatch(parse_recipe_from_json(result$recipe), error = function(e) {
      warning(
        "Failed to parse recipe '", single_id,
        "': ", e$message,
        call. = FALSE
      )
      NULL
    })
  }

  if (length(id) == 1L) {
    return(fetch_one(id))
  }

  results <- lapply(id, fetch_one)
  Filter(Negate(is.null), results)
}

#' @title Publish a recipe
#' @description Publish a Recipe object to the API.
#'   Requires authentication (call \code{api_login()}
#'   first).
#' @param recipe A Recipe object
#' @return Invisibly, the API response with the assigned ID.
#' @export
#' @examples
#' \dontrun{
#' api_publish_recipe(my_recipe)
#' }
#' @family api-recipes
api_publish_recipe <- function(recipe) {
  if (!inherits(recipe, "Recipe")) {
    stop("recipe must be a Recipe object", call. = FALSE)
  }
  result <- api_request(
    "recipes",
    method = "POST", body = recipe$to_list()
  )
  if (isTRUE(result$ok)) {
    metasurvey_msg("Recipe published: ", result$id)
  }
  invisible(result)
}

#' @title Increment recipe download counter
#' @param id Recipe ID
#' @keywords internal
api_download_recipe <- function(id) {
  validate_api_id(id)
  tryCatch(
    api_request(
      paste0("recipes/", id, "/download"),
      method = "POST"
    ),
    error = function(e) {
      warning(
        "Failed to track recipe download for '",
        id, "': ", e$message,
        call. = FALSE
      )
      invisible(NULL)
    }
  )
}

# ════════════════════════════════════════════════════════════════
# WORKFLOWS — GET /workflows, GET /workflows/:id,
#   POST /workflows, POST /workflows/:id/download
# ════════════════════════════════════════════════════════════════

#' @title List workflows from API
#' @description Fetch workflows with optional search and filters.
#' @param search Text search
#' @param survey_type Filter by survey type
#' @param recipe_id Filter workflows that reference this recipe
#' @param user Filter by author email
#' @param limit Maximum results
#' @param offset Skip first N results
#' @return List of RecipeWorkflow objects
#' @export
#' @examples
#' \dontrun{
#' api_list_workflows(survey_type = "ech")
#' }
#' @family api-workflows
api_list_workflows <- function(search = NULL, survey_type = NULL,
                               recipe_id = NULL, user = NULL,
                               limit = 50, offset = 0) {
  params <- list(
    search = search, survey_type = survey_type,
    recipe_id = recipe_id, user = user,
    limit = limit, offset = offset
  )

  result <- api_request("workflows", method = "GET", params = params)

  lapply(result$workflows %||% list(), function(doc) {
    tryCatch(workflow_from_list(doc), error = function(e) {
      warning("Failed to parse workflow: ", e$message, call. = FALSE)
      NULL
    })
  }) |> Filter(f = Negate(is.null))
}

#' @title Get a single workflow by ID
#' @description Retrieve a workflow from the API by its ID.
#' @param id Workflow ID
#' @return RecipeWorkflow object or NULL
#' @export
#' @examples
#' \dontrun{
#' api_get_workflow("w_1739654400_123")
#' }
#' @family api-workflows
api_get_workflow <- function(id) {
  validate_api_id(id)
  result <- tryCatch(
    api_request(paste0("workflows/", id), method = "GET"),
    error = function(e) {
      if (grepl("404", e$message)) {
        return(NULL)
      }
      stop(e)
    }
  )

  if (is.null(result) || is.null(result$workflow)) {
    return(NULL)
  }

  tryCatch(workflow_from_list(result$workflow), error = function(e) {
    warning("Failed to parse workflow: ", e$message, call. = FALSE)
    NULL
  })
}

#' @title Publish a workflow
#' @description Publish a RecipeWorkflow object to the API.
#'   Requires authentication.
#' @param workflow A RecipeWorkflow object
#' @return Invisibly, the API response.
#' @export
#' @examples
#' \dontrun{
#' api_publish_workflow(my_workflow)
#' }
#' @family api-workflows
api_publish_workflow <- function(workflow) {
  if (!inherits(workflow, "RecipeWorkflow")) {
    stop("workflow must be a RecipeWorkflow object", call. = FALSE)
  }
  result <- api_request(
    "workflows",
    method = "POST",
    body = workflow$to_list()
  )
  if (isTRUE(result$ok)) {
    metasurvey_msg("Workflow published: ", result$id)
  }
  invisible(result)
}

#' @title Increment workflow download counter
#' @param id Workflow ID
#' @keywords internal
api_download_workflow <- function(id) {
  validate_api_id(id)
  tryCatch(
    api_request(
      paste0("workflows/", id, "/download"),
      method = "POST"
    ),
    error = function(e) {
      warning(
        "Failed to track workflow download for '",
        id, "': ", e$message,
        call. = FALSE
      )
      invisible(NULL)
    }
  )
}

#' @title Increment download counter (generic)
#' @param type \code{"recipe"} or \code{"workflow"}
#' @param id Object ID
#' @keywords internal
api_track_download <- function(type, id) {
  if (type == "recipe") {
    api_download_recipe(id)
  } else if (type == "workflow") {
    api_download_workflow(id)
  } else {
    warning("Unknown type: ", type, call. = FALSE)
  }
}

# ── Recipe JSON parser ───────────────────────────────────────────────────────

#' @keywords internal
parse_recipe_from_json <- function(doc) {
  # Reconstruct cached_doc from doc field
  cached_doc <- NULL
  if (!is.null(doc$doc)) {
    pipeline <- list()
    raw_pipeline <- doc$doc$pipeline
    if (!is.null(raw_pipeline) && is.list(raw_pipeline)) {
      pipeline <- raw_pipeline
    }
    cached_doc <- list(
      input_variables = as.character(unlist(doc$doc$input_variables)),
      output_variables = as.character(unlist(doc$doc$output_variables)),
      pipeline = pipeline
    )
  }

  # Reconstruct categories
  categories <- list()
  if (!is.null(doc$categories) && length(doc$categories) > 0) {
    categories <- lapply(doc$categories, function(cat_data) {
      tryCatch(RecipeCategory$from_list(cat_data), error = function(e) NULL)
    })
    categories <- Filter(Negate(is.null), categories)
  }

  # Reconstruct certification
  certification <- NULL
  if (!is.null(doc$certification)) {
    certification <- tryCatch(
      RecipeCertification$from_list(doc$certification),
      error = function(e) NULL
    )
  }

  # Reconstruct user_info
  user_info <- NULL
  if (!is.null(doc$user_info)) {
    user_info <- tryCatch(
      RecipeUser$from_list(doc$user_info),
      error = function(e) NULL
    )
  }

  Recipe$new(
    name = doc$name %||% "Unnamed",
    user = doc$user %||% "Unknown",
    edition = doc$edition %||% "Unknown",
    survey_type = doc$survey_type %||% "Unknown",
    default_engine = "data.table",
    depends_on = doc$depends_on %||% list(),
    description = doc$description %||% "",
    steps = doc$steps %||% list(),
    id = doc$id %||% doc[["_id"]],
    doi = doc$doi,
    topic = doc$topic,
    cached_doc = cached_doc,
    categories = categories,
    downloads = as.integer(doc$downloads %||% 0),
    certification = certification,
    user_info = user_info,
    version = doc$version %||% "1.0.0",
    depends_on_recipes = doc$depends_on_recipes %||% list(),
    data_source = doc$data_source
  )
}

# ══════════════════════════════════════════════════════════════════════════════
# ANDA Variable Metadata
# ══════════════════════════════════════════════════════════════════════════════

#' Get ANDA variable metadata from the API
#'
#' @param survey_type Character survey type (default "ech")
#' @param var_names Character vector of variable names. If NULL, returns all.
#' @return A list of variable metadata objects
#' @export
#' @examples
#' \dontrun{
#' api_get_anda_variables("ech", c("pobpcoac", "e27"))
#' }
#' @family anda
api_get_anda_variables <- function(survey_type = "ech", var_names = NULL) {
  params <- list(survey_type = survey_type)
  if (!is.null(var_names) && length(var_names) > 0) {
    params$names <- paste(tolower(var_names), collapse = ",")
  }

  tryCatch(
    {
      resp <- api_request("anda/variables", method = "GET", params = params)
      resp$variables %||% list()
    },
    error = function(e) {
      list()
    }
  )
}

# ══════════════════════════════════════════════════════════════════════════════
# STARS — PUT /recipes/:id/star, GET /recipes/:id/stars, etc.
# ══════════════════════════════════════════════════════════════════════════════

#' @title Rate a recipe
#' @description Give a star rating (1-5) to a recipe. Requires authentication.
#'   Each user can have one rating per recipe (upserts on subsequent calls).
#' @param id Recipe ID
#' @param value Integer rating from 1 to 5
#' @return Invisibly, the API response.
#' @export
#' @examples
#' \dontrun{
#' api_star_recipe("r_1739654400_742", 5)
#' }
#' @family api-stars
api_star_recipe <- function(id, value) {
  validate_api_id(id)
  value <- as.integer(value)
  if (is.na(value) || value < 1L || value > 5L) {
    stop("value must be an integer between 1 and 5", call. = FALSE)
  }
  result <- api_request(
    paste0("recipes/", id, "/star"),
    method = "PUT",
    body = list(value = value)
  )
  invisible(result)
}

#' @title Get star summary for a recipe
#' @description Returns average rating, count, and the current user's rating
#'   (if authenticated).
#' @param id Recipe ID
#' @return List with \code{average}, \code{count}, and optionally
#'   \code{user_value}.
#' @export
#' @examples
#' \dontrun{
#' api_get_recipe_stars("r_1739654400_742")
#' }
#' @family api-stars
api_get_recipe_stars <- function(id) {
  validate_api_id(id)
  api_request(paste0("recipes/", id, "/stars"), method = "GET")
}

#' @title Rate a workflow
#' @description Give a star rating (1-5) to a workflow. Requires authentication.
#' @param id Workflow ID
#' @param value Integer rating from 1 to 5
#' @return Invisibly, the API response.
#' @export
#' @examples
#' \dontrun{
#' api_star_workflow("w_1739654400_123", 4)
#' }
#' @family api-stars
api_star_workflow <- function(id, value) {
  validate_api_id(id)
  value <- as.integer(value)
  if (is.na(value) || value < 1L || value > 5L) {
    stop("value must be an integer between 1 and 5", call. = FALSE)
  }
  result <- api_request(
    paste0("workflows/", id, "/star"),
    method = "PUT",
    body = list(value = value)
  )
  invisible(result)
}

#' @title Get star summary for a workflow
#' @description Returns average rating, count, and the current user's rating
#'   (if authenticated).
#' @param id Workflow ID
#' @return List with \code{average}, \code{count}, and optionally
#'   \code{user_value}.
#' @export
#' @examples
#' \dontrun{
#' api_get_workflow_stars("w_1739654400_123")
#' }
#' @family api-stars
api_get_workflow_stars <- function(id) {
  validate_api_id(id)
  api_request(paste0("workflows/", id, "/stars"), method = "GET")
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMENTS — POST /recipes/:id/comments, GET /recipes/:id/comments, etc.
# ══════════════════════════════════════════════════════════════════════════════

#' @title Add a comment to a recipe
#' @description Post a text comment on a recipe. Requires authentication.
#' @param id Recipe ID
#' @param text Comment text (max 2000 characters)
#' @return Invisibly, the API response.
#' @export
#' @examples
#' \dontrun{
#' api_comment_recipe("r_1739654400_742", "Great recipe!")
#' }
#' @family api-comments
api_comment_recipe <- function(id, text) {
  validate_api_id(id)
  if (!is.character(text) || nchar(text) < 1 || nchar(text) > 2000) {
    stop("text must be between 1 and 2000 characters", call. = FALSE)
  }
  result <- api_request(
    paste0("recipes/", id, "/comments"),
    method = "POST",
    body = list(text = text)
  )
  invisible(result)
}

#' @title Get comments for a recipe
#' @description List all comments on a recipe, sorted by creation date.
#' @param id Recipe ID
#' @return List of comment objects.
#' @export
#' @examples
#' \dontrun{
#' api_get_recipe_comments("r_1739654400_742")
#' }
#' @family api-comments
api_get_recipe_comments <- function(id) {
  validate_api_id(id)
  result <- api_request(
    paste0("recipes/", id, "/comments"),
    method = "GET"
  )
  result$comments %||% list()
}

#' @title Add a comment to a workflow
#' @description Post a text comment on a workflow. Requires authentication.
#' @param id Workflow ID
#' @param text Comment text (max 2000 characters)
#' @return Invisibly, the API response.
#' @export
#' @examples
#' \dontrun{
#' api_comment_workflow("w_1739654400_123", "Very useful workflow!")
#' }
#' @family api-comments
api_comment_workflow <- function(id, text) {
  validate_api_id(id)
  if (!is.character(text) || nchar(text) < 1 || nchar(text) > 2000) {
    stop("text must be between 1 and 2000 characters", call. = FALSE)
  }
  result <- api_request(
    paste0("workflows/", id, "/comments"),
    method = "POST",
    body = list(text = text)
  )
  invisible(result)
}

#' @title Get comments for a workflow
#' @description List all comments on a workflow, sorted by creation date.
#' @param id Workflow ID
#' @return List of comment objects.
#' @export
#' @examples
#' \dontrun{
#' api_get_workflow_comments("w_1739654400_123")
#' }
#' @family api-comments
api_get_workflow_comments <- function(id) {
  validate_api_id(id)
  result <- api_request(
    paste0("workflows/", id, "/comments"),
    method = "GET"
  )
  result$comments %||% list()
}

#' @title Delete a comment
#' @description Delete a comment by its ID. Only the comment author can delete
#'   it. Requires authentication.
#' @param comment_id Comment ID
#' @return Invisibly, the API response.
#' @export
#' @examples
#' \dontrun{
#' api_delete_comment("c_abc123")
#' }
#' @family api-comments
api_delete_comment <- function(comment_id) {
  validate_api_id(comment_id)
  result <- api_request(
    paste0("comments/", comment_id),
    method = "DELETE"
  )
  invisible(result)
}

# ══════════════════════════════════════════════════════════════════════════════
# DEPENDENTS (backlinks) — GET /recipes/:id/dependents
# ══════════════════════════════════════════════════════════════════════════════

#' @title Get recipes that depend on a recipe
#' @description Find all recipes whose \code{depends_on_recipes} field
#'   references the given recipe ID (backlinks).
#' @param id Recipe ID
#' @return List of recipe summaries (id, name, user).
#' @export
#' @examples
#' \dontrun{
#' api_get_recipe_dependents("r_1739654400_742")
#' }
#' @family api-recipes
api_get_recipe_dependents <- function(id) {
  validate_api_id(id)
  result <- api_request(
    paste0("recipes/", id, "/dependents"),
    method = "GET"
  )
  result$dependents %||% list()
}
