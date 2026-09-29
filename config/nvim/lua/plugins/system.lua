-- Minarch uses system language tools and Lua-based completion.
return {
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = { mason = false },
      },
    },
  },
  {
    "saghen/blink.cmp",
    opts = { fuzzy = { implementation = "lua" } },
  },
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- Format Lua through the system language server.
      opts.formatters_by_ft.lua = {}
    end,
  },
}
