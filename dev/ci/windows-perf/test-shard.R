test_that("CI partitions run every ordinary file exactly once and reject bad selectors", {
  scope = new.env(parent = baseenv())
  sys.source(testthat::test_path("../../../tests/testthat/helper-ci-shard.R"), envir = scope)
  files = paste0("test-", letters[1:9], ".R")
  groups = lapply(paste0(1:4, "/4"), function(id) scope$ci_test_shard(files, id))
  expect_identical(groups[[1L]], files[c(1L, 5L, 9L)])
  expect_identical(groups[[4L]], files[c(4L, 8L)])
  expect_identical(sort(unlist(groups, use.names = FALSE)), files)
  expect_identical(anyDuplicated(unlist(groups)), 0L)
  expect_identical(scope$ci_test_shard(files, ""), files)
  expect_identical(scope$ci_test_shard(rev(files), "1/4"), groups[[1L]])
  for (id in c("0/4", "5/4", "1/0", "1/100", "1.5/4", "a", "1/4x")) {
    expect_error(scope$ci_test_shard(files, id))
  }
})
