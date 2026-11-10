test_that("a served R call runs a modifying hook without the permission gate", {
  local_project()
  local_permission_rules()
  gptr_permissions(deny = "r(fn:writeLines)")
  seen = new.env()
  seen$hook_calls = 0L
  seen$risk_is_null = FALSE
  seen$events = character()
  hooks = list(
    gptr_register(gptr_hook("tool_call", function(event, ctx) {
      if (identical(event$tool_name, "r")) {
        seen$hook_calls = seen$hook_calls + 1L
        seen$risk_is_null = is.null(event$risk)
        code = "writeLines('changed', 'result.txt'); answer = sum(x) + 1L"
        return(list(decision = "modify", input = list(code = code)))
      }
      NULL
    })),
    gptr_register(gptr_hook("tool_execution_start", function(event, ctx) {
      if (identical(event$tool_name, "r")) seen$events = c(seen$events, event$type)
      NULL
    })),
    gptr_register(gptr_hook("tool_execution_end", function(event, ctx) {
      if (identical(event$tool_name, "r")) seen$events = c(seen$events, event$type)
      NULL
    })),
    gptr_register(gptr_hook("before_request", function(event, ctx) {
      if (is.null(seen$result)) {
        code = "writeLines('base', 'result.txt'); answer = sum(x)"
        msg = mcp_test_msg("tools/call", list(name = "r", arguments = list(code = code)))
        seen$result = mcp_dispatch_local(msg, ctx$session)$result
      }
      NULL
    }))
  )
  withr::defer(for (off in hooks) off())
  envir = new.env()
  envir$x = 1:3
  session = peter("calculate", model = local_fake_provider(list("done")),
                  envir = envir, mode = "auto")

  expect_false(seen$result$isError)
  expect_identical(envir$answer, 7L)
  expect_identical(readLines("result.txt"), "changed")
  expect_identical(seen$hook_calls, 1L)
  expect_true(seen$risk_is_null)
  expect_identical(seen$events, c("tool_execution_start", "tool_execution_end"))
})

test_that("a non-R served tool still follows its permission mode", {
  local_project()
  session = peter("hello", model = local_fake_provider(list("done")),
                  envir = new.env(), mode = "manual")
  msg = mcp_test_msg("tools/call", list(name = "write",
    arguments = list(path = "result.txt", content = "not allowed")))
  result = mcp_dispatch_local(msg, session)$result

  expect_true(result$isError)
  expect_match(result$content[[1L]]$text, "Permission denied", fixed = TRUE)
  expect_false(file.exists("result.txt"))
})

test_that("an idle served R tool_call hook can block execution", {
  local_project()
  off = gptr_register(gptr_hook("tool_call", function(event, ctx) {
    if (identical(event$tool_name, "r")) list(decision = "block", reason = "R is blocked")
  }))
  withr::defer(off())
  envir = new.env()
  session = peter("hello", model = local_fake_provider(list("done")), envir = envir,
                  mode = "auto")
  msg = mcp_test_msg("tools/call", list(name = "r", arguments = list(code = "answer = 42L")))
  result = mcp_dispatch_local(msg, session)$result

  expect_true(result$isError)
  expect_match(result$content[[1L]]$text, "Tool execution was blocked: R is blocked", fixed = TRUE)
  expect_false(exists("answer", envir = envir, inherits = FALSE))
})
