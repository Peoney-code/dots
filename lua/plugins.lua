local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath
    })
end
vim.opt.rtp:prepend(lazypath)

local keymaps = require("keymaps")

require("lazy").setup({
    -- Theme & appearance
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
    },
    -- Treesitter syntax highlighter
    {
        "nvim-treesitter/nvim-treesitter",
        build = ":TSUpdate",
        opts = {
            highlight = { enable = true },
            indent = {enable = true },
        },
    },
    -- Mason for utilities installation and LSP
    {
        "williamboman/mason.nvim",
        config = function()
            require("mason").setup()
        end,
    },
    {
        "williamboman/mason-lspconfig.nvim",
        dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
        config = function()
            require("lsp").setup()
        end,
    },
    -- Debugging (DAP): C++, Rust, Go — local and remote attach
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "theHamsta/nvim-dap-virtual-text",
            "jay-babu/mason-nvim-dap.nvim",
            "nvim-telescope/telescope-dap.nvim",
            "nvim-neotest/nvim-nio",
        },
        config = function()
            require("dap_config").setup()
            require("telescope").load_extension("dap")
        end,
    },
    -- Filesystem tree
    { "nvim-tree/nvim-web-devicons" },
    {
        "nvim-tree/nvim-tree.lua",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("nvim-tree").setup({
                view = {width = 30,},
                renderer = {group_empty = true,},
                filters = {dotfiles = false,},      -- show hidden files (.dotfiles)
            })
        end,
    },
    -- Telescope for global files search
    {
        "nvim-telescope/telescope.nvim",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-web-devicons",
        },
        config = function()
            require("telescope").setup()
        end,
    },
    -- Git: signs in gutter + hunk actions
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            signs = {
                add = { text = "│" },
                change = { text = "│" },
                delete = { text = "_" },
                topdelete = { text = "‾" },
                changedelete = { text = "~" },
                untracked = { text = "┆" },
            },
            on_attach = require("keymaps").gitsigns_on_attach,
        },
    },
    -- Git: visual TUI panel (requires `lazygit` installed on system)
    {
        "kdheepak/lazygit.nvim",
        cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
        dependencies = { "nvim-lua/plenary.nvim" },
    },
    -- Remote development over SSH (like VSCode Remote SSH)
    {
        "amitds1997/remote-nvim.nvim",
        version = "*",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            "nvim-telescope/telescope.nvim",
        },
        config = function()
            require("remote-nvim").setup()
            pcall(function()
                require("telescope").load_extension("remote-nvim")
            end)
        end,
    },
    -- Buffer tabs (VSCode-like tab bar)
    {
        "akinsho/bufferline.nvim",
        version = "*",
        dependencies = { "nvim-tree/nvim-web-devicons" },
        config = function()
            require("bufferline").setup({
                options = {
                    mode = "buffers",
                    separator_style = "thin",
                    always_show_bufferline = true,
                    show_buffer_close_icons = true,
                    show_close_icon = false,
                    diagnostics = false,
                },
            })
        end,
    },
    -- AI assistant (Cursor-like, local LLM via Ollama)
    {
        "yetone/avante.nvim",
        version = false,
        build = "make",
        event = "VeryLazy",
        dependencies = {
            "nvim-lua/plenary.nvim",
            "MunifTanjim/nui.nvim",
            "nvim-telescope/telescope.nvim",
            "nvim-tree/nvim-web-devicons",
            {
                "MeanderingProgrammer/render-markdown.nvim",
                opts = {
                    file_types = { "markdown", "Avante" },
                },
                ft = { "markdown", "Avante" },
            },
        },
        opts = function()
            return require("ai").opts()
        end,
        config = function(_, opts)
            require("avante").setup(opts)
            require("ai").post_setup()
        end,
    },
    -- Which-key helper
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {
            delay = 200,
            spec = {
                { "<leader>w", group = keymaps.which_key_group("windows") },
                { "<leader>wg", group = keymaps.which_key_group("groups") },
                { "<leader>b", group = keymaps.which_key_group("buffers") },
                { "<leader>g", group = keymaps.which_key_group("git") },
                { "<leader>s", group = keymaps.which_key_group("search") },
                { "<leader>c", group = keymaps.which_key_group("code") },
                { "<leader>f", group = keymaps.which_key_group("file") },
                { "<leader>t", group = keymaps.which_key_group("tree") },
                { "<leader>r", group = keymaps.which_key_group("remote") },
                { "<leader>a", group = keymaps.which_key_group("ai") },
                { "<leader>d", group = keymaps.which_key_group("debug") },
            },
        },
    },
    -- Автоматическое сохранение и восстановление сессий по папкам
    {
        "rmagatti/auto-session",
        lazy = false,
        opts = {
             -- Do not create sessions for following dirs
            suppress_dirs = { "~/", "~/Downloads", "/tmp", "/" },
            -- Auto-save & auto-restore on open/close
            auto_save = true,
            auto_restore = true,
            pre_restore_cmds = {
                function()
                    local ok, workspaces = pcall(require, "workspaces")
                    if ok and workspaces.startup_blocks_session_restore() then
                        return false
                    end
                    return true
                end,
            },
        },
        config = function(_, opts)
            require("auto-session").setup(opts)
            require("workspaces").setup_startup()
        end,
    },
})
