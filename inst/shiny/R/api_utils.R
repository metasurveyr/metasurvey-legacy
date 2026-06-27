# Plumber API utilities for Shiny app
# All network calls go through the deployed plumber API.
# Example recipes/workflows used as initial display
# while API loads (replaced once API responds).

# ── API base URL ──────────────────────────────────────

shiny_api_url <- function() {
  Sys.getenv(
    "METASURVEY_API_URL",
    "https://metasurvey-api-production.up.railway.app"
  )
}

# ── Internal HTTP helper ──────────────────────────────

shiny_api_request <- function(method,
                              endpoint,
                              body = NULL,
                              params = NULL,
                              token = NULL) {
  url <- paste0(shiny_api_url(), "/", endpoint)

  # Query parameters
  if (!is.null(params)) {
    params <- params[
      !vapply(params, is.null, logical(1))
    ]
    if (length(params) > 0) {
      qs <- paste(
        names(params),
        vapply(
          params,
          function(v) {
            utils::URLencode(
              as.character(v),
              reserved = TRUE
            )
          },
          character(1)
        ),
        sep = "=", collapse = "&"
      )
      url <- paste0(url, "?", qs)
    }
  }

  headers <- c("Content-Type" = "application/json")
  if (!is.null(token) && nzchar(token)) {
    headers <- c(
      headers,
      "Authorization" = paste("Bearer", token)
    )
  }

  req <- httr2::request(url)
  ua <- tryCatch(
    paste0("metasurvey/", utils::packageVersion("metasurvey")),
    error = function(e) "metasurvey/dev"
  )
  req <- httr2::req_user_agent(req, ua)
  req <- httr2::req_headers(req, !!!as.list(headers))
  req <- httr2::req_timeout(req, 15)
  req <- httr2::req_retry(req, max_tries = 3, backoff = ~2)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)

  resp <- tryCatch(
    {
      if (method == "GET") {
        httr2::req_perform(req)
      } else if (method == "DELETE") {
        req <- httr2::req_method(req, "DELETE")
        httr2::req_perform(req)
      } else {
        if (method != "POST") {
          req <- httr2::req_method(req, method)
        }
        if (!is.null(body)) {
          req <- httr2::req_body_raw(
            req,
            jsonlite::toJSON(
              body,
              auto_unbox = TRUE,
              null = "null"
            ),
            type = "application/json"
          )
        }
        httr2::req_perform(req)
      }
    },
    error = function(e) NULL
  )

  if (is.null(resp)) {
    return(list(ok = FALSE, error = "Connection failed"))
  }
  if (httr2::resp_status(resp) >= 400) {
    txt <- httr2::resp_body_string(resp)
    parsed <- tryCatch(
      jsonlite::fromJSON(
        txt,
        simplifyVector = FALSE
      ),
      error = function(e) list()
    )
    return(list(
      ok = FALSE,
      error = parsed$error %||% txt,
      status = httr2::resp_status(resp)
    ))
  }
  parsed <- jsonlite::fromJSON(
    httr2::resp_body_string(resp),
    simplifyVector = FALSE
  )
  parsed$ok <- TRUE
  parsed
}

# ── Auth ──────────────────────────────────────────────

hash_password <- function(password) {
  digest::digest(
    password,
    algo = "sha256", serialize = FALSE
  )
}

# In-memory user store for offline/demo mode
.local_users <- new.env(parent = emptyenv())
.local_users$data <- list()

shiny_register <- function(name,
                           email,
                           password,
                           user_type = "individual",
                           institution = NULL) {
  body <- list(
    name = name, email = email,
    password = password,
    user_type = user_type
  )
  if (!is.null(institution) && nzchar(institution)) {
    body$institution <- institution
  }

  result <- shiny_api_request(
    "POST", "auth/register",
    body = body
  )

  # Institutional account pending review
  if (isTRUE(result$ok) && isTRUE(result$pending)) {
    return(list(
      ok = TRUE,
      pending = TRUE,
      message = result$message
    ))
  }

  if (isTRUE(result$ok) && !is.null(result$token)) {
    inst_obj <- if (
      !is.null(institution) &&
        nzchar(institution) &&
        user_type == "institutional_member"
    ) {
      metasurvey::RecipeUser$new(
        name = institution,
        user_type = "institution"
      )
    } else {
      NULL
    }
    user <- metasurvey::RecipeUser$new(
      name = name,
      user_type = user_type,
      email = email,
      institution = inst_obj
    )
    return(list(
      ok = TRUE,
      user = user,
      token = result$token
    ))
  }

  offline <- !isTRUE(result$ok) &&
    !is.null(result$error) &&
    grepl("Connection failed", result$error)
  if (offline) {
    # Offline fallback
    if (email %in% names(.local_users$data)) {
      return(list(
        ok = FALSE,
        error = "Email already registered"
      ))
    }
    .local_users$data[[email]] <- list(
      name = name, email = email,
      password_hash = hash_password(password),
      user_type = user_type,
      institution = institution
    )
    inst_obj <- if (
      !is.null(institution) &&
        nzchar(institution) &&
        user_type == "institutional_member"
    ) {
      metasurvey::RecipeUser$new(
        name = institution,
        user_type = "institution"
      )
    } else {
      NULL
    }
    user <- metasurvey::RecipeUser$new(
      name = name,
      user_type = user_type,
      email = email,
      institution = inst_obj
    )
    return(list(
      ok = TRUE, user = user, token = NULL
    ))
  }

  list(
    ok = FALSE,
    error = result$error %||% "Registration failed"
  )
}

