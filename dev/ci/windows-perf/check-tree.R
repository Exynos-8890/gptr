# Mirror R CMD check's tests/ and 00_pkg_src/gptr layout; installed R/ is not source.
test_tree = function(source, installed_tests, stage) {
  dir.create(stage, recursive = TRUE)
  stopifnot(file.copy(installed_tests, stage, recursive = TRUE))
  src = file.path(stage, "00_pkg_src", "gptr")
  dir.create(src, recursive = TRUE)
  stopifnot(all(file.copy(file.path(source, c("DESCRIPTION", "NAMESPACE", "R")), src,
                         recursive = TRUE)))
  normalizePath(file.path(stage, "tests"), winslash = "/", mustWork = TRUE)
}
