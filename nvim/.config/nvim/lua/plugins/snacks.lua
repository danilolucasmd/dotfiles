-- snacks.nvim is a bundle; only the modules enabled here are active.
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = { enabled = true },
      explorer = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      quickfile = { enabled = true },
      scope = { enabled = true },
      statuscolumn = { enabled = true },
      words = { enabled = true },
      picker = {
        enabled = true,
        sources = {
          explorer = {
            -- M narrows the tree to files git reports as changed (and the
            -- folders leading to them). Snacks has no such filter, but it
            -- already tags every tree node with its git status, and propagates
            -- it up to the parent folders, so dropping unmarked nodes is enough.
            -- Untracked folders are reported whole, hence dir_status for the
            -- files inside them.
            transform = function(item, ctx)
              if not ctx.picker.opts.changed_only or item.file == ctx.filter.cwd then
                return
              end
              local node = require("snacks.explorer.tree"):node(item.file)
              return (node and node.status and not node.ignored or item.dir_status) and true or false
            end,
            actions = {
              explorer_changed_only = function(picker)
                picker.opts.changed_only = not picker.opts.changed_only
                -- Hidden entries have to be let through while filtering: every
                -- stow package keeps its files under a .config folder, and a
                -- hidden folder would cut the tree off above the changes.
                if picker.opts.changed_only then
                  picker.opts.hidden_before_changed_only = picker.opts.hidden
                  picker.opts.hidden = true
                else
                  picker.opts.hidden = picker.opts.hidden_before_changed_only
                end
                if picker.opts.changed_only then
                  -- Changed files usually sit in collapsed folders; open every
                  -- folder on the way to one, or the filter shows only the top.
                  local Tree = require("snacks.explorer.tree")
                  Tree:walk(Tree:find(picker:cwd()), function(node)
                    if not node.dir or node.ignored or not node.status then
                      return false
                    end
                    node.open = true
                  end, { all = true })
                end
                Snacks.notify((picker.opts.changed_only and "Showing changed files only" or "Showing all files"), {
                  title = "Explorer",
                })
                require("snacks.explorer.actions").update(picker, { refresh = true })
              end,
            },
            win = {
              list = {
                keys = {
                  -- Esc in the explorer would otherwise close it; it is toggled
                  -- with <leader>e instead.
                  ["<Esc>"] = function() end,
                  ["M"] = { "explorer_changed_only", desc = "Toggle Changed Files Only" },
                },
              },
            },
          },
        },
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>e", function() Snacks.explorer() end, desc = "Explorer" },
      { "<leader><space>", function() Snacks.picker.files() end, desc = "Find Files" },
      { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>/", function() Snacks.picker.grep() end, desc = "Grep" },
      { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader>n", function() Snacks.picker.notifications() end, desc = "Notification History" },
      { "<leader>un", function() Snacks.notifier.hide() end, desc = "Dismiss All Notifications" },
      -- find
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent" },
      { "<leader>fR", function() Snacks.picker.recent({ filter = { cwd = true } }) end, desc = "Recent (cwd)" },
      { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },
      -- Live grep seeded with the visual selection, or the word under the cursor.
      -- LazyVim has this on <leader>sw; <leader>fg is where the old Telescope
      -- version of this lived.
      { "<leader>fg", function() Snacks.picker.grep_word() end, desc = "Grep Selection or Word", mode = { "n", "x" } },
      -- git
      { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git Status" },
      { "<leader>gd", function() Snacks.picker.git_diff() end, desc = "Git Diff (hunks)" },
      { "<leader>gS", function() Snacks.picker.git_stash() end, desc = "Git Stash" },
      -- search
      { "<leader>sb", function() Snacks.picker.lines() end, desc = "Buffer Lines" },
      { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep Open Buffers" },
      { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" },
      { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Grep Selection or Word", mode = { "n", "x" } },
      { '<leader>s"', function() Snacks.picker.registers() end, desc = "Registers" },
      { "<leader>sa", function() Snacks.picker.autocmds() end, desc = "Autocmds" },
      { "<leader>sc", function() Snacks.picker.command_history() end, desc = "Command History" },
      { "<leader>sC", function() Snacks.picker.commands() end, desc = "Commands" },
      { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Diagnostics" },
      { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer Diagnostics" },
      { "<leader>sh", function() Snacks.picker.help() end, desc = "Help Pages" },
      { "<leader>sH", function() Snacks.picker.highlights() end, desc = "Highlights" },
      { "<leader>si", function() Snacks.picker.icons() end, desc = "Icons" },
      { "<leader>sj", function() Snacks.picker.jumps() end, desc = "Jumps" },
      { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
      { "<leader>sl", function() Snacks.picker.loclist() end, desc = "Location List" },
      { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
      { "<leader>sM", function() Snacks.picker.man() end, desc = "Man Pages" },
      { "<leader>sp", function() Snacks.picker.lazy() end, desc = "Search for Plugin Spec" },
      { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix List" },
      { "<leader>sR", function() Snacks.picker.resume() end, desc = "Resume" },
      { "<leader>su", function() Snacks.picker.undo() end, desc = "Undotree" },
      { "<leader>uC", function() Snacks.picker.colorschemes() end, desc = "Colorschemes" },
      -- LSP reference highlights (words)
      { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "Next Reference" },
      { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev Reference" },
    },
  },
}
