local M = {}

local map = vim.keymap.set

-- Fast save
map({"n", "i", "v"}, "<C-s>", "<cmd>w<CR>", { desc = "Save file"})
-- Turn of search highlights on ESC
map("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Buffer tabs (VSCode-like)
map("n", "<C-Tab>", "<cmd>BufferLineCycleNext<CR>", { desc = "Next tab" })
map("n", "<C-S-Tab>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Previous tab" })
map("n", "<leader>bc", "<cmd>bd<CR>", { desc = "Close tab" })

-- Windows (<leader>w)
map("n", "<leader>wr", "<C-w>v", { desc = "Split right" })
map("n", "<leader>wd", "<C-w>s", { desc = "Split down" })
map("n", "<leader>w=", "<C-w>=", { desc = "Equalize splits" })
map("n", "<leader>wc", "<C-w>c", { desc = "Close window" })

-- Window groups / tab pages (VSCode editor groups)
map("n", "<C-S-Left>", "<cmd>tabprevious<CR>", { desc = "Previous window group" })
map("n", "<C-S-Right>", "<cmd>tabnext<CR>", { desc = "Next window group" })
map("n", "<leader>wga", "<cmd>tabnew<CR>", { desc = "New window group" })
map("n", "<leader>wgt", "<cmd>tab split<CR>", { desc = "New group from current layout" })
map("n", "<leader>wgd", "<cmd>tabclose<CR>", { desc = "Close window group" })

-- Window focus
map("n", "<C-Left>", "<C-w>h", { desc = "Focus left window" })
map("n", "<C-Down>", "<C-w>j", { desc = "Focus window below" })
map("n", "<C-Up>", "<C-w>k", { desc = "Focus window above" })
map("n", "<C-Right>", "<C-w>l", { desc = "Focus right window" })