shiny_login <- function(email, password) {
  result <- shiny_api_request(
    "POST", "auth/login",
    body = list(
      email = email, password = password
    )
  )

  has_user <- isTRUE(result$ok) && !is.null(result$user)
  if (has_user) {
    doc <- result$user
    inst <- NULL
    is_member <- doc$user_type == "institutional_member" &&
      !is.null(doc$institution)
    if (is_member) {
      inst <- metasurvey::RecipeUser$new(
        name = doc$institution,
        user_type = "institution"
      )
    }
    user <- metasurvey::RecipeUser$new(
      name = doc$name,
      user_type = doc$user_type,
      email = doc$email,
      institution = inst
    )
    return(list(
      ok = TRUE,
      user = user,
      token = result$token
    ))
  }

  login_offline <- !isTRUE(result$ok) &&
    !is.null(result$error) &&
    grepl("Connection failed", result$error)
  if (login_offline) {
    # Offline fallback
    pw_hash <- hash_password(password)
    if (email %in% names(.local_users$data)) {
      local_u <- .local_users$data[[email]]
      if (identical(local_u$password_hash, pw_hash)) {
        inst <- NULL
        is_local_member <- local_u$user_type ==
          "institutional_member" &&
          !is.null(local_u$institution)
        if (is_local_member) {
          inst <- metasurvey::RecipeUser$new(
            name = local_u$institution,
            user_type = "institution"
          )
        }
        user <- metasurvey::RecipeUser$new(
          name = local_u$name,
          user_type = local_u$user_type,
          email = local_u$email,
          institution = inst
        )
        return(list(
          ok = TRUE, user = user, token = NULL
        ))
      }
    }
  }

  # Pass through review_status for pending/rejected
  if (!is.null(result$review_status)) {
    return(list(
      ok = FALSE,
      error = result$error,
      review_status = result$review_status
    ))
  }

  list(
    ok = FALSE,
    error = result$error %||% "Invalid email or password"
  )
}

# ── Admin operations ──────────────────────────────────

shiny_fetch_pending_users <- function(token) {
  shiny_api_request(
    "GET", "admin/pending-users",
    token = token
  )
}

shiny_approve_user <- function(email, token) {
  shiny_api_request(
    "POST",
    paste0("admin/approve/", email),
    token = token
  )
}

shiny_reject_user <- function(email, token) {
  shiny_api_request(
    "POST",
    paste0("admin/reject/", email),
    token = token
  )
}

# ── Token generation ──────────────────────────────────

shiny_generate_token <- function(token) {
  shiny_api_request(
    "POST", "auth/generate-token",
    token = token
  )
}

# ── Recipe operations ─────────────────────────────────

shiny_fetch_recipes <- function(filter = list()) {
  params <- list()
  if (!is.null(filter$survey_type)) {
    params$survey_type <- filter$survey_type
  }
  if (!is.null(filter$user)) {
    params$user <- filter$user
  }
  if (!is.null(filter$topic)) {
    params$topic <- filter$topic
  }
  if (!is.null(filter$search)) {
    params$search <- filter$search
  }
  params$limit <- 200

  result <- shiny_api_request(
    "GET", "recipes",
    params = params
  )

  if (!isTRUE(result$ok)) {
    return(list())
  }

  docs <- result$recipes %||% list()
  recipes <- lapply(docs, parse_recipe_doc)
  Filter(Negate(is.null), recipes)
}

parse_recipe_doc <- function(doc) {
  categories <- list()
  if (!is.null(doc$categories)) {
    categories <- lapply(doc$categories, function(c) {
      tryCatch(
        metasurvey::RecipeCategory$from_list(c),
        error = function(e) NULL
      )
    })
    categories <- Filter(Negate(is.null), categories)
  }
  certification <- NULL
  if (!is.null(doc$certification)) {
    certification <- tryCatch(
      metasurvey::RecipeCertification$from_list(
        doc$certification
      ),
      error = function(e) NULL
    )
  }
  user_info <- NULL
  if (!is.null(doc$user_info)) {
    user_info <- tryCatch(
      metasurvey::RecipeUser$from_list(
        doc$user_info
      ),
      error = function(e) NULL
    )
  }
  cached_doc <- NULL
  if (!is.null(doc$doc)) {
    cached_doc <- list(
      input_variables = as.character(
        unlist(doc$doc$input_variables)
      ),
      output_variables = as.character(
        unlist(doc$doc$output_variables)
      ),
      pipeline = doc$doc$pipeline %||% list()
    )
  }
  tryCatch(
    metasurvey::Recipe$new(
      name = doc$name %||% "Unnamed",
      user = doc$user %||% "Unknown",
      edition = doc$edition %||% "Unknown",
      survey_type = doc$survey_type %||% "Unknown",
      default_engine = "data.table",
      depends_on = doc$depends_on %||% list(),
      description = doc$description %||% "",
      steps = as.list(doc$steps %||% list()),
      id = doc$id %||%
        doc[["_id"]] %||%
        paste0("r_", sample.int(1e6, 1)),
      doi = doc$doi, topic = doc$topic,
      cached_doc = cached_doc,
      categories = categories,
      downloads = as.integer(
        doc$downloads %||% 0
      ),
      certification = certification,
      user_info = user_info,
      version = doc$version %||% "1.0.0",
      depends_on_recipes = doc$depends_on_recipes %||%
        list(),
      data_source = doc$data_source
    ),
    error = function(e) NULL
  )
}

