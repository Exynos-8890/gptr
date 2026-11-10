test_that("direct R runs a modifying hook without the permission gate or checkpoints", {
  local_project()
  local_permission_rules()
  gptr_permissions(deny = "r(fn:writeLines)")
  seen = new.env()
  seen$events = character()
  seen$risk_is_null = FALSE
  seen$result_hook_calls = 0L
  offs = list(
    gptr_register(gptr_hook("tool_call", function(event, ctx) {
      if (identical(event$tool_name, "r")) {
        seen$events = c(seen$events, event$type)
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
    gptr_register(gptr_hook("tool_result", function(event, ctx) {
      if (identical(event$tool_name, "r")) seen$result_hook_calls = seen$result_hook_calls + 1L
      NULL
    }))
  )
  withr::defer(for (off in offs) off())
  envir = new.env()
  envir$x = 1:3
  code = "writeLines('base', 'result.txt'); answer = sum(x)"
  fake = local_fake_provider(list(fake_tool("r", code = code), "done"))
  session = peter("calculate", model = fake, envir = envir, mode = "auto")

  expect_identical(envir$answer, 7L)
  expect_identical(if (file.exists("result.txt")) readLines("result.txt") else NULL, "changed")
  expect_true(seen$risk_is_null)
  expect_identical(seen$result_hook_calls, 0L)
  expect_identical(seen$events, c("tool_execution_start", "tool_call", "tool_execution_end"))
  gptr_rewind(session, 0)
  expect_identical(envir$answer, 7L)
  expect_identical(if (file.exists("result.txt")) readLines("result.txt") else NULL, "changed")
})

test_that("a direct R tool_call hook can block execution", {
  local_project()
  off = gptr_register(gptr_hook("tool_call", function(event, ctx) {
    if (identical(event$tool_name, "r")) list(decision = "block", reason = "R is blocked")
  }))
  withr::defer(off())
  envir = new.env()
  fake = local_fake_provider(list(fake_tool("r", code = "answer = 42L"), "done"))
  peter("calculate", model = fake, envir = envir, mode = "auto")

  expect_false(exists("answer", envir = envir, inherits = FALSE))
  result = fake_requests(fake)[[2L]]$last_results[[1L]]
  expect_true(result$is_error)
  expect_match(msg_text(result), "Tool execution was blocked: R is blocked", fixed = TRUE)
})

test_that("a direct non-R tool still follows its permission mode", {
  root = local_project()
  local_gptr_options(interactive = FALSE, noninteractive_ask = "deny")
  fake = local_fake_provider(list(fake_tool("write", path = "result.txt", content = "denied"),
                                  "done"))
  peter("write", model = fake, envir = new.env(), mode = "manual")

  result = fake_requests(fake)[[2L]]$last_results[[1L]]
  expect_true(result$is_error)
  expect_false(file.exists(file.path(root, "result.txt")))
})
