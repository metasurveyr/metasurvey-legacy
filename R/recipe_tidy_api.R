# Tidyverse-style functional API for the Recipe Ecosystem
# These are user-facing wrappers around the R6 classes,
# designed for pipe-friendly workflows.

# --- Constructors ---

#' Create a recipe user
#'
#' Creates a \code{\link{RecipeUser}} object with a simple
#' functional interface.
#'
#' @param name Character. User or institution name.
#' @param type Character. One of \code{"individual"} (default),
#'   \code{"institutional_member"}, or \code{"institution"}.
#' @param email Character or `NULL` (default `NULL`). Email address.
#' @param affiliation Character or `NULL` (default `NULL`). Organizational affiliation.
#' @param institution RecipeUser object or character institution name.
#'   Required for \code{"institutional_member"} type. If a string is provided,
#'   it creates an institution user with that name
#'   automatically.
#' @param url Character or `NULL` (default `NULL`). Institution URL.
#' @param verified Logical (default `FALSE`). Whether the account is verified.
#'
#' @return A \code{\link{RecipeUser}} object.
#'
#' @examples
#' # Individual user
#' user <- recipe_user("Juan Perez", email = "juan@example.com")
#'
#' # Institution
#' inst <- recipe_user(
#'   "Instituto de Economia",
#'   type = "institution", verified = TRUE
#' )
#'
#' # Member linked to institution
#' member <- recipe_user(
#'   "Maria",
#'   type = "institutional_member",
#'   institution = inst
#' )
#'
#' # Member with institution name shortcut
#' member2 <- recipe_user(
#'   "Pedro",
#'   type = "institutional_member",
#'   institution = "IECON"
#' )
#'
#' @seealso \code{\link{RecipeUser}},
#'   \code{\link{set_user_info}},
#'   \code{\link{certify_recipe}}
#' @family tidy-api
#' @export
recipe_user <- function(name, type = "individual", email = NULL,
                        affiliation = NULL, institution = NULL,
                        url = NULL, verified = FALSE) {
  if (is.character(institution)) {
    institution <- RecipeUser$new(
      name = institution, user_type = "institution"
    )
  }
  RecipeUser$new(
    name = name, user_type = type, email = email,
    affiliation = affiliation, institution = institution,
    url = url, verified = verified
  )
}

#' Create a recipe category
#'
#' Creates a \code{\link{RecipeCategory}} object for classifying recipes.
#'
#' @param name Character. Category identifier (e.g. \code{"labor_market"}).
#' @param description Character. Human-readable description.
#'   Defaults to empty.
#' @param parent RecipeCategory object or character parent
#'   category name (default `NULL`). If a string is provided,
#'   it creates a parent category with that name.
#'
#' @return A \code{\link{RecipeCategory}} object.
#'
#' @examples
#' cat <- recipe_category("labor_market", "Labor market indicators")
#'
#' # With parent hierarchy
#' sub <- recipe_category(
#'   "employment", "Employment stats",
#'   parent = "labor_market"
#' )
#'
#' @seealso \code{\link{RecipeCategory}}, \code{\link{add_category}},
#'   \code{\link{default_categories}}
#' @family tidy-api
#' @export
recipe_category <- function(name, description = "", parent = NULL) {
  if (is.character(parent)) {
    parent <- RecipeCategory$new(name = parent, description = "")
  }
  RecipeCategory$new(
    name = name, description = description,
    parent = parent
  )
}

#' Create a recipe certification
#'
#' Creates a \code{\link{RecipeCertification}} object. Typically you would use
#' \code{\link{certify_recipe}} to certify a recipe in a pipeline instead.
#'
#' @param level Character. One of \code{"community"}
#'   (default), \code{"reviewed"}, or
#'   \code{"official"}.
#' @param certified_by RecipeUser or `NULL` (default `NULL`). Required for
#'   reviewed/official.
#' @param notes Character or `NULL` (default `NULL`). Additional notes.
#'
#' @return A \code{\link{RecipeCertification}} object.
#'
#' @examples
#' # Default community certification
#' cert <- recipe_certification()
#'
#' # Official certification
#' inst <- recipe_user("IECON", type = "institution")
#' cert <- recipe_certification("official", certified_by = inst)
#'
#' @seealso \code{\link{RecipeCertification}}, \code{\link{certify_recipe}}
#' @family tidy-api
#' @export
recipe_certification <- function(level = "community",
                                 certified_by = NULL,
                                 notes = NULL) {
  RecipeCertification$new(
    level = level, certified_by = certified_by,
    notes = notes
  )
}

# --- Pipe-friendly recipe modifiers ---

#' Add a category to a recipe
#'
#' Pipe-friendly function to add a category to a Recipe object.
#' Accepts either a category name (string) or a
#' \code{\link{RecipeCategory}} object.
#'
#' @param recipe A Recipe object.
#' @param category Character category name or RecipeCategory object.
#' @param description Character. Description for the category (used when
#'   \code{category} is a string). Defaults to empty.
#'
#' @return The modified Recipe object (invisibly for piping).
#'
#' @examples
#' r <- recipe(
#'   name = "Example", user = "Test",
#'   svy = survey_empty(type = "ech", edition = "2023"),
#'   description = "Example recipe"
#' )
#' r <- r |>
#'   add_category("labor_market", "Labor market indicators") |>
#'   add_category("income")
#'
#' @seealso \code{\link{remove_category}}, \code{\link{recipe_category}},
#'   \code{\link{default_categories}}
#' @family tidy-api
#' @export
add_category <- function(recipe, category, description = "") {
  if (is.character(category)) {
    category <- RecipeCategory$new(
      name = category, description = description
    )
  }
  recipe$add_category(category)
  recipe
}

