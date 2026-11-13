return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ lsp_format = "fallback" })
        end,
        mode = { "n", "x" },
        desc = "Format",
      },
    },
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        sh = { "shfmt" },
        javascript = { "oxfmt" },
        javascriptreact = { "oxfmt" },
        typescript = { "oxfmt" },
        typescriptreact = { "oxfmt" },
      },
      format_on_save = function(buf)
        local enabled = vim.b[buf].autoformat
        if enabled == nil then
          enabled = vim.g.autoformat
        end
        if not enabled then
          return
        end
        -- eslint's fixes run before oxfmt, so oxfmt has the last word on layout.
        if #vim.lsp.get_clients({ bufnr = buf, name = "eslint" }) > 0 then
          return { timeout_ms = 3000, lsp_format = "first", name = "eslint" }
        end
        return { timeout_ms = 3000, lsp_format = "fallback" }
      end,
    },
    init = function()
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
  },
}
