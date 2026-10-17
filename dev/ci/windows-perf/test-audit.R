test_that("the full shard audit rejects missing, duplicated or failing coverage", {
  scope = new.env(parent = baseenv())
  sys.source(testthat::test_path("audit-shards.R"), envir = scope)
  files = c("test-a.R", "test-b.R", "test-native.R")
  make = function(i) list(selector = paste0(i, "/2"), files = files,
    native = "test-native.R", selected = files[[i]], sha = "same-source",
    results = data.frame(file = files[[i]], test = "probe", passed = i,
      failed = 0L, error = FALSE, warning = 0L, skipped = FALSE))
  manifests = lapply(1:2, make)
  result = scope$audit_shards(manifests, files, "test-native.R", "same-source")
  expect_identical(sum(result$passed), 3L)
  expect_error(scope$audit_shards(manifests[1L], files, "test-native.R", "same-source"))
  changed = manifests
  changed[[2L]]$selected = "test-a.R"
  changed[[2L]]$results$file = "test-a.R"
  expect_error(scope$audit_shards(changed, files, "test-native.R", "same-source"))
  changed = manifests
  changed[[2L]]$results$failed = 1L
  expect_error(scope$audit_shards(changed, files, "test-native.R", "same-source"))
  changed = manifests
  changed[[2L]]$results$file = "test-native.R"
  expect_error(scope$audit_shards(changed, files, "test-native.R", "same-source"))
  expect_error(scope$audit_shards(manifests, files, "test-native.R", "other-source"))
})

test_that("native output must contain real passing expectations, not an empty entry", {
  scope = new.env(parent = baseenv())
  sys.source(testthat::test_path("audit-shards.R"), envir = scope)
  line = "[ FAIL 0 | WARN 0 | SKIP 1 | PASS 19 ]"
  expect_identical(scope$native_summary(c("R header", line, "proc.time()")), c(0L, 0L, 1L, 19L))
  expect_error(scope$native_summary("R header only"))
  expect_error(scope$native_summary("[ FAIL 1 | WARN 0 | SKIP 0 | PASS 19 ]"))
  expect_error(scope$native_summary("[ FAIL 0 | WARN 0 | SKIP 1 | PASS 0 ]"))
})
