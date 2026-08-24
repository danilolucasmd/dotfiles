-- Seamless navigation between nvim splits and herdr panes, without a plugin.
-- Tries to move within nvim; if already at the split edge, hands off to the
-- adjacent herdr pane. This was the tmux version (the core of what
-- vim-tmux-navigator did) retargeted at `herdr pane`.
local M = {}

-- wincmd direction -> herdr pane direction
local dirs = { h = "left", j = "down", k = "up", l = "right" }

-- `herdr pane edges --current` reports, per direction, whether this pane is
-- already at that edge of the tab. Checking first keeps focus from wrapping
-- around to the far side, which is the no-wrap behaviour the tmux config had.
local function at_edge(dir)
  local ok, out = pcall(vim.fn.system, { "herdr", "pane", "edges", "--current" })
  if not ok or vim.v.shell_error ~= 0 then
    return true
  end
  local decoded, parsed = pcall(vim.json.decode, out)
  if not decoded or type(parsed) ~= "table" then
    return true
  end
  local edges = vim.tbl_get(parsed, "result", "edges")
  -- Absent means we cannot tell; treat that as an edge and stay put.
  return type(edges) ~= "table" or edges[dirs[dir]] ~= false
end

function M.navigate(dir)
  local from = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(dir)
  if from ~= vim.api.nvim_get_current_win() then
    return
  end
  -- No nvim window that way: cross into the herdr pane, if there is one.
  if vim.env.HERDR_ENV == "1" and not at_edge(dir) then
    vim.fn.system({ "herdr", "pane", "focus", "--current", "--direction", dirs[dir] })
  end
end

return M
