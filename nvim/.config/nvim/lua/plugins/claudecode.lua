-- Move focus to the herdr pane on the right (where the Claude Code CLI runs).
-- Falls back to a plain window move when nvim isn't running inside herdr.
local function focus_claude_pane()
  if vim.env.HERDR_ENV == "1" then
    vim.fn.system({ "herdr", "pane", "focus", "--current", "--direction", "right" })
  else
    vim.cmd("wincmd l")
  end
end

return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  -- Loaded at startup, not on its keys: setup starts the WebSocket server and
  -- writes the ~/.claude/ide lockfile, and Claude (autoConnectIde) only connects
  -- to an nvim whose lockfile already exists when it starts. Loaded on first
  -- keypress, the server came up too late, nothing was connected, and the
  -- mention timed out in the queue.
  event = "VeryLazy",
  opts = {
    -- Claude runs in a herdr pane, not an nvim terminal, so the plugin has
    -- nothing to focus (focus_after_send only warns); focus_claude_pane does it.
    terminal = {
      provider = "none",
    },
    -- Tracking streams every cursor move to Claude, which shows it as an
    -- "In <file>" line under its prompt. Only explicit sends are wanted.
    track_selection = false,
  },
  keys = {
    { "<leader>a", nil, desc = "AI/Claude Code" },
    {
      "<leader>ab",
      function()
        vim.cmd("ClaudeCodeAdd %")
        focus_claude_pane()
      end,
      desc = "Add current buffer",
    },
    {
      "<leader>as",
      -- ClaudeCodeSend refuses to run without selection tracking, so the
      -- range is read here and sent directly (Claude's lines are 0-indexed).
      function()
        local first, last = vim.fn.line("v"), vim.fn.line(".")
        if first > last then
          first, last = last, first
        end
        vim.cmd("normal! \27")
        require("claudecode").send_at_mention(vim.api.nvim_buf_get_name(0), first - 1, last - 1, "ClaudeCodeSend")
        focus_claude_pane()
      end,
      mode = "v",
      desc = "Send to Claude",
    },
  },
}
