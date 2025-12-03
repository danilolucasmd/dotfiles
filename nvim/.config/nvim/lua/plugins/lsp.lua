return {
  "neovim/nvim-lspconfig",
  opts = {
    ---@type lspconfig.options
    servers = {
      vtsls = {
        autoUseWorkspaceTsdk = true,
        settings = {
          typescript = {
            tsserver = {
              maxTsServerMemory = 16384,
            },
          },
        },
      },
      biome = {
        cmd = { "biome", "lsp-proxy" },
        filetypes = {
          "css",
          "graphql",
          "javascript",
          "javascriptreact",
          "json",
          "jsonc",
          "typescript",
          "typescript.tsx",
          "typescriptreact",
        },
        root_dir = require("lspconfig.util").root_pattern("biome.json", "biome.jsonc"),
        single_file_support = false,
      },
      -- Add Relay LSP configuration
      relay_lsp = {
        filetypes = {
          "typescript",
          "typescriptreact",
          "typescript.tsx",
        },
        root_dir = require("lspconfig.util").root_pattern("relay.config.*", "package.json"),
        cmd = { "relay-compiler", "lsp" },
        -- You can customize these options as needed
        auto_start_compiler = false,
        path_to_config = nil,
      },
    },
  },
}
