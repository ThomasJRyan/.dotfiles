return {
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      opts.routes = opts.routes or {}
      table.insert(opts.routes, 1, {
        filter = {
          event = "lsp",
          kind = "progress",
          find = "pyright",
        },
        opts = { skip = true },
      })
    end,
  },
}