shiny_increment_downloads <- function(recipe_id) {
  tryCatch(
    shiny_api_request(
      "POST",
      paste0("recipes/", recipe_id, "/download")
    ),
    error = function(e) NULL
  )
}

shiny_fetch_user_recipes <- function(user_email) {
  shiny_fetch_recipes(
    filter = list(user = user_email)
  )
}

# ── Workflow operations ───────────────────────────────

shiny_fetch_workflows <- function(filter = list()) {
  params <- list()
  if (!is.null(filter$survey_type)) {
    params$survey_type <- filter$survey_type
  }
  if (!is.null(filter$recipe_id)) {
    params$recipe_id <- filter$recipe_id
  }
  if (!is.null(filter$user)) {
    params$user <- filter$user
  }
  if (!is.null(filter$search)) {
    params$search <- filter$search
  }
  params$limit <- 200

  result <- shiny_api_request(
    "GET", "workflows",
    params = params
  )

  if (!isTRUE(result$ok)) {
    return(list())
  }

  docs <- result$workflows %||% list()
  workflows <- lapply(docs, function(doc) {
    tryCatch(
      metasurvey::workflow_from_list(doc),
      error = function(e) NULL
    )
  })
  Filter(Negate(is.null), workflows)
}

shiny_fetch_wf_for_recipe <- function(
    recipe_id) {
  shiny_fetch_workflows(
    filter = list(recipe_id = recipe_id)
  )
}

shiny_incr_wf_downloads <- function(
    workflow_id) {
  tryCatch(
    shiny_api_request(
      "POST",
      paste0(
        "workflows/", workflow_id, "/download"
      )
    ),
    error = function(e) NULL
  )
}

# ── ANDA variable metadata ───────────────────────────

shiny_fetch_anda_variables <- function(survey_type,
                                       var_names) {
  if (length(var_names) == 0) {
    return(list())
  }
  params <- list(
    survey_type = survey_type,
    names = paste(
      tolower(var_names),
      collapse = ","
    )
  )
  tryCatch(
    {
      result <- shiny_api_request(
        "GET", "anda/variables",
        params = params
      )
      if (isTRUE(result$ok)) {
        result$variables %||% list()
      } else {
        list()
      }
    },
    error = function(e) list()
  )
}

# ── Example recipes for local/demo mode ──────────────

