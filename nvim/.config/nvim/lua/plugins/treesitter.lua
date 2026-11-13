-- nvim-treesitter's main branch only installs parsers and queries. Turning
-- highlighting, indent and folds on is done here per buffer, and only when the
-- language has the query for it: a missing indents query would otherwise
-- leave indentexpr pointing at nothing.
local parsers = {
  "bash",
  "c",
  "css",
  "diff",
  "html",
  "javascript",
  "jsdoc",
  "json",
  "lua",
  "luadoc",
  "luap",
  "markdown",
  "markdown_inline",
  "printf",
  "python",
  "query",
  "regex",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "xml",
  "yaml",
}

local function has_query(lang, query)
  local ok, q = pcall(vim.treesitter.query.get, lang, query)
  return ok and q ~= nil
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      require("nvim-treesitter").install(parsers)

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(ev.match)
          if not lang or not vim.treesitter.language.add(lang) then
            return
          end
          if has_query(lang, "highlights") then
            pcall(vim.treesitter.start, ev.buf)
          end
          if has_query(lang, "indents") then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
          if has_query(lang, "folds") then
            vim.wo[0][0].foldmethod = "expr"
            vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
          end
        end,
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    event = "VeryLazy",
    config = function()
      require("nvim-treesitter-textobjects").setup({ move = { set_jumps = true } })

      local moves = {
        goto_next_start = { ["]f"] = "@function.outer", ["]c"] = "@class.outer", ["]a"] = "@parameter.inner" },
        goto_next_end = { ["]F"] = "@function.outer", ["]C"] = "@class.outer", ["]A"] = "@parameter.inner" },
        goto_previous_start = { ["[f"] = "@function.outer", ["[c"] = "@class.outer", ["[a"] = "@parameter.inner" },
        goto_previous_end = { ["[F"] = "@function.outer", ["[C"] = "@class.outer", ["[A"] = "@parameter.inner" },
      }
      for method, keymaps in pairs(moves) do
        for key, query in pairs(keymaps) do
          vim.keymap.set({ "n", "x", "o" }, key, function()
            -- ]c / [c keep their built-in meaning (next/prev change) in diff mode.
            if vim.wo.diff and key:find("[cC]") then
              return vim.cmd.normal({ key, bang = true })
            end
            require("nvim-treesitter-textobjects.move")[method](query, "textobjects")
          end, { desc = method:gsub("_", " ") .. " " .. query, silent = true })
        end
      end
    end,
  },

  {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },
}
