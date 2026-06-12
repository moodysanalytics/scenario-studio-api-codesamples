# This script tests that you are able to access and authenticate the Scenario Studio API

get_script_dir <- function() {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- "--file="
  hit <- grep(file_arg, cmd_args)
  if (length(hit) > 0) {
    return(dirname(normalizePath(sub(file_arg, "", cmd_args[hit[1]]))))
  }

  if (!is.null(sys.frames()[[1]]$ofile)) {
    return(dirname(normalizePath(sys.frames()[[1]]$ofile)))
  }

  normalizePath(getwd())
}

prompt_nonempty <- function(prompt_text) {
  value <- ""
  while (!nzchar(trimws(value))) {
    value <- readline(prompt = paste0(prompt_text, " : "))
  }
  trimws(value)
}

script_dir <- get_script_dir()
s2api_path <- file.path(script_dir, "s2api.R")

if (!file.exists(s2api_path)) {
  cat("Error: s2api.R was not found in the same directory as this program.\n")
  cat("Make sure s2api.R is downloaded to the same directory as this program, and run again.\n")
  cat("Get it here: https://github.com/moodysanalytics/scenario-studio-api-codesamples/blob/master/R/s2api.R\n")
  quit(save = "no", status = 1)
}

source(s2api_path)

cat("\nGet your API keys here: https://economy.com/myeconomy/api-key-info\n\n")
access_key <- prompt_nonempty("Please enter your access key")
encryption_key <- prompt_nonempty("Please enter your encryption key")

tryCatch({
  cat("Instantiating API ...\n")
  api <- MA_S2Api$new(
    acc_key = access_key,
    enc_key = encryption_key,
    oauth = FALSE
  )

  cat("Testing connection ...\n")
  health <- api$get_health()
  health_text <- if (is.character(health) && length(health) == 1) {
    health
  } else {
    jsonlite::toJSON(health, auto_unbox = TRUE)
  }

  cat(paste0("API status: ", health_text, "\n"))
  if (grepl("HEALTHY", toupper(health_text), fixed = TRUE)) {
    cat("[PASS] API successfully accessed\n")
  } else {
    cat("[FAIL] Connection health check failed\n")
  }
}, error = function(ex) {
  cat("[FAIL] Something did not work, see exception below:\n")
  cat(paste0("Exception : ", conditionMessage(ex), "\n"))
})