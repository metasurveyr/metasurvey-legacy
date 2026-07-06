# Explore Module: Search, Filter, Grid

explore_ui <- function(id) {
  ns <- shiny::NS(id)

  htmltools::tagList(
    # Hero section
    hero_section_ui("recipes"),

    # Search & Filters
    htmltools::tags$div(
      class = "search-container",
      htmltools::tags$div(
        class = "search-row",
        htmltools::tags$div(
          class = "search-field",
          shiny::textInput(ns("search"), NULL,
            placeholder = "Search recipes...",
            width = "100%"
          )
        ),
        htmltools::tags$div(
          class = "filter-field",
          shiny::selectInput(ns("filter_svy"), NULL,
            choices = c(
              "Survey" = "", "ECH" = "ech", "EAII" = "eaii",
              "EPH" = "eph", "EAI" = "eai"
            ),
            width = "100%"
          )
        ),
        htmltools::tags$div(
          class = "filter-field",
          shiny::selectInput(ns("filter_category"), NULL,
            choices = c(
              "Category" = "",
              "Labor Market" = "labor_market",
              "Income" = "income",
              "Education" = "education",
              "Health" = "health",
              "Demographics" = "demographics",
              "Housing" = "housing"
            ),
            width = "100%"
          )
        ),
        htmltools::tags$div(
          class = "filter-field",
          shiny::selectInput(ns("filter_cert"), NULL,
            choices = c(
              "Certification" = "",
              "Official" = "official",
              "Reviewed" = "reviewed",
              "Community" = "community"
            ),
            width = "100%"
          )
        ),
        htmltools::tags$div(
          class = "refresh-field",
          shiny::actionButton(ns("btn_refresh"), "",
            icon = shiny::icon("sync"),
            class = "btn-outline-secondary btn-sm"
          )
        )
      )
    ),

    # Stats row
    shiny::uiOutput(ns("stats_row")),

    # Recipe grid
    shiny::uiOutput(ns("recipe_grid")),

    # Detail modal (hidden)
    shiny::uiOutput(ns("detail_modal"))
  )
}

