local function augroup(name)
  return vim.api.nvim_create_augroup("user_" .. name, { clear = true })
end

-- Reload files changed outside nvim (lazygit, Claude Code in the next pane).
vim.api.nvim_create_autocmd("FocusGained", {
  group = augroup("checktime"),
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- Reload a buffer the moment its file changes on disk, not only on focus:
-- Claude edits files from the next herdr pane while this one sits unfocused.
-- The watch is on each file's directory rather than the file, because a write
-- that replaces the file by rename (an atomic save) would leave a watch on the
-- old inode seeing nothing. autoread does the reloading, so a buffer with
-- unsaved edits is never overwritten; nvim asks instead.
local dir_watches = {} ---@type table<string, {handle: uv.uv_fs_event_t, bufs: table<string, integer>}>
local pending_check = {} ---@type table<integer, boolean>

local function unwatch_buf(buf)
  for dir, w in pairs(dir_watches) do
    for name, b in pairs(w.bufs) do
      if b == buf then
        w.bufs[name] = nil
      end
    end
    if next(w.bufs) == nil then
      w.handle:stop()
      w.handle:close()
      dir_watches[dir] = nil
    end
  end
end

local function watch_buf(buf)
  if vim.bo[buf].buftype ~= "" then
    return
  end
  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then
    return
  end
  path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
  local dir, name = vim.fs.dirname(path), vim.fs.basename(path)
  if vim.fn.isdirectory(dir) == 0 then
    return
  end
  unwatch_buf(buf)
  local w = dir_watches[dir]
  if not w then
    local handle = vim.uv.new_fs_event()
    if not handle then
      return
    end
    w = { handle = handle, bufs = {} }
    -- One save fires several events; they are coalesced into one checktime.
    local ok = handle:start(dir, {}, function(err, file)
      local b = not err and file and w.bufs[file]
      if not b or pending_check[b] then
        return
      end
      pending_check[b] = true
      vim.defer_fn(function()
        pending_check[b] = nil
        if vim.api.nvim_buf_is_valid(b) then
          vim.cmd.checktime(b)
        end
      end, 100)
    end)
    if not ok then
      handle:close()
      return
    end
    dir_watches[dir] = w
  end
  w.bufs[name] = buf
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufFilePost", "BufWritePost" }, {
  group = augroup("watch_files"),
  callback = function(event)
    watch_buf(event.buf)
  end,
})
vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = augroup("unwatch_files"),
  callback = function(event)
    unwatch_buf(event.buf)
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("highlight_yank"),
  callback = function()
    vim.hl.on_yank()
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = augroup("resize_splits"),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- Reopen a file at the line it was last left on.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("last_loc"),
  callback = function(event)
    local buf = event.buf
    if vim.bo[buf].filetype == "gitcommit" or vim.b[buf].last_loc then
      return
    end
    vim.b[buf].last_loc = true
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup("close_with_q"),
  pattern = { "checkhealth", "gitsigns-blame", "help", "qf" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.schedule(function()
      vim.keymap.set("n", "q", function()
        vim.cmd("close")
        pcall(vim.api.nvim_buf_delete, event.buf, { force = true })
      end, { buffer = event.buf, silent = true, desc = "Quit buffer" })
    end)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup("man_unlisted"),
  pattern = "man",
  callback = function(event)
    vim.bo[event.buf].buflisted = false
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = augroup("wrap_spell"),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- conceallevel 2 hides the quotes in JSON, which makes it unreadable.
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("json_conceal"),
  pattern = { "json", "jsonc", "json5" },
  callback = function()
    vim.opt_local.conceallevel = 0
  end,
})

-- Writing to a path whose directory does not exist yet creates it.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("auto_create_dir"),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})
