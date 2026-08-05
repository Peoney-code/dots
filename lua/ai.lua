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
}

local HIDDEN_PROVIDERS = {
    "openai", "claude", "azure", "gemini", "vertex", "vertex_claude",
    "copilot", "bedrock", "ollama", "cohere", "mistral", "watsonx_code_assistant",
}

local function fetch_models_result(cfg)
    local cmd = { "curl", "-sf", cfg.models_url }
    if cfg.api_key_name then
        local key = vim.env[cfg.api_key_name]
        if key and key ~= "" then
            cmd[#cmd + 1] = "-H"
            cmd[#cmd + 1] = "Authorization: Bearer " .. key
        end
    end

    local ok, result = pcall(function()
        return vim.system(cmd, { timeout = 5000 }):wait()
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

local function fetch_models(cfg)
    local result = fetch_models_result(cfg)
    return result.models
end

local function provider_online(cfg)
    return #fetch_models(cfg) > 0
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

    local status = fetch_models_result(cfg)
    if not status.online or #status.models == 0 then
        return M.NO_MODEL_LOADED
    end

    local chosen = chosen_model_for_provider(provider_name)
    if not chosen then
        return M.NO_MODEL_CHOSEN
    end

    if vim.tbl_contains(status.models, chosen) then
        return chosen
    end

    return M.NO_MODEL_LOADED
end

local function all_model_entries()
    local entries = {}
    for provider_name, cfg in pairs(LOCAL_PROVIDERS) do
        for _, model_id in ipairs(fetch_models(cfg)) do
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
                vim.notify(
                    "No model loaded. Start LM Studio / Unsloth and load a model, then retry.",
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
            "No models online. Start LM Studio (1234) or Unsloth, then retry.",
            vim.log.levels.WARN
        )
        return
    end

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

    require("avante.api").select_model = M.open_model_picker

    vim.api.nvim_create_user_command("AvanteModels", function()
        M.open_model_picker()
    end, { force = true, desc = "Select AI model" })

    vim.api.nvim_create_user_command("AvanteModes", function()
        M.open_mode_picker()
    end, { force = true, desc = "Select AI interaction mode" })

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

local function local_provider(cfg)
    return {
        __inherited_from = "openai",
        endpoint = cfg.endpoint,
        api_key_name = cfg.api_key_name or "",
        timeout = 120000,
        hide_in_model_selector = true,
        is_env_set = function()
            return provider_online(cfg)
        end,
        extra_request_body = {
            temperature = 0.2,
            max_tokens = 8192,
        },
    }
end

function M.opts()
    load_state()

    local providers = {}

    for name, cfg in pairs(LOCAL_PROVIDERS) do
        providers[name] = local_provider(cfg)
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
