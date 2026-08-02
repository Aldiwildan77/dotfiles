require("git"):setup {
	-- Order of status signs showing in the linemode
	order = 1500,
}

require("copy-file-contents"):setup({
	append_char = "\n",
	notification = true,
})