-- Git (gitsigns)
function M.gitsigns_on_attach(bufnr)
    local gs = require("gitsigns")

    local function buf_map(mode, lhs, rhs, desc)
        map(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    buf_map("n", "]c", function()
        if vim.wo.diff then
            vim.cmd.normal({ "]c", bang = true })
        else
            gs.nav_hunk("next")
        end
    end, "Next git change")
    buf_map("n", "[c", function()
        if vim.wo.diff then
            vim.cmd.normal({ "[c", bang = true })
        else
            gs.nav_hunk("prev")
        end
    end, "Previous git change")
    buf_map("n", "<leader>gs", gs.stage_hunk, "Stage hunk")
    buf_map("n", "<leader>gr", gs.reset_hunk, "Reset hunk")
    buf_map("v", "<leader>gs", function()
        gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, "Stage selection")
    buf_map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
    buf_map("n", "<leader>gb", function()
        gs.blame_line({ full = true })
    end, "Blame line")
    buf_map("n", "<leader>gd", gs.diffthis, "Diff file")
end

-- Git (lazygit)
map("n", "<leader>gg", "<cmd>LazyGit<CR>", { desc = "Open LazyGit" })
map("n", "<leader>gG", "<cmd>LazyGitCurrentFile<CR>", { desc = "LazyGit (current file)" })

-- Remote SSH
map("n", "<leader>rs", "<cmd>RemoteStart<CR>", { desc = "Connect to remote host (SSH)" })
map("n", "<leader>rS", "<cmd>RemoteStop<CR>", { desc = "Stop remote session" })
map("n", "<leader>ri", "<cmd>RemoteInfo<CR>", { desc = "Remote session info" })

-- FS tree
map("n", "<leader>t", "<cmd>NvimTreeToggle<CR>", { desc = "Open/close filesystem tree pane" })

-- Search (telescope)
map("n", "<leader>sf", function() require("telescope.builtin").find_files() end, { desc = "Find file by name" })
map("n", "<leader>st", function() require("telescope.builtin").live_grep() end, { desc = "Search text in files" })
map("n", "<leader>sb", function() require("telescope.builtin").buffers() end, { desc = "Search in open buffers" })

-- Code navigation (LSP)
local function telescope_lsp(method)
    return function()
        require("telescope.builtin")[method]({})
    end
end

map("n", "<leader>cd", telescope_lsp("lsp_definitions"), { desc = "Go to definition" })
map("n", "<leader>cD", telescope_lsp("lsp_declarations"), { desc = "Go to declaration" })
map("n", "<leader>ci", telescope_lsp("lsp_implementations"), { desc = "Go to implementation" })
map("n", "<leader>ct", telescope_lsp("lsp_type_definitions"), { desc = "Go to type definition" })
map("n", "<leader>ch", function() vim.lsp.buf.hover() end, { desc = "Show documentation" })
map("n", "<leader>cr", telescope_lsp("lsp_references"), { desc = "Find references" })
map("n", "<leader>cs", telescope_lsp("lsp_document_symbols"), { desc = "Symbols in file" })
map("n", "<leader>cS", telescope_lsp("lsp_workspace_symbols"), { desc = "Symbols in project" })
map("n", "<leader>cl", telescope_lsp("diagnostics"), { desc = "All diagnostics" })
map("n", "<leader>ce", function() vim.diagnostic.open_float() end, { desc = "Diagnostics at cursor" })
map("n", "<leader>cn", "<cmd>cnext<CR>", { desc = "Next location" })
map("n", "<leader>cp", "<cmd>cprev<CR>", { desc = "Previous location" })
map("n", "<leader>cq", "<cmd>copen<CR>", { desc = "Open locations list" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Previous diagnostic" })

-- Debug (DAP)
local dap = function(fn)
    return function() require("dap")[fn]() end
end

map("n", "<leader>ds", function() require("dap").continue() end, { desc = "Start / continue debug" })
map("n", "<leader>dc", function() require("dap").continue() end, { desc = "Continue" })
map("n", "<leader>di", dap("step_into"), { desc = "Step into" })
map("n", "<leader>do", dap("step_over"), { desc = "Step over" })
map("n", "<leader>dO", dap("step_out"), { desc = "Step out" })
map("n", "<leader>dt", dap("terminate"), { desc = "Terminate debug session" })
map("n", "<leader>db", function() require("dap").toggle_breakpoint() end, { desc = "Toggle breakpoint" })
map("n", "<leader>dB", function()
    require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, { desc = "Conditional breakpoint" })
map("n", "<leader>dl", function()
    require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
end, { desc = "Log point" })
map("n", "<leader>du", function() require("dapui").toggle() end, { desc = "Toggle debug UI" })
map("n", "<leader>dr", function() require("dapui").float_element("repl", { enter = true }) end, { desc = "Debug REPL" })
map("n", "<leader>dw", function()
    require("dapui").float_element("watches", { enter = true })
end, { desc = "Watches" })
map("n", "<leader>dp", function()
    require("telescope").extensions.dap.configurations({})
end, { desc = "Pick debug configuration" })

-- Which-key
map("n", "<leader>?", function()
    require("which-key").show()
end, { desc = "Show keybinds" })

-- Copying selected text to system clipboard (Visual mode)
map("v", "<C-c>", '"+y', { desc = "Copy selection to system clipboard" })

-- Pasting from system clipboard
map("n", "<C-v>", '"+p', { desc = "Paste from system clipboard in Normal mode" })
map("v", "<C-v>", '"+p', { desc = "Paste over selection in Visual mode" })
map("i", "<C-v>", "<C-r>+", { desc = "Paste from system clipboard in Insert mode" })

-- Undo last changes (Ctrl + z)
map("n", "<C-z>", "u", { desc = "Undo last changes" })
map("i", "<C-z>", "<C-o>u", { desc = "Undo last changes" })

--- Group label with live keymap count for which-key, e.g. "windows (4)"
function M.which_key_group(name)
    return function(mapping)
        local ok, label = pcall(function()
            local mode = mapping.mode or "n"
            if type(mode) == "table" then
                mode = mode[1]
            end
            local buf_mode = require("which-key.buf").get({ mode = mode })
            if not buf_mode then
                return name
            end
            local keys = require("which-key.util").keys(mapping.lhs, { norm = true })
            local node = buf_mode.tree:find(keys)
            local count = node and node:count() or 0
            return count > 0 and string.format("%s (%d)", name, count) or name
        end)
        return ok and label or name
    end
end

return M
