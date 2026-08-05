local M = {}

local map = vim.keymap.set

-- Fast save (skip readonly buffers, e.g. avante sidebar)
map("n", "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
map("v", "<C-s>", "<cmd>w<CR>", { desc = "Save file" })
map("i", "<C-s>", function()
    if vim.bo.modifiable then
        vim.cmd("silent! write")
    end
end, { desc = "Save file" })
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

-- Window focus (Ctrl+arrows + terminal/OS fallbacks)
local function map_win_focus(lhs, win_cmd, desc)
    map("n", lhs, win_cmd, { desc = desc })
    map("i", lhs, "<C-o>" .. win_cmd, { desc = desc })
end

for _, binding in ipairs({
    { "<C-Left>", "<C-w>h", "Focus left window" },
    { "<C-Down>", "<C-w>j", "Focus window below" },
    { "<C-Up>", "<C-w>k", "Focus window above" },
    { "<C-Right>", "<C-w>l", "Focus right window" },
    -- xterm / foot / kitty / alacritty when Ctrl+arrow is sent as CSI, not <C-Left>
    { "<Esc>[1;5D", "<C-w>h", "Focus left window" },
    { "<Esc>[1;5C", "<C-w>l", "Focus right window" },
    { "<Esc>[1;5A", "<C-w>k", "Focus window above" },
    { "<Esc>[1;5B", "<C-w>j", "Focus window below" },
    -- some terminals prefix CSI with Meta instead of Esc
    { "<M-[1;5D", "<C-w>h", "Focus left window" },
    { "<M-[1;5C", "<C-w>l", "Focus right window" },
    { "<M-[1;5A", "<C-w>k", "Focus window above" },
    { "<M-[1;5B", "<C-w>j", "Focus window below" },
    -- fallback when Ctrl is captured by compositor
    { "<A-Left>", "<C-w>h", "Focus left window" },
    { "<A-Down>", "<C-w>j", "Focus window below" },
    { "<A-Up>", "<C-w>k", "Focus window above" },
    { "<A-Right>", "<C-w>l", "Focus right window" },
}) do
    map_win_focus(binding[1], binding[2], binding[3])
end

local function map_tab_group(lhs, cmd, desc)
    map("n", lhs, cmd, { desc = desc })
    map("i", lhs, "<C-o>" .. cmd, { desc = desc })
end

for _, binding in ipairs({
    { "<C-S-Left>", "<cmd>tabprevious<CR>", "Previous window group" },
    { "<C-S-Right>", "<cmd>tabnext<CR>", "Next window group" },
    { "<Esc>[1;6D", "<cmd>tabprevious<CR>", "Previous window group" },
    { "<Esc>[1;6C", "<cmd>tabnext<CR>", "Next window group" },
    { "<M-[1;6D", "<cmd>tabprevious<CR>", "Previous window group" },
    { "<M-[1;6C", "<cmd>tabnext<CR>", "Next window group" },
}) do
    map_tab_group(binding[1], binding[2], binding[3])
end

map("n", "<leader>wga", "<cmd>tabnew<CR>", { desc = "New window group" })
map("n", "<leader>wgt", "<cmd>tab split<CR>", { desc = "New group from current layout" })
map("n", "<leader>wgd", "<cmd>tabclose<CR>", { desc = "Close window group" })

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

-- Workspaces (local auto-session + remote SSH)
map("n", "<leader>ws", function() require("workspaces").manage() end, { desc = "Workspaces" })

-- Remote SSH (remote-nvim.nvim)
map("n", "<leader>rr", function() require("workspaces").manage() end, { desc = "Open workspaces" })
map("n", "<leader>rw", function() require("workspaces").manage() end, { desc = "Manage workspaces" })
map("n", "<leader>ra", function() require("remote").attach_active() end, { desc = "Attach to active session" })
map("n", "<leader>rs", function() require("remote").connect_menu() end, { desc = "Connect (all options)" })
map("n", "<leader>rh", function() require("remote").ssh_hosts() end, { desc = "Connect via SSH config" })
map("n", "<leader>rm", function() require("remote").ssh_manual() end, { desc = "Connect via SSH string" })
map("n", "<leader>ri", function() require("remote").session_info() end, { desc = "Session info" })
map("n", "<leader>rS", function() require("remote").session_stop() end, { desc = "Stop remote session" })
map("n", "<leader>rl", function() require("remote").open_log() end, { desc = "Remote plugin log" })
map("n", "<leader>rx", function() require("remote").cleanup_host() end, { desc = "Clean up remote host" })
map("n", "<leader>rd", function() require("workspaces").manage() end, { desc = "Delete workspace" })

-- Filesystem tree (nvim-tree)
map("n", "<leader>t", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file tree" })
map("n", "<leader>to", "<cmd>NvimTreeOpen<CR>", { desc = "Open file tree" })
map("n", "<leader>tc", "<cmd>NvimTreeClose<CR>", { desc = "Close file tree" })
map("n", "<leader>tf", "<cmd>NvimTreeFocus<CR>", { desc = "Focus file tree" })
map("n", "<leader>tr", "<cmd>NvimTreeRefresh<CR>", { desc = "Refresh file tree" })
map("n", "<leader>ts", "<cmd>NvimTreeFindFile<CR>", { desc = "Reveal file in tree" })
map("n", "<leader>tS", "<cmd>NvimTreeFindFileToggle<CR>", { desc = "Reveal file, toggle tree" })
map("n", "<leader>te", "<cmd>NvimTreeCollapse<CR>", { desc = "Collapse tree" })
map("n", "<leader>tE", "<cmd>NvimTreeCollapseKeepBuffers<CR>", { desc = "Collapse tree (keep open dirs)" })
map("n", "<leader>t+", "<cmd>NvimTreeResize +5<CR>", { desc = "Widen file tree" })
map("n", "<leader>t-", "<cmd>NvimTreeResize -5<CR>", { desc = "Narrow file tree" })

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

-- AI (avante.nvim)
map("n", "<leader>aa", function() require("avante.api").ask() end, { desc = "AI sidebar" })
map("n", "<leader>at", function() require("avante.api").toggle() end, { desc = "Toggle AI sidebar" })
map("n", "<leader>az", function() require("avante.api").zen_mode() end, { desc = "AI agent zen mode" })
map("n", "<leader>ap", function() require("ai").pick_provider() end, { desc = "Select AI provider" })
map("n", "<leader>a?", function() require("ai").open_model_picker() end, { desc = "Select AI model" })
map("n", "<leader>am", function() require("ai").open_mode_picker() end, { desc = "Select AI mode" })

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
