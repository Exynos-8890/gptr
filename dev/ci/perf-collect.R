dir.create("perf-evidence", showWarnings = FALSE)
files = list.files("check/gptr.Rcheck/tests", "^perf-results-.*[.]rds$", full.names = TRUE)
if (length(files)) stopifnot(all(file.copy(files, "perf-evidence", overwrite = FALSE)))
for (name in c("00check.log", "00install.out")) {
  path = file.path("check/gptr.Rcheck", name)
  if (file.exists(path)) file.copy(path, "perf-evidence", overwrite = FALSE)
}
logs = list.files("check/gptr.Rcheck/tests", "[.]Rout", full.names = TRUE)
if (length(logs)) stopifnot(all(file.copy(logs, "perf-evidence", overwrite = FALSE)))
