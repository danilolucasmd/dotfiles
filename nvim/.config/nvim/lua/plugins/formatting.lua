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
        javascript = { "biome-check" },
        javascriptreact = { "biome-check" },
        typescript = { "biome-check" },
        typescriptreact = { "biome-check" },
        json = { "biome-check" },
        css = { "biome-check" },
      },
      formatters = {
        -- Without a biome.json, Biome formats with its own defaults (tabs,
        -- short arrays joined on one line), turning a one-line edit in a
        -- project with another style into a whole-file diff. So it only runs
        -- in projects that configure it.
        ["biome-check"] = { require_cwd = true },
      },
      format_on_save = function(buf)
        local enabled = vim.b[buf].autoformat
        if enabled == nil then
          enabled = vim.g.autoformat
        end
        if enabled then
          return { timeout_ms = 3000, lsp_format = "fallback" }
        end
      end,
    },
    init = function()
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
  },
}
