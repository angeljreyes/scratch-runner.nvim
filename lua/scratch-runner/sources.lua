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

---Checks if a given `node --version` string is >= v22.6.0
---@param version string The output from `node --version` (e.g., "v22.6.0")
---@return boolean # `true` if >= 22.6.0, false otherwise
H.is_node_22_6_or_newer = function(version)
    if type(version) ~= "string" then
        return false
    end

    -- Clean the string: strip leading 'v', trim whitespace, remove pre-release tags (e.g., "-rc.1")
    local cleaned = version:gsub("%s+", ""):gsub("^v", ""):gsub("%-.*$", "")

    local parts = vim.split(cleaned, "%.")
    local major = tonumber(parts[1]) or 0
    local minor = tonumber(parts[2]) or 0
    local patch = tonumber(parts[3]) or 0

    if major > 22 then
        return true
    elseif major == 22 then
        if minor > 6 then
            return true
        elseif minor == 6 then
            return patch >= 0
        end
    end

    return false
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
    d = {
        H.make_command_with(
            { "dmd", "gdc", "ldc" },
            function(command, file_path, bin_path)
                return { command, file_path, "-o", bin_path }
            end
        ),
        binary = true,
        file_name = "scratch",
    },
    dart = { { "dart" } },
    dosbatch = {
        { "cmd", "/c" },
        extension = "bat",
    },
    erlang = { { "escript" } },
    fortran = {
        H.make_command_with(
            { "gfortran", "flang", "flang-new", "ifx" },
            function(command, file_path, bin_path)
                return { command, file_path, "-o", bin_path }
            end
        ),
        extension = "F90",
        binary = true,
    },
    fsharp = { { "dotnet", "fsi" }, extension = "fsx" },
    go = { { "go", "run" } },
    groovy = { { "groovy" } },
    haskell = { { "runghc" } },
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
    julia = { { "julia" } },
    nim = {
        { "nim", "r", "--verbosity:0" },
        file_name = "scratch",
    },
    lisp = {
        H.make_command_with({ "sbcl", "ecl", "clisp" }, function(command, file_path)
            if command == "sbcl" then
                return { command, "--script", file_path }
            elseif command == "ecl" then
                return { command, "--shell", file_path }
            else
                return { command, file_path }
            end
        end),
    },
    mojo = { { "mojo", "run" } },
    ocaml = { { "ocaml" } },
    pascal = {
        function(file_path, bin_path)
            return { "fpc", file_path, "-o" .. bin_path }
        end,
        binary = true,
    },
    perl = { { "perl" }, extension = "pl" },
    php = { { "php" } },
    ps1 = {
        H.make_command_with(
            { "powershell", "pwsh" },
            function(command, file_path) return { command, "-ExecutionPolicy", "ByPass", "-File", file_path } end
        ),
    },
    python = {
        H.make_command_with(
            { "python3", "python", "py", "pypy3" },
            function(command, file_path) return { command, file_path } end
        ),
        extension = "py",
    },
    r = { { "Rscript" } },
    racket = { { "racket" } },
    ruby = {
        { "ruby" },
        extension = "rb",
    },
    rust = {
        function(filepath, bin_path) return { "rustc", filepath, "-o", bin_path } end,
        extension = "rs",
        binary = true,
    },
    scala = {
        H.make_command_with(
            { "scala-cli", "scala" },
            function(command, file_path)
                return command == "scala-cli" and { command, "run", file_path } or { command, file_path }
            end
        ),
    },
    scheme = {
        H.make_command_with(
            { "scheme",  "csi", "chicken-csi", "guile" },
            function(command, file_path)
                if command == "scheme" then
                    return { command, "--script", file_path }
                elseif command == "csi" or command == "chicken-csi" then
                    return { command, "-script", file_path }
                else
                    return { command, "--auto-compile", "--fresh-auto-compile", "--no-debug", "-s", file_path }
                end
            end
        )
    },
    sh = { { "sh" } },
    sml = {
        function(file_path, bin_path) return { "mlton", "-output", bin_path, file_path } end,
        extension = "sml",
        binary = true,
    },
    swift = { { "swift" } },
    typescript = {
        H.make_command_with({ "deno", "bun", "node" }, function(command, file_path)
            if command ~= "node" then
                return { command, file_path }
            end

            local node_version = vim.system({ "node", "--version" }):wait(5000).stdout
            if node_version and H.is_node_22_6_or_newer(node_version) then
                return { command, file_path }
            elseif vim.fn.executable("npm") then
                local has_tsx = vim.system({ "npm", "list", "-g", "tsx" }):wait(5000).code == 0
                if has_tsx then
                    return { "npm", "exec", "tsx", file_path }
                end
            end

            util.notify_error(
                "In order to execute a TypeScript file you need either deno, bun,"
                    .. " node >= 22.6 or node with the tsx package installed globally."
            )
            return {}
        end),
        extension = "ts",
    },
    v = { { "v", "run" } },
    vb = {
        { "cscript", "//Nologo" },
        extension = "vbs",
    },
    winbatch = {
        { "cmd", "/c" },
        extension = "bat",
    },
    zig = { { "zig", "run" } },
    zsh = { { "zsh" } },
}
