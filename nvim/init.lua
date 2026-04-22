vim.lsp.enable('pyright')
vim.wo.number = true
vim.cmd [[colorscheme catppuccin]]
vim.cmd [[set expandtab]]
vim.cmd [[set tabstop=4]]
vim.cmd [[set shiftwidth=4]]

vim.pack.add({
    { src = "https://github.com/neovim/nvim-lspconfig.git" },
    { src = "https://github.com/hrsh7th/nvim-cmp.git" },
    { src = "https://github.com/hrsh7th/cmp-nvim-lsp.git" },
})

local lsp = vim.lsp

local servers = { "pyright" }

for _, server in ipairs(servers) do
    lsp.config(server, {
        capabilities = require("cmp_nvim_lsp").default_capabilities(),
        settings = {},
    })
    lsp.enable(server)
end

local cmp = require("cmp")
cmp.setup({
    mapping = cmp.mapping.preset.insert({
        ["<CR>"] = cmp.mapping.confirm({ select = true }),
        ["<Tab>"] = cmp.mapping.select_next_item(),
        ["<S-Tab>"] = cmp.mapping.select_prev_item(),
    }),
    sources = {
        { name = "nvim_lsp" },
        { name = "buffer" },
    },
    experimental = { ghost_text = true },
})

-- Create an autocommand that runs when a buffer is read
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
