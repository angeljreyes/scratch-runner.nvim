---@module "snacks"

local M = {}
local H = {}

---@class scratch-runner.Source 
---@field [1] scratch-runner.SourceCommand
---@field extension? string
---@field binary? boolean

---@alias scratch-runner.SourceCommand
---| string[]
---| (fun(file_path: string, bin_path: string): string[])
---| (fun(file_path: string, bin_path: string): string[][])

M.tmp_dir = vim.fs.joinpath(vim.fn.stdpath("cache") --[[@as string]], "scratch-runner")

---@class scratch-runner.Config
H.config = {
    ---Key that runs the scratch buffer.
    ---@type string?
    run_key = "<CR>",

    ---Key that switches between stdout and stderr.
    ---@type string?
    output_switch_key = "<Tab>",

    ---Commands that run your script. See :h scratch-runner.Source
    ---@type table<string, scratch-runner.Source | scratch-runner.SourceCommand>
    sources = {},
}

---@param opts scratch-runner.Config?
M.setup = function(opts)
    H.config = vim.tbl_deep_extend("force", H.config, opts or {})

    if not vim.tbl_isempty(H.config.sources) then
        local win_by_ft = H.make_win_by_ft(H.config.sources)
        Snacks.config.scratch.win_by_ft = vim.tbl_deep_extend("force", Snacks.config.scratch.win_by_ft or {}, win_by_ft)
    end
end

---Makes a keymap that runs your code.
---@param source scratch-runner.Source Command to run the file through.
---@return snacks.win.Keys
H.make_key = function(source)
    source.binary = source.binary ~= nil and source.binary or false
    return {
        H.config.run_key,
        ---@param window snacks.win
        function(window)
            vim.cmd("silent w")

            local file_path = vim.api.nvim_buf_get_name(window.buf)

            if source.extension then
                local new_file_path = vim.fs.joinpath(M.tmp_dir, "scratch." .. source.extension)
                vim.fn.mkdir(M.tmp_dir, "p")
                local success, err, err_name = vim.uv.fs_copyfile(file_path, new_file_path)
                if not success then
                    vim.notify(
                        "There was an error '" .. err_name .. "' copying the file: " .. err,
                        vim.log.levels.ERROR,
                        { title = "scratch-runner.nvim" }
                    )
                    return
                end
                file_path = new_file_path
            end

            local bin_path = vim.fn.fnamemodify(file_path, ":r")
            local pipeline = H.resolve_source(source, file_path, bin_path)

            for _, command in ipairs(pipeline) do
                if vim.fn.executable(command[1]) == 0 then
                    vim.notify(
                        "'" .. command[1] .. "' wasn't found on your system.",
                        vim.log.levels.ERROR,
                        { title = "scratch-runner.nvim" }
                    )
                    return
                end
            end

            if source.binary then
                table.insert(pipeline, { bin_path })
            end

            H.result_window = Snacks.win({
                style = "scratch",
                height = Snacks.config.scratch.win.height,
                width = Snacks.config.scratch.win.width --[[@as number]],
                zindex = 30,
                title = " Running... ",
                ft = "text",
                bo = { filetype = "text", modifiable = false, buftype = "", bufhidden = "hide", swapfile = false },
                keys = { q = "close" },
            })

            H.run_commands(pipeline)
        end,
        desc = "Run buffer",
    }
end

---@param pipeline string[][] Commands to run.
H.run_commands = function(pipeline)
    -- I had to do some functional-style recursive immutable thingy
    -- in order to allow the commands to run asynchronously.
    local next_cmd = function()
        if pipeline[2] ~= nil then
            H.run_commands(vim.list_slice(pipeline, 2))
        end
    end
    H.run_command(pipeline[1], pipeline[2] == nil, next_cmd)
end

