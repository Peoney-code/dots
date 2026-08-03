
local map = vim.keymap.set

-- Fast save
map({"n", "i", "v"}, "<C-s>", "<cmd>w<CR>", { desc = "Save file"})
-- Turn of search highlights on ESC
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Switching windows
map("n", "<C-Left>", "<C-w>h", {desc = "Switch by 1 window left"})
map("n", "<C-Down>", "<C-w>j", {desc = "Switch by 1 window up"})
map("n", "<C-Up>", "<C-w>k", {desc = "Switch by 1 window up"})
map("n", "<C-Right>", "<C-w>l", {desc = "Switch by 1 window right"})

-- FS tree
map("n", "<leader>t", "<cmd>NvimTreeToggle<CR>", {desc = "Open/close filesystem tree pane"})

-- Files search
map("n", "<leader>fn", function() require("telescope.builtin").find_files() end, { desc = "Find file by name" })
map("n", "<leader>ft", function() require("telescope.builtin").live_grep() end, { desc = "Search text in files" })
map("n", "<leader>fb", function() require("telescope.builtin").buffers() end, { desc = "Search text in open buffers" })

-- Копирование выделенного текста в системный буфер обмена (Visual mode)
map("v", "<C-c>", '"+y', { desc = "Copy selection to system clipboard" })

-- Вставка из системного буфера обмена
map("n", "<C-v>", '"+p', { desc = "Paste from system clipboard in Normal mode" })
map("v", "<C-v>", '"+p', { desc = "Paste over selection in Visual mode" })
map("i", "<C-v>", "<C-r>+", { desc = "Paste from system clipboard in Insert mode" })

-- Отмена последнего изменения (Undo) на Ctrl + z
map("n", "<C-z>", "u", { desc = "Undo last changes" })
map("i", "<C-z>", "<C-o>u", { desc = "Undo last changes" })
