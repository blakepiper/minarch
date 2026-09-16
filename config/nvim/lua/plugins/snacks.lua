return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          projects = {
            -- No ~/dev or ~/projects here, so scan home itself.
            -- Finds repo roots (blarchy, joyce, ...) below ~.
            dev = { "~" },
          },
        },
      },
    },
  },
}
