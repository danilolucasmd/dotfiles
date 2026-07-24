-- Navigate out of a Snacks terminal with Alt+hjkl instead of Ctrl+hjkl.
-- In a split terminal, move to the adjacent nvim split or tmux pane (via the
-- shared helper, so edge hand-off to tmux works); in a floating terminal, pass
-- the key through to the program. Ctrl equivalents are disabled below.
local tnav = require("util.tmux-nav")
local function term_nav(dir)
  ---@param self snacks.terminal
  return function(self)
    return self:is_floating() and "<M-" .. dir .. ">" or vim.schedule(function()
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
          -- Disable LazyVim's Ctrl+hjkl terminal navigation.
          nav_h = false,
          nav_j = false,
          nav_k = false,
          nav_l = false,
          -- Alt+hjkl equivalents.
          nav_h_alt = { "<M-h>", term_nav("h"), desc = "Go to Left Window", expr = true, mode = "t" },
          nav_j_alt = { "<M-j>", term_nav("j"), desc = "Go to Lower Window", expr = true, mode = "t" },
          nav_k_alt = { "<M-k>", term_nav("k"), desc = "Go to Upper Window", expr = true, mode = "t" },
          nav_l_alt = { "<M-l>", term_nav("l"), desc = "Go to Right Window", expr = true, mode = "t" },
        },
      },
    },
  },
}
