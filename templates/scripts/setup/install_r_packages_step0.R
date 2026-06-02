#!/usr/bin/env Rscript

options(repos = c(CRAN = Sys.getenv("ST_STEP0_CRAN_MIRROR", "https://cloud.r-project.org")))
options(BioC_mirror = Sys.getenv("ST_STEP0_BIOC_MIRROR", "https://bioconductor.org"))
options(Ncpus = as.integer(Sys.getenv("ST_STEP0_INSTALL_NCPUS", "2")))
max_dependency_depth <- as.integer(Sys.getenv("ST_STEP0_MAX_DEPENDENCY_DEPTH", "3"))

status_file <- Sys.getenv("ST_STEP0_R_STATUS_FILE", "logs/setup/step0_r_packages.status.tsv")
failed_file <- Sys.getenv("ST_STEP0_R_FAILED_FILE", sub("[.]status[.]tsv$", ".failed.tsv", status_file))
package_log_dir <- Sys.getenv("ST_STEP0_R_PACKAGE_LOG_DIR", file.path(dirname(status_file), "step0_r_package_logs"))
package_plan <- Sys.getenv("ST_STEP0_R_PACKAGE_PLAN", "config/step0_r_packages.tsv")

dir.create(dirname(status_file), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(failed_file), recursive = TRUE, showWarnings = FALSE)
dir.create(package_log_dir, recursive = TRUE, showWarnings = FALSE)

if (!file.exists(status_file)) {
  writeLines("time\tgroup\tpackage\tstatus\tdetails\tlog_file", status_file)
}

failed_packages <- data.frame(group = character(), package = character(), installer = character(), reason = character(), log_file = character(), stringsAsFactors = FALSE)

append_status <- function(group, status, details = "", package = "", log_file = "") {
  write(paste(format(Sys.time(), "%F %T"), group, package, status, details, log_file, sep = "\t"), file = status_file, append = TRUE)
  message("[", group, "] ", if (nzchar(package)) paste0(package, " ") else "", status, if (nzchar(details)) paste0(": ", details) else "")
}

package_log_file <- function(group, pkg) {
  safe <- gsub("[^A-Za-z0-9_.-]+", "_", paste(group, pkg, sep = "__"))
  file.path(package_log_dir, paste0(safe, ".log"))
}

with_package_log <- function(log_file, expr) {
  con <- file(log_file, open = "at")
  sink(con, type = "output")
  sink(con, type = "message")
  on.exit({ sink(type = "message"); sink(type = "output"); close(con) }, add = TRUE)
  force(expr)
}

record_failed_package <- function(group, pkg, installer_name, reason, log_file) {
  failed_packages[nrow(failed_packages) + 1L, ] <<- list(group, pkg, installer_name, reason, log_file)
}

extract_missing_dependencies <- function(log_file, pkg) {
  if (!file.exists(log_file)) return(character())
  lines <- readLines(log_file, warn = FALSE)
  hit <- grep("there is no package called|dependencies?.*not available|dependency .* is not available|ERROR: dependencies|namespace .* is not available", lines, value = TRUE, ignore.case = TRUE)
  if (!length(hit)) return(character())
  quoted <- unlist(regmatches(hit, gregexpr("['`][A-Za-z][A-Za-z0-9.]*['`]", hit, perl = TRUE)))
  quoted <- gsub("['`]", "", quoted)
  no_package <- sub(".*there is no package called ['`]([^'`]+)['`].*", "\\1", hit, ignore.case = TRUE)
  no_package <- no_package[no_package != hit]
  deps_line <- sub(".*dependencies? ['`]([^'`]+)['`].*", "\\1", hit, ignore.case = TRUE)
  deps_line <- deps_line[deps_line != hit]
  deps_split <- unlist(strsplit(deps_line, "',[[:space:]]*'|'[[:space:]]*,[[:space:]]*'|,[[:space:]]*", perl = TRUE))
  deps_split <- gsub("['`]", "", deps_split)
  candidates <- unique(c(quoted, no_package, deps_split))
  candidates <- trimws(candidates)
  candidates <- candidates[nzchar(candidates) & grepl("^[A-Za-z][A-Za-z0-9.]*$", candidates)]
  setdiff(candidates, c(pkg, "ERROR", "WARNING", "package", "packages"))
}

attempt_package <- function(group, pkg, installer, installer_name, log_file, attempt_label) {
  tryCatch({
    with_package_log(log_file, {
      cat("[", format(Sys.time(), "%F %T"), "] package=", pkg, " installer=", installer_name, " attempt=", attempt_label, "\n", sep = "")
      installer(pkg)
    })
    if (!requireNamespace(pkg, quietly = TRUE)) return(list(ok = FALSE, reason = "missing_after_install"))
    list(ok = TRUE, reason = "")
  }, error = function(e) list(ok = FALSE, reason = conditionMessage(e)))
}

