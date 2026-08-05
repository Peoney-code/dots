local M = {}

local function remote_nvim()
    return require("remote-nvim")
end

local function pick_ssh_host()
    for _, choice in ipairs(require("telescope._extensions.choices")()) do
        if choice.value == "remote-ssh-configured-host" then
            choice.action()
            return
        end
    end
end

local function pick_ssh_manual()
    for _, choice in ipairs(require("telescope._extensions.choices")()) do
        if choice.value == "remote-ssh-manual-input" then
            choice.action()
            return
        end
    end
end

local function saved_host_ids()
    return vim.tbl_keys(
        remote_nvim().session_provider:get_config_provider():get_workspace_config()
    )
end

local function running_sessions()
    local sessions = remote_nvim().session_provider:get_all_sessions()
    local running = {}
    for host_id, session in pairs(sessions) do
        if session:is_remote_server_running() then
            running[host_id] = session
        end
    end
    return running
end

local function pick_host(action, prompt, hosts)
    hosts = hosts or saved_host_ids()
    if #hosts == 0 then
        vim.notify("No saved remote hosts", vim.log.levels.WARN)
        return
    end

    if #hosts == 1 then
        action(hosts[1])
        return
    end

    vim.ui.select(hosts, { prompt = prompt }, function(choice)
        if choice then
            action(choice)
        end
    end)
end

local function pick_running_session(action, prompt)
    local sessions = running_sessions()
    local host_ids = vim.tbl_keys(sessions)
    if #host_ids == 0 then
        vim.notify("No active remote sessions", vim.log.levels.WARN)
        return
    end

    if #host_ids == 1 then
        action(sessions[host_ids[1]], host_ids[1])
        return
    end

    vim.ui.select(host_ids, { prompt = prompt }, function(choice)
        if choice then
            action(sessions[choice], choice)
        end
    end)
end

function M.connect_menu()
    require("telescope").extensions["remote-nvim"].connect()
end

function M.reconnect_saved()
    require("workspaces").manage()
end

function M.attach_active()
    pick_running_session(function(session)
        session:launch_neovim()
    end, "Attach to active session")
end

function M.ssh_hosts()
    pick_ssh_host()
end

function M.ssh_manual()
    pick_ssh_manual()
end

function M.session_info()
    vim.cmd("RemoteInfo")
end

function M.session_stop()
    vim.cmd("RemoteStop")
end

function M.open_log()
    vim.cmd("RemoteLog")
end

function M.cleanup_host()
    pick_host(function(host_id)
        vim.cmd({ cmd = "RemoteCleanup", args = { host_id } })
    end, "Clean up remote host")
end

function M.delete_saved()
    require("workspaces").manage()
end

return M
