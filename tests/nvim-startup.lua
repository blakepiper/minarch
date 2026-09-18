-- Allow VimEnter/VeryLazy and scheduled startup callbacks to run before checking.
vim.defer_fn(function()
  local ok, err = pcall(function()
    assert(package.loaded["config.lazy"], "Minarch Neovim bootstrap did not load")
    assert(package.loaded["lazyvim.config"], "LazyVim did not load")
    assert(vim.g.colors_name == "seafoam", "Seafoam colorscheme did not load")
    assert(vim.v.errmsg == "", vim.v.errmsg)
    assert(#_G.minarch_smoke_errors == 0, table.concat(_G.minarch_smoke_errors, "\n"))
  end)
  if not ok then
    io.stderr:write(tostring(err) .. "\n")
    vim.cmd("cquit 1")
  else
    vim.cmd("qa!")
  end
end, 1500)