install_one_package <- function(group, pkg, installer, installer_name, depth = 0L, stack = character()) {
  log_file <- package_log_file(group, pkg)
  if (pkg %in% stack) {
    append_status(group, "dependency_cycle_skipped", paste(stack, collapse = "->"), package = pkg, log_file = log_file)
    return(FALSE)
  }
  if (requireNamespace(pkg, quietly = TRUE)) {
    append_status(group, "package_already_present", paste("depth", depth), package = pkg, log_file = log_file)
    return(TRUE)
  }
  append_status(group, "package_started", paste("depth", depth), package = pkg, log_file = log_file)
  result <- attempt_package(group, pkg, installer, installer_name, log_file, paste0("initial_depth_", depth))
  if (isTRUE(result$ok)) {
    append_status(group, "package_finished", paste("depth", depth), package = pkg, log_file = log_file)
    return(TRUE)
  }
  deps <- extract_missing_dependencies(log_file, pkg)
  append_status(group, if (length(deps)) "dependency_scan_found" else "dependency_scan_none", if (length(deps)) paste(deps, collapse = ",") else result$reason, package = pkg, log_file = log_file)
  if (length(deps) && depth < max_dependency_depth) {
    dep_ok_any <- FALSE
    for (dep in deps) {
      append_status(group, "dependency_install_started", dep, package = pkg, log_file = log_file)
      dep_ok <- install_one_package(paste0(group, "_dependency"), dep, installer, installer_name, depth = depth + 1L, stack = c(stack, pkg))
      append_status(group, if (isTRUE(dep_ok)) "dependency_install_finished" else "dependency_install_failed", dep, package = pkg, log_file = log_file)
      dep_ok_any <- dep_ok_any || isTRUE(dep_ok)
    }
    if (dep_ok_any) {
      append_status(group, "retry_after_dependencies", paste("depth", depth), package = pkg, log_file = log_file)
      result <- attempt_package(group, pkg, installer, installer_name, log_file, paste0("retry_after_dependencies_depth_", depth))
      if (isTRUE(result$ok)) {
        append_status(group, "package_finished", paste("depth", depth), package = pkg, log_file = log_file)
        return(TRUE)
      }
    }
  } else if (length(deps)) {
    append_status(group, "dependency_depth_limit_reached", paste("max_depth", max_dependency_depth), package = pkg, log_file = log_file)
  }
  append_status(group, "package_failed", result$reason, package = pkg, log_file = log_file)
  record_failed_package(group, pkg, installer_name, result$reason, log_file)
  FALSE
}

write_failed_packages <- function() {
  if (!nrow(failed_packages)) {
    writeLines("group\tpackage\tinstaller\treason\tlog_file", failed_file)
    return(invisible(FALSE))
  }
  utils::write.table(failed_packages, file = failed_file, sep = "\t", row.names = FALSE, quote = FALSE)
  invisible(TRUE)
}

plan <- utils::read.delim(package_plan, stringsAsFactors = FALSE, check.names = FALSE)
for (i in seq_len(nrow(plan))) {
  row <- plan[i, , drop = FALSE]
  group <- row[["group"]]
  pkg <- row[["package"]]
  source <- row[["source"]]
  ref <- row[["ref"]]
  if (!nzchar(pkg)) next
  if (identical(source, "cran")) {
    install_one_package(group, pkg, function(x) install.packages(x, dependencies = TRUE), "cran")
  } else if (identical(source, "bioc")) {
    if (!requireNamespace("BiocManager", quietly = TRUE)) install.packages("BiocManager")
    install_one_package(group, pkg, function(x) BiocManager::install(x, ask = FALSE, update = FALSE), "bioc")
  } else if (identical(source, "github")) {
    if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
    log_file <- package_log_file(group, pkg)
    if (requireNamespace(pkg, quietly = TRUE)) {
      append_status(group, "package_already_present", ref, package = pkg, log_file = log_file)
      next
    }
    append_status(group, "package_started", ref, package = pkg, log_file = log_file)
    result <- tryCatch({
      with_package_log(log_file, remotes::install_github(ref, upgrade = "never", dependencies = c("Depends", "Imports", "LinkingTo")))
      list(ok = requireNamespace(pkg, quietly = TRUE), reason = "missing_after_install")
    }, error = function(e) list(ok = FALSE, reason = conditionMessage(e)))
    if (isTRUE(result$ok)) append_status(group, "package_finished", ref, package = pkg, log_file = log_file) else {
      append_status(group, "package_failed", result$reason, package = pkg, log_file = log_file)
      record_failed_package(group, pkg, "github", result$reason, log_file)
    }
  } else {
    append_status(group, "package_failed", paste("unknown_source", source), package = pkg, log_file = package_log_file(group, pkg))
    record_failed_package(group, pkg, source, "unknown_source", package_log_file(group, pkg))
  }
}

has_failed <- write_failed_packages()
append_status("all", if (isTRUE(has_failed)) "finished_with_failures" else "finished", if (isTRUE(has_failed)) failed_file else "Step0 R package installation step finished")
