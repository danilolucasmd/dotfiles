-- Telescope live_grep for selection or word under cursor
vim.keymap.set({ "n", "v" }, "<leader>fg", function()
  local text = ""
  if vim.fn.mode() == "v" or vim.fn.mode() == "V" then
    -- Get visual selection
    vim.cmd('normal! "vy"') -- yank selection into v register
    text = vim.fn.getreg("v")
  else
    -- Get word under cursor in normal mode
    text = vim.fn.expand("<cword>")
  end
  require("telescope.builtin").live_grep({ default_text = text })
end, { noremap = true, silent = true })
