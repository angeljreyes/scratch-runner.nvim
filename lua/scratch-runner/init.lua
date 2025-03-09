---@module "snacks"

local M = {}

---@param cmd string[] | fun(filepath: string): string[]
---@return snacks.win.Keys
M.make_key = function(cmd)
    ---@type snacks.win.Keys
    return {
        "<cr>",
        ---@param window snacks.win
        function(window)
            vim.cmd("silent w")

            local filepath = vim.api.nvim_buf_get_name(window.buf)
            local final_cmd

            if type(cmd) == "function" then
                final_cmd = cmd(filepath)
            elseif type(cmd) == "table" then
                final_cmd = cmd
                table.insert(final_cmd, filepath)
            else
                error("cmd must be a list of strings or a function that returns a list of strings")
            end

            if vim.fn.executable(final_cmd[1]) == 0 then
                vim.notify(final_cmd[1] .. " wasn't found on your system.", vim.log.levels.ERROR)
                return
            end

            local result_window = Snacks.win({
                style = "scratch",
                height = Snacks.config.scratch.win.height,
                width = Snacks.config.scratch.win.width,
                zindex = 30,
                title = " Running... ",
                ft = "text",
                bo = { filetype = "text", modifiable = false, buftype = "", bufhidden = "hide", swapfile = false },
                keys = { q = "close" },
            })

            ---@param lhs string
            ---@param desc string
            local footer_insert_key = function(lhs, desc)
                table.insert(result_window.opts.footer, { " " })
                table.insert(result_window.opts.footer, { " " .. lhs .. " ", "SnacksScratchKey" })
                table.insert(result_window.opts.footer, { " " .. desc .. " ", "SnacksScratchDesc" })
            end

            local footer_add_close = function() footer_insert_key("q", "Go back") end

            vim.system(
                final_cmd,
                { text = true },
                vim.schedule_wrap(function(output)
                    local stdout, stderr
                    if output.stdout and output.stdout ~= "" then
                        stdout = vim.split(output.stdout, "\n")
                    end
                    if output.stderr and output.stderr ~= "" then
                        stderr = vim.split(output.stderr, "\n")
                    end

                    vim.bo[result_window.buf].modifiable = true
                    vim.api.nvim_buf_set_lines(result_window.buf, 0, -1, false, stdout or stderr or { "" })
                    vim.bo[result_window.buf].modifiable = false
                    if not stdout and stderr then
                        result_window.opts.title = {
                            { " " },
                            { " ", "Error" },
                            { " Code Output " },
                        }
                        result_window.opts.footer = {}
                        footer_add_close()
                    elseif stdout and stderr then
                        local showing_stderr = false
                        result_window.opts.title = {
                            { " " },
                            { " ", "WarningMsg" },
                            { " Code Output " },
                        }
                        result_window.opts.footer = {}
                        footer_insert_key("<Tab>", "Show stderr")
                        footer_add_close()
                        vim.keymap.set("n", "<tab>", function()
                            result_window.opts.footer = {}
                            vim.bo[result_window.buf].modifiable = true
                            if showing_stderr then
                                vim.api.nvim_buf_set_lines(result_window.buf, 0, -1, false, stdout)
                                footer_insert_key("<Tab>", "Show stderr")
                            else
                                vim.api.nvim_buf_set_lines(result_window.buf, 0, -1, false, stderr)
                                footer_insert_key("<Tab>", "Show stdout")
                            end
                            vim.bo[result_window.buf].modifiable = false
                            footer_add_close()
                            showing_stderr = not showing_stderr
                            result_window:update()
                        end, { desc = "Show stdout/stderr", buffer = result_window.buf })
                    else
                        result_window.opts.title = {
                            { " " },
                            { " ", "Added" },
                            { " Code Output " },
                        }
                        result_window.opts.footer = {}
                        footer_add_close()
                    end
                    result_window:update()
                end)
            )
        end,
        desc = "Run buffer",
    }
end

---Make the `win_by_ft` option.
---@param filetypes table<string, string[] | fun(filepath: string): string[]>
---@return table<string, snacks.win.Config>
M.make_win_by_ft = function(filetypes)
    ---@type table<string, snacks.win.Config>
    local win_by_ft = {}

    for ft, cmd in pairs(filetypes) do
        ---@diagnostic disable-next-line: missing-fields
        win_by_ft[ft] = { keys = { run = M.make_key(cmd) } }
    end

    return win_by_ft
end

return M
