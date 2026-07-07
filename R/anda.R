# ══════════════════════════════════════════════════════════════════════════════
# ANDA Metadata Integration
#
# Functions to fetch and parse DDI XML metadata from INE Uruguay's ANDA5
# catalog (https://www4.ine.gub.uy/Anda5/). Provides variable-level
# metadata (labels, value labels, types) for ECH survey variables.
# ══════════════════════════════════════════════════════════════════════════════

.check_httr2 <- function() {
  if (!requireNamespace("httr2", quietly = TRUE)) {
    stop("Package 'httr2' is required for ANDA operations. ",
      "Install it with: install.packages('httr2')",
      call. = FALSE
    )
  }
}

#' Fetch DDI XML from ANDA5 catalog
#'
#' Downloads the DDI (Data Documentation Initiative) XML file for a given
#' catalog entry from INE Uruguay's ANDA5 catalog.
#'
#' @param catalog_id Integer catalog ID (e.g., 767 for ECH 2024)
#' @param base_url Character base URL of the ANDA5 instance
#' @param dest_file Character path where to save the XML file. If NULL, uses a
#'   temporary file.
#' @return Character path to the downloaded DDI XML file
#' @keywords internal
anda_fetch_ddi <- function(catalog_id,
                           base_url = "https://www4.ine.gub.uy/Anda5",
                           dest_file = NULL) {
  .check_httr2()
  url <- paste0(base_url, "/metadata/export/", catalog_id, "/ddi")

  if (is.null(dest_file)) {
    dest_file <- tempfile(fileext = ".xml")
  }

  req <- httr2::request(url)
  req <- httr2::req_user_agent(req, metasurvey_user_agent())
  req <- httr2::req_options(
    req,
    ssl_verifypeer = getOption("metasurvey.ssl_verify", TRUE)
  )
  req <- httr2::req_timeout(req, 60)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- httr2::req_perform(req, path = dest_file)

  if (httr2::resp_status(resp) != 200) {
    stop(
      "Failed to download DDI from ANDA5 (catalog_id=", catalog_id,
      "): HTTP ", httr2::resp_status(resp),
      call. = FALSE
    )
  }

  dest_file
}

