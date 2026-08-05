local M = {}

-- AVANTE_PROVIDER=lmstudio|ollama  (default: lmstudio)
M.provider = vim.env.AVANTE_PROVIDER or "lmstudio"

local saved_model_path = vim.fs.joinpath(vim.fn.expand("~"), ".config", "avante.nvim", "config.json")

local function endpoint_alive(url)
    local ok, result = pcall(function()
        return vim.system({ "curl", "-sf", url }, { timeout = 2000 }):wait()
    end)
    return ok and result and result.code == 0
end

function M.lmstudio_alive()
    return endpoint_alive("http://127.0.0.1:1234/v1/models")
end

function M.ollama_alive()
    return endpoint_alive("http://127.0.0.1:11434/api/tags")
end

function M.provider_alive(name)
    if name == "ollama" then
        return M.ollama_alive()
    end
    return M.lmstudio_alive()
end

--- Explicit override via env; otherwise rely on avante's saved model file.
function M.env_model()
    local model = vim.env.AVANTE_MODEL
    if model and model ~= "" then
        return model
    end
end

function M.has_saved_model()
    local file = io.open(saved_model_path, "r")
    if not file then
        return false
    end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then
        return false
    end
    local ok, data = pcall(vim.json.decode, content)
    return ok and data and data.last_model and data.last_model ~= ""
end

function M.open_model_picker()
    require("avante.model_selector").open()
end

function M.maybe_prompt_model()
    if M.env_model() or M.has_saved_model() then
        return
    end

    if not M.provider_alive(M.provider) then
        vim.notify(
            "AI: запусти LM Studio (порт 1234) или Ollama, затем :AvanteModels",
            vim.log.levels.WARN
        )
        return
    end

    M.open_model_picker()
end

function M.post_setup()
    vim.defer_fn(M.maybe_prompt_model, 200)
end

function M.provider_opts(name)
    local opts = {
        timeout = 120000,
        is_env_set = function()
            return M.provider_alive(name)
        end,
        hide_in_model_selector = M.provider ~= name,
    }

    local model = M.env_model()
    if model then
        opts.model = model
    end

    if name == "lmstudio" then
        return vim.tbl_extend("force", opts, {
            __inherited_from = "openai",
            endpoint = "http://127.0.0.1:1234/v1",
            api_key_name = "",
            extra_request_body = {
                temperature = 0.2,
                max_tokens = 8192,
            },
        })
    end

    return vim.tbl_extend("force", opts, {
        endpoint = "http://127.0.0.1:11434",
        extra_request_body = {
            options = {
                temperature = 0.2,
                num_ctx = 32768,
                keep_alive = "5m",
            },
        },
    })
end

function M.opts()
    return {
        provider = M.provider,
        mode = "agentic",
        instructions_file = "avante.md",
        providers = {
            lmstudio = M.provider_opts("lmstudio"),
            ollama = M.provider_opts("ollama"),
        },
        behaviour = {
            auto_suggestions = false,
            auto_set_keymaps = true,
            auto_apply_diff_after_generation = false,
            auto_approve_tool_permissions = true,
            auto_add_current_file = true,
            minimize_diff = true,
        },
        windows = {
            position = "right",
            width = 35,
        },
    }
end

return M
