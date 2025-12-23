return {
	{
		"zaldih/themery.nvim",
		config = function()
			require("themery").setup({
				themes = {
					"catppuccin-mocha",
					"catppuccin-frappe",
					"catppuccin-macchiato",
					"onedark_dark",
					"onedark_vivid",
					"sonokai",
					"everforest",
					"edge",
					"dracula",
					"dracula-soft",
					"zephyr",
					"kanagawa-wave",
					"kanagawa-dragon",
					"kanagawa-lotus",
					"oxocarbon",
					"minimal-base16",
					"minimal",
				}, -- Your list of installed colorschemes.
				livePreview = true, -- Apply theme while picking. Default to true.
			})
		end,
	},
	{
		"olimorris/onedarkpro.nvim",
		priority = 1000, -- Ensure it loads first
	},

	{
		"sainnhe/sonokai",
		lazy = false,
		priority = 1000,
		config = function()
			-- Optionally configure and load the colorscheme
			-- directly inside the plugin declaration.
			vim.g.sonokai_enable_italic = true
		end,
	},
	{
		"navarasu/onedark.nvim",
		priority = 1000, -- Ensure it loads first
	},
	{
		"catppuccin/nvim",
		priority = 1000,
	},
	{
		"neanias/everforest-nvim",
		version = false,
		lazy = false,
		priority = 1000, -- make sure to load this before all the other start plugins
		-- Optional; default configuration will be used if setup isn't called.
		config = function()
			-- require('everforest').setup {
			--   -- Your config here
			-- }
		end,
	},
	{
		"sainnhe/edge",
		lazy = false,
		priority = 1000,
		config = function()
			-- Optionally configure and load the colorscheme
			-- directly inside the plugin declaration.
			vim.g.edge_enable_italic = true
		end,
	},
	{
		"Mofiqul/dracula.nvim",
		priority = 1000,
		lazy = false,
		config = function()
			italic_comment = true -- default false
		end,
	},
	{
		"glepnir/zephyr-nvim",
		priority = 1000,
	},
	{
		"rebelot/kanagawa.nvim",

		priority = 1000,
	},
	{

		"nyoom-engineering/oxocarbon.nvim",

		priority = 1000,
	},

	{

		"Yazeed1s/minimal.nvim",
		priority = 1000,
	},

	vim.keymap.set("n", "<leader>tt", "<cmd>Themery<CR>"),
}
