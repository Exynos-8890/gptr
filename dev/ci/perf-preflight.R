# Offline regression for the experiment's preparation, not package tests.
root = normalizePath(".")
old = Sys.getenv("GPTR_CI_PERF_VARIANT", unset = NA_character_)
for (variant in c("baseline", "optimized")) {
  fixture = tempfile(paste0("gptr-perf-", variant, "-"))
  dir.create(fixture)
  stopifnot(file.copy(file.path(root, "tests"), fixture, recursive = TRUE))
  Sys.setenv(GPTR_CI_PERF_VARIANT = variant)
  setwd(fixture)
  source(file.path(root, "dev/ci/perf-prepare.R"), local = new.env())
  setup = readLines("tests/testthat/setup.R")
  stopifnot(any(grepl('OMP_THREAD_LIMIT = "2"', setup, fixed = TRUE)),
            !any(grepl('OMP_THREAD_LIMIT = "1"', setup, fixed = TRUE)),
            identical(readLines("tests/testthat/test-zzz.R"),
                      readLines(file.path(root, "tests/testthat/test-zzz.R"))))
  entries = list.files("tests", "^(testthat|native-.*)[.]R$", full.names = TRUE)
  for (entry in entries) {
    parse(entry)
    stopifnot(any(grepl('perf_test_check("gptr"', readLines(entry), fixed = TRUE)))
  }
  parse("tests/testthat/setup.R")
  parse("tests/testthat/test-subagent-team.R")
  setwd(root)
  message("Preparation contract passed: ", variant)
}
if (is.na(old)) Sys.unsetenv("GPTR_CI_PERF_VARIANT") else Sys.setenv(GPTR_CI_PERF_VARIANT = old)
