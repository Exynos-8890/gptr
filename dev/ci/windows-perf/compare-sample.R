sample_signature = function(table) {
  table = table[, c("file", "test", "passed", "failed", "error", "warning", "skipped")]
  table = table[do.call(order, table), , drop = FALSE]
  rownames(table) = NULL
  table
}

same_sample = function(baseline, candidate) {
  identical(sample_signature(baseline), sample_signature(candidate))
}

if (sys.nframe() == 0L) {
  root = commandArgs(TRUE)
  stopifnot(length(root) == 1L)
  read = function(arm, file) readRDS(file.path(root, paste0("windows-sample-", arm), file))
  a = read("serial", "results.rds")
  b = read("parallel2", "results.rds")
  shards = rbind(read("shard1", "results.rds"), read("shard2", "results.rds"))
  cat("Parallel signatures identical:", same_sample(a, b), "\n")
  cat("Shard-union signatures identical:", same_sample(a, shards), "\n")
  for (arm in c("serial", "parallel2", "shard1", "shard2")) {
    x = read(arm, "results.rds")
    t = read(arm, "timing.rds")
    cat(arm, ":", t$test_seconds, "test seconds;", sum(x$passed), "pass;",
        sum(x$failed) + sum(x$error), "fail;", sum(x$skipped), "skip\n")
  }
  stopifnot(same_sample(a, b), same_sample(a, shards),
    all(a$failed == 0L), !any(a$error), all(a$warning == 0L))
}
