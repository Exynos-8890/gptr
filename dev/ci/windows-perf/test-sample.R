test_that("sample arms admit the same tests without overlap between shards", {
  scope = new.env(parent = baseenv())
  sys.source(testthat::test_path("sample-plan.R"), envir = scope)
  baseline = scope$sample_plan("serial")
  expect_setequal(baseline, paste0("test-", c("aaa-state", "auth-redact", "cli-claude",
    "doc-io", "http-reactor", "json-partial", "session-store", "subagent-team"), ".R"))
  expect_identical(scope$sample_plan("parallel2"), baseline)
  shards = c(scope$sample_plan("shard1"), scope$sample_plan("shard2"))
  expect_setequal(shards, baseline)
  expect_identical(anyDuplicated(shards), 0L)
  expect_error(scope$sample_plan("unknown"), "Unknown sample arm", fixed = TRUE)
})
