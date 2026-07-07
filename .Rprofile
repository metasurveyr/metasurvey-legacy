# source("renv/activate.R")

if (!nzchar(Sys.getenv("CI"))) {
  library(utils)

  # Same semantics as metasurvey_msg() (R/meta.R): respects
  # options(metasurvey.verbose = FALSE). Defined locally because the
  # package is not loaded yet when .Rprofile runs.
  metasurvey_msg <- function(...) {
    if (isTRUE(getOption("metasurvey.verbose", TRUE))) {
      message(...)
    }
  }

  clean_directory_ech <- function(cache = TRUE) {
    # Remove example-data directory if it exists
    if (cache) {
      metasurvey_msg("Cache is enabled, skipping directory cleanup")
    } else {
      if (dir.exists("example-data")) {
        unlink("example-data", recursive = TRUE)
        metasurvey_msg("Removed existing example-data directory")
      } else {
        metasurvey_msg("No existing example-data directory to remove")
      }
    }
  }

  download_example_ech <- function() {
    zip_url <- "https://informe-tfg.s3.us-east-2.amazonaws.com/example-data.zip"
    dest_zip <- "example-data.zip"
    temp_dir <- tempfile("example-data")

    # Download the zip file
    download.file(zip_url, destfile = dest_zip, mode = "wb")
    metasurvey_msg("Downloaded example-data.zip")

    # Unzip to temporary directory
    dir.create(temp_dir)
    unzip(dest_zip, exdir = temp_dir)
    metasurvey_msg("Unzipped example-data.zip")

    target_dir <- file.path("example-data")
    dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
    file.rename(
      list.files(file.path(temp_dir, "example-data"), full.names = TRUE),
      file.path(target_dir, basename(list.files(file.path(temp_dir, "example-data"))))
    )
    metasurvey_msg("Moved unzipped data to chapters/example-data")

    # Cleanup
    unlink(dest_zip)
    unlink(temp_dir, recursive = TRUE)
    metasurvey_msg("Cleanup done")
  }


  if (dir.exists("example-data")) {
    metasurvey_msg("example-data directory already exists")
    cache <- TRUE
  } else {
    metasurvey_msg("example-data directory does not exist")
    cache <- FALSE
  }

  if (cache) {
    metasurvey_msg("Cache is enabled, skipping directory cleanup")
  } else {
    clean_directory_ech(cache = FALSE)
    download_example_ech()
  }
} # end CI guard
