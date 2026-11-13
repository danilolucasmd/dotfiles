-- Lines added and removed per file, and in total, for the explorer: everything
-- not yet committed, against HEAD, staged or not. That is the same set of files
-- the explorer's git status marks cover, so every marked file can carry a count.
--
-- git diff does not count untracked files at all, so those are read here and
-- every line counted as added, the way a diff tool shows a new file. Files over
-- 1MB, or with a NUL in their first 8KB (binary), are skipped rather than read.
local M = {}

M.files = {} ---@type table<string, {add: integer, del: integer}>
M.total = { add = 0, del = 0 }

local running, again = false, nil ---@type boolean, fun()?

local function count_lines(path)
  local f = io.open(path, "rb")
  if not f then
    return nil
  end
  local size = f:seek("end")
  if not size or size > 1024 * 1024 then
    f:close()
    return nil
  end
  f:seek("set")
  local data = f:read("*a") or ""
  f:close()
  if data:sub(1, 8192):find("\0", 1, true) then
    return nil
  end
  local _, n = data:gsub("\n", "")
  if #data > 0 and data:sub(-1) ~= "\n" then
    n = n + 1
  end
  return n
end

-- `--numstat -z` writes "add\tdel\tpath\0", or for a rename "add\tdel\t\0old\0new\0";
-- binary files have "-" for both counts.
local function parse_numstat(out, root, files)
  local fields = vim.split(out, "\0", { plain = true })
  local i = 1
  while i <= #fields do
    local add, del, path = fields[i]:match("^(%S+)\t(%S+)\t(.*)$")
    if not add then
      i = i + 1
    else
      if path == "" then
        path = fields[i + 2]
        i = i + 3
      else
        i = i + 1
      end
      if path and add ~= "-" then
        files[root .. "/" .. path] = { add = tonumber(add) or 0, del = tonumber(del) or 0 }
      end
    end
  end
end

---@param root string git root
---@param on_change fun() called (scheduled) when the counts differ from the last run
function M.refresh(root, on_change)
  if running then
    again = function()
      M.refresh(root, on_change)
    end
    return
  end
  running = true
  local files = {} ---@type table<string, {add: integer, del: integer}>
  local git = { "git", "--no-pager", "--no-optional-locks" }

  local function finish()
    local total = { add = 0, del = 0 }
    for _, s in pairs(files) do
      total.add, total.del = total.add + s.add, total.del + s.del
    end
    local changed = not vim.deep_equal(files, M.files)
    M.files, M.total = files, total
    running = false
    if changed then
      vim.schedule(on_change)
    end
    if again then
      local fn = again
      again = nil
      vim.schedule(fn)
    end
  end

  vim.system(vim.list_extend(vim.deepcopy(git), { "diff", "HEAD", "--numstat", "-z" }), { cwd = root, text = true }, function(diff)
    if diff.code == 0 then
      parse_numstat(diff.stdout or "", root, files)
    end
    vim.system(vim.list_extend(vim.deepcopy(git), { "ls-files", "--others", "--exclude-standard", "-z" }), { cwd = root, text = true }, function(ls)
      if ls.code == 0 then
        for path in (ls.stdout or ""):gmatch("([^%z]+)") do
          local n = count_lines(root .. "/" .. path)
          if n then
            files[root .. "/" .. path] = { add = n, del = 0 }
          end
        end
      end
      finish()
    end)
  end)
end

return M
