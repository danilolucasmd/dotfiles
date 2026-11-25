local map = vim.keymap.set

-- Arrow keys do nothing in any mode: hjkl or nothing.
map({ "", "i" }, "<Up>", "<Nop>", { silent = true })
map({ "", "i" }, "<Down>", "<Nop>", { silent = true })
map({ "", "i" }, "<Left>", "<Nop>", { silent = true })
map({ "", "i" }, "<Right>", "<Nop>", { silent = true })

-- j/k move by screen line on wrapped text, unless given a count.
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })

-- Ctrl+hjkl stays inside nvim and stops at the outer split. Moving to another
-- herdr pane is herdr's own Alt+hjkl; the two are kept apart on purpose.
map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window" })

map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase Window Height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Window Height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Window Width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Window Width" })

-- Buffers (cycling and moving live with bufferline, in plugins/ui.lua)
map("n", "<leader>bb", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map("n", "<leader>`", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
map("n", "<leader>bd", function()
  Snacks.bufdelete()
end, { desc = "Delete Buffer" })
map("n", "<leader>bo", function()
  Snacks.bufdelete.other()
end, { desc = "Delete Other Buffers" })
map("n", "<leader>bD", "<cmd>bd<cr>", { desc = "Delete Buffer and Window" })

map({ "i", "n", "s" }, "<esc>", function()
  vim.cmd("noh")
  if vim.snippet.active() then
    vim.snippet.stop()
  end
  return "<esc>"
end, { expr = true, desc = "Escape and Clear hlsearch" })

map("n", "<leader>ur", "<cmd>nohlsearch<bar>diffupdate<bar>normal! <C-L><cr>", { desc = "Redraw / Clear hlsearch" })

-- n always searches forward and N backward, whichever way the search went.
map("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "Next Search Result" })
map({ "x", "o" }, "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next Search Result" })
map("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "Prev Search Result" })
map({ "x", "o" }, "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev Search Result" })

-- Undo break-points, so u does not throw away a whole sentence.
map("i", ",", ",<c-g>u")
map("i", ".", ".<c-g>u")
map("i", ";", ";<c-g>u")

map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

map("x", "<", "<gv")
map("x", ">", ">gv")

map("n", "gco", "o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Below" })
map("n", "gcO", "O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>", { desc = "Add Comment Above" })

map("n", "<leader>l", "<cmd>Lazy<cr>", { desc = "Lazy" })
map("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New File" })
map("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit All" })

map("n", "<leader>xl", function()
  local ok, err = pcall(vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 and vim.cmd.lclose or vim.cmd.lopen)
  if not ok and err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end, { desc = "Location List" })
map("n", "<leader>xq", function()
  local ok, err = pcall(vim.fn.getqflist({ winid = 0 }).winid ~= 0 and vim.cmd.cclose or vim.cmd.copen)
  if not ok and err then
    vim.notify(err, vim.log.levels.ERROR)
  end
end, { desc = "Quickfix List" })

-- Diagnostics
local function diagnostic_goto(next, severity)
  return function()
    vim.diagnostic.jump({
      count = (next and 1 or -1) * vim.v.count1,
      severity = severity and vim.diagnostic.severity[severity] or nil,
      float = true,
    })
  end
end
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Line Diagnostics" })
map("n", "]d", diagnostic_goto(true), { desc = "Next Diagnostic" })
map("n", "[d", diagnostic_goto(false), { desc = "Prev Diagnostic" })
map("n", "]e", diagnostic_goto(true, "ERROR"), { desc = "Next Error" })
map("n", "[e", diagnostic_goto(false, "ERROR"), { desc = "Prev Error" })
map("n", "]w", diagnostic_goto(true, "WARN"), { desc = "Next Warning" })
map("n", "[w", diagnostic_goto(false, "WARN"), { desc = "Prev Warning" })

-- Windows
map("n", "<leader>-", "<C-W>s", { desc = "Split Window Below", remap = true })
map("n", "<leader>|", "<C-W>v", { desc = "Split Window Right", remap = true })
map("n", "<leader>wd", "<C-W>c", { desc = "Delete Window", remap = true })

-- Tabs
map("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", { desc = "New Tab" })
map("n", "<leader><tab>]", "<cmd>tabnext<cr>", { desc = "Next Tab" })
map("n", "<leader><tab>[", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })
map("n", "<leader><tab>d", "<cmd>tabclose<cr>", { desc = "Close Tab" })
map("n", "<leader><tab>o", "<cmd>tabonly<cr>", { desc = "Close Other Tabs" })

