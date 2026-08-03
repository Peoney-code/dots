local M = {}

function M.setup()
    local dap = require("dap")
    local dapui = require("dapui")

    require("mason-nvim-dap").setup({
        ensure_installed = { "cppdbg", "codelldb", "delve" },
        automatic_installation = true,
    })

    dapui.setup({
        icons = { expanded = "▾", collapsed = "▸", current_frame = "▸" },
        floating = { border = "rounded" },
        layouts = {
            {
                elements = {
                    { id = "scopes", size = 0.25 },
                    { id = "breakpoints", size = 0.25 },
                    { id = "stacks", size = 0.25 },
                    { id = "watches", size = 0.25 },
                },
                size = 0.33,
                position = "left",
            },
            {
                elements = {
                    { id = "repl", size = 0.5 },
                    { id = "console", size = 0.5 },
                },
                size = 0.27,
                position = "bottom",
            },
        },
    })

    require("nvim-dap-virtual-text").setup({
        enabled = true,
        enabled_commands = true,
        highlight_changed_variables = true,
        highlight_new_keys = true,
        show_stop_reason = true,
        virt_text_pos = "eol",
    })

  -- Auto-open UI when a session starts; close when it ends
    local function open_debug_ui()
        dapui.open({ reset = true })
    end

    dap.listeners.after.event_initialized["dapui"] = open_debug_ui
    dap.listeners.after.event_terminated["dapui"] = function()
        dapui.close()
    end
    dap.listeners.after.event_exited["dapui"] = function()
        dapui.close()
    end

    -- .vscode/launch.json is loaded automatically (see :help dap-providers)

    local pick_process = require("dap.utils").pick_process
    local pick_executable = function(default)
        return vim.fn.input("Path to executable: ", default or "", "file")
    end
    local pick_address = function(default)
        return vim.fn.input("Remote address (host:port): ", default or "localhost:2345", "file")
    end

    -- C++ (cppdbg: GDB / LLDB, local + gdbserver remote)
    dap.configurations.cpp = {
        {
            name = "Launch (cppdbg)",
            type = "cppdbg",
            request = "launch",
            program = function()
                return pick_executable(vim.fn.getcwd() .. "/")
            end,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
        },
        {
            name = "Attach to process",
            type = "cppdbg",
            request = "attach",
            processId = pick_process,
            cwd = "${workspaceFolder}",
        },
        {
            name = "Attach remote (gdbserver)",
            type = "cppdbg",
            request = "attach",
            program = function()
                return pick_executable(vim.fn.getcwd() .. "/")
            end,
            cwd = "${workspaceFolder}",
            MIMode = "gdb",
            miDebuggerServerAddress = function()
                return pick_address("localhost:2345")
            end,
            setupCommands = {
                {
                    text = "-enable-pretty-printing",
                    description = "enable pretty printing",
                    ignoreFailures = true,
                },
            },
        },
    }
    dap.configurations.c = dap.configurations.cpp

    -- Rust (CodeLLDB)
    dap.configurations.rust = {
        {
            name = "Launch (codelldb)",
            type = "codelldb",
            request = "launch",
            program = function()
                return pick_executable(vim.fn.getcwd() .. "/target/debug/")
            end,
            cwd = "${workspaceFolder}",
            stopOnEntry = false,
        },
        {
            name = "Attach to process",
            type = "codelldb",
            request = "attach",
            pid = pick_process,
        },
        {
            name = "Attach remote (lldb-server)",
            type = "codelldb",
            request = "attach",
            pid = pick_process,
            initCommands = function()
                local address = pick_address("localhost:1234")
                return {
                    "platform select remote-linux",
                    "platform connect connect://" .. address,
                }
            end,
        },
    }

    -- Go (delve)
    dap.configurations.go = {
        {
            name = "Debug package",
            type = "go",
            request = "launch",
            mode = "debug",
            program = "${fileDirname}",
        },
        {
            name = "Debug file",
            type = "go",
            request = "launch",
            mode = "debug",
            program = "${file}",
        },
        {
            name = "Debug test",
            type = "go",
            request = "launch",
            mode = "test",
            program = "${fileDirname}",
        },
        {
            name = "Attach remote (delve)",
            type = "go",
            request = "attach",
            mode = "remote",
            host = function()
                return vim.fn.input("Remote host: ", "127.0.0.1", "file")
            end,
            port = function()
                return tonumber(vim.fn.input("Remote port: ", "2345", "file"))
            end,
        },
    }
end

return M
