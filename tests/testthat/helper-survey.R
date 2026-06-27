# Helper functions for tests
# Creates a minimal Survey object for testing purposes

make_test_survey <- function(n = 10) {
  set.seed(42)
  df <- data.table::data.table(
    id = seq_len(n),
    x = seq_len(n),
    y = seq_len(n) * 2,
    age = sample(18:65, n, replace = TRUE),
    income = round(runif(n, 1000, 5000), 2),
    region = sample(1:4, n, replace = TRUE),
    status = sample(1:3, n, replace = TRUE),
    group = sample(1:3, n, replace = TRUE),
    w = round(runif(n, 0.5, 2), 4)
  )
  Survey$new(
    data = df,
    edition = "2023",
    type = "ech",
    psu = NULL,
    engine = "data.table",
    weight = add_weight(annual = "w")
  )
}

make_test_data <- function(n = 10) {
  set.seed(42)
  data.table::data.table(
    id = seq_len(n),
    age = sample(18:65, n, replace = TRUE),
    income = round(runif(n, 1000, 5000), 2),
    region = sample(1:4, n, replace = TRUE),
    status = sample(1:3, n, replace = TRUE),
    w = round(runif(n, 0.5, 2), 4)
  )
}

make_eco_recipe <- function(name, user, svy_type = "ech", edition = "2023",
                            topic = NULL, downloads = 0L,
                            categories = list(), certification = NULL,
                            user_info = NULL) {
  Recipe$new(
    name = name, edition = edition, survey_type = svy_type,
    default_engine = "data.table", depends_on = list(),
    user = user, description = paste("Test recipe:", name),
    steps = list(), id = stats::runif(1), doi = NULL,
    topic = topic, categories = categories,
    downloads = as.integer(downloads),
    certification = certification,
    user_info = user_info
  )
}

make_test_panel <- function() {
  # Create a minimal RotativePanelSurvey object for testing
  implantation <- make_test_survey(n = 20)
  implantation_data <- get_data(implantation)
  implantation_data[, `:=`(mes = 1, anio = 2023, numero = id)]
  implantation$periodicity <- "monthly"

  RotativePanelSurvey$new(
    implantation = implantation,
    follow_up = list(),
    type = "ech",
    default_engine = "data.table",
    steps = list(),
    recipes = list(),
    workflows = list(),
    design = NULL
  )
}