#' Remove a category from a recipe
#'
#' Pipe-friendly function to remove a category from a Recipe by name.
#'
#' @param recipe A Recipe object.
#' @param name Character. Category name to remove.
#'
#' @return The modified Recipe object.
#'
#' @examples
#' r <- recipe(
#'   name = "Example", user = "Test",
#'   svy = survey_empty(type = "ech", edition = "2023"),
#'   description = "Example recipe"
#' )
#' r <- r |>
#'   add_category("labor_market") |>
#'   remove_category("labor_market")
#'
#' @seealso \code{\link{add_category}}
#' @family tidy-api
#' @export
remove_category <- function(recipe, name) {
  recipe$remove_category(name)
  recipe
}

#' Certify a recipe
#'
#' Pipe-friendly function to certify a Recipe at a given quality level.
#'
#' @param recipe A Recipe object.
#' @param user RecipeUser who is certifying.
#' @param level Character. Certification level:
#'   \code{"reviewed"} or \code{"official"}.
#'
#' @return The modified Recipe object.
#'
#' @examples
#' r <- recipe(
#'   name = "Example", user = "Test",
#'   svy = survey_empty(type = "ech", edition = "2023"),
#'   description = "Example recipe"
#' )
#' inst <- recipe_user("IECON", type = "institution")
#' r <- r |> certify_recipe(inst, "official")
#'
#' @seealso \code{\link{recipe_certification}}, \code{\link{recipe_user}}
#' @family tidy-api
#' @export
certify_recipe <- function(recipe, user, level) {
  recipe$certify(user, level)
  recipe
}

#' Set user info on a recipe
#'
#' Pipe-friendly function to assign a \code{\link{RecipeUser}} to a Recipe.
#'
#' @param recipe A Recipe object.
#' @param user A RecipeUser object.
#'
#' @return The modified Recipe object.
#'
#' @examples
#' r <- recipe(
#'   name = "Example", user = "Test",
#'   svy = survey_empty(type = "ech", edition = "2023"),
#'   description = "Example recipe"
#' )
#' user <- recipe_user("Juan Perez", email = "juan@example.com")
#' r <- r |> set_user_info(user)
#'
#' @seealso \code{\link{recipe_user}}
#' @family tidy-api
#' @export
set_user_info <- function(recipe, user) {
  recipe$user_info <- user
  recipe
}

#' Set version on a recipe
#'
#' Pipe-friendly function to set the version string on a Recipe.
#'
#' @param recipe A Recipe object.
#' @param version Character version string (e.g. \code{"2.0.0"}).
#'
#' @return The modified Recipe object.
#'
#' @examples
#' r <- recipe(
#'   name = "Example", user = "Test",
#'   svy = survey_empty(type = "ech", edition = "2023"),
#'   description = "Example recipe"
#' )
#' r <- r |> set_version("2.0.0")
#'
#' @family tidy-api
#' @export
set_version <- function(recipe, version) {
  recipe$version <- version
  recipe
}

# --- Backend/registry wrappers ---

#' Search recipes
#'
#' Search for recipes by name or description in the active backend.
#'
#' @param query Character search string.
#'
#' @return List of matching Recipe objects.
#'
#' @examples
#' set_backend("local", path = tempfile(fileext = ".json"))
#' r <- recipe(
#'   name = "Labor Market", user = "Test",
#'   svy = survey_empty(type = "ech", edition = "2023"),
#'   description = "Labor market indicators"
#' )
#' publish_recipe(r)
#' results <- search_recipes("labor")
#' length(results)
#'
#' @seealso \code{\link{filter_recipes}}, \code{\link{rank_recipes}},
#'   \code{\link{set_backend}}
#' @family tidy-api
#' @export
search_recipes <- function(query) {
  get_backend()$search(query)
}

#' Rank recipes by downloads
#'
#' Get the top recipes ranked by download count from the active backend.
#'
#' @param n Integer. Maximum number of recipes to return, or NULL for all.
#'
#' @return List of Recipe objects sorted by downloads (descending).
#'
#' @examples
#' set_backend("local", path = tempfile(fileext = ".json"))
#' top10 <- rank_recipes(n = 10)
#'
#' @seealso \code{\link{search_recipes}}, \code{\link{filter_recipes}}
#' @family tidy-api
#' @export
rank_recipes <- function(n = NULL) {
  get_backend()$rank(n = n)
}

#' Filter recipes by criteria
#'
#' Filter recipes in the active backend by survey type, edition, category,
#' or certification level.
#'
#' @param survey_type Character survey type or NULL.
#' @param edition Character edition or NULL.
#' @param category Character category name or NULL.
#' @param certification_level Character certification level or NULL.
#' @param topic Character topic name or NULL.
#'
#' @return List of matching Recipe objects.
#'
#' @examples
#' set_backend("local", path = tempfile(fileext = ".json"))
#' ech_recipes <- filter_recipes(survey_type = "ech")
#' length(ech_recipes)
#'
#' @seealso \code{\link{search_recipes}}, \code{\link{rank_recipes}}
#' @family tidy-api
#' @export
filter_recipes <- function(survey_type = NULL, edition = NULL,
                           category = NULL, certification_level = NULL,
                           topic = NULL) {
  get_backend()$filter(
    survey_type = survey_type, edition = edition,
    category = category, certification_level = certification_level,
    topic = topic
  )
}

#' List all recipes
#'
#' List all recipes from the active backend.
#'
#' @return List of all Recipe objects.
#'
#' @examples
#' set_backend("local", path = tempfile(fileext = ".json"))
#' all <- list_recipes()
#' length(all)
#'
#' @seealso \code{\link{search_recipes}}, \code{\link{filter_recipes}}
#' @family tidy-api
#' @export
list_recipes <- function() {
  get_backend()$list_all()
}
