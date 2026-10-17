audit_shards = function(manifests, files, native, sha) {
  count = length(manifests)
  stopifnot(count > 0L, !anyDuplicated(files), all(native %in% files))
  selectors = vapply(manifests, function(x) x$selector, character(1))
  stopifnot(setequal(selectors, paste0(seq_len(count), "/", count)))
  selected = unlist(lapply(manifests, function(x) x$selected), use.names = FALSE)
  stopifnot(!anyDuplicated(selected), setequal(selected, setdiff(files, native)))
  for (x in manifests) {
    stopifnot(identical(x$sha, sha), setequal(x$files, files), setequal(x$native, native),
      nrow(x$results) > 0L, setequal(unique(x$results$file), x$selected),
      all(x$results$failed == 0L), !any(x$results$error), all(x$results$warning == 0L))
  }
  do.call(rbind, lapply(manifests, function(x) x$results))
}

native_summary = function(lines) {
  line = utils::tail(lines[grepl("^\\[ FAIL ", lines)], 1L)
  stopifnot(length(line) == 1L)
  counts = as.integer(strsplit(trimws(gsub("[^0-9]+", " ", line)), " +")[[1L]])
  stopifnot(length(counts) == 4L, all(counts[1:2] == 0L), counts[[4L]] > 0L)
  counts
}

if (sys.nframe() == 0L) {
  args = commandArgs(TRUE)
  stopifnot(length(args) == 2L)
  files = sort(list.files("tests/testthat", pattern = "^test.*[.][rR]$"))
  entries = list.files("tests", pattern = "^native-.*[.]R$", full.names = TRUE)
  native = vapply(entries, function(path) {
    code = readLines(path, encoding = "UTF-8")
    line = code[grepl('stopifnot(file.exists("testthat/', code, fixed = TRUE)]
    stopifnot(length(line) == 1L)
    sub('.*testthat/(test-[A-Za-z0-9_-]+[.]R)".*', "\\1", line)
  }, character(1))
  for (version in c("release", "oldrel-4")) {
    root = file.path(args[[1L]], paste0("windows-shard-", version, "-", 1:4))
    paths = unlist(lapply(root, list.files, pattern = "^windows-shard-results[.]rds$",
      recursive = TRUE, full.names = TRUE), use.names = FALSE)
    stopifnot(length(paths) == 4L)
    result = audit_shards(lapply(paths, readRDS), files, unname(native), args[[2L]])
    for (directory in root) {
      for (entry in entries) {
        name = sub("[.]R$", ".Rout", basename(entry))
        output = list.files(directory, recursive = TRUE, full.names = TRUE)
        output = output[basename(output) == name]
        stopifnot(length(output) == 1L)
        native_summary(readLines(output, encoding = "UTF-8"))
      }
      log = list.files(directory, pattern = "^00check[.]log$", recursive = TRUE,
                       full.names = TRUE)
      stopifnot(length(log) == 1L)
      status = grep("^Status:", readLines(log, encoding = "UTF-8"), value = TRUE)
      stopifnot(length(status) == 1L, !grepl("ERROR|WARNING", status))
    }
    message(version, ": ", length(unique(result$file)), " ordinary files; ",
      length(native), " native files in original fresh entries; ", sum(result$passed),
      " pass; ", sum(result$skipped), " skip; no failures or warnings")
  }
}
