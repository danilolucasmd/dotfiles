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
  opts = {
    focus_after_send = true,
    terminal = {
      provider = "none",
    },
  },
  config = true,
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
      function()
        vim.cmd("ClaudeCodeSend")
        focus_claude_pane()
      end,
      mode = "v",
      desc = "Send to Claude",
    },
  },
}