-- Git (pickers; hunk maps come from gitsigns)
map("n", "<leader>gl", function()
  Snacks.picker.git_log()
end, { desc = "Git Log" })
map("n", "<leader>gf", function()
  Snacks.picker.git_log_file()
end, { desc = "Git Current File History" })
map("n", "<leader>gb", function()
  Snacks.picker.git_log_line()
end, { desc = "Git Blame Line" })
map({ "n", "x" }, "<leader>gB", function()
  Snacks.gitbrowse()
end, { desc = "Git Browse (open)" })

map("n", "<leader>ui", vim.show_pos, { desc = "Inspect Pos" })
map("n", "<leader>uI", function()
  vim.treesitter.inspect_tree()
  vim.api.nvim_input("I")
end, { desc = "Inspect Tree" })

-- UI toggles
Snacks.toggle({
  name = "Auto Format (Global)",
  get = function()
    return vim.g.autoformat
  end,
  set = function(state)
    vim.g.autoformat = state
    vim.b.autoformat = nil
  end,
}):map("<leader>uf")
Snacks.toggle({
  name = "Auto Format (Buffer)",
  get = function()
    if vim.b.autoformat ~= nil then
      return vim.b.autoformat
    end
    return vim.g.autoformat
  end,
  set = function(state)
    vim.b.autoformat = state
  end,
}):map("<leader>uF")
Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
Snacks.toggle.line_number():map("<leader>ul")
Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.treesitter():map("<leader>uT")
Snacks.toggle.indent():map("<leader>ug")
Snacks.toggle.inlay_hints():map("<leader>uh")
Snacks.toggle.zoom():map("<leader>wm")

-- The whole diff inline in the window being edited, hunk-style but without
-- opening anything: gitsigns' unified diffthis draws the removed lines in place
-- and tints what was added, against the index like the signs are. It is the
-- real buffer underneath, so editing carries on as normal, with ]h / [h moving
-- between hunks. gitsigns ties a view to one window and buffer, so the toggle is
-- a global mode that reopens the view in whichever file window is entered.
local function show_inline_diff()
  local buf = vim.api.nvim_get_current_buf()
  if
    vim.g.inline_diff
    and not vim.wo.diff
    and vim.bo[buf].buftype == ""
    and require("gitsigns.cache").cache[buf]
    and not require("gitsigns.unified").get_view()
  then
    require("gitsigns").diffthis(nil, { unified = true })
  end
end

vim.api.nvim_create_autocmd("BufEnter", {
  group = vim.api.nvim_create_augroup("user_inline_diff", { clear = true }),
  callback = function()
    vim.schedule(show_inline_diff)
  end,
})

-- A file opened for the first time attaches after BufEnter, so its first update
-- opens the view. A commit that leaves the buffer clean closes it until new
-- hunks appear. The User GitSignsUpdate event only tracks unstaged hunks, so it
-- stays silent when staged ones are committed.
require("gitsigns.manager").on_update(function(ctx)
  local clean = #(ctx.bcache.hunks or {}) == 0 and #(ctx.bcache.hunks_staged or {}) == 0
  vim.schedule(function()
    if not clean then
      if vim.api.nvim_get_current_buf() == ctx.bufnr then
        show_inline_diff()
      end
      return
    end
    local unified = require("gitsigns.unified")
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local view = unified.get_view(win)
      if view and view.buf == ctx.bufnr then
        unified.close(win)
      end
    end
  end)
end)

Snacks.toggle({
  name = "Inline Diff",
  get = function()
    return vim.g.inline_diff == true
  end,
  set = function(state)
    vim.g.inline_diff = state
    require("gitsigns").toggle_numhl(state)
    if state then
      show_inline_diff()
      return
    end
    local unified = require("gitsigns.unified")
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      unified.close(win)
    end
  end,
}):map("<leader>gv")

-- The same comparison side by side: the staged version opens read-only in a
-- vertical split on the left, in vim's diff mode, with ]c / [c between changes.
-- Closing the gitsigns:// window is enough to switch it off; gitsigns turns
-- diff mode off in the remaining window when its buffer is hidden.
local function side_by_side_wins()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.wo[win].diff and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)):match("^gitsigns://") then
      wins[#wins + 1] = win
    end
  end
  return wins
end
Snacks.toggle({
  name = "Side-by-side Diff",
  get = function()
    return #side_by_side_wins() > 0
  end,
  set = function(state)
    if state then
      require("gitsigns").diffthis(nil, { vertical = true })
    else
      for _, win in ipairs(side_by_side_wins()) do
        vim.api.nvim_win_close(win, false)
      end
    end
  end,
}):map("<leader>gV")
