local M = {}

function M.setup()
    vim.diagnostic.config({
        virtual_text = true,
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
    })

    vim.lsp.config("lua_ls", {
        settings = {
            Lua = {
                runtime = { version = "LuaJIT" },
                diagnostics = {
                    globals = { "vim" },
                },
            },
        },
    })

    require("mason-lspconfig").setup({
        ensure_installed = {
            "lua_ls",
            "pyright",
            "clangd",
            "rust_analyzer",
            -- gopls requires `go` in PATH (pacman -S go); install manually via :Mason after that
            "gopls",
            "ts_ls",
            "bashls",
            "jsonls",
        },
    })
end

return M
