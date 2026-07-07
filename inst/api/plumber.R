# ==============================================================================
# metasurvey Data API — plumber + mongolite
#
# Endpoints:
#   POST /auth/register    — Register a new user
#   POST /auth/login       — Login, returns JWT
#   GET  /auth/me          — Get current user profile (requires JWT)
#
#   GET  /recipes          — List/search/filter recipes
#   GET  /recipes/:id      — Get single recipe by ID
#   POST /recipes          — Publish a recipe (requires JWT)
#   POST /recipes/:id/download — Increment download counter
#
#   GET  /workflows          — List/search/filter workflows
#   GET  /workflows/:id      — Get single workflow by ID
#   POST /workflows          — Publish a workflow (requires JWT)
#   POST /workflows/:id/download — Increment download counter
#
#   GET  /indicators              — List/search/filter indicators
#   GET  /indicators/:id          — Get single indicator
#   GET  /indicators/:id/recipe   — Get recipe that produced it
#   GET  /indicators/:id/workflow — Get workflow (estimation + design)
#   POST /indicators              — Publish an indicator (requires JWT)
#   POST /indicators/compute      — Request on-demand computation (requires JWT)
#
# Config (env vars):
#   METASURVEY_MONGO_URI           — MongoDB connection string (required)
#   METASURVEY_DB                  — Database name (default: metasurvey)
#   METASURVEY_JWT_SECRET          — JWT signing secret
#   METASURVEY_WORKER_URL          — Internal worker URL (e.g. http://worker:8788)
#   METASURVEY_ENABLE_INDICATORS   — "1" (default) or "0" to disable /indicators
#   METASURVEY_ENABLE_WORKER       — "0" (default) or "1" to enable POST /compute
#   METASURVEY_ENABLE_DOCS         — "0" (default) or "1" to enable Swagger UI
#
# Launch:
#   METASURVEY_MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net" \
#     Rscript -e 'plumber::plumb("inst/api/plumber.R")$run(port=8787)'
# ==============================================================================

library(plumber)
library(jsonlite)
library(mongolite)
library(digest)
library(jose)

# -- Global serializer (auto_unbox so scalars are JSON scalars, not arrays) ----

#* @plumber
function(pr) {
  pr$setSerializer(serializer_json(auto_unbox = TRUE))

  # Disable Swagger UI in production (set METASURVEY_ENABLE_DOCS=1 to enable)
  enable_docs <- tolower(Sys.getenv("METASURVEY_ENABLE_DOCS", "0")) %in%
    c("1", "true", "yes")
  if (!enable_docs) {
    pr$setDocs(FALSE)
  }

  # Enhance OpenAPI spec with security scheme and API info
  spec <- pr$getApiSpec()
  spec$info <- list(
    title = "metasurvey API",
    description = paste(
      "REST API for sharing survey recipes, estimation workflows,",
      "published indicators with traceability, and",
      "ANDA variable metadata. Built with plumber + MongoDB.",
      "\n\nAuthentication: POST /auth/login returns a JWT token.",
      "Include it as `Authorization: Bearer <token>` in requests",
      "that require authentication."
    ),
    version = "2.0.0",
    contact = list(
      name = "metasurvey",
      url = "https://metasurveyr.github.io/metasurvey"
    )
  )
  spec$components$securitySchemes <- list(
    bearerAuth = list(
      type = "http",
      scheme = "bearer",
      bearerFormat = "JWT",
      description = paste0(
        "JWT token from /auth/login (24h)",
        " or /auth/generate-token (90 days)"
      )
    )
  )
  pr$setApiSpec(spec)
}

# -- Config -------------------------------------------------------------------

MONGO_URI <- Sys.getenv("METASURVEY_MONGO_URI", "")
DATABASE <- Sys.getenv("METASURVEY_DB", "metasurvey")
JWT_SECRET <- Sys.getenv(
  "METASURVEY_JWT_SECRET",
  "metasurvey-dev-secret-change-me"
)
ADMIN_EMAIL <- Sys.getenv("METASURVEY_ADMIN_EMAIL", "")
WORKER_URL <- Sys.getenv("METASURVEY_WORKER_URL", "")

# Feature flags — disable modules not available in this deployment
ENABLE_INDICATORS <- tolower(Sys.getenv(
  "METASURVEY_ENABLE_INDICATORS", "1"
)) %in% c("1", "true", "yes")
ENABLE_WORKER <- tolower(Sys.getenv(
  "METASURVEY_ENABLE_WORKER", "0"
)) %in% c("1", "true", "yes")
REDIS_URL <- Sys.getenv("REDIS_URL", "")
REDIS_HOST <- Sys.getenv("REDIS_HOST", "")
REDIS_PORT <- Sys.getenv("REDIS_PORT", "6379")
REDIS_PASSWORD <- Sys.getenv("REDIS_PASSWORD", "")
ENABLE_REDIS <- nzchar(REDIS_URL) || nzchar(REDIS_HOST)
ENABLE_ASYNC <- tolower(Sys.getenv(
  "METASURVEY_ENABLE_ASYNC", "0"
)) %in% c("1", "true", "yes")
ENABLE_DOCS <- tolower(Sys.getenv(
  "METASURVEY_ENABLE_DOCS", "0"
)) %in% c("1", "true", "yes")

# Rate limiting config
RATE_LIMIT_MAX <- 5L # max attempts per window
RATE_LIMIT_WINDOW <- 300L # 5 minutes

if (!nzchar(MONGO_URI)) {
  stop(
    "METASURVEY_MONGO_URI environment variable is required. ",
    "Set it to your MongoDB connection string, e.g.:\n",
    paste0(
      "  export METASURVEY_MONGO_URI=",
      "'mongodb+srv://user:pass",
      "@cluster.mongodb.net'"
    )
  )
}

# -- mongolite connections (one per collection, reused) -----------------------

db_users <- mongolite::mongo(
  collection = "users",
  db = DATABASE, url = MONGO_URI
)
db_recipes <- mongolite::mongo(
  collection = "recipes",
  db = DATABASE, url = MONGO_URI
)
db_workflows <- mongolite::mongo(
  collection = "workflows",
  db = DATABASE, url = MONGO_URI
)
db_anda <- mongolite::mongo(
  collection = "anda_variables",
  db = DATABASE, url = MONGO_URI
)
db_stars <- mongolite::mongo(
  collection = "stars",
  db = DATABASE, url = MONGO_URI
)
db_comments <- mongolite::mongo(
  collection = "comments",
  db = DATABASE, url = MONGO_URI
)
if (ENABLE_INDICATORS) {
  db_indicators <- mongolite::mongo(
    collection = "indicators",
    db = DATABASE, url = MONGO_URI
  )
}

message(sprintf(
  "[metasurvey-api] Connected to MongoDB: %s (db: %s)",
  sub("://.*@", "://***@", MONGO_URI),
  DATABASE
))
message(sprintf(
  paste0(
    "[metasurvey-api] Collections",
    " — users: %d, recipes: %d,",
    " workflows: %d, anda: %d"
  ),
  db_users$count(), db_recipes$count(),
  db_workflows$count(), db_anda$count()
))
if (ENABLE_INDICATORS) {
  message(sprintf(
    "[metasurvey-api] Indicators: %d",
    db_indicators$count()
  ))
}
message(sprintf(
  "[metasurvey-api] Features — indicators: %s, worker: %s",
  if (ENABLE_INDICATORS) "ON" else "OFF",
  if (ENABLE_WORKER) "ON" else "OFF"
))

# -- Redis connection ---------------------------------------------------------

redis_con <- NULL