example_recipes <- function() {
  iecon <- metasurvey::RecipeUser$new(
    name = "Instituto de Economia",
    user_type = "institution",
    verified = TRUE
  )
  member_maria <- metasurvey::RecipeUser$new(
    name = "Maria Garcia",
    user_type = "institutional_member",
    email = "maria@iecon.edu.uy",
    institution = iecon
  )
  user_juan <- metasurvey::RecipeUser$new(
    name = "Juan Perez",
    user_type = "individual",
    email = "juan@example.com"
  )
  user_ana <- metasurvey::RecipeUser$new(
    name = "Ana Rodriguez",
    user_type = "individual",
    email = "ana@fcea.edu.uy",
    affiliation = "UdelaR"
  )

  labor <- metasurvey::RecipeCategory$new(
    "labor_market", "Labor market indicators"
  )
  income <- metasurvey::RecipeCategory$new(
    "income", "Income distribution and poverty"
  )
  education <- metasurvey::RecipeCategory$new(
    "education", "Education attainment"
  )
  health <- metasurvey::RecipeCategory$new(
    "health", "Health outcomes"
  )
  demographics <- metasurvey::RecipeCategory$new(
    "demographics", "Population demographics"
  )
  housing <- metasurvey::RecipeCategory$new(
    "housing", "Housing conditions"
  )

  list(
    metasurvey::Recipe$new(
      name = "Indicadores del Mercado Laboral",
      edition = "2023",
      survey_type = "ech",
      default_engine = "data.table",
      depends_on = list(
        "POBPCOAC", "PE7", "PE7_1"
      ),
      user = "maria@iecon.edu.uy",
      description = paste0(
        "Construye tasas de actividad, empleo",
        " y desempleo a partir de la ECH.",
        " Incluye clasificacion de condicion",
        " de actividad economica segun",
        " definiciones del INE Uruguay."
      ),
      steps = list(),
      id = "example_001",
      doi = "10.5281/zenodo.12345",
      topic = "labor_market",
      categories = list(labor, income),
      downloads = 1847L,
      certification =
        metasurvey::RecipeCertification$new(
          "official",
          certified_by = iecon
        ),
      user_info = member_maria,
      version = "2.1.0",
      cached_doc = list(
        input_variables = c(
          "POBPCOAC", "PE7", "PE7_1",
          "PT4", "pesoano"
        ),
        output_variables = c(
          "condicion_actividad",
          "tasa_actividad",
          "tasa_empleo",
          "tasa_desempleo"
        ),
        pipeline = list(
          list(
            index = 1, type = "recode",
            outputs = "condicion_actividad",
            inputs = c("POBPCOAC"),
            inferred_type = "categorical",
            comment = "Clasificacion PEA/PEI"
          ),
          list(
            index = 2, type = "compute",
            outputs = "horas_trabajadas",
            inputs = c("PE7", "PE7_1"),
            inferred_type = "numeric",
            comment = "Total horas semanales"
          ),
          list(
            index = 3, type = "compute",
            outputs = c(
              "tasa_actividad",
              "tasa_empleo",
              "tasa_desempleo"
            ),
            inputs = c(
              "condicion_actividad", "pesoano"
            ),
            inferred_type = "numeric",
            comment = "Tasas principales"
          )
        )
      )
    ),
    metasurvey::Recipe$new(
      name = "Distribucion del Ingreso y Pobreza",
      edition = "2023",
      survey_type = "ech",
      default_engine = "data.table",
      depends_on = list(
        "HT11", "HT13", "YSVL"
      ),
      user = "maria@iecon.edu.uy",
      description = paste0(
        "Calcula ingreso per capita del hogar,",
        " deciles de ingreso y clasificacion",
        " de linea de pobreza e indigencia",
        " segun metodologia INE 2006."
      ),
      steps = list(),
      id = "example_002",
      doi = "10.5281/zenodo.12346",
      topic = "income",
      categories = list(income),
      downloads = 2103L,
      certification =
        metasurvey::RecipeCertification$new(
          "official",
          certified_by = iecon
        ),
      user_info = member_maria,
      version = "3.0.1",
      cached_doc = list(
        input_variables = c(
          "HT11", "HT13", "YSVL",
          "HT19", "pesoano", "nper"
        ),
        output_variables = c(
          "ingreso_pc", "decil_ingreso",
          "pobreza", "indigencia"
        ),
        pipeline = list(
          list(
            index = 1, type = "compute",
            outputs = "ingreso_pc",
            inputs = c("HT11", "nper"),
            inferred_type = "numeric",
            comment = paste0(
              "Ingreso per capita del hogar"
            )
          ),
          list(
            index = 2, type = "compute",
            outputs = "decil_ingreso",
            inputs = c(
              "ingreso_pc", "pesoano"
            ),
            inferred_type = "numeric",
            comment = "Deciles ponderados"
          ),
          list(
            index = 3, type = "recode",
            outputs = "pobreza",
            inputs = c("ingreso_pc"),
            inferred_type = "categorical",
            comment = paste0(
              "Linea de pobreza INE 2006"
            )
          ),
          list(
            index = 4, type = "recode",
            outputs = "indigencia",
            inputs = c("ingreso_pc"),
            inferred_type = "categorical",
            comment = paste0(
              "Linea de indigencia INE 2006"
            )
          )
        )
      )
    ),
    metasurvey::Recipe$new(
      name = "Nivel Educativo y Asistencia",
      edition = "2023",
      survey_type = "ech",
      default_engine = "data.table",
      depends_on = list(
        "E27", "E197_1", "E51_7"
      ),
      user = "ana@fcea.edu.uy",
      description = paste0(
        "Construye indicadores de nivel",
        " educativo alcanzado, anos de",
        " educacion y asistencia actual",
        " al sistema educativo."
      ),
      steps = list(),
      id = "example_003",
      topic = "education",
      categories = list(education),
      downloads = 634L,
      certification =
        metasurvey::RecipeCertification$new(
          "reviewed",
          certified_by = member_maria
        ),
      user_info = user_ana,
      version = "1.2.0",
      cached_doc = list(
        input_variables = c(
          "E27", "E197_1", "E51_7",
          "E51_8", "E49"
        ),
        output_variables = c(
          "nivel_educativo",
          "anos_educacion",
          "asiste_educacion"
        ),
        pipeline = list(
          list(
            index = 1, type = "recode",
            outputs = "nivel_educativo",
            inputs = c("E27", "E197_1"),
            inferred_type = "categorical",
            comment = paste0(
              "Primaria/Secundaria/",
              "Terciaria/Posgrado"
            )
          ),
          list(
            index = 2, type = "compute",
            outputs = "anos_educacion",
            inputs = c(
              "E27", "E51_7", "E51_8"
            ),
            inferred_type = "numeric",
            comment = "Anos totales aprobados"
          ),
          list(
            index = 3, type = "recode",
            outputs = "asiste_educacion",
            inputs = c("E49"),
            inferred_type = "categorical",
            comment = paste0(
              "Asiste actualmente SI/NO"
            )
          )
        )
      )
    ),
    metasurvey::Recipe$new(
      name = "Cobertura de Salud",
      edition = "2023",
      survey_type = "ech",
      default_engine = "data.table",
      depends_on = list("S8", "S10"),
      user = "juan@example.com",
      description = paste0(
        "Indicadores de tipo de cobertura",
        " de salud y derechos vigentes."
      ),
      steps = list(),
      id = "example_004",
      topic = "health",
      categories = list(health),
      downloads = 312L,
      user_info = user_juan,
      version = "1.0.0",
      cached_doc = list(
        input_variables = c(
          "S8", "S10", "S11"
        ),
        output_variables = c(
          "tipo_cobertura", "tiene_derechos"
        ),
        pipeline = list(
          list(
            index = 1, type = "recode",
            outputs = "tipo_cobertura",
            inputs = c("S8", "S10"),
            inferred_type = "categorical",
            comment = paste0(
              "ASSE/Mutualista/Privado/Otro"
            )
          ),
          list(
            index = 2, type = "recode",
            outputs = "tiene_derechos",
            inputs = c("S11"),
            inferred_type = "categorical",
            comment = paste0(
              "Derechos vigentes SI/NO"
            )
          )
        )
      )
    ),
    metasurvey::Recipe$new(
      name = "Estructura Demografica",
      edition = "2022-2023",
      survey_type = "ech",
      default_engine = "data.table",
      depends_on = list("E26", "E27"),
      user = "maria@iecon.edu.uy",
      description = paste0(
        "Variables demograficas basicas:",
        " grupos de edad, sexo, region,",
        " area geografica."
      ),
      steps = list(),
      id = "example_005",
      topic = "demographics",
      categories = list(demographics),
      downloads = 3210L,
      certification =
        metasurvey::RecipeCertification$new(
          "official",
          certified_by = iecon
        ),
      user_info = member_maria,
      version = "4.0.0",
      cached_doc = list(
        input_variables = c(
          "E26", "E27", "region_3",
          "AREA", "dpto"
        ),
        output_variables = c(
          "grupo_edad", "tramo_edad",
          "sexo_label", "region", "area"
        ),
        pipeline = list(
          list(
            index = 1, type = "recode",
            outputs = "grupo_edad",
            inputs = c("E26"),
            inferred_type = "categorical",
            comment = "0-14/15-24/25-64/65+"
          ),
          list(
            index = 2, type = "recode",
            outputs = "tramo_edad",
            inputs = c("E26"),
            inferred_type = "categorical",
            comment = "Quinquenales"
          ),
          list(
            index = 3, type = "recode",
            outputs = "sexo_label",
            inputs = c("E27"),
            inferred_type = "categorical",
            comment = "Hombre/Mujer"
          ),
          list(
            index = 4, type = "recode",
            outputs = "region",
            inputs = c("region_3"),
            inferred_type = "categorical",
            comment = paste0(
              "Montevideo/Interior/Rural"
            )
          ),
          list(
            index = 5, type = "recode",
            outputs = "area",
            inputs = c("AREA"),
            inferred_type = "categorical",
            comment = "Urbano/Rural"
          )
        )
      )
    ),
    metasurvey::Recipe$new(
      name = "Condiciones de Vivienda",
      edition = "2023",
      survey_type = "ech",
      default_engine = "data.table",
      depends_on = list("D8", "D9"),
      user = "juan@example.com",
      description = paste0(
        "Caracteristicas de la vivienda:",
        " tipo, materiales, hacinamiento,",
        " acceso a servicios basicos."
      ),
      steps = list(),
      id = "example_006",
      topic = "housing",
      categories = list(housing),
      downloads = 189L,
      user_info = user_juan,
      version = "1.0.0",
      cached_doc = list(
        input_variables = c(
          "D8", "D9", "D10",
          "D16", "D18", "nper", "D21"
        ),
        output_variables = c(
          "tipo_vivienda",
          "material_techo",
          "hacinamiento",
          "saneamiento"
        ),
        pipeline = list(
          list(
            index = 1, type = "recode",
            outputs = "tipo_vivienda",
            inputs = c("D8"),
            inferred_type = "categorical",
            comment = "Casa/Apartamento/Otro"
          ),
          list(
            index = 2, type = "recode",
            outputs = "material_techo",
            inputs = c("D10"),
            inferred_type = "categorical",
            comment = "Material predominante"
          ),
          list(
            index = 3, type = "compute",
            outputs = "hacinamiento",
            inputs = c("D9", "nper"),
            inferred_type = "numeric",
            comment = paste0(
              "Personas por dormitorio"
            )
          ),
          list(
            index = 4, type = "recode",
            outputs = "saneamiento",
            inputs = c("D21"),
            inferred_type = "categorical",
            comment = "Red/Pozo/Otro"
          )
        )
      )
    ),
    metasurvey::Recipe$new(
      name = paste0(
        "Indicadores de Innovacion Empresarial"
      ),
      edition = "2019-2021",
      survey_type = "eaii",
      default_engine = "data.table",
      depends_on = list("p3_1", "p4_1"),
      user = "ana@fcea.edu.uy",
      description = paste0(
        "Procesamiento de la EAII.",
        " Indicadores de innovacion en",
        " producto, proceso, organizacion",
        " y comercializacion."
      ),
      steps = list(),
      id = "example_007",
      topic = "labor_market",
      categories = list(labor),
      downloads = 456L,
      certification =
        metasurvey::RecipeCertification$new(
          "reviewed",
          certified_by = member_maria
        ),
      user_info = user_ana,
      version = "1.1.0",
      cached_doc = list(
        input_variables = c(
          "p3_1", "p3_2", "p4_1", "p4_2",
          "p5_1", "tamano", "sector_ciiu"
        ),
        output_variables = c(
          "innova_producto",
          "innova_proceso",
          "innova_organizacion",
          "tipo_innovador"
        ),
        pipeline = list(
          list(
            index = 1, type = "recode",
            outputs = "innova_producto",
            inputs = c("p3_1", "p3_2"),
            inferred_type = "categorical",
            comment = paste0(
              "Innovacion en producto SI/NO"
            )
          ),
          list(
            index = 2, type = "recode",
            outputs = "innova_proceso",
            inputs = c("p4_1", "p4_2"),
            inferred_type = "categorical",
            comment = paste0(
              "Innovacion en proceso SI/NO"
            )
          ),
          list(
            index = 3, type = "recode",
            outputs = "innova_organizacion",
            inputs = c("p5_1"),
            inferred_type = "categorical",
            comment = paste0(
              "Innovacion organizacional SI/NO"
            )
          ),
          list(
            index = 4, type = "recode",
            outputs = "tipo_innovador",
            inputs = c(
              "innova_producto",
              "innova_proceso",
              "innova_organizacion"
            ),
            inferred_type = "categorical",
            comment = paste0(
              "TPP/Amplio/No innovador"
            )
          )
        )
      )
    ),
    metasurvey::Recipe$new(
      name = "Transiciones Laborales (Panel)",
      edition = "2020-2023",
      survey_type = "ech",
      default_engine = "data.table",
      depends_on = list("POBPCOAC"),
      user = "juan@example.com",
      description = paste0(
        "Analisis de transiciones entre",
        " estados laborales usando datos",
        " de panel rotativo de la ECH."
      ),
      steps = list(),
      id = "example_008",
      topic = "labor_market",
      categories = list(labor, demographics),
      downloads = 98L,
      user_info = user_juan,
      version = "0.9.0",
      cached_doc = list(
        input_variables = c(
          "POBPCOAC", "POBPCOAC_t1",
          "E26", "pesoano"
        ),
        output_variables = c(
          "estado_t0", "estado_t1",
          "transicion"
        ),
        pipeline = list(
          list(
            index = 1, type = "recode",
            outputs = "estado_t0",
            inputs = c("POBPCOAC"),
            inferred_type = "categorical",
            comment = paste0(
              "Estado laboral periodo 0"
            )
          ),
          list(
            index = 2, type = "recode",
            outputs = "estado_t1",
            inputs = c("POBPCOAC_t1"),
            inferred_type = "categorical",
            comment = paste0(
              "Estado laboral periodo 1"
            )
          ),
          list(
            index = 3, type = "compute",
            outputs = "transicion",
            inputs = c(
              "estado_t0", "estado_t1"
            ),
            inferred_type = "categorical",
            comment = "Matriz de transicion"
          )
        )
      )
    )
  )
}

