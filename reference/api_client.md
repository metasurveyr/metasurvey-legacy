# API Client for metasurvey

HTTP client for the metasurvey REST API (plumber).

The metasurvey API is a server deployed separately (Docker, Cloud Run,
etc.). Users of the R package interact with it through these client
functions.

## Setup


    # 1. Point to the deployed API
    configure_api(url = "https://metasurvey-api.example.com")

    # 2. Register or login
    api_register("Ana Garcia", "ana@example.com", "password123")
    api_login("ana@example.com", "password123")

    # 3. Use the API
    api_list_recipes(survey_type = "ech")
    api_publish_recipe(my_recipe)