---@param command string[]
---@param show_output boolean
---@param next_cmd fun()
H.run_command = function(command, show_output, next_cmd)
    ---@param lhs string
    ---@param desc string
    local footer_insert_key = function(lhs, desc)
        table.insert(H.result_window.opts.footer, { " " })
        table.insert(H.result_window.opts.footer, { " " .. lhs .. " ", "SnacksScratchKey" })
        table.insert(H.result_window.opts.footer, { " " .. desc .. " ", "SnacksScratchDesc" })
    end

    local footer_add_close = function() footer_insert_key("q", "Go back") end
    local running = true
    local killed = false

    local process = vim.system(
        command,
        show_output and { text = true } or { text = true, stdout = false },
        vim.schedule_wrap(function(output)
            running = false
            if killed then
                return false
            end

            local has_errored = output.code ~= 0

            local stdout, stderr
            if output.stdout and output.stdout ~= "" then
                stdout = vim.split(output.stdout, "\n")
            end
            if output.stderr and output.stderr ~= "" and (show_output or has_errored) then
                stderr = vim.split(output.stderr, "\n")
            end

            vim.bo[H.result_window.buf].modifiable = true
            vim.api.nvim_buf_set_lines(H.result_window.buf, 0, -1, false, stdout or stderr or { "" })
            vim.bo[H.result_window.buf].modifiable = false
            if not stdout and stderr then
                H.result_window.opts.title = {
                    { " " },
                    { " ", "Error" },
                    { " Code Output " },
                }
                H.result_window.opts.footer = {}
                footer_add_close()
            elseif stdout and stderr then
                local showing_stderr = false
                H.result_window.opts.title = {
                    { " " },
                    { " ", "WarningMsg" },
                    { " Code Output " },
                }
                H.result_window.opts.footer = {}
                footer_insert_key(H.config.output_switch_key, "Show stderr")
                footer_add_close()
                vim.keymap.set("n", H.config.output_switch_key, function()
                    H.result_window.opts.footer = {}
                    vim.bo[H.result_window.buf].modifiable = true
                    if showing_stderr then
                        vim.api.nvim_buf_set_lines(H.result_window.buf, 0, -1, false, stdout)
                        footer_insert_key(H.config.output_switch_key, "Show stderr")
                    else
                        vim.api.nvim_buf_set_lines(H.result_window.buf, 0, -1, false, stderr)
                        footer_insert_key(H.config.output_switch_key, "Show stdout")
                    end
                    vim.bo[H.result_window.buf].modifiable = false
                    footer_add_close()
                    showing_stderr = not showing_stderr
                    H.result_window:update()
                end, { desc = "Show stdout/stderr", buffer = H.result_window.buf })
            else
                H.result_window.opts.title = {
                    { " " },
                    { " ", "Added" },
                    { " Code Output " },
                }
                H.result_window.opts.footer = {}
                footer_add_close()
            end
            H.result_window:update()
            if output.code == 0 then
                next_cmd()
            end
        end)
    )

    vim.keymap.set("n", "q", function()
        if running then
            process:kill(15)
            killed = true
        end
        H.result_window:close()
    end, { desc = "Cancel", buffer = H.result_window.buf })

    H.result_window.opts.footer = {}
    footer_insert_key("q", "Stop")
    H.result_window:update()
end

---Make the `win_by_ft` option.
---@param sources table<string, scratch-runner.Source | scratch-runner.SourceCommand> Filetypes as keys, cmds as values.
---@return table<string, snacks.win.Config>
H.make_win_by_ft = function(sources)
    ---@type table<string, snacks.win.Config>
    local win_by_ft = {}

    for ft, source in pairs(sources) do
        local normalized = H.normalize_source(source)

        ---@diagnostic disable-next-line: missing-fields
        win_by_ft[ft] = { keys = { run = H.make_key(normalized) } }
    end

    return win_by_ft
end

---@param source scratch-runner.Source
---@param file_path string
---@param bin_path string
---@return string[][]
H.resolve_source = function(source, file_path, bin_path)
    ---@type string[][]
    local pipeline

    vim.validate({
        cmd = { source, "table" },
        ["source[1]"] = { source[1], { "table", "function" } },
    })

    local one = source[1]
    if type(one) == "table" then
        vim.validate({
            ["source[1][1]"] = { source[1][1], "string" },
        })
        table.insert(one, file_path)
        pipeline = { one }
    else
        local result = one(file_path, bin_path)
        vim.validate({
            ["source[1]()"] = { result, "table" }
        })
        local result_one = result[1]
        vim.validate({
            ["source[1]()[1]"] = { result_one, { "string", "table" } }
        })
        if type(result_one) == "string" then
            pipeline = { result }
        else
            vim.validate({
                ["source[1]()[1][1]"] = { result_one[1], "string" }
            })
            pipeline = result
        end
    end

    return pipeline
end

---@param source scratch-runner.Source | scratch-runner.SourceCommand
---@return scratch-runner.Source
H.normalize_source = function(source)
    local normalized

    if type(source) == "function" then
        normalized = { source }
    elseif type(source) == "table" then
        if type(source[1]) == "string" then
            normalized = { source }
        elseif type(source[1]) == "table" or type(source[1]) == "function" then
            normalized = source
        else
            error("") -- TODO:
        end
    end

    return normalized
end

return M