#' Search ANDA5 catalog
#'
#' Queries the ANDA5 REST API to list available survey datasets.
#'
#' @param keyword Character search term (e.g., "ECH")
#' @param base_url Character base URL of the ANDA5 instance
#' @param limit Integer max results to return
#' @return A data.frame with columns: id, title, year_start, year_end
#' @keywords internal
anda_catalog_search <- function(keyword = "ECH",
                                base_url = "https://www4.ine.gub.uy/Anda5",
                                limit = 50) {
  .check_httr2()
  url <- paste0(base_url, "/index.php/api/catalog/search")

  req <- httr2::request(url)
  req <- httr2::req_user_agent(req, metasurvey_user_agent())
  req <- httr2::req_url_query(req, sk = keyword, ps = limit, format = "json")
  req <- httr2::req_options(
    req,
    ssl_verifypeer = getOption("metasurvey.ssl_verify", TRUE)
  )
  req <- httr2::req_timeout(req, 30)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- httr2::req_perform(req)

  if (httr2::resp_status(resp) != 200) {
    stop("ANDA5 catalog search failed: HTTP ", httr2::resp_status(resp),
      call. = FALSE
    )
  }

  body <- httr2::resp_body_json(resp)
  rows <- body$result$rows %||% list()

  if (length(rows) == 0) {
    return(data.frame(
      id = character(), title = character(),
      year_start = character(), year_end = character(),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    id = vapply(
      rows,
      function(r) as.character(r$id %||% ""),
      character(1)
    ),
    title = vapply(
      rows, function(r) r$title %||% "",
      character(1)
    ),
    year_start = vapply(
      rows, function(r) r$year_start %||% "",
      character(1)
    ),
    year_end = vapply(
      rows, function(r) r$year_end %||% "",
      character(1)
    ),
    stringsAsFactors = FALSE
  )
}

#' Parse variables from a DDI XML file
#'
#' Reads a DDI Codebook XML file and extracts variable-level metadata:
#' name, label, type (discrete/continuous), and value labels.
#'
#' @param ddi_xml_path Character path to the DDI XML file
#' @return A list of variable metadata, each with: name, label, type,
#'   value_labels (named list or NULL), description
#' @keywords internal
anda_parse_variables <- function(ddi_xml_path) {
  if (!requireNamespace("xml2", quietly = TRUE)) {
    stop(
      "Package 'xml2' is required. ",
      "Install it with: install.packages('xml2')",
      call. = FALSE
    )
  }

  doc <- xml2::read_xml(ddi_xml_path)
  ns <- xml2::xml_ns(doc)

  # Find all <var> elements in <dataDscr>
  vars <- xml2::xml_find_all(doc, ".//d1:dataDscr/d1:var", ns)

  if (length(vars) == 0) {
    warning("No variables found in DDI file", call. = FALSE)
    return(list())
  }

  seen <- character(0)
  result <- list()

  for (v in vars) {
    name <- xml2::xml_attr(v, "name")
    if (is.na(name) || !nzchar(name)) next

    # Deduplicate: same variable may appear in multiple files
    name_lower <- tolower(name)
    if (name_lower %in% seen) next
    seen <- c(seen, name_lower)

    intrvl <- xml2::xml_attr(v, "intrvl")
    var_type <- if (!is.na(intrvl) && intrvl == "contin") {
      "continuous"
    } else {
      "discrete"
    }

    # Label
    labl_node <- xml2::xml_find_first(v, "d1:labl", ns)
    label <- if (!is.null(labl_node) && !inherits(labl_node, "xml_missing")) {
      trimws(xml2::xml_text(labl_node))
    } else {
      ""
    }

    # Description text
    txt_node <- xml2::xml_find_first(v, "d1:txt", ns)
    description <- if (!is.null(txt_node) && !inherits(txt_node, "xml_missing")) {
      trimws(xml2::xml_text(txt_node))
    } else {
      ""
    }

    # Value labels (categories)
    catgry_nodes <- xml2::xml_find_all(v, "d1:catgry", ns)
    value_labels <- NULL
    if (length(catgry_nodes) > 0) {
      value_labels <- list()
      for (cat in catgry_nodes) {
        cat_val <- xml2::xml_find_first(cat, "d1:catValu", ns)
        cat_lab <- xml2::xml_find_first(cat, "d1:labl", ns)
        if (!inherits(cat_val, "xml_missing") && !inherits(cat_lab, "xml_missing")) {
          val <- trimws(xml2::xml_text(cat_val))
          lab <- trimws(xml2::xml_text(cat_lab))
          value_labels[[val]] <- lab
        }
      }
      if (length(value_labels) == 0) value_labels <- NULL
    }

    result[[length(result) + 1L]] <- list(
      name         = name_lower,
      label        = label,
      type         = var_type,
      value_labels = value_labels,
      description  = description
    )
  }

  result
}

# Known ANDA5 catalog IDs for ECH editions
.ech_catalog_ids <- list(
  "2007" = 49L,  "2008" = 50L,  "2009" = 51L,  "2010" = 734L,
  "2011" = 726L, "2012" = 725L, "2013" = 724L, "2014" = 723L,
  "2015" = 721L, "2016" = 722L, "2017" = 720L, "2018" = 719L,
  "2019" = 715L, "2020" = 714L, "2021" = 716L, "2022" = 730L,
  "2023" = 735L, "2024" = 767L
)

#' List available ECH editions in ANDA5
#'
#' Returns the known ECH editions available in INE Uruguay's ANDA5 catalog.
#'
#' @return A data.frame with columns: edition, catalog_id
#' @keywords internal
anda_list_editions <- function() {
  ids <- .ech_catalog_ids
  data.frame(
    edition = names(ids),
    catalog_id = unlist(ids, use.names = FALSE),
    stringsAsFactors = FALSE
  )
}

#' Download ECH microdata from ANDA5
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Downloads microdata files for a given ECH edition from INE Uruguay's
#' ANDA5 catalog. Automatically accepts the terms of use, parses available
#' resources, and downloads the appropriate file.
#'
#' For editions >= 2022, ANDA provides separate files for implantation,
#' monthly follow-ups, and bootstrap replicate weights. Use the `resource`
#' parameter to select which file to download.
#'
#' @param edition Character year (e.g., "2023")
#' @param resource Character type of resource to download. One of:
#'   \describe{
#'     \item{"implantation"}{(default) Main implantation file. For editions
#'       < 2022, downloads the main microdata file.}
#'     \item{"monthly"}{Monthly follow-up files (editions >= 2022 only).
#'       Returns a character vector of paths, one per month.}
#'     \item{"bootstrap_annual"}{Annual bootstrap replicate weights.}
#'     \item{"bootstrap_monthly"}{Monthly bootstrap replicate weights.}
#'     \item{"bootstrap_quarterly"}{Quarterly bootstrap replicate weights.}
#'     \item{"bootstrap_semestral"}{Semestral bootstrap replicate weights.}
#'     \item{"poverty"}{Poverty line microdata (Microdatos_LP).}
#'   }
#' @param dest_dir Character directory where to save files. Defaults to
#'   a temporary directory.
#' @param base_url Character base URL of the ANDA5 instance
#' @return Character path (or vector of paths for
#'   monthly) to the downloaded file(s), ready to pass
#'   to \code{load_survey()} or
#'   \code{data.table::fread()}.
#' @family anda
#' @export
#' @examples
#' \dontrun{
#' path <- anda_download_microdata("2023", resource = "implantation")
#' svy <- load_survey(path, svy_type = "ech", svy_edition = "2023")
#' }
anda_download_microdata <- function(edition,
                                    resource = "implantation",
                                    dest_dir = tempdir(),
                                    base_url =
                                      "https://www4.ine.gub.uy/Anda5") {
  .check_httr2()
  catalog_id <- .ech_catalog_ids[[as.character(edition)]]
  if (is.null(catalog_id)) {
    avail <- paste(names(.ech_catalog_ids), collapse = ", ")
    stop("Unknown ECH edition '", edition, "'. Available: ", avail,
      call. = FALSE
    )
  }

  metasurvey_msg(
    "Downloading ECH ", edition,
    " from ANDA5 (catalog ", catalog_id, ")..."
  )

  # Accept terms and get download page
  accept_url <- paste0(
    base_url, "/index.php/catalog/",
    catalog_id, "/get-microdata"
  )
  req <- httr2::request(accept_url)
  req <- httr2::req_user_agent(req, metasurvey_user_agent())
  req <- httr2::req_body_form(req, accept = "1")
  req <- httr2::req_options(
    req,
    ssl_verifypeer = getOption("metasurvey.ssl_verify", TRUE)
  )
  req <- httr2::req_timeout(req, 30)
  req <- httr2::req_error(req, is_error = function(resp) FALSE)
  resp <- httr2::req_perform(req)

  if (httr2::resp_status(resp) != 200) {
    stop(
      "Failed to access microdata page: HTTP ",
      httr2::resp_status(resp),
      call. = FALSE
    )
  }

  # Parse all resources with their titles and IDs
  page_html <- httr2::resp_body_string(resp)
  resources <- .anda_parse_resources(page_html, catalog_id)

  if (nrow(resources) == 0) {
    stop("No downloadable resources found for ECH ", edition, call. = FALSE)
  }

  # Select the appropriate resource(s)
  selected <- .anda_select_resource(resources, resource, edition)

  # Download each selected resource
  paths <- vapply(seq_len(nrow(selected)), function(i) {
    rid <- selected$id[i]
    title <- selected$title[i]
    dl_url <- paste0(
      base_url, "/index.php/catalog/",
      catalog_id, "/download/", rid
    )
    dest_raw <- file.path(
      dest_dir,
      paste0("ech_", edition, "_", rid, "_raw")
    )

    metasurvey_msg("  Downloading: ", title)
    dl_req <- httr2::request(dl_url)
    dl_req <- httr2::req_user_agent(dl_req, metasurvey_user_agent())
    dl_req <- httr2::req_options(
      dl_req,
      ssl_verifypeer = getOption("metasurvey.ssl_verify", TRUE)
    )
    dl_req <- httr2::req_timeout(dl_req, 300)
    dl_req <- httr2::req_error(dl_req, is_error = function(resp) FALSE)
    dl_resp <- httr2::req_perform(dl_req, path = dest_raw)

    if (httr2::resp_status(dl_resp) != 200) {
      stop(
        "Failed to download '", title,
        "': HTTP ", httr2::resp_status(dl_resp),
        call. = FALSE
      )
    }

    file_size <- file.info(dest_raw)$size
    metasurvey_msg(sprintf(
      "  Done: %.1f MB", file_size / 1024 / 1024
    ))

    .anda_extract_file(
      dest_raw, dest_dir, paste0(edition, "_", rid)
    )
  }, character(1))

  if (length(paths) == 1) paths <- paths[1]
  paths
}

#' Parse ANDA download page for resource titles and IDs
#' @param html Character HTML content
#' @param catalog_id Integer catalog ID
#' @return data.frame with columns: id, title
#' @keywords internal
.anda_parse_resources <- function(html, catalog_id) {
  pattern <- paste0('data-file-id="(\\d+)"[^>]*title="([^"]*)"')
  m <- regmatches(html, gregexpr(pattern, html))[[1]]

  if (length(m) == 0) {
    return(data.frame(
      id = character(), title = character(),
      stringsAsFactors = FALSE
    ))
  }

  ids <- gsub('.*data-file-id="(\\d+)".*', "\\1", m)
  titles <- gsub('.*title="([^"]*)".*', "\\1", m)

  data.frame(id = ids, title = titles, stringsAsFactors = FALSE)
}

#' Select resources matching the requested type
#' @param resources data.frame from .anda_parse_resources
#' @param resource Character resource type
#' @param edition Character edition year
#' @return data.frame subset of matching resources
#' @keywords internal
.anda_select_resource <- function(resources, resource, edition) {
  yr <- as.integer(edition)
  titles_lower <- tolower(resources$title)

  selected <- switch(resource,
    "implantation" = {
      if (yr >= 2022) {
        # 2022+: look for "implantacion" file, or "ECH_YYYY.csv" pattern
        idx <- grep("implantacion", titles_lower)
        if (length(idx) == 0) {
          # Fallback: match ECH_YYYY.csv (4-digit year, NOT monthly ECH_MM_YY)
          ech_pattern <- paste0("^ech_", edition, "\\.")
          idx <- grep(ech_pattern, titles_lower)
        }
        if (length(idx) == 0) {
          stop(
            "No implantation file found for ECH ", edition,
            ". Available: ", paste(resources$title, collapse = ", "),
            call. = FALSE
          )
        }
        resources[idx[1], , drop = FALSE]
      } else {
        # Pre-2022: prefer SAV format (most reliable), then CSV
        idx_sav <- grep("_sav", titles_lower)
        idx_csv <- grep("\\.(csv|CSV)$", resources$title)
        # Exclude FIES/LP files
        exclude <- grep("fies|microdatos_lp|estrato", titles_lower)
        if (length(idx_csv) > 0) {
          idx_csv <- setdiff(idx_csv, exclude)
          if (length(idx_csv) > 0) {
            return(resources[idx_csv[1], , drop = FALSE])
          }
        }
        if (length(idx_sav) > 0) {
          idx_sav <- setdiff(idx_sav, exclude)
          if (length(idx_sav) > 0) {
            return(resources[idx_sav[1], , drop = FALSE])
          }
        }
        # Fallback: first non-excluded resource
        main <- setdiff(seq_len(nrow(resources)), exclude)
        if (length(main) == 0) main <- 1
        resources[main[1], , drop = FALSE]
      }
    },
    "monthly" = {
      idx <- grep("^ech_\\d{2}_", titles_lower)
      if (length(idx) == 0) {
        stop(
          "No monthly files found for ECH ", edition,
          ". Monthly data is available from 2022 onwards.",
          call. = FALSE
        )
      }
      resources[idx, , drop = FALSE]
    },
    "bootstrap_annual" = {
      idx <- grep(
        "bootstrap.*anual|anual.*bootstrap",
        titles_lower
      )
      if (length(idx) == 0) {
        stop("No annual bootstrap weights found for ECH ", edition, call. = FALSE)
      }
      resources[idx[1], , drop = FALSE]
    },
    "bootstrap_monthly" = {
      idx <- grep(
        "bootstrap.*mensual|mensual.*bootstrap",
        titles_lower
      )
      if (length(idx) == 0) {
        stop("No monthly bootstrap weights found for ECH ", edition, call. = FALSE)
      }
      resources[idx, , drop = FALSE]
    },
    "bootstrap_quarterly" = {
      idx <- grep(
        "bootstrap.*trimestral|trimestral.*bootstrap",
        titles_lower
      )
      if (length(idx) == 0) {
        stop("No quarterly bootstrap weights found for ECH ", edition, call. = FALSE)
      }
      resources[idx[1], , drop = FALSE]
    },
    "bootstrap_semestral" = {
      idx <- grep(
        "bootstrap.*semestral|semestral.*bootstrap",
        titles_lower
      )
      if (length(idx) == 0) {
        stop("No semestral bootstrap weights found for ECH ", edition, call. = FALSE)
      }
      resources[idx[1], , drop = FALSE]
    },
    "poverty" = {
      idx <- grep(
        "microdatos_lp|linea.*pobreza", titles_lower
      )
      if (length(idx) == 0) {
        stop("No poverty line data found for ECH ", edition, call. = FALSE)
      }
      resources[idx[1], , drop = FALSE]
    },
    stop(
      "Unknown resource type '", resource,
      "'. Use: implantation, monthly, bootstrap_annual, ",
      "bootstrap_monthly, bootstrap_quarterly, bootstrap_semestral, poverty"
    )
  )

  selected
}

#' Extract downloaded ANDA file (handles ZIP, RAR, CSV, SAV)
#' @param raw_path Path to the raw downloaded file
#' @param dest_dir Destination directory
#' @param label Label for naming extracted files
#' @return Path to the extracted data file
#' @keywords internal
.anda_extract_file <- function(raw_path, dest_dir, label) {
  # Read first bytes to detect file type
  con <- file(raw_path, "rb")
  magic <- readBin(con, "raw", n = 7)
  close(con)

  is_zip <- length(magic) >= 2 &&
    identical(magic[1:2], as.raw(c(0x50, 0x4B)))
  # RAR magic: 52 61 72 21 1A 07 00
  # RAR5: 52 61 72 21 1A 07 01 00
  rar_magic <- as.raw(
    c(0x52, 0x61, 0x72, 0x21, 0x1a, 0x07)
  )
  is_rar <- length(magic) >= 6 &&
    identical(magic[1:6], rar_magic)
  is_sav <- length(magic) >= 4 &&
    identical(magic[1:4], charToRaw("$FL2"))

  if (is_zip) {
    extract_dir <- file.path(dest_dir, paste0("ech_", label))
    dir.create(
      extract_dir,
      showWarnings = FALSE,
      recursive = TRUE
    )
    utils::unzip(raw_path, exdir = extract_dir)
    unlink(raw_path)
    return(.anda_find_data_file(extract_dir, label))
  } else if (is_rar) {
    if (!requireNamespace("archive", quietly = TRUE)) {
      stop(
        "Package 'archive' is required. ",
        "Install it with: install.packages('archive')",
        call. = FALSE
      )
    }
    extract_dir <- file.path(dest_dir, paste0("ech_", label))
    dir.create(
      extract_dir,
      showWarnings = FALSE,
      recursive = TRUE
    )
    archive::archive_extract(raw_path, dir = extract_dir)
    unlink(raw_path)
    return(.anda_find_data_file(extract_dir, label))
  } else if (is_sav) {
    dest_sav <- file.path(dest_dir, paste0("ech_", label, ".sav"))
    file.rename(raw_path, dest_sav)
    return(dest_sav)
  } else {
    # Assume CSV/text
    dest_csv <- file.path(dest_dir, paste0("ech_", label, ".csv"))
    file.rename(raw_path, dest_csv)
    return(dest_csv)
  }
}

#' Find the main data file in an extracted directory
#' @param dir Character path to extracted directory
#' @param label Character label for error messages
#' @return Character path to the data file
#' @keywords internal
.anda_find_data_file <- function(dir, label) {
  extracted <- list.files(
    dir,
    recursive = TRUE, full.names = TRUE
  )

  # If extraction produced another archive, extract recursively
  archives <- grep(
    "\\.(zip|rar)$", extracted,
    value = TRUE, ignore.case = TRUE
  )
  if (length(archives) > 0 && length(extracted) == length(archives)) {
    for (a in archives) {
      sub_result <- tryCatch(
        .anda_extract_file(
          a, dirname(a), paste0(label, "_sub")
        ),
        error = function(e) NULL
      )
      if (!is.null(sub_result)) {
        return(sub_result)
      }
    }
  }

  # Prefer CSV, then SAV, then any file
  csv_files <- grep("\\.(csv|CSV)$", extracted, value = TRUE)
  sav_files <- grep("\\.(sav|SAV)$", extracted, value = TRUE)
  xlsx_files <- grep("\\.(xlsx|XLSX)$", extracted, value = TRUE)

  if (length(csv_files) > 0) {
    return(csv_files[1])
  }
  if (length(sav_files) > 0) {
    return(sav_files[1])
  }
  if (length(xlsx_files) > 0) {
    return(xlsx_files[1])
  }
  if (length(extracted) > 0) {
    return(extracted[1])
  }

  stop("Extracted archive was empty for ECH ", label, call. = FALSE)
}

#' Query ANDA variable metadata from the API
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Fetches variable metadata (labels, types, value labels) from the
#' metasurvey API's ANDA endpoint.
#'
#' @param survey_type Character survey type (default "ech")
#' @param var_names Character vector of variable names to look up. If NULL,
#'   returns all variables for the survey type.
#' @return A data.frame with columns: name, label, type
#' @family anda
#' @export
#' @examples
#' \dontrun{
#' anda_variables("ech", c("pobpcoac", "e27"))
#' }
anda_variables <- function(survey_type = "ech", var_names = NULL) {
  vars <- api_get_anda_variables(survey_type, var_names)

  if (length(vars) == 0) {
    return(data.frame(
      name = character(), label = character(), type = character(),
      stringsAsFactors = FALSE
    ))
  }

  data.frame(
    name = vapply(vars, function(v) v$name %||% "", character(1)),
    label = vapply(vars, function(v) v$label %||% "", character(1)),
    type = vapply(vars, function(v) v$type %||% "unknown", character(1)),
    stringsAsFactors = FALSE
  )
}

#' Get detailed metadata for a single ANDA variable
#'
#' @param survey_type Character survey type (default "ech")
#' @param var_name Character variable name
#' @return A list with: name, label, type, value_labels, description.
#'   NULL if not found.
#' @keywords internal
anda_variable_detail <- function(survey_type = "ech", var_name) {
  vars <- api_get_anda_variables(survey_type, var_name)
  if (length(vars) == 0) {
    return(NULL)
  }
  vars[[1]]
}
