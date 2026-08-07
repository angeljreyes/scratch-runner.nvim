local M = {}

---@param message string
---@param level vim.log.levels
---@param opts? table
M.notify = function(message, level, opts)
    opts = vim.tbl_deep_extend("force", opts or {}, { title = "scratch-runner.nvim" })
    vim.notify(message, level, opts)
end

---@param message string
---@param opts? table
M.notify_info = function(message, opts) M.notify(message, vim.log.levels.INFO, opts) end

---@param message string
---@param opts? table
M.notify_warn = function(message, opts) M.notify(message, vim.log.levels.WARN, opts) end

---@param message string
---@param opts? table
M.notify_error = function(message, opts) M.notify(message, vim.log.levels.ERROR, opts) end

return M
