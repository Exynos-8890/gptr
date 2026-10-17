# Two balanced groups of ordinary files, including time-sensitive and CPU-heavy tests.
sample_plan = function(arm) {
  groups = list(
    c("subagent-team", "auth-redact", "cli-claude", "json-partial"),
    c("doc-io", "session-store", "aaa-state", "http-reactor")
  )
  names = switch(arm, serial = , parallel2 = unlist(groups, use.names = FALSE),
    shard1 = groups[[1L]], shard2 = groups[[2L]], stop("Unknown sample arm: ", arm))
  sort(paste0("test-", names, ".R"))
}