# Resolve Redis connection params from env vars.
# Priority: individual REDIS_HOST/PORT/PASSWORD > parse REDIS_URL
resolve_redis_params <- function() {
  host <- Sys.getenv("REDIS_HOST", "")
  port <- Sys.getenv("REDIS_PORT", "6379")
  pass <- Sys.getenv("REDIS_PASSWORD", "")
  if (nzchar(host)) {
    return(list(
      host = host,
      port = as.integer(port),
      password = if (nzchar(pass)) pass else NULL
    ))
  }
  # Fallback: parse REDIS_URL
  url <- trimws(Sys.getenv("REDIS_URL", ""))
  if (!grepl("^redis://", url)) {
    return(NULL)
  }
  rest <- sub("^redis://", "", url)
  password <- NULL
  if (grepl("@", rest)) {
    auth <- sub("@.*$", "", rest)
    rest <- sub("^[^@]+@", "", rest)
    if (grepl(":", auth)) {
      password <- sub("^[^:]*:", "", auth)
    } else {
      password <- auth
    }
  }
  rest <- sub("/.*$", "", rest)
  parts <- strsplit(rest, ":")[[1]]
  host <- parts[1]
  port <- if (length(parts) >= 2) as.integer(parts[2]) else 6379L
  if (!nzchar(host)) {
    return(NULL)
  }
  list(host = host, port = port, password = password)
}

redis_error_msg <- NULL

if (ENABLE_REDIS) {
  redis_params <- resolve_redis_params()
  message(sprintf(
    "[metasurvey-api] Connecting to Redis: %s:%s",
    if (!is.null(redis_params)) redis_params$host else "?",
    if (!is.null(redis_params)) redis_params$port else "?"
  ))
  # redux reads REDIS_URL env var internally and fails on authenticated URLs.
  # Workaround: build a clean URL without auth and pass password separately.
  redis_con <- tryCatch(
    {
      if (!is.null(redis_params)) {
        clean_url <- sprintf("redis://%s:%d", redis_params$host, redis_params$port)
        r <- redux::hiredis(url = clean_url)
        if (!is.null(redis_params$password)) {
          r$AUTH(redis_params$password)
        }
        r
      } else {
        redux::hiredis()
      }
    },
    error = function(e) {
      redis_error_msg <<- e$message
      message(sprintf(
        "[metasurvey-api] Redis connection failed (disabled): %s",
        e$message
      ))
      NULL
    }
  )
  if (!is.null(redis_con)) {
    message("[metasurvey-api] Redis: connected")
  }
} else {
  message("[metasurvey-api] Redis: disabled (no REDIS_URL or REDIS_HOST)")
}

# -- Cache helpers ------------------------------------------------------------

cache_params_hash <- function(...) {
  params <- list(...)
  params <- params[order(names(params))]
  digest::digest(params, algo = "xxhash32", serialize = TRUE)
}

cache_get <- function(key) {
  if (is.null(redis_con)) {
    return(NULL)
  }
  raw <- tryCatch(redis_con$GET(key), error = function(e) NULL)
  if (is.null(raw)) {
    return(NULL)
  }
  tryCatch(
    jsonlite::fromJSON(raw, simplifyVector = FALSE),
    error = function(e) NULL
  )
}

cache_set <- function(key, value, ttl) {
  if (is.null(redis_con)) {
    return(invisible(NULL))
  }
  json <- tryCatch(
    jsonlite::toJSON(value, auto_unbox = TRUE, null = "null"),
    error = function(e) NULL
  )
  if (is.null(json)) {
    return(invisible(NULL))
  }
  tryCatch(
    redis_con$SETEX(key, as.integer(ttl), json),
    error = function(e) invisible(NULL)
  )
}

cache_del <- function(...) {
  if (is.null(redis_con)) {
    return(invisible(NULL))
  }
  keys <- c(...)
  for (k in keys) {
    tryCatch(redis_con$DEL(k), error = function(e) invisible(NULL))
  }
}

cache_del_pattern <- function(pattern) {
  if (is.null(redis_con)) {
    return(invisible(NULL))
  }
  tryCatch(
    {
      cursor <- "0"
      repeat {
        result <- redis_con$SCAN(cursor, "MATCH", pattern, "COUNT", "100")
        cursor <- result[[1]]
        keys <- result[[2]]
        if (length(keys) > 0) {
          for (k in keys) redis_con$DEL(k)
        }
        if (cursor == "0") break
      }
    },
    error = function(e) invisible(NULL)
  )
}

# -- Rate limiting helpers ---------------------------------------------------

rate_limit_check <- function(action, client_ip) {
  if (is.null(redis_con)) {
    return(TRUE)
  }
  key <- sprintf("ratelimit:%s:%s", action, client_ip)
  tryCatch(
    {
      count <- redis_con$INCR(key)
      if (identical(as.integer(count), 1L)) {
        redis_con$EXPIRE(key, RATE_LIMIT_WINDOW)
      }
      as.integer(count) <= RATE_LIMIT_MAX
    },
    error = function(e) TRUE
  )
}

rate_limit_remaining <- function(action, client_ip) {
  if (is.null(redis_con)) {
    return(RATE_LIMIT_MAX)
  }
  key <- sprintf("ratelimit:%s:%s", action, client_ip)
  count <- tryCatch(as.integer(redis_con$GET(key) %||% "0"),
    error = function(e) 0L
  )
  max(0L, RATE_LIMIT_MAX - count)
}

# -- Job queue helpers --------------------------------------------------------

JOB_TTL <- 3600L
QUEUE_KEY <- "queue:compute"

make_job_id <- function() {
  paste0("job_", as.integer(Sys.time()), "_", sample.int(99999L, 1L))
}

job_get <- function(job_id) {
  if (is.null(redis_con)) {
    return(NULL)
  }
  raw <- tryCatch(
    redis_con$GET(paste0("job:", job_id)),
    error = function(e) NULL
  )
  if (is.null(raw)) {
    return(NULL)
  }
  tryCatch(
    jsonlite::fromJSON(raw, simplifyVector = FALSE),
    error = function(e) NULL
  )
}

job_set <- function(job_id, data) {
  if (is.null(redis_con)) {
    return(invisible(NULL))
  }
  json <- jsonlite::toJSON(data, auto_unbox = TRUE, null = "null")
  tryCatch(
    redis_con$SETEX(paste0("job:", job_id), JOB_TTL, json),
    error = function(e) invisible(NULL)
  )
}

job_enqueue <- function(job_id) {
  if (is.null(redis_con)) {
    return(invisible(NULL))
  }
  tryCatch(
    redis_con$LPUSH(QUEUE_KEY, job_id),
    error = function(e) invisible(NULL)
  )
}

message(sprintf(
  "[metasurvey-api] Features — async: %s, docs: %s",
  if (ENABLE_ASYNC && !is.null(redis_con)) "ON" else "OFF",
  if (ENABLE_DOCS) "ON" else "OFF"
))

# -- JWT helpers --------------------------------------------------------------

jwt_encode <- function(payload) {
  payload$iat <- as.integer(Sys.time())
  payload$exp <- as.integer(Sys.time()) + 86400L # 24h
  jwt_claim <- jose::jwt_claim(
    iss = "metasurvey-api",
    sub = payload$email,
    name = payload$name,
    user_type = payload$user_type,
    exp = payload$exp,
    iat = payload$iat
  )
  jose::jwt_encode_hmac(jwt_claim, charToRaw(JWT_SECRET))
}

jwt_decode <- function(token) {
  tryCatch(
    jose::jwt_decode_hmac(token, charToRaw(JWT_SECRET)),
    error = function(e) NULL
  )
}

hash_password <- function(pw) {
  digest::digest(pw, algo = "sha256", serialize = FALSE)
}

# -- Auth middleware -----------------------------------------------------------

get_user_from_request <- function(req) {
  auth_header <- req$HTTP_AUTHORIZATION
  if (is.null(auth_header)) {
    return(NULL)
  }
  token <- sub("^Bearer\\s+", "", auth_header)
  if (!nzchar(token)) {
    return(NULL)
  }
  jwt_decode(token)
}

require_auth <- function(req, res) {
  user <- get_user_from_request(req)
  if (is.null(user)) {
    res$status <- 401L
    return(list(
      error = paste0(
        "Authentication required.",
        " Send Authorization:",
        " Bearer <token>"
      )
    ))
  }
  user
}

require_admin <- function(req, res) {
  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }
  if (!nzchar(ADMIN_EMAIL) || user$sub != ADMIN_EMAIL) {
    res$status <- 403L
    return(list(error = "Admin access required"))
  }
  user
}

