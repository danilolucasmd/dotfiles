-- Navigate out of a Snacks terminal with Ctrl+hjkl.
-- In a split terminal, move to the adjacent nvim split or herdr pane (via the
-- shared helper, so edge hand-off to herdr works); in a floating terminal, pass
-- the key through to the program.
local tnav = require("util.herdr-nav")
local function term_nav(dir)
  ---@param self snacks.terminal
  return function(self)
    return self:is_floating() and "<C-" .. dir .. ">" or vim.schedule(function()
      tnav.navigate(dir)
    end)
  end
end

return {
  "folke/snacks.nvim",
  opts = {
    terminal = {
      win = {
        keys = {
          -- Override LazyVim's Ctrl+hjkl terminal navigation with the herdr-aware versions.
          nav_h = { "<C-h>", term_nav("h"), desc = "Go to Left Window", expr = true, mode = "t" },
          nav_j = { "<C-j>", term_nav("j"), desc = "Go to Lower Window", expr = true, mode = "t" },
          nav_k = { "<C-k>", term_nav("k"), desc = "Go to Upper Window", expr = true, mode = "t" },
          nav_l = { "<C-l>", term_nav("l"), desc = "Go to Right Window", expr = true, mode = "t" },
        },
      },
    },
  },
}
