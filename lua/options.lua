local opt = vim.opt

-- Leader key setup
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Lines numbers
opt.number = true
opt.relativenumber = true

-- Tabs and spaces
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- Search
opt.ignorecase = true	-- search case insensetive
opt.smartcase = true	-- once the capital letter occures- search becomes case-sensitive

-- UI
opt.termguicolors = true	-- use 24-bit colors
opt.cursorline = true		-- highlight current line
opt.signcolumn = "yes"		-- show additional column with plugin-specific signs
opt.scrolloff = 8		-- number of lines to fix around the cursor then scrolling

-- Clipboard (use system clipboard lice CTRL(CMD) + C/V)
opt.clipboard = "unnamedplus"

-- Full mouse support
vim.opt.mouse = "a"