# -- CORS ---------------------------------------------------------------------

#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")

  # Security headers
  res$setHeader("X-Content-Type-Options", "nosniff")
  res$setHeader("X-Frame-Options", "DENY")
  res$setHeader("X-XSS-Protection", "1; mode=block")
  res$setHeader("Referrer-Policy", "strict-origin-when-cross-origin")
  res$setHeader(
    "Strict-Transport-Security",
    "max-age=31536000; includeSubDomains"
  )
  res$setHeader(
    "Permissions-Policy",
    "camera=(), microphone=(), geolocation=()"
  )
  res$setHeader(
    "Content-Security-Policy",
    "default-src 'none'; frame-ancestors 'none'"
  )

  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200L
    return(list())
  }
  plumber::forward()
}

# ==============================================================================
# AUTH
# ==============================================================================

#* Register a new user. Individual accounts
#* are auto-approved. Institutional accounts
#* require admin review.
#* @tag Auth
#* @post /auth/register
#* @param name:str User display name
#* @param email:str Email address (must be unique)
#* @param password:str Password (hashed with SHA-256 before storage)
#* @param user_type:str Account type:
#*   individual, institutional_member,
#*   or institution
#* @param institution:str Institution name (required for institutional_member)
#* @response 201 Account created.
#*   Returns {ok, token, user} for individual;
#*   {ok, pending, message, user} for
#*   institutional.
#* @response 400 Missing required fields or invalid user_type.
#* @response 409 Email already registered.
function(req, res, name, email, password,
         user_type = "individual",
         institution = NULL) {
  if (missing(name) || missing(email) || missing(password)) {
    res$status <- 400L
    return(list(error = "name, email, and password are required"))
  }

  # Prevent NoSQL injection
  if (
    !is.character(name) || !is.character(email) ||
      !is.character(password) || length(name) != 1 ||
      length(email) != 1 || length(password) != 1
  ) {
    res$status <- 400L
    return(list(error = "name, email, and password are required"))
  }

  valid_types <- c("individual", "institutional_member", "institution")
  if (!user_type %in% valid_types) {
    res$status <- 400L
    return(list(error = paste(
      "user_type must be one of:",
      paste(valid_types, collapse = ", ")
    )))
  }

  if (user_type == "institutional_member" && (is.null(institution) || !nzchar(institution))) {
    res$status <- 400L
    return(list(error = "institution is required for institutional_member"))
  }

  # Check duplicate
  existing <- db_users$find(
    query = toJSON(list(email = jsonlite::unbox(email)), auto_unbox = FALSE),
    limit = 1
  )
  if (nrow(existing) > 0) {
    res$status <- 409L
    return(list(error = "Registration failed. Please try again or login."))
  }

  # Institutional accounts require admin review
  needs_review <- user_type %in% c("institution", "institutional_member")
  review_status <- if (needs_review) "pending" else "approved"

  doc <- toJSON(list(
    name = name,
    email = email,
    password_hash = hash_password(password),
    user_type = user_type,
    institution = if (is.null(institution)) NULL else institution,
    verified = FALSE,
    review_status = review_status,
    created_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  ), auto_unbox = TRUE, null = "null")

  tryCatch(
    {
      db_users$insert(doc)

      if (needs_review) {
        res$status <- 201L
        list(
          ok = TRUE,
          pending = TRUE,
          message = paste0(
            paste0(
              "Account created.",
              " Institutional accounts",
              " require admin review",
              " before activation. "
            ),
            "You will be able to login once your account is approved."
          ),
          user = list(
            name = name,
            email = email,
            user_type = user_type,
            review_status = "pending"
          )
        )
      } else {
        token <- jwt_encode(list(
          email = email,
          name = name,
          user_type = user_type
        ))
        res$status <- 201L
        list(
          ok = TRUE,
          token = token,
          user = list(
            name = name,
            email = email,
            user_type = user_type,
            review_status = "approved"
          )
        )
      }
    },
    error = function(e) {
      res$status <- 500L
      list(error = paste("Registration failed:", e$message))
    }
  )
}

#* Login and receive a JWT token (24h expiry).
#* Use the token in Authorization:
#* Bearer <token> header.
#* @tag Auth
#* @post /auth/login
#* @param email:str Registered email address
#* @param password:str Account password
#* @response 200 Returns {ok, token, user}.
#* @response 401 Invalid email or password.
#* @response 403 Account pending review or rejected.
function(req, res, email, password) {
  if (missing(email) || missing(password)) {
    res$status <- 400L
    return(list(error = "email and password are required"))
  }

  # Prevent NoSQL injection: ensure email/password are plain strings
  if (!is.character(email) || !is.character(password) || length(email) != 1 || length(password) != 1) {
    res$status <- 400L
    return(list(error = "email and password are required"))
  }

  # Rate limiting: max 5 attempts per IP per 5 minutes
  client_ip <- req$REMOTE_ADDR %||% "unknown"
  if (!rate_limit_check("login", client_ip)) {
    res$status <- 429L
    remaining <- rate_limit_remaining("login", client_ip)
    res$setHeader("Retry-After", as.character(RATE_LIMIT_WINDOW))
    return(list(
      error = "Too many login attempts. Try again later.",
      retry_after = RATE_LIMIT_WINDOW
    ))
  }

  query <- toJSON(
    list(
      email = jsonlite::unbox(email),
      password_hash = jsonlite::unbox(hash_password(password))
    ),
    auto_unbox = FALSE
  )
  result <- db_users$find(query = query, limit = 1)

  if (nrow(result) == 0) {
    res$status <- 401L
    return(list(error = "Invalid email or password"))
  }

  doc <- as.list(result[1, ])

  # Check review status for institutional accounts
  rs <- doc$review_status %||% "approved"
  if (rs == "pending") {
    res$status <- 403L
    return(list(
      error = "Account pending review",
      review_status = "pending",
      message = paste0(
        "Your institutional account is",
        " awaiting admin approval.",
        " You will be notified once",
        " reviewed."
      )
    ))
  }
  if (rs == "rejected") {
    res$status <- 403L
    return(list(
      error = "Account not approved",
      review_status = "rejected",
      message = paste0(
        "Your institutional account",
        " request was not approved.",
        " Contact the admin for details."
      )
    ))
  }

  token <- jwt_encode(list(
    email = doc$email,
    name = doc$name,
    user_type = doc$user_type
  ))
  list(
    ok = TRUE,
    token = token,
    user = list(
      name = doc$name,
      email = doc$email,
      user_type = doc$user_type,
      institution = doc$institution,
      verified = isTRUE(doc$verified),
      review_status = rs
    )
  )
}

#* Get current user profile. Requires JWT authentication.
#* @tag Auth
#* @get /auth/me
#* @response 200 Returns {name, email,
#*   user_type, institution, verified,
#*   created_at}.
#* @response 401 Authentication required.
function(req, res) {
  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  result <- db_users$find(
    query = toJSON(list(email = user$sub), auto_unbox = TRUE),
    limit = 1
  )

  if (nrow(result) == 0) {
    res$status <- 404L
    return(list(error = "User not found"))
  }

  d <- as.list(result[1, ])
  list(
    name = d$name,
    email = d$email,
    user_type = d$user_type,
    institution = d$institution,
    verified = isTRUE(d$verified),
    created_at = d$created_at
  )
}

#* Refresh JWT token. Issue a new 24h token. Requires valid (non-expired) JWT.
#* @tag Auth
#* @post /auth/refresh
#* @response 200 Returns {ok, token}.
function(req, res) {
  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  # Issue a new token with fresh expiry
  token <- jwt_encode(list(
    email = user$sub,
    name = user$name,
    user_type = user$user_type
  ))
  list(ok = TRUE, token = token)
}

