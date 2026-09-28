vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.autoread = true
-- Keep the common 80- and 120-column limits visible without enforcing them.
vim.opt.colorcolumn = "80,120"

-- Apply to diagnostics from every LSP and linter. Line length is a style
-- preference, so keep the guide columns but hide matching warnings/errors.
local line_length_patterns = {
  "line too long",
  "line is too long",
  "line exceeds.*length",
  "line length",
  "maximum line length",
  "max line length",
  "too many characters",
  "MD013",
  "E501",
  "W505",
}

vim.diagnostic.config({
  signs = true,
  underline = true,
  virtual_text = true,
  update_in_insert = false,
  severity_sort = true,
  -- Diagnostic handlers from LSPs and linters share this API, so filtering
  -- here covers all installed servers without server-specific configuration.
})

-- Filter diagnostics before they enter Neovim's shared diagnostic cache.
-- vim.diagnostic.config() callback values are option resolvers, not filters.
local original_publish = vim.lsp.handlers["textDocument/publishDiagnostics"]
vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
  if result and result.diagnostics then
    result.diagnostics = vim.tbl_filter(function(diagnostic)
      local message = (diagnostic.message or ""):lower()
      for _, pattern in ipairs(line_length_patterns) do
        if message:find(pattern:lower()) then
          return false
        end
      end
      return true
    end, result.diagnostics)
  end
  return original_publish(err, result, ctx, config)
end

-- Search from the directory where Neovim was launched unless an attached LSP
-- provides a more specific project root. This avoids treating the managed
-- ~/dev/.git marker as the root of the whole development workspace.
vim.g.root_spec = { "lsp", "cwd" }

vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local line_count = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
