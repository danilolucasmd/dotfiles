-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Disable move line (triggered by escape)
vim.keymap.del({ "n", "i", "v" }, "<A-j>")
vim.keymap.del({ "n", "i", "v" }, "<A-k>")

-- Disable mouse
vim.keymap.set("", "<up>", "<nop>", { noremap = true })
vim.keymap.set("", "<down>", "<nop>", { noremap = true })
vim.keymap.set("i", "<up>", "<nop>", { noremap = true })
vim.keymap.set("i", "<down>", "<nop>", { noremap = true })
vim.opt.mouse = ""

-- Disable Arrow Keys in Normal, Visual, and Operator-pending modes
vim.keymap.set("", "<Up>", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("", "<Down>", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("", "<Left>", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("", "<Right>", "<Nop>", { noremap = true, silent = true })

-- Disable Arrow Keys in Insert mode
vim.keymap.set("i", "<Up>", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("i", "<Down>", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("i", "<Left>", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("i", "<Right>", "<Nop>", { noremap = true, silent = true })

-- Move buffers
vim.keymap.set("n", "<leader>bH", "<cmd>BufferLineMovePrev<CR>", { desc = "Move buffer left" })
vim.keymap.set("n", "<leader>bL", "<cmd>BufferLineMoveNext<CR>", { desc = "Move buffer right" })