#* Generate a long-lived API token (90 days)
#* for R scripting. Requires JWT authentication.
#* @tag Auth
#* @post /auth/generate-token
#* @response 200 Returns {ok, token, expires_in, expires_at}.
function(req, res) {
  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  payload <- list(
    email = user$sub,
    name = user$name,
    user_type = user$user_type
  )
  payload$iat <- as.integer(Sys.time())
  payload$exp <- as.integer(Sys.time()) + 90L * 86400L # 90 days

  jwt_claim <- jose::jwt_claim(
    iss = "metasurvey-api",
    sub = payload$email,
    name = payload$name,
    user_type = payload$user_type,
    exp = payload$exp,
    iat = payload$iat
  )
  token <- jose::jwt_encode_hmac(jwt_claim, charToRaw(JWT_SECRET))

  list(
    ok = TRUE,
    token = token,
    expires_in = "90 days",
    expires_at = format(Sys.time() + 90 * 86400, "%Y-%m-%dT%H:%M:%SZ")
  )
}

# ==============================================================================
# ADMIN — Institution review
# ==============================================================================

#* List institutional accounts pending admin review. Requires admin JWT.
#* @tag Admin
#* @get /admin/pending-users
#* @response 200 Returns {ok, count, users}.
#* @response 403 Admin access required.
function(req, res) {
  user <- require_admin(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  tryCatch(
    {
      result <- db_users$find(
        query = '{"review_status": "pending"}',
        fields = '{"password_hash": 0}'
      )
      if (nrow(result) == 0) {
        return(list(ok = TRUE, count = 0L, users = list()))
      }
      users <- lapply(seq_len(nrow(result)), function(i) as.list(result[i, ]))
      list(ok = TRUE, count = length(users), users = users)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Approve an institutional account.
#* Sets review_status to "approved".
#* Requires admin JWT.
#* @tag Admin
#* @post /admin/approve/<email>
#* @response 200 Returns {ok, message}.
function(req, res, email) {
  user <- require_admin(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  tryCatch(
    {
      db_users$update(
        query = toJSON(list(email = email), auto_unbox = TRUE),
        update = toJSON(list(`$set` = list(
          review_status = "approved",
          reviewed_by = user$sub,
          reviewed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
        )), auto_unbox = TRUE)
      )
      list(ok = TRUE, message = paste("Account approved:", email))
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Reject an institutional account.
#* Sets review_status to "rejected".
#* Requires admin JWT.
#* @tag Admin
#* @post /admin/reject/<email>
#* @response 200 Returns {ok, message}.
function(req, res, email) {
  user <- require_admin(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  tryCatch(
    {
      db_users$update(
        query = toJSON(list(email = email), auto_unbox = TRUE),
        update = toJSON(list(`$set` = list(
          review_status = "rejected",
          reviewed_by = user$sub,
          reviewed_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
        )), auto_unbox = TRUE)
      )
      list(ok = TRUE, message = paste("Account rejected:", email))
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

# ==============================================================================
# RECIPES
# ==============================================================================

#* List recipes with optional search,
#* filtering, and pagination.
#* Sorted by downloads descending.
#* @tag Recipes
#* @get /recipes
#* @param search:str Regex search on recipe name
#* @param survey_type:str Filter by survey type: ech, eaii, eph, eai
#* @param topic:str Filter by topic:
#*   labor_market, income, education,
#*   health, demographics, housing
#* @param certification:str Filter by
#*   certification level: community,
#*   reviewed, official
#* @param user:str Filter by author email
#* @param limit:int Max results (default 50)
#* @param offset:int Skip N results for pagination (default 0)
#* @response 200 Returns {ok, count,
#*   recipes: [{id, name, user,
#*   survey_type, edition, description,
#*   topic, version, downloads, steps,
#*   depends_on, certification,
#*   user_info, doc, ...}]}.
function(req, res, search = NULL, survey_type = NULL, topic = NULL,
         certification = NULL, user = NULL, limit = 50, offset = 0) {
  cache_key <- sprintf(
    "cache:recipes_list:%s",
    cache_params_hash(
      search = search %||% "", survey_type = survey_type %||% "",
      topic = topic %||% "", certification = certification %||% "",
      user = user %||% "", limit = as.integer(limit),
      offset = as.integer(offset)
    )
  )
  cached <- cache_get(cache_key)
  if (!is.null(cached)) {
    return(cached)
  }

  filter <- list()
  if (!is.null(survey_type) && nzchar(survey_type)) {
    filter$survey_type <- survey_type
  }
  if (!is.null(topic) && nzchar(topic)) {
    filter$topic <- topic
  }
  if (!is.null(certification) && nzchar(certification)) {
    filter[["certification.level"]] <- certification
  }
  if (!is.null(user) && nzchar(user)) {
    filter$user <- user
  }

  if (!is.null(search) && nzchar(search)) {
    filter$name <- list(`$regex` = search, `$options` = "i")
  }

  query_json <- if (length(filter) == 0) {
    "{}"
  } else {
    toJSON(filter, auto_unbox = TRUE)
  }

  tryCatch(
    {
      iter <- db_recipes$iterate(
        query = query_json,
        sort = '{"downloads": -1}',
        skip = as.integer(offset),
        limit = as.integer(limit)
      )

      docs <- list()
      while (!is.null(doc <- iter$one())) {
        doc[["_id"]] <- NULL
        # Strip email from public responses
        if (!is.null(doc$user_info)) {
          doc$user_info$email <- NULL
        }
        docs[[length(docs) + 1L]] <- doc
      }

      result <- list(ok = TRUE, count = length(docs), recipes = docs)
      cache_set(cache_key, result, 60L)
      result
    },
    error = function(e) {
      res$status <- 500L
      list(error = paste("Failed to fetch recipes:", e$message))
    }
  )
}

#* Get a single recipe by its unique ID.
#* @tag Recipes
#* @get /recipes/<id>
#* @response 200 Returns {ok, recipe: {id, name, user, survey_type, ...}}.
#* @response 404 Recipe not found.
function(req, res, id) {
  cache_key <- sprintf("cache:recipe:%s", id)
  cached <- cache_get(cache_key)
  if (!is.null(cached)) {
    return(cached)
  }

  tryCatch(
    {
      iter <- db_recipes$iterate(
        query = toJSON(list(id = id), auto_unbox = TRUE),
        limit = 1
      )
      doc <- iter$one()

      if (is.null(doc)) {
        res$status <- 404L
        return(list(error = "Recipe not found"))
      }

      doc[["_id"]] <- NULL
      if (!is.null(doc$user_info)) doc$user_info$email <- NULL
      result <- list(ok = TRUE, recipe = doc)
      cache_set(cache_key, result, 300L)
      result
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Publish a new recipe. Requires JWT
#* authentication. Send the recipe as
#* JSON body with required fields: name,
#* survey_type, edition. Optional:
#* description, topic, steps, depends_on,
#* categories, version, doc.
#* @tag Recipes
#* @post /recipes
#* @response 201 Returns {ok, id}.
#* @response 400 Missing required fields.
#* @response 401 Authentication required.
function(req, res) {
  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  body <- req$body
  if (is.null(body)) {
    res$status <- 400L
    return(list(error = "Request body is required"))
  }

  # Validate required fields
  required <- c("name", "survey_type", "edition")
  missing_fields <- required[!required %in% names(body)]
  if (length(missing_fields) > 0) {
    res$status <- 400L
    return(list(error = paste(
      "Missing required fields:",
      paste(missing_fields, collapse = ", ")
    )))
  }

  # Set metadata
  body$user <- user$sub # email from JWT
  body$downloads <- 0L
  body$created_at <- format(
    Sys.time(), "%Y-%m-%dT%H:%M:%SZ"
  )
  if (is.null(body$id)) {
    body$id <- paste0(
      "r_", as.integer(Sys.time()),
      "_", sample.int(999, 1)
    )
  }
  if (is.null(body$version)) body$version <- "1.0.0"
  if (is.null(body$certification)) {
    body$certification <- list(
      level = "community",
      certified_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
    )
  }
  if (is.null(body$user_info)) {
    body$user_info <- list(
      name = user$name,
      user_type = user$user_type,
      email = user$sub
    )
  }

  tryCatch(
    {
      db_recipes$insert(toJSON(body, auto_unbox = TRUE, null = "null"))
      cache_del_pattern("cache:recipes_list:*")
      res$status <- 201L
      list(ok = TRUE, id = body$id)
    },
    error = function(e) {
      res$status <- 500L
      list(error = paste("Failed to publish recipe:", e$message))
    }
  )
}

#* Increment recipe download counter. No authentication required.
#* @tag Recipes
#* @post /recipes/<id>/download
#* @response 200 Returns {ok}.
function(req, res, id) {
  tryCatch(
    {
      db_recipes$update(
        query = toJSON(list(id = id), auto_unbox = TRUE),
        update = '{"$inc": {"downloads": 1}}'
      )
      cache_del(sprintf("cache:recipe:%s", id))
      cache_del_pattern("cache:recipes_list:*")
      list(ok = TRUE)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Rate a recipe (1-5). Requires authentication.
#* Creates or updates the user's rating for this recipe.
#* @tag Recipes
#* @put /recipes/<id>/star
#* @response 200 Returns {ok, value}.
#* @response 401 Unauthorized.
function(req, res, id) {
  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) list())
  value <- as.integer(body$value)
  if (is.na(value) || value < 1L || value > 5L) {
    res$status <- 400L
    return(list(error = "value must be an integer between 1 and 5"))
  }

  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  tryCatch(
    {
      db_stars$update(
        query = toJSON(list(
          user = user$sub,
          target_type = "recipe",
          target_id = id
        ), auto_unbox = TRUE),
        update = toJSON(list(
          `$set` = list(value = value, updated_at = now),
          `$setOnInsert` = list(
            user = user$sub,
            target_type = "recipe",
            target_id = id,
            created_at = now
          )
        ), auto_unbox = TRUE),
        upsert = TRUE
      )
      cache_del(sprintf("cache:recipe:%s", id))
      list(ok = TRUE, value = value)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Get star summary for a recipe.
#* Returns average rating, count, and the current
#* user's rating if authenticated.
#* @tag Recipes
#* @get /recipes/<id>/stars
#* @response 200 Returns {average, count, user_value}.
function(req, res, id) {
  tryCatch(
    {
      query <- toJSON(list(
        target_type = "recipe", target_id = id
      ), auto_unbox = TRUE)
      all_stars <- db_stars$find(query, fields = '{"value": 1, "user": 1, "_id": 0}')
      count <- nrow(all_stars)
      average <- if (count > 0) round(mean(all_stars$value), 2) else 0

      user_value <- NULL
      token <- sub("^Bearer\\s+", "", req$HTTP_AUTHORIZATION %||% "")
      if (nzchar(token)) {
        user <- tryCatch(decode_token(token), error = function(e) NULL)
        if (!is.null(user)) {
          user_row <- all_stars[all_stars$user == user$sub, ]
          if (nrow(user_row) > 0) user_value <- user_row$value[1]
        }
      }

      list(average = average, count = count, user_value = user_value)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Add a comment to a recipe. Requires authentication.
#* @tag Recipes
#* @post /recipes/<id>/comments
#* @response 200 Returns {ok, comment}.
#* @response 401 Unauthorized.
function(req, res, id) {
  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) list())
  text <- trimws(body$text %||% "")
  if (!nzchar(text)) {
    res$status <- 400L
    return(list(error = "text is required"))
  }
  if (nchar(text) > 2000L) {
    res$status <- 400L
    return(list(error = "text must be 2000 characters or fewer"))
  }

  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  comment_id <- paste0("c_", as.integer(Sys.time()), "_", sample(999, 1))

  comment <- list(
    id = comment_id,
    user = user$sub,
    user_name = user$name,
    target_type = "recipe",
    target_id = id,
    text = text,
    created_at = now
  )

  tryCatch(
    {
      db_comments$insert(toJSON(comment, auto_unbox = TRUE, null = "null"))
      list(ok = TRUE, comment = comment)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* List comments for a recipe, sorted by date ascending.
#* @tag Recipes
#* @get /recipes/<id>/comments
#* @response 200 Returns {comments}.
function(req, res, id) {
  tryCatch(
    {
      query <- toJSON(list(
        target_type = "recipe", target_id = id
      ), auto_unbox = TRUE)
      comments <- db_comments$find(
        query,
        sort = '{"created_at": 1}',
        fields = '{"_id": 0}'
      )
      list(comments = comments)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Get recipes that depend on this recipe (backlinks).
#* @tag Recipes
#* @get /recipes/<id>/dependents
#* @response 200 Returns {dependents}.
function(req, res, id) {
  tryCatch(
    {
      query <- toJSON(list(
        depends_on_recipes = id
      ), auto_unbox = TRUE)
      deps <- db_recipes$find(
        query,
        fields = '{"_id": 0, "id": 1, "name": 1, "user": 1, "edition": 1, "survey_type": 1}'
      )
      list(dependents = deps)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

# ==============================================================================
# WORKFLOWS
# ==============================================================================

#* List workflows with optional search,
#* filtering, and pagination.
#* Sorted by downloads descending.
#* @tag Workflows
#* @get /workflows
#* @param search:str Regex search on workflow name
#* @param survey_type:str Filter by survey type: ech, eaii, eph, eai
#* @param recipe_id:str Filter by referenced recipe ID
#* @param user:str Filter by author email
#* @param limit:int Max results (default 50)
#* @param offset:int Skip N results for pagination (default 0)
#* @response 200 Returns {ok, count,
#*   workflows: [{id, name, user,
#*   survey_type, edition,
#*   estimation_type, recipe_ids,
#*   calls, ...}]}.
function(req, res, search = NULL, survey_type = NULL, recipe_id = NULL,
         user = NULL, limit = 50, offset = 0) {
  cache_key <- sprintf(
    "cache:wf_list:%s",
    cache_params_hash(
      search = search %||% "", survey_type = survey_type %||% "",
      recipe_id = recipe_id %||% "", user = user %||% "",
      limit = as.integer(limit), offset = as.integer(offset)
    )
  )
  cached <- cache_get(cache_key)
  if (!is.null(cached)) {
    return(cached)
  }

  filter <- list()
  if (!is.null(survey_type) && nzchar(survey_type)) {
    filter$survey_type <- survey_type
  }
  if (!is.null(recipe_id) && nzchar(recipe_id)) {
    filter$recipe_ids <- recipe_id
  }
  if (!is.null(user) && nzchar(user)) {
    filter$user <- user
  }
  if (!is.null(search) && nzchar(search)) {
    filter$name <- list(`$regex` = search, `$options` = "i")
  }

  query_json <- if (length(filter) == 0) {
    "{}"
  } else {
    toJSON(filter, auto_unbox = TRUE)
  }

  tryCatch(
    {
      iter <- db_workflows$iterate(
        query = query_json,
        sort = '{"downloads": -1}',
        skip = as.integer(offset),
        limit = as.integer(limit)
      )

      docs <- list()
      while (!is.null(doc <- iter$one())) {
        doc[["_id"]] <- NULL
        if (!is.null(doc$user_info)) doc$user_info$email <- NULL
        docs[[length(docs) + 1L]] <- doc
      }

      result <- list(ok = TRUE, count = length(docs), workflows = docs)
      cache_set(cache_key, result, 60L)
      result
    },
    error = function(e) {
      res$status <- 500L
      list(error = paste("Failed to fetch workflows:", e$message))
    }
  )
}

#* Get a single workflow by its unique ID.
#* @tag Workflows
#* @get /workflows/<id>
#* @response 200 Returns {ok, workflow: {id, name, user, survey_type, ...}}.
#* @response 404 Workflow not found.
function(req, res, id) {
  cache_key <- sprintf("cache:wf:%s", id)
  cached <- cache_get(cache_key)
  if (!is.null(cached)) {
    return(cached)
  }

  tryCatch(
    {
      iter <- db_workflows$iterate(
        query = toJSON(list(id = id), auto_unbox = TRUE),
        limit = 1
      )
      doc <- iter$one()

      if (is.null(doc)) {
        res$status <- 404L
        return(list(error = "Workflow not found"))
      }

      doc[["_id"]] <- NULL
      if (!is.null(doc$user_info)) doc$user_info$email <- NULL
      result <- list(ok = TRUE, workflow = doc)
      cache_set(cache_key, result, 300L)
      result
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Publish a new workflow. Requires JWT
#* authentication. Send the workflow as
#* JSON body with required fields: name,
#* survey_type, edition. Optional:
#* description, estimation_type,
#* recipe_ids, calls, call_metadata,
#* categories, version.
#* @tag Workflows
#* @post /workflows
#* @response 201 Returns {ok, id}.
#* @response 400 Missing required fields.
#* @response 401 Authentication required.
function(req, res) {
  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  body <- req$body
  if (is.null(body)) {
    res$status <- 400L
    return(list(error = "Request body is required"))
  }

  required <- c("name", "survey_type", "edition")
  missing_fields <- required[!required %in% names(body)]
  if (length(missing_fields) > 0) {
    res$status <- 400L
    return(list(error = paste(
      "Missing required fields:",
      paste(missing_fields, collapse = ", ")
    )))
  }

  body$user <- user$sub
  body$downloads <- 0L
  body$created_at <- format(
    Sys.time(), "%Y-%m-%dT%H:%M:%SZ"
  )
  if (is.null(body$id)) {
    body$id <- paste0(
      "wf_", as.integer(Sys.time()),
      "_", sample.int(999, 1)
    )
  }
  if (is.null(body$version)) body$version <- "1.0.0"
  if (is.null(body$certification)) {
    body$certification <- list(
      level = "community",
      certified_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
    )
  }
  if (is.null(body$user_info)) {
    body$user_info <- list(
      name = user$name,
      user_type = user$user_type,
      email = user$sub
    )
  }

  tryCatch(
    {
      db_workflows$insert(toJSON(body, auto_unbox = TRUE, null = "null"))
      cache_del_pattern("cache:wf_list:*")
      res$status <- 201L
      list(ok = TRUE, id = body$id)
    },
    error = function(e) {
      res$status <- 500L
      list(error = paste("Failed to publish workflow:", e$message))
    }
  )
}

#* Increment workflow download counter. No authentication required.
#* @tag Workflows
#* @post /workflows/<id>/download
#* @response 200 Returns {ok}.
function(req, res, id) {
  tryCatch(
    {
      db_workflows$update(
        query = toJSON(list(id = id), auto_unbox = TRUE),
        update = '{"$inc": {"downloads": 1}}'
      )
      cache_del(sprintf("cache:wf:%s", id))
      cache_del_pattern("cache:wf_list:*")
      list(ok = TRUE)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Rate a workflow (1-5). Requires authentication.
#* @tag Workflows
#* @put /workflows/<id>/star
#* @response 200 Returns {ok, value}.
function(req, res, id) {
  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) list())
  value <- as.integer(body$value)
  if (is.na(value) || value < 1L || value > 5L) {
    res$status <- 400L
    return(list(error = "value must be an integer between 1 and 5"))
  }

  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  tryCatch(
    {
      db_stars$update(
        query = toJSON(list(
          user = user$sub,
          target_type = "workflow",
          target_id = id
        ), auto_unbox = TRUE),
        update = toJSON(list(
          `$set` = list(value = value, updated_at = now),
          `$setOnInsert` = list(
            user = user$sub,
            target_type = "workflow",
            target_id = id,
            created_at = now
          )
        ), auto_unbox = TRUE),
        upsert = TRUE
      )
      cache_del(sprintf("cache:wf:%s", id))
      list(ok = TRUE, value = value)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Get star summary for a workflow.
#* @tag Workflows
#* @get /workflows/<id>/stars
#* @response 200 Returns {average, count, user_value}.
function(req, res, id) {
  tryCatch(
    {
      query <- toJSON(list(
        target_type = "workflow", target_id = id
      ), auto_unbox = TRUE)
      all_stars <- db_stars$find(query, fields = '{"value": 1, "user": 1, "_id": 0}')
      count <- nrow(all_stars)
      average <- if (count > 0) round(mean(all_stars$value), 2) else 0

      user_value <- NULL
      token <- sub("^Bearer\\s+", "", req$HTTP_AUTHORIZATION %||% "")
      if (nzchar(token)) {
        user <- tryCatch(decode_token(token), error = function(e) NULL)
        if (!is.null(user)) {
          user_row <- all_stars[all_stars$user == user$sub, ]
          if (nrow(user_row) > 0) user_value <- user_row$value[1]
        }
      }

      list(average = average, count = count, user_value = user_value)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Add a comment to a workflow. Requires authentication.
#* @tag Workflows
#* @post /workflows/<id>/comments
#* @response 200 Returns {ok, comment}.
function(req, res, id) {
  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) list())
  text <- trimws(body$text %||% "")
  if (!nzchar(text)) {
    res$status <- 400L
    return(list(error = "text is required"))
  }
  if (nchar(text) > 2000L) {
    res$status <- 400L
    return(list(error = "text must be 2000 characters or fewer"))
  }

  now <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  comment_id <- paste0("c_", as.integer(Sys.time()), "_", sample(999, 1))

  comment <- list(
    id = comment_id,
    user = user$sub,
    user_name = user$name,
    target_type = "workflow",
    target_id = id,
    text = text,
    created_at = now
  )

  tryCatch(
    {
      db_comments$insert(toJSON(comment, auto_unbox = TRUE, null = "null"))
      list(ok = TRUE, comment = comment)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* List comments for a workflow, sorted by date ascending.
#* @tag Workflows
#* @get /workflows/<id>/comments
#* @response 200 Returns {comments}.
function(req, res, id) {
  tryCatch(
    {
      query <- toJSON(list(
        target_type = "workflow", target_id = id
      ), auto_unbox = TRUE)
      comments <- db_comments$find(
        query,
        sort = '{"created_at": 1}',
        fields = '{"_id": 0}'
      )
      list(comments = comments)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

# ==============================================================================
# COMMENTS (cross-type)
# ==============================================================================

#* Delete a comment. Only the author can delete their own comments.
#* @tag Comments
#* @delete /comments/<comment_id>
#* @response 200 Returns {ok}.
#* @response 401 Unauthorized.
#* @response 403 Forbidden — not the comment author.
function(req, res, comment_id) {
  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  tryCatch(
    {
      query <- toJSON(list(id = comment_id), auto_unbox = TRUE)
      existing <- db_comments$find(query, fields = '{"user": 1, "_id": 0}')
      if (nrow(existing) == 0) {
        res$status <- 404L
        return(list(error = "Comment not found"))
      }
      if (existing$user[1] != user$sub) {
        res$status <- 403L
        return(list(error = "You can only delete your own comments"))
      }
      db_comments$remove(query)
      list(ok = TRUE)
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

# ==============================================================================
# INDICATORS
# Feature-gated: set METASURVEY_ENABLE_INDICATORS=0 to disable
# ==============================================================================

require_indicators <- function(res) {
  if (!ENABLE_INDICATORS) {
    res$status <- 404L
    return(list(error = "Indicators module is disabled"))
  }
  NULL
}

require_worker <- function(res) {
  if (!ENABLE_WORKER || !nzchar(WORKER_URL)) {
    res$status <- 404L
    return(list(error = "Worker module is disabled"))
  }
  NULL
}

#* List published indicators with optional
#* search, filtering, and pagination.
#* Sorted by published_at descending.
#* No authentication required.
#* @tag Indicators
#* @get /indicators
#* @param search:str Regex search on indicator name
#* @param survey_type:str Filter by survey type
#* @param recipe_id:str Filter by recipe ID
#* @param workflow_id:str Filter by workflow ID
#* @param edition:str Filter by survey edition
#* @param limit:int Max results (default 50)
#* @param offset:int Skip N results (default 0)
#* @response 200 Returns {ok, count,
#*   indicators: [{id, name, value, se,
#*   cv, recipe_id, workflow_id, ...}]}.
function(req, res, search = NULL,
         survey_type = NULL,
         recipe_id = NULL,
         workflow_id = NULL,
         edition = NULL,
         limit = 50, offset = 0) {
  guard <- require_indicators(res)
  if (!is.null(guard)) {
    return(guard)
  }

  cache_key <- sprintf(
    "cache:ind_list:%s",
    cache_params_hash(
      search = search %||% "", survey_type = survey_type %||% "",
      recipe_id = recipe_id %||% "", workflow_id = workflow_id %||% "",
      edition = edition %||% "", limit = as.integer(limit),
      offset = as.integer(offset)
    )
  )
  cached <- cache_get(cache_key)
  if (!is.null(cached)) {
    return(cached)
  }

  filter <- list()
  if (!is.null(survey_type) && nzchar(survey_type)) {
    filter$survey_type <- survey_type
  }
  if (!is.null(recipe_id) && nzchar(recipe_id)) {
    filter$recipe_id <- recipe_id
  }
  if (!is.null(workflow_id) && nzchar(workflow_id)) {
    filter$workflow_id <- workflow_id
  }
  if (!is.null(edition) && nzchar(edition)) {
    filter$edition <- edition
  }
  if (!is.null(search) && nzchar(search)) {
    filter$name <- list(
      `$regex` = search,
      `$options` = "i"
    )
  }

  query_json <- if (length(filter) == 0) {
    "{}"
  } else {
    toJSON(filter, auto_unbox = TRUE)
  }

  tryCatch(
    {
      iter <- db_indicators$iterate(
        query = query_json,
        sort = '{"published_at": -1}',
        skip = as.integer(offset),
        limit = as.integer(limit)
      )

      docs <- list()
      while (!is.null(doc <- iter$one())) {
        doc[["_id"]] <- NULL
        if (!is.null(doc$user_info)) doc$user_info$email <- NULL
        docs[[length(docs) + 1L]] <- doc
      }

      result <- list(ok = TRUE, count = length(docs), indicators = docs)
      cache_set(cache_key, result, 60L)
      result
    },
    error = function(e) {
      res$status <- 500L
      list(error = paste(
        "Failed to fetch indicators:",
        e$message
      ))
    }
  )
}

#* Get a single indicator by its unique ID.
#* No authentication required.
#* @tag Indicators
#* @get /indicators/<id>
#* @response 200 Returns {ok, indicator:
#*   {id, name, value, se, cv,
#*   confint_lower, confint_upper,
#*   recipe_id, workflow_id, ...}}.
#* @response 404 Indicator not found.
function(req, res, id) {
  guard <- require_indicators(res)
  if (!is.null(guard)) {
    return(guard)
  }

  cache_key <- sprintf("cache:ind:%s", id)
  cached <- cache_get(cache_key)
  if (!is.null(cached)) {
    return(cached)
  }

  tryCatch(
    {
      iter <- db_indicators$iterate(
        query = toJSON(
          list(id = id),
          auto_unbox = TRUE
        ),
        limit = 1
      )
      doc <- iter$one()

      if (is.null(doc)) {
        res$status <- 404L
        return(list(error = "Indicator not found"))
      }

      doc[["_id"]] <- NULL
      if (!is.null(doc$user_info)) doc$user_info$email <- NULL
      result <- list(ok = TRUE, indicator = doc)
      cache_set(cache_key, result, 3600L)
      result
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Get the recipe that produced an indicator.
#* Shows the data transformation steps
#* (input variables, recodes, computations).
#* No authentication required.
#* @tag Indicators
#* @get /indicators/<id>/recipe
#* @response 200 Returns {ok, indicator_id,
#*   recipe: {id, name, steps, doc, ...}}.
#* @response 404 Indicator not found.
function(req, res, id) {
  guard <- require_indicators(res)
  if (!is.null(guard)) {
    return(guard)
  }

  cache_key <- sprintf("cache:ind_recipe:%s", id)
  cached <- cache_get(cache_key)
  if (!is.null(cached)) {
    return(cached)
  }

  tryCatch(
    {
      iter <- db_indicators$iterate(
        query = toJSON(
          list(id = id),
          auto_unbox = TRUE
        ),
        limit = 1
      )
      ind <- iter$one()

      if (is.null(ind)) {
        res$status <- 404L
        return(list(error = "Indicator not found"))
      }

      rid <- ind$recipe_id
      if (is.null(rid) || !nzchar(rid)) {
        return(list(
          ok = TRUE,
          indicator_id = id,
          recipe = NULL,
          message = "No recipe linked to this indicator"
        ))
      }

      riter <- db_recipes$iterate(
        query = toJSON(
          list(id = rid),
          auto_unbox = TRUE
        ),
        limit = 1
      )
      rdoc <- riter$one()
      if (!is.null(rdoc)) {
        rdoc[["_id"]] <- NULL
        if (!is.null(rdoc$user_info)) rdoc$user_info$email <- NULL
      }

      result <- list(ok = TRUE, indicator_id = id, recipe = rdoc)
      cache_set(cache_key, result, 3600L)
      result
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Get the workflow that produced an indicator.
#* Shows the estimation calls (svymean,
#* svytotal, svyby), design type,
#* and referenced recipe IDs.
#* No authentication required.
#* @tag Indicators
#* @get /indicators/<id>/workflow
#* @response 200 Returns {ok, indicator_id,
#*   workflow: {id, name, estimation_type,
#*   calls, call_metadata,
#*   recipe_ids, ...}}.
#* @response 404 Indicator not found.
function(req, res, id) {
  guard <- require_indicators(res)
  if (!is.null(guard)) {
    return(guard)
  }

  cache_key <- sprintf("cache:ind_wf:%s", id)
  cached <- cache_get(cache_key)
  if (!is.null(cached)) {
    return(cached)
  }

  tryCatch(
    {
      iter <- db_indicators$iterate(
        query = toJSON(
          list(id = id),
          auto_unbox = TRUE
        ),
        limit = 1
      )
      ind <- iter$one()

      if (is.null(ind)) {
        res$status <- 404L
        return(list(error = "Indicator not found"))
      }

      wid <- ind$workflow_id
      if (is.null(wid) || !nzchar(wid)) {
        return(list(
          ok = TRUE,
          indicator_id = id,
          workflow = NULL,
          message = "No workflow linked"
        ))
      }

      witer <- db_workflows$iterate(
        query = toJSON(
          list(id = wid),
          auto_unbox = TRUE
        ),
        limit = 1
      )
      wdoc <- witer$one()
      if (!is.null(wdoc)) {
        wdoc[["_id"]] <- NULL
        if (!is.null(wdoc$user_info)) wdoc$user_info$email <- NULL
      }

      result <- list(ok = TRUE, indicator_id = id, workflow = wdoc)
      cache_set(cache_key, result, 3600L)
      result
    },
    error = function(e) {
      res$status <- 500L
      list(error = e$message)
    }
  )
}

#* Publish a new indicator. Requires JWT
#* authentication. Required fields: name,
#* workflow_id, value. Optional: recipe_id,
#* description, survey_type, edition,
#* estimation_type, stat, se, cv,
#* confint_lower, confint_upper, metadata.
#* @tag Indicators
#* @post /indicators
#* @response 201 Returns {ok, id}.
#* @response 400 Missing required fields.
#* @response 401 Authentication required.
function(req, res) {
  guard <- require_indicators(res)
  if (!is.null(guard)) {
    return(guard)
  }

  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  body <- req$body
  if (is.null(body)) {
    res$status <- 400L
    return(list(error = "Request body is required"))
  }

  required <- c("name", "workflow_id", "value")
  missing_fields <- required[
    !required %in% names(body)
  ]
  if (length(missing_fields) > 0) {
    res$status <- 400L
    return(list(error = paste(
      "Missing required fields:",
      paste(missing_fields, collapse = ", ")
    )))
  }

  body$user <- user$sub
  body$published_at <- format(
    Sys.time(), "%Y-%m-%dT%H:%M:%SZ"
  )
  body$metasurvey_version <- "0.0.16"
  if (is.null(body$id)) {
    body$id <- paste0(
      "ind_", as.integer(Sys.time()),
      "_", sample.int(999, 1)
    )
  }
  if (is.null(body$user_info)) {
    body$user_info <- list(
      name = user$name,
      user_type = user$user_type,
      email = user$sub
    )
  }

  tryCatch(
    {
      db_indicators$insert(toJSON(
        body,
        auto_unbox = TRUE,
        null = "null"
      ))
      cache_del_pattern("cache:ind_list:*")
      res$status <- 201L
      list(ok = TRUE, id = body$id)
    },
    error = function(e) {
      res$status <- 500L
      list(error = paste(
        "Failed to publish indicator:",
        e$message
      ))
    }
  )
}

# -- Synchronous compute helper (used as fallback when async is off) ----------

.compute_sync <- function(body, user, res) {
  tryCatch(
    {
      worker_resp <- httr2::request(
        paste0(WORKER_URL, "/compute")
      ) |>
        httr2::req_body_json(body) |>
        httr2::req_timeout(300) |>
        httr2::req_perform()

      worker_result <- httr2::resp_body_json(worker_resp)

      if (!isTRUE(worker_result$ok)) {
        res$status <- 502L
        return(list(
          error = "Worker computation failed",
          detail = worker_result$error
        ))
      }

      indicator_ids <- character(0)
      results <- worker_result$results

      for (r in results) {
        ind_id <- paste0(
          "ind_", as.integer(Sys.time()),
          "_", sample.int(9999, 1)
        )

        ind_doc <- list(
          id = ind_id,
          name = r$stat %||% "Computed indicator",
          workflow_id = body$workflow_id,
          recipe_id = if (length(body$recipe_ids) > 0) {
            body$recipe_ids[[1]]
          } else {
            NULL
          },
          survey_type = body$survey_type,
          edition = body$edition,
          estimation_type = body$estimation_type %||% "annual",
          stat = r$stat,
          value = r$value,
          se = r$se,
          cv = r$cv,
          confint_lower = r$confint_lower,
          confint_upper = r$confint_upper,
          metadata = list(
            call = r$call,
            by_group = r$by_group,
            filters = body$filters,
            computed_on_demand = TRUE
          ),
          user = user$sub,
          user_info = list(
            name = user$name,
            user_type = user$user_type,
            email = user$sub
          ),
          published_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
          metasurvey_version = "0.0.16"
        )

        db_indicators$insert(toJSON(
          ind_doc,
          auto_unbox = TRUE, null = "null"
        ))
        indicator_ids <- c(indicator_ids, ind_id)
      }

      cache_del_pattern("cache:ind_list:*")

      list(
        ok = TRUE,
        indicator_ids = indicator_ids,
        count = length(results),
        results = results
      )
    },
    error = function(e) {
      res$status <- 502L
      list(error = paste("Worker request failed:", e$message))
    }
  )
}

#* Request an on-demand computation.
#* When async mode is enabled (Redis + METASURVEY_ENABLE_ASYNC=1),
#* returns 202 Accepted with a job_id. Poll GET /jobs/<job_id>
#* for status and results.
#* When async is disabled, runs synchronously (original behavior).
#*
#* @tag Indicators
#* @post /indicators/compute
#* @response 200 Synchronous result: {ok, indicator_ids, count, results}.
#* @response 202 Job accepted (async): {ok, job_id, status, poll_url}.
#* @response 400 Missing fields or no worker.
#* @response 401 Authentication required.
#* @response 502 Worker unavailable or error.
function(req, res) {
  guard <- require_indicators(res)
  if (!is.null(guard)) {
    return(guard)
  }
  guard <- require_worker(res)
  if (!is.null(guard)) {
    return(guard)
  }

  user <- require_auth(req, res)
  if (is.list(user) && !is.null(user$error)) {
    return(user)
  }

  body <- req$body
  if (is.null(body)) {
    res$status <- 400L
    return(list(error = "Request body is required"))
  }

  required <- c("workflow_id", "survey_type", "edition")
  missing_fields <- required[!required %in% names(body)]
  if (length(missing_fields) > 0) {
    res$status <- 400L
    return(list(error = paste(
      "Missing required fields:",
      paste(missing_fields, collapse = ", ")
    )))
  }

  # Async path: Redis available + feature flag on
  if (ENABLE_ASYNC && !is.null(redis_con)) {
    job_id <- make_job_id()

    job_data <- list(
      job_id    = job_id,
      status    = "queued",
      params    = body,
      user      = user$sub,
      user_name = user$name,
      user_type = user$user_type,
      queued_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
    )

    job_set(job_id, job_data)
    job_enqueue(job_id)

    res$status <- 202L
    return(list(
      ok       = TRUE,
      job_id   = job_id,
      status   = "queued",
      poll_url = paste0("/jobs/", job_id)
    ))
  }

  # Synchronous fallback (original behavior)
  .compute_sync(body, user, res)
}

#* Poll the status of an async computation job.
#* Returns queued, running, completed, or failed.
#* Results are included when status is "completed".
#*
#* @tag Jobs
#* @get /jobs/<job_id>
#* @response 200 Returns {ok, job_id, status, [results], [error]}.
#* @response 404 Job not found or expired.
#* @response 503 Redis unavailable.
function(req, res, job_id) {
  if (is.null(redis_con)) {
    res$status <- 503L
    return(list(error = "Async jobs unavailable (Redis not configured)"))
  }

  job <- job_get(job_id)

  if (is.null(job)) {
    res$status <- 404L
    return(list(error = "Job not found or expired"))
  }

  out <- list(
    ok          = TRUE,
    job_id      = job$job_id,
    status      = job$status,
    queued_at   = job$queued_at,
    started_at  = job$started_at,
    finished_at = job$finished_at
  )

  if (identical(job$status, "completed")) {
    out$indicator_ids <- job$indicator_ids
    out$count <- job$count
    out$results <- job$results
  } else if (identical(job$status, "failed")) {
    out$error <- job$error
  }

  out
}

# ==============================================================================
# ANDA METADATA
# ==============================================================================

#* Get ANDA variable metadata from INE
#* Uruguay's data catalog. Returns variable
#* labels, types, and value categories.
#* @tag ANDA
#* @param survey_type:str Survey type (default "ech")
#* @param names:str Comma-separated variable names (returns all if empty)
#* @get /anda/variables
#* @response 200 Returns {ok, count,
#*   variables: [{survey_type, name,
#*   label, type, value_labels,
#*   description, source_edition,
#*   source_catalog_id}]}.
function(survey_type = "ech", names = "") {
  names_key <- if (nzchar(names)) {
    digest::digest(sort(tolower(trimws(strsplit(names, ",")[[1]]))),
      algo = "xxhash32", serialize = TRUE
    )
  } else {
    "all"
  }
  cache_key <- sprintf("cache:anda:%s:%s", survey_type, names_key)
  cached <- cache_get(cache_key)
  if (!is.null(cached)) {
    return(cached)
  }

  query <- list(survey_type = survey_type)

  if (nzchar(names)) {
    var_names <- trimws(strsplit(names, ",")[[1]])
    var_names <- tolower(var_names)
    query$name <- list(`$in` = var_names)
  }

  query_json <- jsonlite::toJSON(query, auto_unbox = TRUE)
  docs <- db_anda$find(query_json, fields = '{"_id": 0}')

  result <- list(ok = TRUE, count = nrow(docs), variables = docs)
  cache_set(cache_key, result, 86400L)
  result
}

# ==============================================================================
# HEALTH
# ==============================================================================

#* API health check. Returns service status
#* and MongoDB connection state.
#* No authentication required.
#* @tag System
#* @get /health
#* @response 200 Returns {status, service,
#*   version, database, mongodb, timestamp}.
function() {
  ok <- tryCatch(
    {
      db_users$count()
      TRUE
    },
    error = function(e) FALSE
  )

  redis_ok <- if (!is.null(redis_con)) {
    tryCatch(
      {
        as.character(redis_con$PING()) == "PONG"
      },
      error = function(e) FALSE
    )
  } else {
    NA
  }

  list(
    status = if (ok) "ok" else "degraded",
    service = "metasurvey-api",
    version = "2.0.0",
    database = DATABASE,
    mongodb = if (ok) "connected" else "disconnected",
    redis = if (is.na(redis_ok)) {
      "disabled"
    } else if (redis_ok) {
      "connected"
    } else {
      "disconnected"
    },
    async = ENABLE_ASYNC && !is.null(redis_con),
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ")
  )
}
