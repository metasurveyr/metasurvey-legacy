# Referencia de la API y Base de Datos (ES)

## Descripcion general

metasurvey provee una API REST construida con
[plumber](https://www.rplumber.io/) respaldada por MongoDB para
compartir recetas, workflows y metadatos de variables con la comunidad.
La API se despliega en Railway y es utilizada tanto por las funciones
del cliente R (`api_*`) como por la aplicacion Shiny de exploracion.

**URL de produccion:**
`https://metasurvey-api-production.up.railway.app`

**Documentacion interactiva de la API (Swagger UI):**
`https://metasurvey-api-production.up.railway.app/__docs__/`

La interfaz Swagger UI proporciona un explorador interactivo de
endpoints generado automaticamente por plumber. Para esquemas detallados
de solicitudes/respuestas y documentacion de las colecciones de MongoDB,
consulte las secciones a continuacion.

## Configuracion

``` r

library(metasurvey)

# Point to the production API (default)
configure_api("https://metasurvey-api-production.up.railway.app")

# Or use an environment variable
Sys.setenv(METASURVEY_API_URL = "https://metasurvey-api-production.up.railway.app")
```

El cliente R lee la URL primero desde
[`configure_api()`](https://metasurveyr.github.io/metasurvey/reference/configure_api.md),
luego recurre a la variable de entorno `METASURVEY_API_URL`, y
finalmente utiliza la URL de produccion.

## Autenticacion

La API utiliza autenticacion JWT (JSON Web Token) con firma HMAC-SHA256.
Los tokens expiran despues de 24 horas; se pueden generar tokens de
larga duracion (90 dias) para scripts automatizados.

### Registro

``` r

# Individual account (auto-approved)
api_register("Ana Garcia", "ana@example.com", "password123")

# Institutional member (requires admin review)
api_register(
  "Carlos Rodriguez",
  "carlos@ine.gub.uy",
  "password123",
  user_type = "institutional_member",
  institution = "INE Uruguay"
)
```

Tipos de cuenta:

| Tipo | Descripcion | Aprobacion |
|----|----|----|
| `individual` | Investigador independiente | Automatica |
| `institutional_member` | Miembro de una institucion reconocida | Requiere revision de administrador |
| `institution` | Cuenta institucional | Requiere revision de administrador |

### Inicio de sesion

``` r

api_login("ana@example.com", "password123")
```

El token se almacena en la sesion y se utiliza automaticamente en las
llamadas posteriores a la API. El cliente renueva los tokens
automaticamente dentro de los 5 minutos previos a su expiracion.

### Gestion de sesion

``` r

# View current user profile
api_me()

# Refresh token
api_refresh_token()

# Logout
api_logout()
```

### Tokens de larga duracion

Para scripts automatizados y CI/CD, genere un token de 90 dias desde la
aplicacion Shiny (pestana Perfil) o utilicelo directamente:

``` r

Sys.setenv(METASURVEY_TOKEN = "your-long-lived-token")

# API calls work without interactive login
recipes <- api_list_recipes(survey_type = "ech")
```

## Endpoints de la API

### Recetas

| Metodo | Endpoint                | Auth | Descripcion                       |
|--------|-------------------------|------|-----------------------------------|
| `GET`  | `/recipes`              | No   | Listar y buscar recetas           |
| `GET`  | `/recipes/:id`          | No   | Obtener una receta individual     |
| `POST` | `/recipes`              | Si   | Publicar una nueva receta         |
| `POST` | `/recipes/:id/download` | No   | Incrementar contador de descargas |

#### Listar recetas

``` r

# All recipes
all <- api_list_recipes()

# Filter by survey type
ech <- api_list_recipes(survey_type = "ech")

# Search by text
labor <- api_list_recipes(search = "empleo")

# Filter by topic
income <- api_list_recipes(topic = "income")

# Filter by certification level
official <- api_list_recipes(certification = "official")

# Pagination
page2 <- api_list_recipes(limit = 10, offset = 10)
```

Parametros de consulta:

| Parametro | Tipo | Descripcion |
|----|----|----|
| `search` | string | Busqueda regex sobre el nombre de la receta |
| `survey_type` | string | `ech`, `eaii`, `eph`, `eai` |
| `topic` | string | `labor_market`, `income`, `education`, `health`, `demographics`, `housing` |
| `certification` | string | `community`, `reviewed`, `official` |
| `user` | string | Filtrar por email del autor |
| `limit` | integer | Resultados maximos (por defecto 50) |
| `offset` | integer | Omitir N resultados (por defecto 0) |

#### Obtener receta

``` r

recipe <- api_get_recipe("ech_employment_001")
```

#### Publicar receta

``` r

api_login("ana@example.com", "password123")
api_publish_recipe(my_recipe)
```

El servidor establece automaticamente el campo `user` a partir del JWT,
inicializa `downloads = 0`, genera un `id` si no se proporciona, y
asigna la certificacion `community` por defecto.

### Workflows

| Metodo | Endpoint                  | Auth | Descripcion                       |
|--------|---------------------------|------|-----------------------------------|
| `GET`  | `/workflows`              | No   | Listar y buscar workflows         |
| `GET`  | `/workflows/:id`          | No   | Obtener un workflow individual    |
| `POST` | `/workflows`              | Si   | Publicar un nuevo workflow        |
| `POST` | `/workflows/:id/download` | No   | Incrementar contador de descargas |

``` r

# List workflows for ECH
wf <- api_list_workflows(survey_type = "ech")

# Find workflows that use a specific recipe
wf <- api_list_workflows(recipe_id = "ech_employment_001")

# Get specific workflow
w <- api_get_workflow("wf_labor_market_001")

# Publish
api_publish_workflow(my_workflow)
```

### Metadatos de variables ANDA

> **Nota:** La integracion con ANDA es una implementacion *no oficial*
> que analiza metadatos DDI XML del catalogo publico ANDA del INE
> Uruguay. No esta avalada por el INE y puede contener errores o quedar
> desactualizada si el INE modifica la estructura del catalogo. Siempre
> verifique las definiciones criticas de variables contra el libro de
> codigos oficial.

El endpoint `/anda/variables` proporciona metadatos de variables
obtenidos del catalogo ANDA del INE Uruguay (formato DDI XML). Esto
incluye etiquetas de variables, categorias de valores e informacion de
tipo.

| Metodo | Endpoint          | Auth | Descripcion                    |
|--------|-------------------|------|--------------------------------|
| `GET`  | `/anda/variables` | No   | Obtener metadatos de variables |

``` r

# Get all ECH variables
vars <- api_get_anda_variables(survey_type = "ech")

# Get specific variables
vars <- api_get_anda_variables(
  survey_type = "ech",
  var_names = c("pobpcoac", "e27", "ht11")
)
```

Parametros de consulta:

| Parametro | Tipo | Descripcion |
|----|----|----|
| `survey_type` | string | Tipo de encuesta (por defecto `"ech"`) |
| `names` | string | Nombres de variables separados por coma (todas si esta vacio) |

Cada documento de variable contiene:

| Campo               | Descripcion                            |
|---------------------|----------------------------------------|
| `name`              | Nombre de la variable (minusculas)     |
| `label`             | Etiqueta legible                       |
| `type`              | `discrete`, `continuous` o `unknown`   |
| `value_labels`      | Lista de mapeos codigo-etiqueta        |
| `description`       | Descripcion extendida                  |
| `source_edition`    | Edicion de la encuesta (ej., `"2024"`) |
| `source_catalog_id` | ID del catalogo ANDA (ej., `767`)      |

### Administracion

| Metodo | Endpoint | Auth | Descripcion |
|----|----|----|----|
| `GET` | `/admin/pending-users` | Admin | Listar cuentas institucionales pendientes de revision |
| `POST` | `/admin/approve/:email` | Admin | Aprobar una cuenta institucional |
| `POST` | `/admin/reject/:email` | Admin | Rechazar una cuenta institucional |

El acceso de administrador se controla mediante la variable de entorno
`METASURVEY_ADMIN_EMAIL` en el servidor.

### Verificacion de estado

| Metodo | Endpoint  | Auth | Descripcion                   |
|--------|-----------|------|-------------------------------|
| `GET`  | `/health` | No   | Estado de la API y de MongoDB |

``` json
{
  "status": "ok",
  "service": "metasurvey-api",
  "version": "2.0.0",
  "database": "metasurvey",
  "mongodb": "connected",
  "timestamp": "2026-02-15T12:00:00Z"
}
```

## Esquema de MongoDB

La base de datos tiene cuatro colecciones, cada una con validacion de
esquema JSON e indices optimizados.

### Diagrama Entidad-Relacion

El siguiente diagrama muestra las colecciones de MongoDB y sus
relaciones:

``` mermaid
erDiagram
    users {
        string email PK
        string name
        string password_hash
        string user_type
        string institution
    }
    recipes {
        string id PK
        string name
        string user FK
        string survey_type
        string edition
        array steps
        object certification
        array categories
    }
    workflows {
        string id PK
        string name
        string user FK
        string survey_type
        array recipe_ids FK
        array calls
    }
    anda_variables {
        string survey_type PK
        string name PK
        string label
        string type
        object value_labels
    }

    users ||--o{ recipes : publica
    users ||--o{ workflows : publica
    recipes ||--o{ workflows : referencia
```

### Colecciones

#### `users`

| Campo | Tipo | Requerido | Descripcion |
|----|----|----|----|
| `name` | string | Si | Nombre para mostrar |
| `email` | string | Si | Email (unico, validado) |
| `password_hash` | string | Si | Hash SHA-256 (64 caracteres) |
| `user_type` | enum | Si | `individual`, `institutional_member`, `institution` |
| `institution` | string | No | Nombre de la institucion |
| `verified` | boolean | No | Si la identidad esta verificada |
| `review_status` | enum | No | `approved`, `pending`, `rejected` |
| `reviewed_by` | string | No | Email del administrador que reviso |
| `reviewed_at` | string | No | Marca de tiempo ISO |
| `created_at` | string | Si | Marca de tiempo ISO |

**Indices:** unico en `email`.

#### `recipes`

| Campo | Tipo | Requerido | Descripcion |
|----|----|----|----|
| `id` | string | No | Identificador unico (auto-generado) |
| `name` | string | Si | Nombre de la receta |
| `user` | string | Si | Email del autor |
| `survey_type` | enum | Si | `ech`, `eaii`, `eph`, `eai` |
| `edition` | string/array | No | Edicion(es) de la encuesta |
| `description` | string | No | Descripcion |
| `topic` | enum | No | `labor_market`, `income`, `education`, `health`, `demographics`, `housing` |
| `version` | string | No | Version semantica (por defecto `"1.0.0"`) |
| `downloads` | number | No | Contador de descargas (por defecto `0`) |
| `steps` | array | No | Expresiones de pasos como cadenas de texto |
| `depends_on` | array | No | Nombres de variables de entrada requeridas |
| `depends_on_recipes` | array | No | IDs de recetas de las que depende |
| `categories` | array | No | Objetos de categoria |
| `certification` | object | No | `{level, certified_at, certified_by, notes}` |
| `user_info` | object | No | `{name, user_type, email, url, verified}` |
| `doc` | object | No | `{input_variables, output_variables, pipeline}` |
| `data_source` | object | No | `{s3_bucket, s3_prefix, file_pattern, provider}` |

**Indices:** unico en `id`; en `user`, `survey_type`, `topic`,
`downloads` (desc), `certification.level`; compuesto en
`(survey_type, edition)`; busqueda de texto en
`(name, description, topic)`.

#### `workflows`

| Campo | Tipo | Requerido | Descripcion |
|----|----|----|----|
| `id` | string | No | Identificador unico (auto-generado) |
| `name` | string | Si | Nombre del workflow |
| `user` | string | Si | Email del autor |
| `survey_type` | enum | Si | `ech`, `eaii`, `eph`, `eai` |
| `edition` | string/array | No | Edicion(es) de la encuesta |
| `description` | string | No | Descripcion |
| `version` | string | No | Version semantica |
| `downloads` | number | No | Contador de descargas |
| `estimation_type` | string/array | No | `annual`, `quarterly`, `monthly` |
| `recipe_ids` | array | No | IDs de recetas referenciadas |
| `calls` | array | No | Llamadas de estimacion como cadenas de texto |
| `call_metadata` | array | No | Descripciones de las llamadas |
| `categories` | array | No | Objetos de categoria |
| `certification` | object | No | Igual que en recetas |
| `user_info` | object | No | Igual que en recetas |

**Indices:** unico en `id`; en `user`, `survey_type`, `recipe_ids`,
`downloads` (desc); compuesto en `(survey_type, edition)`; busqueda de
texto en `(name, description)`.

#### `anda_variables`

| Campo               | Tipo   | Requerido | Descripcion                         |
|---------------------|--------|-----------|-------------------------------------|
| `survey_type`       | string | Si        | Tipo de encuesta                    |
| `name`              | string | Si        | Nombre de la variable (minusculas)  |
| `label`             | string | Si        | Etiqueta legible                    |
| `type`              | enum   | No        | `discrete`, `continuous`, `unknown` |
| `value_labels`      | object | No        | Mapeos codigo-etiqueta              |
| `description`       | string | No        | Descripcion extendida               |
| `source_edition`    | string | No        | Edicion (ej., `"2024"`)             |
| `source_catalog_id` | number | No        | ID del catalogo ANDA                |

**Indices:** compuesto unico en `(survey_type, name)`; en `survey_type`.

## Configuracion de la base de datos

Para configurar la base de datos en un nuevo despliegue:

``` bash
# 1. Create collections with JSON Schema validation and indexes
mongosh "$METASURVEY_MONGO_URI" inst/scripts/setup_mongodb.js

# 2. Seed recipes, workflows, and users
METASURVEY_MONGO_URI="..." Rscript inst/scripts/seed_ech_recipes.R

# 3. Seed ANDA variable metadata from INE catalog
METASURVEY_MONGO_URI="..." Rscript inst/scripts/seed_anda_metadata.R
```

El script de configuracion crea las cuatro colecciones y construye los
indices. Es idempotente: las colecciones existentes se omiten.

## Despliegue del servidor

### Variables de entorno

| Variable | Requerida | Por defecto | Descripcion |
|----|----|----|----|
| `METASURVEY_MONGO_URI` | Si | — | Cadena de conexion a MongoDB |
| `METASURVEY_DB` | No | `metasurvey` | Nombre de la base de datos |
| `METASURVEY_JWT_SECRET` | No | `metasurvey-dev-secret-...` | Secreto para firma JWT (sobreescribir en produccion) |
| `METASURVEY_ADMIN_EMAIL` | No | — | Email del administrador para revision institucional |

### Ejecucion local

``` bash
METASURVEY_MONGO_URI="mongodb+srv://user:pass@cluster.mongodb.net" \
  Rscript -e 'plumber::plumb("inst/api/plumber.R")$run(port = 8787)'
```

La interfaz Swagger UI estara disponible en
`http://localhost:8787/__docs__/`.

### Docker

``` bash
docker build -t metasurvey-api inst/api/
docker run -p 8787:8787 \
  -e METASURVEY_MONGO_URI="mongodb+srv://..." \
  -e METASURVEY_JWT_SECRET="your-production-secret" \
  -e METASURVEY_ADMIN_EMAIL="admin@example.com" \
  metasurvey-api
```

### Railway

La API esta configurada para despliegue en Railway mediante el archivo
`render.yaml` en `inst/api/`. Suba el repositorio y configure las
variables de entorno en el panel de Railway.

## CORS

La API permite solicitudes de origen cruzado desde cualquier origen:

- **Metodos permitidos:** GET, POST, OPTIONS
- **Encabezados permitidos:** Content-Type, Authorization

## Proximos pasos

- **[Explorador interactivo de
  recetas](https://metasurveyr.github.io/metasurvey/articles/shiny-explorer.md)**
  – Navegue recetas y workflows a traves de la aplicacion web Shiny
- **[Creacion y publicacion de
  recetas](https://metasurveyr.github.io/metasurvey/articles/recipes.md)**
  – Construya recetas de forma programatica y publiquelas en la API
- **[Workflows de
  estimacion](https://metasurveyr.github.io/metasurvey/articles/workflows-and-estimation.md)**
  – Calcule estimaciones ponderadas de encuestas con
  [`workflow()`](https://metasurveyr.github.io/metasurvey/reference/workflow.md)
