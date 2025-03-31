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

---@param message string
---@param level vim.log.levels
---@param opts? table
H.notify = function(message, level, opts)
    opts = vim.tbl_deep_extend("force", opts or {}, { title = "scratch-runner.nvim" })
    vim.notify(message, level, opts)
end

---@param message string
---@param opts? table
H.notify_info = function(message, opts) H.notify(message, vim.log.levels.INFO, opts) end

---@param message string
---@param opts? table
H.notify_warn = function(message, opts) H.notify(message, vim.log.levels.WARN, opts) end

---@param message string
---@param opts? table
H.notify_error = function(message, opts) H.notify(message, vim.log.levels.ERROR, opts) end

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
            local in_visual_mode = vim.fn.mode():find("[Vv]")

            if source.extension or in_visual_mode then
                local extension = source.extension or vim.fn.fnamemodify(file_path, ":e")
                local new_file_path = vim.fs.joinpath(M.tmp_dir, "scratch." .. extension)
                vim.fn.mkdir(M.tmp_dir, "p")
                if in_visual_mode then
                    local selection = H.get_visual_selection(window.buf)
                    local file = io.open(new_file_path, "w")
                    if file == nil then
                        H.notify_error("Could not open file " .. new_file_path)
                        return
                    end
                    file:write(vim.fn.join(selection, "\n"))
                    file:close()
                else
                    local success, err, err_name = vim.uv.fs_copyfile(file_path, new_file_path)
                    if not success then
                        H.notify_error("There was an error '" .. err_name .. "' copying the file: " .. err)
                        return
                    end
                end
                file_path = new_file_path
            end

            local bin_path = vim.fn.fnamemodify(file_path, ":r")
            local pipeline = H.resolve_source(source, file_path, bin_path)

            for _, command in ipairs(pipeline) do
                if vim.fn.executable(command[1]) == 0 then
                    H.notify_error("'" .. command[1] .. "' wasn't found on your system.")
                    return
                end
            end

            if source.binary then
                table.insert(pipeline, { bin_path })
            end

            local win_config = {
                style = "scratch",
                zindex = 30,
                title = " Running... ",
                ft = "text",
                bo = { filetype = "text", modifiable = false, buftype = "", bufhidden = "hide", swapfile = false },
                keys = { q = "close" },
            }
            local scratch_user_config = Snacks.config.scratch.win

            win_config = vim.tbl_extend("keep", win_config, scratch_user_config or {})

            H.result_window = Snacks.win(win_config)
            H.run_commands(pipeline)
        end,
        desc = "Run buffer",
        mode = { "n", "x" },
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
        local normalized = H.normalize_source(source, ft)

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
            ["source[1]()"] = { result, "table" },
        })
        local result_one = result[1]
        vim.validate({
            ["source[1]()[1]"] = { result_one, { "string", "table" } },
        })
        if type(result_one) == "string" then
            pipeline = { result }
        else
            vim.validate({
                ["source[1]()[1][1]"] = { result_one[1], "string" },
            })
            pipeline = result
        end
    end

    return pipeline
end

---@param source scratch-runner.Source | scratch-runner.SourceCommand
---@param ft string
---@return scratch-runner.Source
H.normalize_source = function(source, ft)
    local normalized

    if type(source) == "function" then
        normalized = { source }
    elseif type(source) == "table" then
        if type(source[1]) == "string" then
            normalized = { source }
        elseif type(source[1]) == "table" or type(source[1]) == "function" then
            normalized = source
        else
            H.notify_error(
                "Source for filetype '" .. ft .. "' is incorrect.\nSee `:h scratch-runner.Source` to fix this."
            )
        end
    end

    return normalized
end

---@param bufnr integer
---@return string[]
H.get_visual_selection = function(bufnr)
    -- I just copy-pasterinoed this function from
    -- snacks.nvim/lua/snacks/debug.lua because it turns out copying
    -- text in visual selection is more complicated than it should
    -- and I just want this to work.

    local lines ---@type string[]
    local mode = vim.fn.mode()

    if mode == "v" then
        vim.cmd("normal! v")
    elseif mode == "V" then
        vim.cmd("normal! V")
    end

    local from = vim.api.nvim_buf_get_mark(bufnr, "<")
    local to = vim.api.nvim_buf_get_mark(bufnr, ">")

    -- for some reason, sometimes the column is off by one
    -- see: https://github.com/folke/snacks.nvim/issues/190
    local col_to = math.min(to[2] + 1, #vim.api.nvim_buf_get_lines(bufnr, to[1] - 1, to[1], false)[1])

    lines = vim.api.nvim_buf_get_text(bufnr, from[1] - 1, from[2], to[1] - 1, col_to, {})
    -- Insert empty lines to keep the line numbers
    for _ = 1, from[1] - 1 do
        table.insert(lines, 1, "")
    end
    vim.fn.feedkeys("gv", "nx")

    return lines
end

return M
