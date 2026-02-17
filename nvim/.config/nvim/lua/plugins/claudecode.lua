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
        vim.cmd("TmuxNavigateRight")
      end,
      desc = "Add current buffer",
    },
    {
      "<leader>as",
      function()
        vim.cmd("ClaudeCodeSend")
        vim.cmd("TmuxNavigateRight")
      end,
      mode = "v",
      desc = "Send to Claude",
    },
  },
}
