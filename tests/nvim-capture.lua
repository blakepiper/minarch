-- Test instrumentation only; never installed into the canonical config.
_G.minarch_smoke_errors = {}
local notify = vim.notify
vim.notify = function(message, level, opts)
  if level == vim.log.levels.ERROR then
    table.insert(_G.minarch_smoke_errors, tostring(message))
  end
  return notify(message, level, opts)
end
