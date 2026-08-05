local M = {}

local _startup_handled = false
local _refreshing_picker = false

local function is_headless()
    if vim.tbl_contains(vim.v.argv, "--headless") then
        return true
    end
    return #vim.api.nvim_list_uis() == 0
end

local function remote_entries()
    local ok, remote_nvim = pcall(require, "remote-nvim")
    if not ok then
        return {}
    end

    local config_provider = remote_nvim.session_provider:get_config_provider()
    local entries = {}

    for _, host_id in ipairs(vim.tbl_keys(config_provider:get_workspace_config())) do
        local cfg = config_provider:get_workspace_config(host_id)
        local label = host_id
        if cfg.host and cfg.host ~= host_id then
            label = ("%s → %s"):format(host_id, cfg.host)
        end
        table.insert(entries, {
            kind = "remote",
            id = host_id,
            display = ("[remote] %s"):format(label),
            config = cfg,
        })
    end

    return entries
end

local function local_entries()
    local ok, AutoSession = pcall(require, "auto-session")
    if not ok then
        return {}
    end

    local Lib = require("auto-session.lib")
    local session_root = AutoSession.get_root_dir()
    local entries = {}

    for _, session in ipairs(Lib.get_session_list(session_root)) do
        table.insert(entries, {
            kind = "local",
            id = session.session_name,
            display = ("[local] %s"):format(session.display_name),
            session = session,
        })
    end

    return entries
end

local function all_entries()
    local entries = vim.list_extend(local_entries(), remote_entries())
    table.sort(entries, function(a, b)
        if a.kind ~= b.kind then
            return a.kind == "local"
        end
        return a.id < b.id
    end)
    return entries
end

local function restore_default_session()
    if _startup_handled or _refreshing_picker then
        return
    end
    pcall(function()
        require("auto-session").auto_restore_session_at_vim_enter()
    end)
end

function M.should_show_startup_picker()
    if is_headless() or vim.g.remote_neovim_host or #vim.v.argv > 0 then
        return false
    end
    return #all_entries() > 0
end

function M.startup_blocks_session_restore()
    return M.should_show_startup_picker()
end

local function open_entry(entry)
    if entry.kind == "local" then
        _startup_handled = true
        require("auto-session").autosave_and_restore(entry.id)
        return
    end

    _startup_handled = true
    vim.cmd({ cmd = "RemoteStart", args = { entry.id } })
end

local function delete_entry(entry, on_done)
    if entry.kind == "local" then
        require("auto-session").delete_session(entry.id)
        vim.notify("Removed local session: " .. entry.id, vim.log.levels.INFO)
    else
        vim.cmd({ cmd = "RemoteConfigDel", args = { entry.id } })
        vim.notify("Removed remote workspace: " .. entry.id, vim.log.levels.INFO)
    end
    if on_done then
        on_done()
    end
end

local function confirm_delete(entry, on_done)
    local label = entry.kind == "local" and "local session" or "remote workspace"
    local choice = vim.fn.confirm(
        ("Delete %s '%s'?"):format(label, entry.id),
        "&Delete\n&Cancel",
        2
    )
    if choice == 1 then
        delete_entry(entry, on_done)
    end
end

function M.manage(opts)
    opts = vim.tbl_extend("force", { startup = false }, opts or {})
    local entries = all_entries()

    if #entries == 0 then
        if not opts.silent then
            vim.notify("No saved workspaces", vim.log.levels.INFO)
        end
        if opts.startup then
            restore_default_session()
        end
        return
    end

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    local previewers = require("telescope.previewers")
    local previewer_utils = require("telescope.previewers.utils")

    local previewer = previewers.new_buffer_previewer({
        define_preview = function(self, entry)
            if entry.value.kind == "local" then
                local Lib = require("auto-session.lib")
                local lines, filetype = Lib.get_session_preview(entry.value.session.path, "summary")
                if type(lines) ~= "table" then
                    lines = { "No preview available" }
                end
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
                if filetype then
                    vim.bo[self.state.bufnr].filetype = filetype
                end
                previewer_utils.highlighter(self.state.bufnr, "markdown")
                return
            end

            local lines = { "# " .. entry.value.id, "" }
            for key, value in vim.spairs(entry.value.config) do
                if type(value) ~= "table" then
                    lines[#lines + 1] = string.format("%s: %s", key, tostring(value))
                end
            end
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
            previewer_utils.highlighter(self.state.bufnr, "markdown")
        end,
    })

    local picker = pickers.new(opts, {
        prompt_title = "Workspaces  ·  Enter open  ·  d delete  ·  n new remote  ·  Esc continue",
        previewer = previewer,
        finder = finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.display,
                    ordinal = entry.kind .. " " .. entry.id .. " " .. entry.display,
                }
            end,
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(bufnr, map)
            local function open_selected()
                local entry = action_state.get_selected_entry()
                if not entry then
                    return
                end
                actions.close(bufnr)
                open_entry(entry.value)
            end

            local function delete_selected()
                local entry = action_state.get_selected_entry()
                if not entry then
                    return
                end
                confirm_delete(entry.value, function()
                    _refreshing_picker = opts.startup
                    actions.close(bufnr)
                    vim.schedule(function()
                        M.manage(opts)
                        _refreshing_picker = false
                    end)
                end)
            end

            actions.select_default:replace(open_selected)
            map("i", "<CR>", open_selected)
            map("n", "<CR>", open_selected)
            map("i", "<C-d>", delete_selected)
            map("n", "d", delete_selected)
            map("i", "<C-n>", function()
                actions.close(bufnr)
                require("remote").connect_menu()
            end)
            map("n", "n", function()
                actions.close(bufnr)
                require("remote").connect_menu()
            end)

            actions.close:enhance({
                after = function()
                    if opts.startup then
                        restore_default_session()
                    end
                end,
            })

            return true
        end,
    })

    picker:find()
end

function M.setup_startup()
    vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
            vim.schedule(function()
                if M.should_show_startup_picker() then
                    M.manage({ startup = true })
                end
            end)
        end,
    })
end

return M
