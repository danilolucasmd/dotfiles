return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        ["javascript"] = { "oxfmt" },
        ["javascriptreact"] = { "oxfmt" },
        ["typescript"] = { "oxfmt" },
        ["typescriptreact"] = { "oxfmt" },
      },
    },
  },
}
