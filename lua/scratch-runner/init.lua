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

---@param opts? table Extra fields to merge.
---@return snacks.win.Config
H.get_scratch_terminal_style = function(opts)
    -- Load snacks.terminal to ensure that the style is not nil
    require("snacks.terminal")
    if H.scratch_terminal_style == nil then
        local scratch_style =
            vim.tbl_deep_extend("force", Snacks.config.styles.scratch, Snacks.config.scratch.win or {})
        H.scratch_terminal_style = vim.tbl_deep_extend(
            "force",
            vim.tbl_extend("force", scratch_style, Snacks.config.styles.terminal),
            { wo = scratch_style.wo },
            {
                wo = {
                    number = false,
                    relativenumber = false,
                    signcolumn = "no",
                },
                keys = {
                    q = "close",
                    gf = false,
                },
                zindex = nil,
            }
        )
    end

    if opts then
        return vim.tbl_deep_extend("force", H.scratch_terminal_style, opts)
    end

    return H.scratch_terminal_style
end

---@class scratch-runner.Config
H.config = {
    ---Key that runs the scratch buffer.
    ---@type string?
    run_key = "<CR>",

    ---Commands that run your script. See :h scratch-runner.Source
    ---@type table<string, scratch-runner.Source | scratch-runner.SourceCommand>
    sources = {},
}

---@param opts scratch-runner.Config?
M.setup = function(opts)
    if opts and opts["output_switch_key"] ~= nil then
        H.notify_warn(
            "This plugin no longer separates std output from std error. As a result of this, the"
                .. " configuration option 'output_switch_key' is deprecated and no longer does"
                .. " anything. Consider removing it from the opts table in your configuration."
        )
    end

    H.config = vim.tbl_deep_extend("force", H.config, opts or {})

    if not vim.tbl_isempty(H.config.sources) then
        local win_by_ft = H.make_win_by_ft(H.config.sources)
        Snacks.config.scratch.win_by_ft = vim.tbl_deep_extend("force", Snacks.config.scratch.win_by_ft or {}, win_by_ft)
    end
end

---@param window snacks.win
---@param source scratch-runner.Source Command to run the file through.
H.run_callback = function(window, source)
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

    H.run_commands(pipeline, window)
end

---Makes a keymap that runs your code.
---@param source scratch-runner.Source Command to run the file through.
---@return snacks.win.Keys
H.make_key = function(source)
    source.binary = source.binary ~= nil and source.binary or false
    return {
        H.config.run_key,
        function(window) H.run_callback(window, source) end,
        desc = "Run buffer",
        mode = { "n", "x" },
    }
end

---@param pipeline string[][] Commands to run.
---@param window snacks.win Scratch window to open the terminal from.
H.run_commands = function(pipeline, window)
    local next_cmd = function()
        if pipeline[2] ~= nil then
            H.run_commands(vim.list_slice(pipeline, 2), window)
        end
    end

    local icon, icon_hl = Snacks.util.icon(vim.bo[window.buf].filetype, "filetype")
    local style = H.get_scratch_terminal_style({
        zindex = window.opts.zindex + 10,
        title = {
            { " " },
            { icon, icon_hl },
            { "  Running... " },
        },
    })
    local terminal = Snacks.terminal.open(pipeline[1], { win = style, interactive = false, auto_close = false })

    terminal:on("TermClose", function()
        if vim.v.event.status == 0 and pipeline[2] ~= nil then
            terminal:close()
            next_cmd()
        else
            terminal.opts.title[3] = { "  Result " }
            terminal:update()
        end
    end, { buf = true })
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

    vim.validate("source", source, "table")
    vim.validate("source[1]", source[1], { "table", "function" })

    local one = source[1]
    if type(one) == "table" then
        one = vim.deepcopy(one)
        vim.validate("source[1][1]", source[1][1], "string")
        table.insert(one, file_path)
        pipeline = { one }
    else
        local result = one(file_path, bin_path)
        vim.validate("source[1]()", result, "table")
        local result_one = result[1]
        vim.validate("source[1]()[1]", result_one, { "string", "table" })
        if type(result_one) == "string" then
            pipeline = { result }
        else
            vim.validate("source[1]()[1][1]", result_one[1], "string")
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