explore_server <- function(
    id,
    auth_state,
    navigate_to_workflow = NULL,
    pending_recipe_id = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reactive: all recipes — start empty, load from API
    all_recipes <- shiny::reactiveVal(list())
    recipes_loaded <- shiny::reactiveVal(FALSE)

    # Counter for unique graph IDs
    graph_counter <- shiny::reactiveVal(0)

    # Track current modal recipe for star/comment observers
    current_modal_recipe <- shiny::reactiveValues(id = NULL)

    load_recipes <- function() {
      recipes <- tryCatch(
        shiny_fetch_recipes(),
        error = function(e) {
          list()
        }
      )
      if (length(recipes) > 0) {
        all_recipes(recipes)
        recipes_loaded(TRUE)
      }
    }

    # Load from API, auto-retry every 5s until recipes arrive
    shiny::observe({
      if (!recipes_loaded()) {
        load_recipes()
        if (!recipes_loaded()) {
          shiny::invalidateLater(5000)
        }
      }
    })

    # Refresh button
    shiny::observeEvent(input$btn_refresh, {
      load_recipes()
    })

    # Debounce search input to avoid excessive reactivity
    search_debounced <- shiny::reactive({
      input$search
    }) |> shiny::debounce(300)

    # Filtered recipes
    filtered <- shiny::reactive({
      recipes <- all_recipes()
      if (length(recipes) == 0) {
        return(list())
      }

      query <- tolower(trimws(search_debounced() %||% ""))
      svy <- input$filter_svy %||% ""
      category <- input$filter_category %||% ""
      cert <- input$filter_cert %||% ""

      # Filter
      result <- recipes
      if (nzchar(query)) {
        result <- Filter(function(r) {
          grepl(query, tolower(r$name %||% "")) ||
            grepl(query, tolower(r$description %||% ""))
        }, result)
      }
      if (nzchar(svy)) {
        result <- Filter(function(r) r$survey_type == svy, result)
      }
      if (nzchar(category)) {
        result <- Filter(function(r) {
          cat_names <- vapply(r$categories, function(c) c$name, character(1))
          category %in% cat_names || identical(r$topic, category)
        }, result)
      }
      if (nzchar(cert)) {
        result <- Filter(function(r) {
          (r$certification$level %||% "community") == cert
        }, result)
      }

      # Sort by downloads desc
      if (length(result) > 1) {
        dls <- vapply(result, function(r) r$downloads %||% 0L, integer(1))
        result <- result[order(dls, decreasing = TRUE)]
      }

      result
    })

    # Stats row
    output$stats_row <- shiny::renderUI({
      recipes <- all_recipes()
      n_total <- length(recipes)
      n_official <- sum(vapply(recipes, function(r) {
        (r$certification$level %||% "community") == "official"
      }, logical(1)))
      total_downloads <- sum(vapply(
        recipes,
        function(r) r$downloads %||% 0L,
        integer(1)
      ))

      htmltools::tags$div(
        style = paste0(
          "display: grid; ",
          "grid-template-columns: repeat(3, 1fr); ",
          "gap: 1rem; ",
          "margin-bottom: 1rem;"
        ),
        htmltools::tags$div(
          class = "stat-box",
          htmltools::tags$div(class = "stat-number", n_total),
          htmltools::tags$div(class = "stat-label", "Total Recipes")
        ),
        htmltools::tags$div(
          class = "stat-box",
          htmltools::tags$div(class = "stat-number", n_official),
          htmltools::tags$div(class = "stat-label", "Official")
        ),
        htmltools::tags$div(
          class = "stat-box",
          htmltools::tags$div(
            class = "stat-number",
            format_downloads(total_downloads)
          ),
          htmltools::tags$div(class = "stat-label", "Total Downloads")
        )
      )
    })

    # Recipe grid
    output$recipe_grid <- shiny::renderUI({
      recipes <- filtered()

      if (length(recipes) == 0) {
        if (!recipes_loaded()) {
          return(htmltools::tags$div(
            class = "empty-state",
            bsicons::bs_icon("arrow-repeat", size = "4rem"),
            htmltools::tags$h5("Loading recipes..."),
            htmltools::tags$p("Connecting to the recipe registry.")
          ))
        }
        return(htmltools::tags$div(
          class = "empty-state",
          bsicons::bs_icon("journal-x", size = "4rem"),
          htmltools::tags$h5("No recipes found"),
          htmltools::tags$p("Try adjusting your search or filters.")
        ))
      }

      cards <- lapply(seq_along(recipes), function(i) {
        recipe_card_ui(recipes[[i]], ns, i)
      })

      htmltools::tags$div(class = "recipe-grid", cards)
    })

    # Helper: open recipe detail modal
    open_recipe_modal <- function(recipe) {
      # Increment downloads
      tryCatch(
        shiny_increment_downloads(recipe$id),
        error = function(e) NULL
      )

      # Find workflows that reference this recipe
      referencing_workflows <- tryCatch(
        {
          all_wf <- shiny_fetch_workflows()
          Filter(function(wf) recipe$id %in% wf$recipe_ids, all_wf)
        },
        error = function(e) list()
      )

      # Generate unique ID for this modal's graph
      graph_counter(graph_counter() + 1)
      graph_id <- paste0("recipe_graph_", graph_counter())

      # Create the graph output dynamically with unique ID
      if (requireNamespace("visNetwork", quietly = TRUE)) {
        output[[graph_id]] <- visNetwork::renderVisNetwork({
          recipe_pipeline_graph(recipe)
        })
      }

      # Fetch ANDA variable labels
      doc_info <- recipe$doc()
      all_vars <- unique(c(
        unlist(doc_info$input_variables),
        unlist(doc_info$output_variables)
      ))
      anda_labels <- tryCatch(
        shiny_fetch_anda_variables(recipe$survey_type, all_vars),
        error = function(e) {
          shiny::showNotification(
            paste("Could not fetch ANDA variables:", e$message),
            type = "warning", duration = 5
          )
          list()
        }
      )

      # Fetch stars, comments, and dependents
      logged_in <- isTRUE(auth_state$logged_in)
      token <- if (logged_in) auth_state$token else NULL
      user_email <- if (logged_in) auth_state$email else NULL

      stars_data <- tryCatch(
        shiny_get_stars("recipe", recipe$id, token),
        error = function(e) list(average = 0, count = 0)
      )

      comments <- tryCatch(
        shiny_get_comments("recipe", recipe$id),
        error = function(e) list()
      )

      dependents <- tryCatch(
        shiny_get_recipe_dependents(recipe$id),
        error = function(e) list()
      )

      # Store current recipe ID for observers
      current_modal_recipe$id <- recipe$id

      shiny::showModal(
        shiny::modalDialog(
          recipe_detail_ui(recipe,
            ns = ns,
            referencing_workflows = referencing_workflows,
            graph_output_id = graph_id,
            all_recipes = all_recipes(),
            anda_labels = anda_labels
          ),
          star_rating_widget(
            ns, "recipe",
            average = stars_data$average,
            count = stars_data$count,
            user_value = stars_data$user_value,
            logged_in = logged_in
          ),
          comments_section_ui(
            comments, ns, "recipe",
            current_user = user_email,
            logged_in = logged_in
          ),
          dependents_section_ui(dependents, ns),
          size = "l",
          easyClose = TRUE,
          footer = shiny::modalButton("Close")
        )
      )
    }

    # Card click -> open detail modal
    shiny::observeEvent(input$card_click, {
      idx <- input$card_click
      recipes <- filtered()
      if (idx < 1 || idx > length(recipes)) {
        return()
      }
      open_recipe_modal(recipes[[idx]])
    })

    # Cross-navigation: open recipe by ID from another module
    if (!is.null(pending_recipe_id)) {
      shiny::observeEvent(pending_recipe_id(),
        {
          req <- pending_recipe_id()
          if (is.null(req)) {
            return()
          }
          rid <- req$id
          recipes <- all_recipes()
          for (r in recipes) {
            if (as.character(r$id) == rid) {
              open_recipe_modal(r)
              return()
            }
          }
        },
        ignoreNULL = TRUE,
        ignoreInit = TRUE
      )
    }

    # Cross-reference: navigate to dependency recipe from recipe detail
    shiny::observeEvent(input$navigate_dep_recipe, {
      rid <- input$navigate_dep_recipe
      shiny::removeModal()
      recipes <- all_recipes()
      for (r in recipes) {
        if (as.character(r$id) == rid) {
          open_recipe_modal(r)
          return()
        }
      }
    })

    # Cross-reference: navigate to workflow from recipe detail
    shiny::observeEvent(input$navigate_workflow, {
      if (!is.null(navigate_to_workflow)) {
        shiny::removeModal()
        navigate_to_workflow(input$navigate_workflow)
      }
    })

    # Star click: rate recipe
    shiny::observeEvent(input$recipe_star_click, {
      value <- input$recipe_star_click
      rid <- current_modal_recipe$id
      if (is.null(rid) || !isTRUE(auth_state$logged_in)) {
        return()
      }
      tryCatch(
        {
          result <- shiny_star("recipe", rid, value, auth_state$token)
          if (isTRUE(result$ok)) {
            shiny::showNotification(
              paste("Rated", value, "stars"),
              type = "message", duration = 2
            )
          } else {
            shiny::showNotification(
              paste("Could not save rating:", result$error %||% "Unknown error"),
              type = "error", duration = 3
            )
          }
        },
        error = function(e) {
          shiny::showNotification(
            paste("Could not save rating:", e$message),
            type = "error", duration = 3
          )
        }
      )
    })

    # Submit comment on recipe
    shiny::observeEvent(input$recipe_submit_comment, {
      text <- input$recipe_submit_comment
      rid <- current_modal_recipe$id
      if (is.null(rid) || !isTRUE(auth_state$logged_in)) {
        return()
      }
      if (!nzchar(trimws(text))) {
        return()
      }
      tryCatch(
        {
          result <- shiny_add_comment("recipe", rid, text, auth_state$token)
          if (isTRUE(result$ok)) {
            shiny::showNotification(
              "Comment added",
              type = "message", duration = 2
            )
          } else {
            shiny::showNotification(
              paste("Could not add comment:", result$error %||% "Unknown error"),
              type = "error", duration = 3
            )
          }
        },
        error = function(e) {
          shiny::showNotification(
            paste("Could not add comment:", e$message),
            type = "error", duration = 3
          )
        }
      )
    })

    # Delete comment
    shiny::observeEvent(input$delete_comment, {
      cid <- input$delete_comment
      if (is.null(cid) || !isTRUE(auth_state$logged_in)) {
        return()
      }
      tryCatch(
        {
          result <- shiny_delete_comment(cid, auth_state$token)
          if (isTRUE(result$ok)) {
            shiny::showNotification(
              "Comment deleted",
              type = "message", duration = 2
            )
          } else {
            shiny::showNotification(
              paste("Could not delete comment:", result$error %||% "Unknown error"),
              type = "error", duration = 3
            )
          }
        },
        error = function(e) {
          shiny::showNotification(
            paste("Could not delete comment:", e$message),
            type = "error", duration = 3
          )
        }
      )
    })

    # Return the all_recipes reactive for cross-reference by workflows module
    all_recipes
  })
}
