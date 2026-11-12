return {
  {
    "nvim-mini/mini.pairs",
    event = "VeryLazy",
    opts = {
      modes = { insert = true, command = true },
    },
  },

  {
    "nvim-mini/mini.surround",
    -- LazyVim's gs* prefix, kept so the muscle memory carries over.
    keys = {
      { "gsa", desc = "Add Surrounding", mode = { "n", "x" } },
      { "gsd", desc = "Delete Surrounding" },
      { "gsf", desc = "Find Right Surrounding" },
      { "gsF", desc = "Find Left Surrounding" },
      { "gsh", desc = "Highlight Surrounding" },
      { "gsr", desc = "Replace Surrounding" },
      { "gsn", desc = "Update `MiniSurround.config.n_lines`" },
    },
    opts = {
      mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    },
  },

  {
    "nvim-mini/mini.ai",
    event = "VeryLazy",
    dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
    opts = function()
      local ai = require("mini.ai")
      return {
        n_lines = 500,
        custom_textobjects = {
          o = ai.gen_spec.treesitter({ -- code block
            a = { "@block.outer", "@conditional.outer", "@loop.outer" },
            i = { "@block.inner", "@conditional.inner", "@loop.inner" },
          }),
          f = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
          c = ai.gen_spec.treesitter({ a = "@class.outer", i = "@class.inner" }),
          t = { "<([%p%w]-)%f[^<%w][^<>]->.-</%1>", "^<.->().*()</[^/]->$" }, -- tags
          d = { "%f[%d]%d+" }, -- digits
          e = { -- word segment in camelCase / snake_case
            { "%u[%l%d]+%f[^%l%d]", "%f[%S][%l%d]+%f[^%l%d]", "%f[%P][%l%d]+%f[^%l%d]", "^[%l%d]+%f[^%l%d]" },
            "^().*()$",
          },
          g = function(ai_type) -- whole buffer; `ig` drops leading and trailing blank lines
            local first, last = 1, vim.fn.line("$")
            if ai_type == "i" then
              first = vim.fn.nextnonblank(first)
              last = vim.fn.prevnonblank(last)
              if first == 0 then
                return { from = { line = 1, col = 1 } }
              end
            end
            local to_col = math.max(vim.fn.getline(last):len(), 1)
            return { from = { line = first, col = 1 }, to = { line = last, col = to_col } }
          end,
          u = ai.gen_spec.function_call(), -- usage
          U = ai.gen_spec.function_call({ name_pattern = "[%w_]" }), -- usage, without dot in name
        },
      }
    end,
  },

  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    -- stylua: ignore
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
      { "<c-space>", mode = { "n", "o", "x" }, function()
        require("flash").treesitter({ actions = { ["<c-space>"] = "next", ["<BS>"] = "prev" } })
      end, desc = "Treesitter Incremental Selection" },
    },
  },
}
