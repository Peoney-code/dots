local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({
        "git", "clone", "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath
    })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
    -- Theme & appearance
    {
        "folke/tokyonight.nvim",
        lazy = false,
        priority = 1000,
        config = function()
            vim.cmd([[colorscheme tokyonight-night]])
        end,
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
        dependencies = {"williamboman/mason.nvim", "neovim/nvim-lspconfig"},
        config = function()
            require("mason-lspconfig").setup()
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
    -- Which-key helper
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = {delay = 300,},
        keys = {
            {
                "<leader>?",
                function()
                    require("which-key").show({ global = false})
                end,
                desc = "Show keybinds for current buffer",
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
        },
    },
})