# ── Example workflows for local/demo mode ────────────

example_workflows <- function() {
  iecon <- metasurvey::RecipeUser$new(
    name = "Instituto de Economia",
    user_type = "institution",
    verified = TRUE
  )
  member_maria <- metasurvey::RecipeUser$new(
    name = "Maria Garcia",
    user_type = "institutional_member",
    email = "maria@iecon.edu.uy",
    institution = iecon
  )
  user_juan <- metasurvey::RecipeUser$new(
    name = "Juan Perez",
    user_type = "individual",
    email = "juan@example.com"
  )
  user_ana <- metasurvey::RecipeUser$new(
    name = "Ana Rodriguez",
    user_type = "individual",
    email = "ana@fcea.edu.uy",
    affiliation = "UdelaR"
  )

  list(
    metasurvey::RecipeWorkflow$new(
      id = "wf_001",
      name = "Analisis del Mercado Laboral",
      description = paste0(
        "Estimaciones principales del",
        " mercado de trabajo: tasas de",
        " actividad, empleo y desempleo,",
        " horas trabajadas y brechas",
        " de genero."
      ),
      user = "maria@iecon.edu.uy",
      user_info = member_maria,
      survey_type = "ech",
      edition = "2023",
      estimation_type = c(
        "annual", "quarterly"
      ),
      recipe_ids = c(
        "example_001", "example_005"
      ),
      calls = list(
        paste0(
          "svymean(~tasa_actividad,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svymean(~tasa_empleo,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svymean(~tasa_desempleo,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svymean(~horas_trabajadas,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svyby(~tasa_empleo,",
          " ~sexo_label, design,",
          " svymean, na.rm = TRUE)"
        )
      ),
      call_metadata = list(
        list(
          type = "svymean",
          formula = "~tasa_actividad",
          description = paste0(
            "Proporcion de PEA sobre PET"
          )
        ),
        list(
          type = "svymean",
          formula = "~tasa_empleo",
          description = paste0(
            "Proporcion de ocupados",
            " sobre PET"
          )
        ),
        list(
          type = "svymean",
          formula = "~tasa_desempleo",
          description = paste0(
            "Proporcion de desocupados",
            " sobre PEA"
          )
        ),
        list(
          type = "svymean",
          formula = "~horas_trabajadas",
          description = paste0(
            "Promedio de horas semanales"
          )
        ),
        list(
          type = "svyby",
          formula = "~tasa_empleo",
          by = "~sexo_label",
          description = paste0(
            "Tasa de empleo por sexo"
          )
        )
      ),
      downloads = 892L,
      certification =
        metasurvey::RecipeCertification$new(
          "official",
          certified_by = iecon
        ),
      version = "2.0.0"
    ),
    metasurvey::RecipeWorkflow$new(
      id = "wf_002",
      name = "Distribucion de Ingresos",
      description = paste0(
        "Estimaciones de ingreso per capita,",
        " pobreza e indigencia con",
        " desagregacion regional."
      ),
      user = "maria@iecon.edu.uy",
      user_info = member_maria,
      survey_type = "ech",
      edition = "2023",
      estimation_type = "annual",
      recipe_ids = c("example_002"),
      calls = list(
        paste0(
          "svymean(~ingreso_pc,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svytotal(~ingreso_pc,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svymean(~pobreza,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svymean(~indigencia,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svyby(~ingreso_pc, ~region,",
          " design, svymean,",
          " na.rm = TRUE)"
        )
      ),
      call_metadata = list(
        list(
          type = "svymean",
          formula = "~ingreso_pc",
          description = paste0(
            "Ingreso promedio per capita"
          )
        ),
        list(
          type = "svytotal",
          formula = "~ingreso_pc",
          description = paste0(
            "Masa total de ingresos"
          )
        ),
        list(
          type = "svymean",
          formula = "~pobreza",
          description = "Tasa de pobreza"
        ),
        list(
          type = "svymean",
          formula = "~indigencia",
          description = "Tasa de indigencia"
        ),
        list(
          type = "svyby",
          formula = "~ingreso_pc",
          by = "~region",
          description = paste0(
            "Ingreso por region"
          )
        )
      ),
      downloads = 1205L,
      certification =
        metasurvey::RecipeCertification$new(
          "official",
          certified_by = iecon
        ),
      version = "3.0.0"
    ),
    metasurvey::RecipeWorkflow$new(
      id = "wf_003",
      name = "Perfil Educativo Nacional",
      description = paste0(
        "Nivel educativo, anos de educacion",
        " y tasas de asistencia con",
        " perspectiva demografica."
      ),
      user = "ana@fcea.edu.uy",
      user_info = user_ana,
      survey_type = "ech",
      edition = "2023",
      estimation_type = "annual",
      recipe_ids = c(
        "example_003", "example_005"
      ),
      calls = list(
        paste0(
          "svymean(~anos_educacion,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svymean(~nivel_educativo,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svymean(~asiste_educacion,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svyby(~anos_educacion,",
          " ~sexo_label, design,",
          " svymean, na.rm = TRUE)"
        )
      ),
      call_metadata = list(
        list(
          type = "svymean",
          formula = "~anos_educacion",
          description = paste0(
            "Anos promedio de educacion"
          )
        ),
        list(
          type = "svymean",
          formula = "~nivel_educativo",
          description = paste0(
            "Distribucion por nivel",
            " educativo"
          )
        ),
        list(
          type = "svymean",
          formula = "~asiste_educacion",
          description = "Tasa de asistencia"
        ),
        list(
          type = "svyby",
          formula = "~anos_educacion",
          by = "~sexo_label",
          description = paste0(
            "Educacion por sexo"
          )
        )
      ),
      downloads = 341L,
      certification =
        metasurvey::RecipeCertification$new(
          "reviewed",
          certified_by = member_maria
        ),
      version = "1.2.0"
    ),
    metasurvey::RecipeWorkflow$new(
      id = "wf_004",
      name = paste0(
        "Panorama Demografico y Salud"
      ),
      description = paste0(
        "Estructura poblacional, cobertura",
        " de salud y derechos vigentes."
      ),
      user = "juan@example.com",
      user_info = user_juan,
      survey_type = "ech",
      edition = "2023",
      estimation_type = "annual",
      recipe_ids = c(
        "example_004", "example_005"
      ),
      calls = list(
        paste0(
          "svymean(~tipo_cobertura,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svymean(~tiene_derechos,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svyby(~grupo_edad,",
          " ~sexo_label, design,",
          " svymean, na.rm = TRUE)"
        ),
        "svytotal(~1, design)"
      ),
      call_metadata = list(
        list(
          type = "svymean",
          formula = "~tipo_cobertura",
          description = paste0(
            "Distribucion por cobertura",
            " de salud"
          )
        ),
        list(
          type = "svymean",
          formula = "~tiene_derechos",
          description = paste0(
            "Tasa con derechos vigentes"
          )
        ),
        list(
          type = "svyby",
          formula = "~grupo_edad",
          by = "~sexo_label",
          description = paste0(
            "Piramide poblacional"
          )
        ),
        list(
          type = "svytotal",
          formula = "~1",
          description = paste0(
            "Poblacion total estimada"
          )
        )
      ),
      downloads = 178L,
      version = "1.0.0"
    ),
    metasurvey::RecipeWorkflow$new(
      id = "wf_005",
      name = "Condiciones Habitacionales",
      description = paste0(
        "Hacinamiento, tipo de vivienda y",
        " saneamiento con desagregacion",
        " territorial."
      ),
      user = "juan@example.com",
      user_info = user_juan,
      survey_type = "ech",
      edition = "2023",
      estimation_type = "annual",
      recipe_ids = c(
        "example_006", "example_005"
      ),
      calls = list(
        paste0(
          "svymean(~hacinamiento,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svymean(~tipo_vivienda,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svyby(~saneamiento, ~area,",
          " design, svymean,",
          " na.rm = TRUE)"
        )
      ),
      call_metadata = list(
        list(
          type = "svymean",
          formula = "~hacinamiento",
          description = paste0(
            "Hacinamiento promedio"
          )
        ),
        list(
          type = "svymean",
          formula = "~tipo_vivienda",
          description = paste0(
            "Distribucion tipo de vivienda"
          )
        ),
        list(
          type = "svyby",
          formula = "~saneamiento",
          by = "~area",
          description = paste0(
            "Saneamiento por area"
          )
        )
      ),
      downloads = 95L,
      version = "1.0.0"
    ),
    metasurvey::RecipeWorkflow$new(
      id = "wf_006",
      name = paste0(
        "Innovacion y Transiciones",
        " Laborales"
      ),
      description = paste0(
        "Indicadores de innovacion",
        " empresarial y analisis de",
        " transiciones entre estados",
        " laborales."
      ),
      user = "ana@fcea.edu.uy",
      user_info = user_ana,
      survey_type = "eaii",
      edition = "2019-2021",
      estimation_type = "annual",
      recipe_ids = c(
        "example_007", "example_008"
      ),
      calls = list(
        paste0(
          "svymean(~innova_producto,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svymean(~innova_proceso,",
          " design, na.rm = TRUE)"
        ),
        paste0(
          "svyby(~tipo_innovador,",
          " ~tamano, design, svymean,",
          " na.rm = TRUE)"
        ),
        paste0(
          "svyby(~estado_t1,",
          " ~estado_t0, design,",
          " svymean, na.rm = TRUE)"
        )
      ),
      call_metadata = list(
        list(
          type = "svymean",
          formula = "~innova_producto",
          description = paste0(
            "Tasa de innovacion",
            " en producto"
          )
        ),
        list(
          type = "svymean",
          formula = "~innova_proceso",
          description = paste0(
            "Tasa de innovacion",
            " en proceso"
          )
        ),
        list(
          type = "svyby",
          formula = "~tipo_innovador",
          by = "~tamano",
          description = paste0(
            "Tipo innovador por tamano"
          )
        ),
        list(
          type = "svyby",
          formula = "~estado_t1",
          by = "~estado_t0",
          description = paste0(
            "Matriz de transicion laboral"
          )
        )
      ),
      downloads = 267L,
      certification =
        metasurvey::RecipeCertification$new(
          "reviewed",
          certified_by = member_maria
        ),
      version = "1.0.0"
    )
  )
}

