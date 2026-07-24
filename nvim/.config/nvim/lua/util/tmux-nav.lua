-- Seamless navigation between nvim splits and tmux panes, without a plugin.
-- Tries to move within nvim; if already at the split edge, hands off to the
-- adjacent tmux pane (respecting tmux's no-wrap edge guard). This is the core
-- of what vim-tmux-navigator did, in a few lines.
local M = {}

-- wincmd direction -> tmux select-pane direction / pane-edge format
local pane = { h = "L", j = "D", k = "U", l = "R" }
local edge = { h = "pane_at_left", j = "pane_at_bottom", k = "pane_at_top", l = "pane_at_right" }

function M.navigate(dir)
  local from = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(dir)
  local moved = from ~= vim.api.nvim_get_current_win()
  if not moved and vim.env.TMUX then
    -- No nvim window that way: cross into the tmux pane, unless we're already at
    -- that edge of the tmux window (matches the no-wrap guard in tmux.conf).
    vim.fn.system({ "tmux", "if-shell", "-F", "#{" .. edge[dir] .. "}", "", "select-pane -" .. pane[dir] })
  end
end

return M
