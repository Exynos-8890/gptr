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

test_that("Rtools setup comparison keeps the same source-install regression file", {
  scope = new.env(parent = baseenv())
  sys.source(testthat::test_path("sample-plan.R"), envir = scope)
  expect_identical(scope$sample_plan("install-default"), "test-aaa-state.R")
  expect_identical(scope$sample_plan("install-no-rtools"), "test-aaa-state.R")
  expect_identical(scope$sample_plan("install-no-rtools-cold"), "test-aaa-state.R")
})

test_that("Rtools setup probes keep Rscript expressions out of Rtools42 Bash", {
  workflow = yaml::read_yaml(testthat::test_path(
    "../../../.github/workflows/windows-performance-setup.yaml"))
  steps = Filter(function(step) identical(step$name, "Verify sample partition"),
    workflow$jobs$setup$steps)
  expect_identical(steps[[1L]]$shell, "pwsh")
})

test_that("staged tests see original sources rather than the installed binary", {
  scope = new.env(parent = baseenv())
  sys.source(testthat::test_path("check-tree.R"), envir = scope)
  root = withr::local_tempdir()
  src = file.path(root, "source")
  dir.create(src)
  dir.create(file.path(src, "R"))
  writeLines("Package: gptr", file.path(src, "DESCRIPTION"))
  writeLines("", file.path(src, "NAMESPACE"))
  writeLines("probe = function() 1", file.path(src, "R", "probe.R"))
  installed_tests = file.path(root, "installed", "tests")
  dir.create(file.path(installed_tests, "testthat"), recursive = TRUE)
  writeLines("# unchanged test", file.path(installed_tests, "testthat", "test-probe.R"))
  staged = scope$test_tree(src, installed_tests, file.path(root, "check"))
  expect_false(file.exists(file.path(dirname(staged), "DESCRIPTION")))
  expect_identical(readLines(file.path(staged, "testthat", "test-probe.R")), "# unchanged test")
  expect_identical(readLines(file.path(dirname(staged), "00_pkg_src", "gptr", "R", "probe.R")),
                   "probe = function() 1")
})

test_that("comparison rejects changed expectations, skips and missing test blocks", {
  scope = new.env(parent = baseenv())
  sys.source(testthat::test_path("compare-sample.R"), envir = scope)
  baseline = data.frame(file = c("test-a.R", "test-b.R"), test = c("alpha", "beta"),
    passed = c(3L, 4L), failed = 0L, error = FALSE, warning = 0L, skipped = FALSE)
  expect_true(scope$same_sample(baseline, baseline[2:1, ]))
  changed = baseline
  changed$passed[[1L]] = 2L
  expect_false(scope$same_sample(baseline, changed))
  changed = baseline
  changed$skipped[[1L]] = TRUE
  expect_false(scope$same_sample(baseline, changed))
  expect_false(scope$same_sample(baseline, baseline[1L, ]))
})
