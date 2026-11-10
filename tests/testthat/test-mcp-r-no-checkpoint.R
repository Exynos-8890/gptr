test_that("a served R change remains after rewind in the execution-only experiment", {
  local_project()
  seen = new.env()
  off = gptr_register(gptr_hook("before_request", function(event, ctx) {
    if (is.null(seen$result)) {
      msg = mcp_test_msg("tools/call", list(name = "r", arguments = list(code = "x = 2L")))
      seen$result = mcp_dispatch_local(msg, ctx$session)$result
    }
    NULL
  }))
  withr::defer(off())
  envir = new.env()
  envir$x = 1L
  session = peter("change x", model = local_fake_provider(list("done")),
                  envir = envir, mode = "auto")

  expect_false(seen$result$isError)
  expect_identical(envir$x, 2L)
  gptr_rewind(session, 0)
  expect_identical(envir$x, 2L)
})
