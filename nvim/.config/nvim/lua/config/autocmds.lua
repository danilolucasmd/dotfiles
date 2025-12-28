-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Allow escape from terminal session within neovim
function _G.set_terminal_keymaps()
  local opts = { noremap = true }
  vim.api.nvim_buf_set_keymap(0, "t", "<esc>", [[<C-\><C-n>]], opts)
end

vim.cmd("autocmd! TermOpen term://* lua set_terminal_keymaps()")

-- Hide tmux bar when enter neovim
if vim.env.TMUX then
  vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, {
    callback = function()
      -- Hide the tmux status bar when Neovim starts or resumes
      vim.cmd("silent !tmux set status off")
    end,
  })

  vim.api.nvim_create_autocmd({ "VimLeave", "VimSuspend" }, {
    callback = function()
      -- Show the tmux status bar when Neovim exits or is suspended
      vim.cmd("silent !tmux set status on")
    end,
  })
end
