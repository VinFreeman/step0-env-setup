#!/usr/bin/env Rscript

split_env <- function(value) {
  value <- trimws(value)
  if (!nzchar(value)) return(character())
  trimws(unlist(strsplit(value, "[,[:space:]]+")))
}

r_packages <- split_env(Sys.getenv("ST_STEP0_VALIDATE_R_PACKAGES", ""))
python_modules <- split_env(Sys.getenv("ST_STEP0_VALIDATE_PYTHON_MODULES", ""))
failures <- character()

if (length(r_packages)) {
  missing_r <- r_packages[!vapply(r_packages, requireNamespace, quietly = TRUE, FUN.VALUE = logical(1))]
  if (length(missing_r)) failures <- c(failures, paste0("Missing R packages: ", paste(missing_r, collapse = ", ")))
}

cat("R version: ", R.version.string, "\n", sep = "")
for (pkg in r_packages) {
  if (requireNamespace(pkg, quietly = TRUE)) {
    cat(pkg, " ", as.character(utils::packageVersion(pkg)), "\n", sep = "")
  }
}

if (length(python_modules)) {
  module_csv <- paste(python_modules, collapse = ",")
  cmd <- "import importlib, os\nmods=os.environ['ST_STEP0_VALIDATE_PYTHON_MODULES'].replace(',', ' ').split()\nfor mod in mods:\n    importlib.import_module(mod)\nprint('python modules ok')\n"
  status <- system2("python", c("-c", shQuote(cmd)), stdout = TRUE, stderr = TRUE, env = paste0("ST_STEP0_VALIDATE_PYTHON_MODULES=", module_csv))
  exit_code <- attr(status, "status")
  cat(paste(status, collapse = "\n"), "\n", sep = "")
  if (!is.null(exit_code) && exit_code != 0) failures <- c(failures, paste0("Python import validation failed: ", paste(python_modules, collapse = ", ")))
}

if (length(failures)) {
  cat(paste0(failures, collapse = "\n"), "\n")
  quit(status = 1)
}

cat("Step0 validation passed.\n")
