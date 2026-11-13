-- The inline (<leader>gv) and side-by-side (<leader>gV) diffs. monokai-pro gives
-- these a dim red/green foreground, which repaints whole lines in one colour
-- over the syntax highlighting, on a background barely off the editor's.
-- Background only, so the code keeps its colours: a tint per line, a stronger
-- one on the words that changed. Set after the colorscheme rather than through
-- monokai-pro's `override`, because that merges into the theme's own definition,
-- and the theme links several of these to Diff*, a link that would win over any
-- colour.
local diff_hl = {
  -- Split diff (vim's own diff mode). DiffDelete also draws the filler lines
  -- opposite an addition, so it keeps a dim foreground for the ╱ fill.
  DiffAdd = { bg = "#33402b" },
  DiffDelete = { fg = "#5b3a41", bg = "#4a2a31" },
  DiffChange = { bg = "#3b3530" },
  DiffText = { bg = "#5c4a35" },
  -- Inline diff (gitsigns' unified view).
  GitSignsDeleteVirtLn = { bg = "#4a2a31" },
  GitSignsDeleteVirtLnInLine = { bg = "#6e2f3c" },
  GitSignsAddPreview = { bg = "#33402b" },
  GitSignsAddInline = { bg = "#4b6136" },
  GitSignsChangeInline = { bg = "#4b6136" },
  GitSignsDeleteInline = { bg = "#6e2f3c" },
  -- Number column on those lines. The Nr groups only show while the inline
  -- diff is on (numhl is toggled with it), and gitsigns calls a modified line
  -- "change", which reads as an addition in this view.
  GitSignsVirtLnum = { fg = "#ff6188", bg = "#4a2a31" },
  GitSignsAddNr = { fg = "#a9dc76", bg = "#33402b" },
  GitSignsChangeNr = { fg = "#a9dc76", bg = "#33402b" },
  -- Explorer mark for a file with both staged and unstaged changes.
  SnacksPickerGitStatusPartial = { fg = "#ffd866" },
}

return {
  {
    "gthelding/monokai-pro.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("monokai-pro").setup({
        filter = "pro",
        override = function()
          return {
            NonText = { fg = "#948a8b" },
            MiniIconsGrey = { fg = "#948a8b" },
            MiniIconsRed = { fg = "#fd6883" },
            MiniIconsBlue = { fg = "#85dacc" },
            MiniIconsGreen = { fg = "#adda78" },
            MiniIconsYellow = { fg = "#f9cc6c" },
            MiniIconsOrange = { fg = "#f38d70" },
            MiniIconsPurple = { fg = "#a8a9eb" },
            MiniIconsAzure = { fg = "#a8a9eb" },
            MiniIconsCyan = { fg = "#85dacc" }, -- same value as MiniIconsBlue for consistency
          }
        end,
      })
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("user_inline_diff_hl", { clear = true }),
        pattern = "monokai-pro",
        callback = function()
          for group, hl in pairs(diff_hl) do
            vim.api.nvim_set_hl(0, group, hl)
          end
        end,
      })
      vim.cmd.colorscheme("monokai-pro")
    end,
  },
}
