# Candidate preparation in a CI checkout only; no runtime package code or skips change.
variant = Sys.getenv("GPTR_CI_PERF_VARIANT")
stopifnot(variant %in% c("baseline", "optimized"))
paths = sort(list.files("tests/testthat", "^test.*[.][rR]$"))
dir.create("perf-evidence", showWarnings = FALSE)
writeLines(paths, "perf-evidence/test-inventory.txt")

path = "tests/testthat/test-subagent-team.R"
lines = readLines(path, encoding = "UTF-8")
title = grep("each report fits min(2000", lines, fixed = TRUE)
stopifnot(length(title) == 1L,
          identical(lines[[title + 1L]], "  local_team_fake(function(request) report)"))
if (variant == "optimized") {
  lines[[title + 1L]] = paste0("  local_team_fake(function(request) ",
                              "list(text = report, chunk = 65536L))")
}
regression = c(
  "", "test_that(\"report budgets agree for small and large fake deltas\", {",
  "  text = strrep(\"word \", 200L)", "  chunk = 16L",
  "  local_team_fake(function(request) list(text = text, chunk = chunk))",
  "  e = new.env(); e$two = list(a = 1, b = 2)", "  outputs = character()",
  "  for (chunk in c(16L, 65536L)) {",
  "    fan = gptr_map(team_call(\"x\", parallel = 2L, envir = e,",
  "                             context = list(sym_item(\"two\", e$two))))",
  "    txt = subagent_reports_block(list(session = fan), 100L)",
  "    expect_lte(est_tokens(txt), 100)",
  "    expect_true(grepl(\"[... truncated; full report in $text]\", txt, fixed = TRUE))",
  "    outputs = c(outputs, txt)", "  }",
  "  expect_identical(outputs[[1L]], outputs[[2L]])", "})")
writeLines(c(lines, regression), path)

path = "tests/testthat/setup.R"
lines = readLines(path, encoding = "UTF-8")
hit = grep('    OMP_THREAD_LIMIT = "2",', lines, fixed = TRUE)
stopifnot(length(hit) == 1L)
# Keep the repository's asserted setup contract. The inherited CPU affinity,
# not a different value of this variable, bounds the complete process tree.
probe = c("", "if (nzchar(Sys.getenv(\"GPTR_PERF_LAUNCHER\"))) {",
  "  status = system2(Sys.getenv(\"GPTR_PERF_PYTHON\"),",
  "    c(shQuote(Sys.getenv(\"GPTR_PERF_LAUNCHER\")), \"--verify-parent\"))",
  "  stopifnot(identical(status, 0L))", "}")
writeLines(c(lines, probe), path)

# Keep the Windows native/ordinary split, including each fresh native R process.
entries = list.files("tests", "^(testthat|native-.*)[.]R$", full.names = TRUE)
for (entry in entries) {
  lines = readLines(entry, encoding = "UTF-8")
  stopifnot(any(grepl('test_check("gptr"', lines, fixed = TRUE)))
  lines = gsub('test_check("gptr"', 'perf_test_check("gptr"', lines, fixed = TRUE)
  id = tools::file_path_sans_ext(basename(entry))
  wrapper = c(
    "perf_test_check = function(..., stop_on_failure = TRUE) {",
    "  old = options(Ncpus = 2L)", "  on.exit(options(old))",
    "  testthat::set_max_fails(Inf)",
    "  result = testthat::test_check(..., stop_on_failure = FALSE)",
    "  table = as.data.frame(result)",
    "  table = table[, !vapply(table, is.list, logical(1)), drop = FALSE]",
    sprintf('  saveRDS(table, "perf-results-%s.rds")', id),
    "  if (stop_on_failure && any(table$failed > 0 | table$error)) stop(\"Test failures.\")",
    "  invisible(result)", "}")
  writeLines(c(wrapper, lines), entry)
}
stopifnot(identical(paths, sort(list.files("tests/testthat", "^test.*[.][rR]$"))))
message("Prepared ", variant, "; unchanged test-file inventory; original assertions retained.")
