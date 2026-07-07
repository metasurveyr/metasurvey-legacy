# Auth Module: Login + Register

auth_ui <- function(id) {
  ns <- shiny::NS(id)

  htmltools::tags$div(
    class = "auth-layout",
    # Left: Branding panel
    htmltools::tags$div(
      class = "auth-branding",
      htmltools::tags$h2(
        bsicons::bs_icon("journal-code", size = "1.5rem"),
        " metasurvey"
      ),
      htmltools::tags$p(
        class = "tagline",
        "La plataforma abierta para compartir, descubrir y reutilizar",
        htmltools::tags$strong(" metodologias de encuestas."),
        " Construida por y para la comunidad estadistica."
      ),
      htmltools::tags$ul(
        class = "auth-feature-list",
        htmltools::tags$li(
          bsicons::bs_icon("send-check-fill", size = ".9rem"),
          htmltools::tags$span(
            htmltools::tags$strong("Publica tus recetas"),
            " — compartí tus pipelines con un DOI reproducible."
          )
        ),
        htmltools::tags$li(
          bsicons::bs_icon("arrow-repeat", size = ".9rem"),
          htmltools::tags$span(
            htmltools::tags$strong("Reutilizá workflows"),
            " — copiá estimaciones en una sola linea de R."
          )
        ),
        htmltools::tags$li(
          bsicons::bs_icon("key-fill", size = ".9rem"),
          htmltools::tags$span(
            htmltools::tags$strong("API Token personal"),
            " — acceede a la API desde cualquier entorno."
          )
        ),
        htmltools::tags$li(
          bsicons::bs_icon("star-fill", size = ".9rem"),
          htmltools::tags$span(
            htmltools::tags$strong("Califica y comentá"),
            " — da feedback y mejorá la calidad colectiva."
          )
        )
      ),
      # Social proof stats bar
      htmltools::tags$div(
        class = "auth-stats-bar",
        htmltools::tags$div(
          class = "auth-stat",
          htmltools::tags$span(class = "auth-stat-num", "100%"),
          htmltools::tags$span(class = "auth-stat-lbl", "Open Source")
        ),
        htmltools::tags$div(
          class = "auth-stat",
          htmltools::tags$span(class = "auth-stat-num", "Gratis"),
          htmltools::tags$span(class = "auth-stat-lbl", "Para siempre")
        ),
        htmltools::tags$div(
          class = "auth-stat",
          htmltools::tags$span(class = "auth-stat-num", "R"),
          htmltools::tags$span(class = "auth-stat-lbl", "Nativo")
        )
      )
    ),

    # Right: Form panel
    htmltools::tags$div(
      class = "auth-form-panel",
      shiny::tabsetPanel(
        id = ns("auth_tabs"), type = "pills",

        # Login Tab
        shiny::tabPanel(
          "Login",
          htmltools::tags$div(
            style = "padding-top: 1.25rem;",
            htmltools::tags$h3("Bienvenido de nuevo"),
            htmltools::tags$div(
              class = "auth-form-sub",
              "Accede a tus recetas y token API."
            ),
            shiny::textInput(ns("login_email"), "Email",
              placeholder = "tu@email.com"
            ),
            shiny::passwordInput(ns("login_password"), "Contrasena",
              placeholder = "Tu contrasena"
            ),
            htmltools::tags$div(style = "margin-top: .5rem;"),
            shiny::actionButton(ns("btn_login"), "Iniciar sesion",
              class = "btn-primary",
              icon = shiny::icon("sign-in-alt")
            ),
            htmltools::tags$div(
              class = "auth-switch-hint",
              "\u00bfAun no tenes cuenta?",
              htmltools::tags$strong(" Es gratis y lleva menos de 1 minuto.")
            ),
            shiny::uiOutput(ns("login_feedback"))
          )
        ),

        # Register Tab
        shiny::tabPanel(
          "Register",
          htmltools::tags$div(
            style = "padding-top: 1.25rem;",
            htmltools::tags$h3("Crear cuenta gratis"),
            htmltools::tags$div(
              class = "auth-form-sub",
              bsicons::bs_icon("lightning-charge-fill", size = ".8rem"),
              " Cuentas individuales activadas al instante."
            ),
            shiny::textInput(ns("reg_name"), "Nombre completo",
              placeholder = "Juan Perez"
            ),
            shiny::textInput(ns("reg_email"), "Email",
              placeholder = "tu@email.com"
            ),
            shiny::passwordInput(ns("reg_password"), "Contrasena",
              placeholder = "Min. 6 caracteres"
            ),
            shiny::selectInput(ns("reg_type"), "Tipo de cuenta",
              choices = c(
                "Individual (acceso inmediato)" = "individual",
                "Miembro institucional" = "institutional_member",
                "Institucion" = "institution"
              )
            ),
            shiny::conditionalPanel(
              condition = sprintf(
                "input['%s'] == 'institutional_member'",
                ns("reg_type")
              ),
              shiny::textInput(ns("reg_institution"), "Nombre de la institucion",
                placeholder = "ej. Instituto de Economia"
              )
            ),
            htmltools::tags$div(style = "margin-top: .75rem;"),
            shiny::actionButton(ns("btn_register"), "Crear cuenta",
              class = "btn-primary btn-register-cta",
              icon = shiny::icon("user-plus")
            ),
            htmltools::tags$div(
              class = "auth-legal-note",
              bsicons::bs_icon("shield-check", size = ".75rem"),
              " Sin spam. Sin tarjeta de credito. 100% gratis."
            ),
            shiny::uiOutput(ns("register_feedback"))
          )
        )
      )
    )
  )
}

