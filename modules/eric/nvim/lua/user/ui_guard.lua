local M = {}

-- true for a real file on disk, not a scratch, help, or plugin buffer
function M.is_file_backed_buffer(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name == "" or vim.bo[bufnr].buftype ~= "" then
        return false
    end

    local uri = vim.uri_from_bufnr(bufnr)
    return uri ~= nil and vim.startswith(uri, "file://")
end

-- runs callback unless the current window is a float or shows a UI filetype
-- the list is vim.g.ignored_ui_filetypes from user/options.lua
function M.ft_guard(callback)
    if vim.api.nvim_win_get_config(0).relative ~= "" then
        return
    end
    if not vim.tbl_contains(vim.g.ignored_ui_filetypes or {}, vim.bo.filetype) then
        callback()
    end
end

return M
