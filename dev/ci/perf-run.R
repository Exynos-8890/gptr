# Run the original check or serial resource gate; persist scalar evidence, never mask failures.
args = commandArgs(TRUE)
stopifnot(length(args) == 1L, args %in% c("check", "connections", "copy"))
mode = args[[1L]]
variant = Sys.getenv("GPTR_CI_PERF_VARIANT")
stopifnot(variant %in% c("baseline", "optimized"))
dir.create("perf-evidence", showWarnings = FALSE)
if (mode == "check") {
  rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"),
    build_args = c("--no-manual", "--compact-vignettes=gs+qpdf"),
    error_on = "warning", check_dir = "check")
  log = readLines("check/gptr.Rcheck/00check.log", encoding = "UTF-8")
  stopifnot(any(startsWith(log, "Status:")))
} else {
  # A parent-only connection assertion would miss worker leaks; these lanes stay serial.
  Sys.setenv(TESTTHAT_PARALLEL = "false")
  # Both arms need the same installed-package-dependent tests admitted. The
  # baseline still loads source with devtools; only the candidate tests installed.
  if (variant %in% c("baseline", "optimized")) {
    lib = file.path(tempdir(), "perf-library")
    dir.create(lib)
    install = processx::run(file.path(R.home("bin"), "R"),
      c("CMD", "INSTALL", "--no-multiarch", "--no-docs", paste0("--library=", lib), "."),
      echo = TRUE, timeout = 300, error_on_status = FALSE)
    stopifnot(install$status == 0L)
    .libPaths(c(lib, .libPaths()))
    Sys.setenv(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  }
  run_tests = function(...) {
    if (variant == "baseline") {
      result = devtools::test(...)
    } else {
      result = testthat::test_local(".", load_package = "installed", ...)
    }
    table = as.data.frame(result)
    table = table[, !vapply(table, is.list, logical(1)), drop = FALSE]
    saveRDS(table, "perf-evidence/perf-results-gate.rds")
    result
  }
  testthat::set_max_fails(Inf)
  if (mode == "connections") {
    source("dev/ci/check-connections.R", local = TRUE)
    run_gate(test = run_tests)
  } else {
    stopifnot(capabilities("profmem"))
    run_tests(filter = "copy", stop_on_failure = TRUE)
  }
}