auth_server <- function(id, auth_state) {
  shiny::moduleServer(id, function(input, output, session) {
    # Login
    shiny::observeEvent(input$btn_login, {
      email <- trimws(input$login_email)
      password <- input$login_password

      if (!nzchar(email) || !nzchar(password)) {
        output$login_feedback <- shiny::renderUI(
          htmltools::tags$div(
            class = "alert alert-warning mt-3",
            bsicons::bs_icon("exclamation-triangle-fill"),
            " Please fill in all fields."
          )
        )
        return()
      }

      result <- tryCatch(
        shiny_login(email, password),
        error = function(e) list(ok = FALSE, error = e$message)
      )

      if (isTRUE(result$ok)) {
        auth_state$user <- result$user
        auth_state$logged_in <- TRUE
        auth_state$email <- email
        auth_state$token <- result$token
        shiny::showNotification(
          paste("Welcome,", result$user$name, "!"),
          type = "message", duration = 3
        )
      } else if (!is.null(result$review_status) && result$review_status == "pending") {
        output$login_feedback <- shiny::renderUI(
          htmltools::tags$div(
            class = "alert alert-info mt-3",
            bsicons::bs_icon("hourglass-split"),
            paste0(
              " Your account is pending ",
              "admin review. You will be ",
              "notified once approved."
            )
          )
        )
      } else if (!is.null(result$review_status) && result$review_status == "rejected") {
        output$login_feedback <- shiny::renderUI(
          htmltools::tags$div(
            class = "alert alert-danger mt-3",
            bsicons::bs_icon("x-circle-fill"),
            paste0(
              " Your institutional account ",
              "was not approved. ",
              "Contact the administrator."
            )
          )
        )
      } else {
        output$login_feedback <- shiny::renderUI(
          htmltools::tags$div(
            class = "alert alert-danger mt-3",
            bsicons::bs_icon("x-circle-fill"),
            paste(" ", result$error %||% "Login failed.")
          )
        )
      }
    })

    # Register
    shiny::observeEvent(input$btn_register, {
      name <- trimws(input$reg_name)
      email <- trimws(input$reg_email)
      password <- input$reg_password
      user_type <- input$reg_type
      institution <- trimws(input$reg_institution %||% "")

      if (!nzchar(name) || !nzchar(email) || !nzchar(password)) {
        output$register_feedback <- shiny::renderUI(
          htmltools::tags$div(
            class = "alert alert-warning mt-3",
            bsicons::bs_icon("exclamation-triangle-fill"),
            " Please fill in all required fields."
          )
        )
        return()
      }

      if (nchar(password) < 6) {
        output$register_feedback <- shiny::renderUI(
          htmltools::tags$div(
            class = "alert alert-warning mt-3",
            bsicons::bs_icon("exclamation-triangle-fill"),
            " Password must be at least 6 characters."
          )
        )
        return()
      }

      inst_arg <- if (
        user_type == "institutional_member" &&
          nzchar(institution)
      ) {
        institution
      } else {
        NULL
      }

      result <- tryCatch(
        shiny_register(name, email, password, user_type, inst_arg),
        error = function(e) list(ok = FALSE, error = e$message)
      )

      if (isTRUE(result$ok) && isTRUE(result$pending)) {
        # Institutional account pending review
        output$register_feedback <- shiny::renderUI(
          htmltools::tags$div(
            class = "alert alert-info mt-3",
            bsicons::bs_icon("hourglass-split"),
            htmltools::tags$strong(" Account created!"),
            htmltools::tags$br(),
            "Institutional accounts require admin approval before activation. ",
            "You will be able to login once your account is reviewed."
          )
        )
      } else if (isTRUE(result$ok)) {
        auth_state$user <- result$user
        auth_state$logged_in <- TRUE
        auth_state$email <- email
        auth_state$token <- result$token
        shiny::showNotification(
          paste("Account created! Welcome,", name),
          type = "message", duration = 3
        )
      } else {
        output$register_feedback <- shiny::renderUI(
          htmltools::tags$div(
            class = "alert alert-danger mt-3",
            bsicons::bs_icon("x-circle-fill"),
            paste(" ", result$error %||% "Registration failed.")
          )
        )
      }
    })
  })
}
