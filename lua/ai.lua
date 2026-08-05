local M = {}

local STATE_FILE = vim.fn.stdpath("state") .. "/avante-ui.json"

local INTERACTION_MODES = {
    ask = {
        label = "Ask",
        mode = "legacy",
        ask = true,
        behaviour = {
            auto_apply_diff_after_generation = false,
            auto_approve_tool_permissions = false,
        },
    },
    plan = {
        label = "Plan",
        mode = "legacy",
        ask = false,
        behaviour = {
            auto_apply_diff_after_generation = false,
            auto_approve_tool_permissions = true,
        },
    },
    agent = {
        label = "Agent",
        mode = "agentic",
        ask = false,
        behaviour = {
            auto_apply_diff_after_generation = false,
            auto_approve_tool_permissions = true,
        },
    },
}

M.current_mode = "agent"
M.layout = {}

M.NO_MODEL_CHOSEN = "no_model_chosen"
M.NO_MODEL_LOADED = "no_model_loaded"

local PLACEHOLDER_MODELS = {
    [M.NO_MODEL_CHOSEN] = true,
    [M.NO_MODEL_LOADED] = true,
}

function M.is_placeholder_model(model_id)
    return type(model_id) == "string" and PLACEHOLDER_MODELS[model_id] == true
end

function M.is_usable_model(model_id)
    if type(model_id) ~= "string" or model_id == "" then
        return false
    end
    if M.is_placeholder_model(model_id) or model_id == "not selected" then
        return false
    end
    return true
end

local LOCAL_PROVIDERS = {
    lmstudio = {
        label = "LM Studio",
        endpoint = "http://127.0.0.1:1234/v1",
        models_url = "http://127.0.0.1:1234/v1/models",
    },
    unsloth = {
        label = "Unsloth",
        endpoint = ("http://127.0.0.1:%s/v1"):format(vim.env.UNSLOTH_PORT or "8888"),
        models_url = ("http://127.0.0.1:%s/v1/models"):format(vim.env.UNSLOTH_PORT or "8888"),
        api_key_name = "UNSLOTH_STUDIO_AUTH_TOKEN",
    },
    cursor = {
        label = "Cursor",
        endpoint = ("http://127.0.0.1:%s/v1"):format(vim.env.CURSOR_PROXY_PORT or "4646"),
        models_url = ("http://127.0.0.1:%s/v1/models"):format(vim.env.CURSOR_PROXY_PORT or "4646"),
        health_url = ("http://127.0.0.1:%s/health"):format(vim.env.CURSOR_PROXY_PORT or "4646"),
        api_key = vim.env.CURSOR_API_KEY or "not-needed",
        timeout = 300000,
        use_agent_models = true,
        unloaded_hint = "Start cursor-agent-api-proxy locally and run `agent login`.",
    },
}

local HIDDEN_PROVIDERS = {
    "openai", "claude", "azure", "gemini", "vertex", "vertex_claude",
    "copilot", "bedrock", "ollama", "cohere", "mistral", "watsonx_code_assistant",
}

