# Sampling only: the unchanged installed tests, under the same CPU budget in every arm.
(function() {
  repo = normalizePath(".", winslash = "/")
  source("dev/ci/windows-perf/sample-plan.R", local = TRUE)
  source("dev/ci/windows-perf/check-tree.R", local = TRUE)
  args = commandArgs(TRUE)
  stopifnot(length(args) == 1L)
  arm = args[[1L]]
  files = sample_plan(arm)
  stopifnot(all(files %in% list.files("tests/testthat")))
  out = file.path(repo, "dev/ci/windows-perf/evidence")
  dir.create(out, showWarnings = FALSE)
  writeLines(files, file.path(out, "files.txt"))
  root = withr::local_tempdir("gptr-windows-perf-")
  paths = c(HOME = "home", USERPROFILE = "home", APPDATA = "config", LOCALAPPDATA = "cache",
    R_USER_CONFIG_DIR = "config", R_USER_DATA_DIR = "data", R_USER_CACHE_DIR = "cache",
    XDG_CONFIG_HOME = "config", XDG_CACHE_HOME = "cache", XDG_DATA_HOME = "data",
    GPTR_PROJECT_ROOT = "project")
  paths = stats::setNames(file.path(root, paths), names(paths))
  for (path in unique(paths)) dir.create(path)
  withr::local_envvar(c(paths, GPTR_REPLAY = "replay", GPTR_LIVE_TESTS = "false",
    NOT_CRAN = "true", `_R_CHECK_PACKAGE_NAME_` = "gptr", OMP_THREAD_LIMIT = "2",
    OMP_NUM_THREADS = "1", OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
    VECLIB_MAXIMUM_THREADS = "1", RCPP_PARALLEL_NUM_THREADS = "1",
    TESTTHAT_PARALLEL = if (arm == "parallel2") "true" else "false", TESTTHAT_CPUS = "2"))
  withr::local_options(Ncpus = 2L)
  lib = file.path(root, "library")
  dir.create(lib)
  withr::local_libpaths(c(lib, .libPaths()))
  withr::local_envvar(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  start = proc.time()[["elapsed"]]
  install = processx::run(file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", "--install-tests", "--no-multiarch", paste0("--library=", lib), repo),
    echo = TRUE, error_on_status = FALSE, timeout = 300)
  installed = proc.time()[["elapsed"]] - start
  stopifnot(install$status == 0L)
  tests = system.file("tests", package = "gptr", lib.loc = lib, mustWork = TRUE)
  tests = test_tree(repo, tests, file.path(root, "check"))
  # Probe every testthat worker; do not alter any test body or expectation.
  probe = c("local({", "  status = system2(Sys.getenv('GPTR_WINDOWS_PERF_PYTHON'),",
    "    c('-I', '-B', shQuote(Sys.getenv('GPTR_WINDOWS_PERF_LAUNCHER')), '--verify-parent'))",
    "  stopifnot(identical(status, 0L))", "})")
  writeLines(probe, file.path(tests, "testthat/setup-perf-cpu.R"))
  withr::local_dir(tests)
  stems = sub("^test-", "", sub("[.]R$", "", files))
  filter = paste0("^(", paste(stems, collapse = "|"), ")$")
  testthat::set_max_fails(Inf)
  t0 = proc.time()[["elapsed"]]
  result = testthat::test_check("gptr", filter = filter, reporter = "summary",
                                stop_on_failure = FALSE, stop_on_warning = FALSE)
  elapsed = proc.time()[["elapsed"]] - t0
  table = as.data.frame(result)
  table = table[, !vapply(table, is.list, logical(1)), drop = FALSE]
  saveRDS(table, file.path(out, "results.rds"))
  saveRDS(list(arm = arm, r = R.version.string, install_seconds = installed,
    test_seconds = elapsed, total_seconds = proc.time()[["elapsed"]] - start,
    sha = Sys.getenv("GITHUB_SHA")), file.path(out, "timing.rds"))
  stopifnot(identical(sort(unique(table$file)), files), nrow(table) > 0L,
    all(table$failed == 0L), !any(table$error), all(table$warning == 0L))
  message(arm, ": ", sum(table$passed), " pass; ", sum(table$skipped),
          " skip; ", round(elapsed, 2L), " test seconds")
})()
