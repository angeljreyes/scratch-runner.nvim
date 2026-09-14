local util = require("scratch-runner.util")
local H = {}

---Returns the first command that is found in the OS or `nil` if none
---was found.
---@generic T : string
---@param commands [T, ...] List of commands to search
---@return T?
H.get_first_available = function(commands)
    for _, command in ipairs(commands) do
        if vim.fn.executable(command) == 1 then
            return command
        end
    end

    return nil
end

---Returns a `SourceCommand` that attempts to use the first command in
---`commands` that is found in the OS, and notifies the user with an
---error if no command was found.
---@generic T : string
---@param commands [T, ...]
---@param callback fun(command: T, file_path: string, bin_path: string): string[] | string[][]
---@return scratch-runner.SourceCommand
H.make_command_with = function(commands, callback)
    ---@param file_path string
    ---@param bin_path string
    ---@return string[]
    return function(file_path, bin_path)
        local command = H.get_first_available(commands)
        if command == nil then
            local list = table.concat(commands, ", ")
            util.notify_error("In order to run a script of this filetype you need one of these programs: " .. list)
            return {}
        end
        return callback(command, file_path, bin_path)
    end
end

---@type table<string, scratch-runner.Source>
return {
    bash = { { "bash" } },
    c = {
        H.make_command_with(
            { "gcc", "clang" },
            function(command, file_path, bin_path) return { command, file_path, "-o", bin_path } end
        ),
        binary = true,
    },
    clojure = {
        H.make_command_with(
            { "bb", "clojure", "lein" },
            function(command, file_path)
                if command == "bb" then
                    return { command, file_path }
                elseif command == "clojure" then
                    return { command, "-M", file_path }
                else
                    return { command, "exec", file_path }
                end
            end
        )
    },
    cpp = {
        H.make_command_with(
            { "g++", "clang++" },
            function(command, file_path, bin_path) return { command, file_path, "-o", bin_path } end
        ),
        binary = true,
    },
    crystal = { { "crystal" } },
    cs = {
        function(file_path)
            if vim.fn.executable("dotnet") then
                local dotnet_version = vim.system({ "dotnet", "--version" }):wait(5000).stdout
                -- If dotnet version is >= 10 (if major has 2 digits or more)
                if dotnet_version and dotnet_version:match("^%d%d") then
                    return { "dotnet", "run", file_path }
                end
            end

            if vim.fn.executable("dotnet-script") then
                return { "dotnet-script", file_path }
            end

            util.notify_error("In order to run a C# script you need either dotnet >= 10, or the dotnet-script tool.")
            return {}
        end,
    },
    dart = { { "dart" } },
    dosbatch = {
        { "cmd", "/c" },
        extension = "bat",
    },
    fsharp = { { "dotnet", "fsi" }, extension = "fsx" },
    go = { { "go", "run" } },
    groovy = { { "groovy" } },
    html = {
        function(file_path)
            vim.ui.open(file_path)
            return {}
        end
    },
    java = { { "java" } },
    javascript = {
        H.make_command_with({ "deno", "bun", "node" }, function(command, file_path) return { command, file_path } end),
        extension = "js",
    },
}