local function fetch_models_result(cfg)
    local cmd = { "curl", "-sf", cfg.models_url }
    if cfg.api_key then
        cmd[#cmd + 1] = "-H"
        cmd[#cmd + 1] = "Authorization: Bearer " .. cfg.api_key
    elseif cfg.api_key_name then
        local key = vim.env[cfg.api_key_name]
        if key and key ~= "" then
            cmd[#cmd + 1] = "-H"
            cmd[#cmd + 1] = "Authorization: Bearer " .. key
        end
    end

    local ok, result = pcall(function()
        return vim.system(cmd, { timeout = cfg.fetch_timeout or 15000 }):wait()
    end)
    if not ok or not result or result.code ~= 0 then
        return { online = false, models = {} }
    end
    if not result.stdout or result.stdout == "" then
        return { online = true, models = {} }
    end

    local decoded_ok, body = pcall(vim.json.decode, result.stdout)
    if not decoded_ok or type(body) ~= "table" or type(body.data) ~= "table" then
        return { online = true, models = {} }
    end

    local models = {}
    for _, model in ipairs(body.data) do
        if type(model) == "table" and type(model.id) == "string" then
            models[#models + 1] = model.id
        end
    end
    table.sort(models)
    return { online = true, models = models }
end

local function merge_model_ids(...)
    local seen = {}
    local models = {}
    for _, list in ipairs({ ... }) do
        for _, model_id in ipairs(list) do
            if not seen[model_id] then
                seen[model_id] = true
                models[#models + 1] = model_id
            end
        end
    end
    table.sort(models)
    return models
end

local function cursor_agent_path()
    local from_env = vim.env.CURSOR_AGENT_PATH
    if from_env and from_env ~= "" and vim.fn.executable(from_env) == 1 then
        return from_env
    end
    if vim.fn.executable("agent") == 1 then
        return "agent"
    end
    return nil
end

local function parse_agent_models_output(stdout)
    local trimmed = vim.trim(stdout)
    if trimmed == "" then
        return {}
    end

    local decoded_ok, body = pcall(vim.json.decode, trimmed)
    if decoded_ok and type(body) == "table" then
        local models = {}
        local list = body.data or body.models or body
        if type(list) == "table" then
            for _, item in ipairs(list) do
                if type(item) == "string" then
                    models[#models + 1] = item
                elseif type(item) == "table" and type(item.id) == "string" then
                    models[#models + 1] = item.id
                elseif type(item) == "table" and type(item.name) == "string" then
                    models[#models + 1] = item.name
                end
            end
        end
        if #models > 0 then
            table.sort(models)
            return models
        end
    end

    local models = {}
    for line in vim.gsplit(trimmed, "\n", { plain = true, trimempty = true }) do
        line = vim.trim(line)
        if line == "" or line:match("^Available models") or line:match("^Tip:") then
            goto continue
        end
        local model_id = line:match("^(%S+)%s+-") or line:match("^(%S+)$")
        if model_id and model_id ~= "Available" then
            models[#models + 1] = model_id
        end
        ::continue::
    end
    table.sort(models)
    return models
end

local function fetch_cursor_models_via_cli()
    local agent = cursor_agent_path()
    if not agent then
        return {}
    end

    local arg_lists = {
        { "models", "--json" },
        { "models" },
        { "--list-models" },
    }
    for _, args in ipairs(arg_lists) do
        local cmd = vim.list_extend({ agent }, args)
        local ok, result = pcall(function()
            return vim.system(cmd, { timeout = 60000 }):wait()
        end)
        if ok and result and result.code == 0 and result.stdout and result.stdout ~= "" then
            local models = parse_agent_models_output(result.stdout)
            if #models > 0 then
                return models
            end
        end
    end
    return {}
end

local function fetch_cursor_models(cfg)
    local cli_models = fetch_cursor_models_via_cli()
    if cfg.use_agent_models and #cli_models > 0 then
        return merge_model_ids(cli_models, fetch_models_result(cfg).models)
    end
    return fetch_models_result(cfg).models
end

local function provider_online(cfg)
    if cfg.health_url then
        local ok, result = pcall(function()
            return vim.system({ "curl", "-sf", cfg.health_url }, { timeout = 3000 }):wait()
        end)
        if ok and result and result.code == 0 then
            return true
        end
        if cfg.use_agent_models and cursor_agent_path() then
            return #fetch_cursor_models_via_cli() > 0
        end
        return false
    end
    return #fetch_models_result(cfg).models > 0
end

local function fetch_provider_models(provider_name, cfg)
    if provider_name == "cursor" then
        return fetch_cursor_models(cfg)
    end
    return fetch_models_result(cfg).models
end

local function fetch_models(cfg)
    local result = fetch_models_result(cfg)
    return result.models
end

function M.cursor_setup_message()
    local port = vim.env.CURSOR_PROXY_PORT or "4646"
    local lines = {}
    if not provider_online(LOCAL_PROVIDERS.cursor) then
        lines[#lines + 1] = ("1. Proxy: npm i -g cursor-agent-api-proxy && cursor-agent-api start %s"):format(port)
    end
    if not cursor_agent_path() then
        lines[#lines + 1] = "2. CLI: curl https://cursor.com/install -fsS | bash"
        lines[#lines + 1] = "3. Login: agent login"
    end
    if #lines == 0 then
        return "Cursor proxy is up but no models returned. Run `agent login` and retry."
    end
    return table.concat(lines, "\n")
end

local function notify_cursor_setup_if_missing(entries)
    for _, entry in ipairs(entries) do
        if entry.provider == "cursor" then
            return
        end
    end
    vim.notify("Cursor models not in list:\n" .. M.cursor_setup_message(), vim.log.levels.WARN)
end

local function unloaded_hint(provider_name)
    local cfg = LOCAL_PROVIDERS[provider_name]
    if cfg and cfg.unloaded_hint then
        return cfg.unloaded_hint
    end
    return "Start the provider server and load a model, then retry."
end

local function load_state()
    local ok, raw = pcall(vim.fn.readfile, STATE_FILE)
    if not ok or not raw or #raw == 0 then
        return
    end
    local decoded_ok, state = pcall(vim.json.decode, table.concat(raw, "\n"))
    if not decoded_ok or type(state) ~= "table" then
        return
    end
    if type(state.mode) == "string" and INTERACTION_MODES[state.mode] then
        M.current_mode = state.mode
    end
    if type(state.layout) == "table" then
        M.layout = state.layout
    end
end

local function save_state()
    vim.fn.mkdir(vim.fn.stdpath("state"), "p")
    local payload = vim.json.encode({
        mode = M.current_mode,
        layout = M.layout,
    })
    pcall(vim.fn.writefile, vim.split(payload, "\n"), STATE_FILE)
end

local function refresh_sidebar_header()
    local sidebar = require("avante").get()
    if sidebar and sidebar:is_open() then
        sidebar:render_result()
    end
end

function M.get_mode_label()
    local def = INTERACTION_MODES[M.current_mode]
    return def and def.label or M.current_mode
end

function M.apply_interaction_mode(name)
    local def = INTERACTION_MODES[name]
    if not def then
        return
    end

    local Config = require("avante.config")
    Config.override({
        mode = def.mode,
        behaviour = vim.tbl_deep_extend("force", Config.behaviour, def.behaviour),
    })
    Config.ask_opts = vim.tbl_extend("force", Config.ask_opts or {}, { ask = def.ask })

    M.current_mode = name
    save_state()
    refresh_sidebar_header()
end

function M.open_mode_picker()
    local items = {}
    for name, def in pairs(INTERACTION_MODES) do
        items[#items + 1] = { name = name, label = def.label }
    end
    table.sort(items, function(a, b)
        return a.name < b.name
    end)

    vim.ui.select(vim.tbl_map(function(item)
        local marker = item.name == M.current_mode and " (current)" or ""
        return item.label .. marker
    end, items), { prompt = "AI mode" }, function(_, idx)
        if not idx then
            return
        end
        local picked = items[idx].name
        M.apply_interaction_mode(picked)
        vim.notify("AI mode: " .. INTERACTION_MODES[picked].label, vim.log.levels.INFO)
    end)
end

local function sync_layout_from_sidebar(sidebar)
    local Config = require("avante.config")

    local function capture(container, key, config_section)
        if not container or not container.winid or not vim.api.nvim_win_is_valid(container.winid) then
            return
        end
        local height = vim.api.nvim_win_get_height(container.winid)
        M.layout[key] = height
        if config_section then
            Config.windows[config_section].height = height
        end
    end

    capture(sidebar.containers.input, "input", "input")
    capture(sidebar.containers.selected_files, "selected_files", "selected_files")
    save_state()
end

local function apply_saved_layout()
    local Config = require("avante.config")
    if M.layout.input then
        Config.windows.input.height = M.layout.input
    end
    if M.layout.selected_files then
        Config.windows.selected_files.height = M.layout.selected_files
    end
end

local function chosen_model_for_provider(provider_name)
    local Config = require("avante.config")
    local last_model, last_provider = Config.get_last_used_model(Config.providers)
    if not M.is_usable_model(last_model) then
        return nil
    end
    if last_provider and last_provider ~= provider_name then
        return nil
    end
    return last_model
end

local function resolve_provider_model(provider_name)
    local cfg = LOCAL_PROVIDERS[provider_name]
    if not cfg then
        return M.NO_MODEL_CHOSEN
    end

    local models = fetch_provider_models(provider_name, cfg)
    if #models == 0 then
        return M.NO_MODEL_LOADED
    end

    local chosen = chosen_model_for_provider(provider_name)
    if not chosen then
        return M.NO_MODEL_CHOSEN
    end

    if vim.tbl_contains(models, chosen) then
        return chosen
    end

    return M.NO_MODEL_LOADED
end

local function all_model_entries()
    local entries = {}
    for provider_name, cfg in pairs(LOCAL_PROVIDERS) do
        for _, model_id in ipairs(fetch_provider_models(provider_name, cfg)) do
            entries[#entries + 1] = {
                provider = provider_name,
                model = model_id,
                label = string.format("[%s] %s", cfg.label, model_id),
            }
        end
    end
    table.sort(entries, function(a, b)
        return a.label < b.label
    end)
    return entries
end

function M.list_all_model_entries()
    return all_model_entries()
end

function M.provider_alive(name)
    local cfg = LOCAL_PROVIDERS[name]
    return cfg and provider_online(cfg)
end

local function set_provider_model(provider_name, model_id, persist)
    local Config = require("avante.config")
    if Config.provider ~= provider_name then
        require("avante.api").switch_provider(provider_name)
    end

    Config.override({
        providers = {
            [provider_name] = vim.tbl_deep_extend(
                "force",
                Config.get_provider_config(provider_name),
                { model = model_id }
            ),
        },
    })

    local provider = require("avante.providers")[provider_name]
    if provider then
        provider.model = model_id
    end

    if persist and M.is_usable_model(model_id) then
        Config.save_last_model(model_id, provider_name)
    end
end

local function ensure_provider_model()
    local Config = require("avante.config")
    local provider_name = Config.provider
    local provider_cfg = Config.providers[provider_name]
    if not provider_cfg then
        return
    end

    local current = provider_cfg.model
    local resolved = resolve_provider_model(provider_name)

    if current == resolved then
        return
    end

    if M.is_usable_model(current) and resolved == M.NO_MODEL_CHOSEN then
        return
    end

    set_provider_model(provider_name, resolved, false)
end

function M.apply_model(provider_name, model_id)
    if not M.is_usable_model(model_id) then
        vim.notify("Invalid model selection", vim.log.levels.WARN)
        return
    end
    set_provider_model(provider_name, model_id, true)
    refresh_sidebar_header()
end

function M.refresh_provider_model()
    ensure_provider_model()
    refresh_sidebar_header()
end

local function patch_input_submit_keys()
    local Sidebar = require("avante.sidebar")
    if Sidebar._ai_input_submit_patched then
        return
    end
    Sidebar._ai_input_submit_patched = true

    local function insert_newline()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-j>", true, false, true), "n", true)
    end

    local orig_create = Sidebar.create_input_container
    function Sidebar:create_input_container()
        orig_create(self)
        local input = self.containers.input
        if not input or not input.bufnr or not vim.api.nvim_buf_is_valid(input.bufnr) then
            return
        end

        local function on_submit()
            self:submit_input()
        end

        input:map("i", "<CR>", function()
            local cmp = require("cmp")
            if cmp.visible() then
                cmp.confirm({ select = true })
            else
                on_submit()
            end
        end, { noremap = true }, true)

        input:map("i", "<S-CR>", insert_newline, { noremap = true }, true)
    end
end

local function patch_sidebar_layout()
    local Sidebar = require("avante.sidebar")
    if Sidebar._ai_layout_patched then
        return
    end
    Sidebar._ai_layout_patched = true

    local orig_adjust = Sidebar.adjust_layout
    function Sidebar:adjust_layout()
        apply_saved_layout()
        orig_adjust(self)
    end

    local orig_files_height = Sidebar.get_selected_files_container_height
    function Sidebar:get_selected_files_container_height()
        local saved = M.layout.selected_files
        if saved then
            return math.max(saved, orig_files_height(self))
        end
        return orig_files_height(self)
    end

    local orig_render_header = Sidebar.render_header
    function Sidebar:render_header(winid, bufnr, header_text, hl, reverse_hl, opts)
        if opts and opts.include_model then
            ensure_provider_model()
        end
        orig_render_header(self, winid, bufnr, header_text, hl, reverse_hl, opts)
        if not (opts and opts.include_model) then
            return
        end
        if not self.containers.result or winid ~= self.containers.result.winid then
            return
        end
        local mode_label = M.get_mode_label()
        local winbar = vim.api.nvim_get_option_value("winbar", { win = winid })
        vim.api.nvim_set_option_value("winbar", winbar .. " | " .. mode_label, { win = winid })
    end

    local orig_submit_input = Sidebar.submit_input
    function Sidebar:submit_input()
        local Config = require("avante.config")
        local model = Config.providers[Config.provider] and Config.providers[Config.provider].model
        if M.is_placeholder_model(model) then
            if model == M.NO_MODEL_CHOSEN then
                vim.notify("No model chosen. Pick one with <leader>a?", vim.log.levels.WARN)
                M.open_model_picker()
            else
                local Config = require("avante.config")
                vim.notify(
                    "No model loaded. " .. unloaded_hint(Config.provider),
                    vim.log.levels.WARN
                )
            end
            return
        end
        orig_submit_input(self)
    end
end

function M.open_model_picker()
    local entries = all_model_entries()
    if #entries == 0 then
        local Config = require("avante.config")
        set_provider_model(Config.provider, M.NO_MODEL_LOADED, false)
        refresh_sidebar_header()
        vim.notify(
            "No models online.\n" .. M.cursor_setup_message(),
            vim.log.levels.WARN
        )
        return
    end

    notify_cursor_setup_if_missing(entries)

    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    pickers.new({}, {
        prompt_title = "AI models",
        finder = finders.new_table({
            results = entries,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.label,
                    ordinal = entry.label,
                }
            end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(bufnr, _)
            actions.select_default:replace(function()
                local entry = action_state.get_selected_entry()
                if not entry then
                    return
                end
                actions.close(bufnr)
                M.apply_model(entry.value.provider, entry.value.model)
                vim.notify("Model: " .. entry.value.label, vim.log.levels.INFO)
            end)
            return true
        end,
    }):find()
end

function M.pick_provider()
    local items = {}
    for name, cfg in pairs(LOCAL_PROVIDERS) do
        items[#items + 1] = {
            name = name,
            label = string.format("%s (%s)", cfg.label, provider_online(cfg) and "online" or "offline"),
        }
    end
    table.sort(items, function(a, b)
        return a.name < b.name
    end)

    vim.ui.select(vim.tbl_map(function(item)
        return item.label
    end, items), { prompt = "AI provider" }, function(_, idx)
        if not idx then
            return
        end
        local provider = items[idx].name
        require("avante.api").switch_provider(provider)
        M.refresh_provider_model()
        vim.notify("AI provider: " .. LOCAL_PROVIDERS[provider].label, vim.log.levels.INFO)
    end)
end

function M.setup()
    load_state()
    apply_saved_layout()
    patch_sidebar_layout()
    patch_input_submit_keys()

    require("avante.api").select_model = M.open_model_picker
    require("avante.model_selector").open = M.open_model_picker

    vim.api.nvim_create_user_command("AvanteModels", function()
        M.open_model_picker()
    end, { force = true, desc = "Select AI model" })

    vim.api.nvim_create_user_command("AvanteModes", function()
        M.open_mode_picker()
    end, { force = true, desc = "Select AI interaction mode" })

    vim.api.nvim_create_user_command("AvanteCursorSetup", function()
        vim.notify(M.cursor_setup_message(), vim.log.levels.INFO)
    end, { force = true, desc = "Cursor AI setup instructions" })

    local layout_group = vim.api.nvim_create_augroup("ai_avante_layout", { clear = true })
    vim.api.nvim_create_autocmd("WinResized", {
        group = layout_group,
        callback = function()
            local sidebar = require("avante").get()
            if not sidebar or not sidebar:is_open() then
                return
            end
            sync_layout_from_sidebar(sidebar)
        end,
    })

    vim.api.nvim_create_autocmd("FocusGained", {
        group = layout_group,
        callback = function()
            local sidebar = require("avante").get()
            if sidebar and sidebar:is_open() then
                M.refresh_provider_model()
            end
        end,
    })

    ensure_provider_model()
    M.apply_interaction_mode(M.current_mode)
end

local function local_provider(cfg, provider_name)
    local provider = {
        __inherited_from = "openai",
        endpoint = cfg.endpoint,
        api_key_name = cfg.api_key_name or "",
        timeout = cfg.timeout or 120000,
        hide_in_model_selector = false,
        is_env_set = function()
            return provider_online(cfg)
        end,
        list_models = function()
            return vim.tbl_map(function(model_id)
                return {
                    id = model_id,
                    name = provider_name .. "/" .. model_id,
                    display_name = string.format("[%s] %s", cfg.label, model_id),
                }
            end, fetch_provider_models(provider_name, cfg))
        end,
        extra_request_body = vim.tbl_extend("force", {
            temperature = 0.2,
            max_tokens = 8192,
        }, cfg.extra_request_body or {}),
    }

    if cfg.api_key then
        provider.api_key = cfg.api_key
        provider.api_key_name = ""
        provider.parse_api_key = function()
            return cfg.api_key
        end
    end

    return provider
end

function M.opts()
    load_state()

    local providers = {}

    for name, cfg in pairs(LOCAL_PROVIDERS) do
        providers[name] = local_provider(cfg, name)
    end

    for _, name in ipairs(HIDDEN_PROVIDERS) do
        providers[name] = {
            hide_in_model_selector = true,
            is_env_set = function()
                return false
            end,
        }
    end

    return {
        provider = vim.env.AVANTE_PROVIDER or "lmstudio",
        mode = "agentic",
        instructions_file = "avante.md",
        providers = providers,
        selector = {
            provider = "telescope",
            exclude_auto_select = { "terminal", "help", "qf", "lazy", "Avante", "AvanteInput" },
        },
        behaviour = {
            auto_suggestions = false,
            auto_set_keymaps = true,
            auto_apply_diff_after_generation = false,
            auto_approve_tool_permissions = true,
            auto_add_current_file = false,
            enable_token_counting = false,
            minimize_diff = true,
        },
        mappings = {
            submit = {
                normal = "<CR>",
                insert = "<CR>",
            },
        },
        windows = {
            position = "right",
            width = 35,
            sidebar_header = {
                enabled = true,
                align = "left",
                rounded = true,
                include_model = true,
            },
            input = {
                height = M.layout.input or 8,
            },
            selected_files = {
                height = M.layout.selected_files or 6,
            },
        },
    }
end

return M
