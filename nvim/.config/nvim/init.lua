local autocmd = vim.api.nvim_create_autocmd

autocmd("VimEnter", {
	command = ":silent !kitty @ set-spacing padding=0 margin=0",
})

require("options")
require("config.lazy")
require("keymaps")
require("macro")
