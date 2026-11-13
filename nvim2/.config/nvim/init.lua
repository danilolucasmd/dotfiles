-- Options first: mapleader has to exist before any plugin spec registers a
-- <leader> key. Keymaps and autocmds come after lazy.nvim so `Snacks` is loaded.
require("config.options")
require("config.lazy")
require("config.keymaps")
require("config.autocmds")
