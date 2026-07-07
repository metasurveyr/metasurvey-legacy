## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup--------------------------------------------------------------------
library(metasurvey)


show_engines()

set_engine(
  "data.table"
)


## -----------------------------------------------------------------------------

# Tipo de encuesta: ECH
# Edición de la encuesta: 2018
# Variable de ponderación: pesoano

svy_example <- metasurvey::load_survey(
  path = metasurvey::load_survey_example("2019-2021.csv"),
  svy_type = "eaii",
  svy_edition = "2019-2021",
  svy_weight = "w_trans"
)

class(svy_example)


## -----------------------------------------------------------------------------
survey_to_data_frame(svy_example)[1:5, 1:3]
survey_to_tibble(svy_example)[1:5, 1:3]
get_data(svy_example)[1:5, 1:3]

## -----------------------------------------------------------------------------

eaii_2019 <- metasurvey::load_survey(
  svy_type = "eaii",
  svy_edition = "2019-2021",
  svy_weight = "w_trans",
  input = metasurvey::load_survey_example("2019-2021.csv"),
  dec = ","
)


## -----------------------------------------------------------------------------

eaii_2019 <- eaii_2019 %>%
  metasurvey::step_recode( # Clasificación tamaño de la empresa decreto Nº 504/007
    new_var = "cant_traba_tramo",
    data.table::between(IG_4_1_3, 0, 4) ~ "1",
    data.table::between(IG_4_1_3, 5, 19) ~ "2",
    data.table::between(IG_4_1_3, 20, 99) ~ "3",
    IG_4_1_3 > 99 ~ "4"
  ) %>%
  metasurvey::step_recode( # Clasificación tamaño de la empresa decreto Nº 504/007
    new_var = "ingreso_vta_pesos",
    data.table::between(IG_5_1_1_3, 0, 9942787) ~ "1",
    data.table::between(IG_5_1_1_3, 9942788, 49713934) ~ "2", # nolint
    data.table::between(IG_5_1_1_3, 49713935, 372854507) ~ "3", # nolint
    IG_5_1_1_3 > 372854507 ~ "4"
  ) %>%
  metasurvey::step_recode( # Clasificación tamaño de la empresa decreto Nº 504/007
    new_var = "tamanio",
    cant_traba_tramo == "1" & ingreso_vta_pesos == "1" ~ "Pequenias",
    cant_traba_tramo == "2" & ingreso_vta_pesos == "2" ~ "Pequenias",
    cant_traba_tramo == "2" & ingreso_vta_pesos == "1" ~ "Pequenias",
    cant_traba_tramo == "1" & ingreso_vta_pesos == "2" ~ "Pequenias",
    cant_traba_tramo == "3" & ingreso_vta_pesos == "3" ~ "Medianas",
    cant_traba_tramo == "3" & ingreso_vta_pesos == "2" ~ "Medianas",
    cant_traba_tramo == "3" & ingreso_vta_pesos == "1" ~ "Medianas",
    cant_traba_tramo == "1" & ingreso_vta_pesos == "3" ~ "Medianas",
    cant_traba_tramo == "2" & ingreso_vta_pesos == "3" ~ "Medianas",
    cant_traba_tramo == "4" & ingreso_vta_pesos == "4" ~ "Grandes",
    cant_traba_tramo == "4" & ingreso_vta_pesos == "3" ~ "Grandes",
    cant_traba_tramo == "4" & ingreso_vta_pesos == "2" ~ "Grandes",
    cant_traba_tramo == "4" & ingreso_vta_pesos == "1" ~ "Grandes",
    cant_traba_tramo == "1" & ingreso_vta_pesos == "4" ~ "Grandes",
    cant_traba_tramo == "2" & ingreso_vta_pesos == "4" ~ "Grandes",
    cant_traba_tramo == "3" & ingreso_vta_pesos == "4" ~ "Grandes"
  )


## -----------------------------------------------------------------------------
eaii_2019 <- eaii_2019 %>%
  metasurvey::step_compute(
    edad = difftime(
      "2019-01-01",
      as.Date(paste(IG_3_5_1, "01", "01", sep = "-")),
      units = "weeks"
    ) / 52
  ) %>%
  metasurvey::step_recode(
    "edad_tramos",
    data.table::between(edad, 0, 10) ~ "Jovenes",
    data.table::between(edad, 11, 20) ~ "Medianas",
    edad > 20 ~ "Maduras"
  )

## -----------------------------------------------------------------------------
eaii_2019 <- eaii_2019 %>%
  metasurvey::step_recode(
    "tipo_empresa",
    IG_3_6 == 1 ~ "Publica",
    IG_3_6 == 2 ~ "Privada",
    IG_3_6 == 3 ~ "Mixta"
  )

## -----------------------------------------------------------------------------
eaii_2019 <- eaii_2019 %>%
  metasurvey::step_recode(
    "sector",
    data.table::between(Division, 10, 33) ~ "Industria",
    data.table::between(Division, 34, 99) ~ "Servicios",
    Division == "E1" ~ "Servicios",
    Division == "C1" ~ "Industria",
    Division == "C2" ~ "Industria"
  ) %>%
  metasurvey::step_compute(
    subsector = Division
  )

## -----------------------------------------------------------------------------
eaii_2019 <- eaii_2019 %>%
  metasurvey::step_recode(
    new_var = "realiza_innovacion",
    B1_1_1 == 1 ~ 1,
    B1_2_1 == 1 ~ 1,
    B1_3_1 == 1 ~ 1,
    B1_4_1 == 1 ~ 1,
    B1_5_1 == 1 ~ 1,
    B1_6_1 == 1 ~ 1,
    B1_7_1 == 1 ~ 1,
    B1_8_1 == 1 ~ 1,
    B1_9_1 == 1 ~ 1,
    .default = 0
  )

## ----eval = FALSE-------------------------------------------------------------
#  #TODO Poner ejemplo de estimar una proporción

## -----------------------------------------------------------------------------

eaii_2019 <- eaii_2019 %>%
  metasurvey::step_recode(
    new_var = "tipo_actividad",
    B1_1_1 == 1 ~ "I + D Interna",
    B1_2_1 == 1 ~ "I + D Externa",
    B1_3_1 == 1 ~ "Bienes de Capital",
    B1_4_1 == 1 ~ "Software",
    B1_5_1 == 1 ~ "Propiedad Intelectual",
    B1_6_1 == 1 ~ "Ingeniería",
    B1_7_1 == 1 ~ "Capacitación",
    B1_8_1 == 1 ~ "Marketing",
    B1_9_1 == 1 ~ "Gestión",
    .default = "Otra"
  )

## -----------------------------------------------------------------------------
metasurvey::view_graph(eaii_2019)