# ── Stars ─────────────────────────────────────────────

shiny_star <- function(target_type, id, value, token) {
  shiny_api_request(
    "PUT",
    paste0(target_type, "s/", id, "/star"),
    body = list(value = as.integer(value)),
    token = token
  )
}

shiny_get_stars <- function(target_type, id,
                            token = NULL) {
  shiny_api_request(
    "GET",
    paste0(target_type, "s/", id, "/stars"),
    token = token
  )
}

# ── Comments ──────────────────────────────────────────

shiny_add_comment <- function(target_type, id,
                              text, token) {
  shiny_api_request(
    "POST",
    paste0(target_type, "s/", id, "/comments"),
    body = list(text = text),
    token = token
  )
}

shiny_get_comments <- function(target_type, id) {
  result <- shiny_api_request(
    "GET",
    paste0(target_type, "s/", id, "/comments")
  )
  if (isTRUE(result$ok)) {
    result$comments %||% list()
  } else {
    list()
  }
}

shiny_delete_comment <- function(comment_id, token) {
  shiny_api_request(
    "DELETE",
    paste0("comments/", comment_id),
    token = token
  )
}

# ── Dependents (backlinks) ────────────────────────────

shiny_get_recipe_dependents <- function(id) {
  result <- shiny_api_request(
    "GET",
    paste0("recipes/", id, "/dependents")
  )
  if (isTRUE(result$ok)) {
    result$dependents %||% list()
  } else {
    list()
  }
}
