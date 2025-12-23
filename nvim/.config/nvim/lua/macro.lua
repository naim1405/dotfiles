vim.api.nvim_create_augroup("JSLogMacro", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
	group = "JSLogMacro",
	pattern = { "javascript", "javascriptreact", "typescript" },
	callback = function()
		vim.fn.setreg("l", "yoconsole.log('🚀 pa : ', pa)")
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	group = "JSLogMacro",
	pattern = { "py", "python" },
	callback = function()
		vim.fn.setreg("l", "yoprint('🚀 pa : ', pa)")
	end,
})
--vim.fn.setreg('l', "yoconsole.log('🚀 pa : ', pa)")
