local M = {}

local path = vim.fn.stdpath("state") .. "/colorscheme"

function M.load()
    if vim.fn.filereadable(path) == 1 then
        local lines = vim.fn.readfile(path)
        if lines[1] and lines[1] ~= "" then
            return lines[1]
        end
    end
end

function M.save(name)
    vim.fn.writefile({ name }, path)
end

---@param name string
---@param opts? { persist?: boolean }
function M.apply(name, opts)
    opts = opts or {}
    vim.g._colorscheme_loading = true
    local ok = pcall(vim.cmd.colorscheme, name)
    vim.g._colorscheme_loading = false
    if ok and opts.persist ~= false then
        M.save(name)
    end
    return ok
end

vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
        if vim.g._colorscheme_loading or not vim.g.colors_name then
            return
        end
        M.save(vim.g.colors_name)
    end,
})

vim.api.nvim_create_autocmd("User", {
    pattern = "LazyDone",
    callback = function()
        local saved = M.load()
        if saved then
            M.apply(saved, { persist = false })
        else
            M.apply("tokyonight-night", { persist = false })
        end
    end,
})

return M
