return {
    "dropbar.nvim",
    -- InsertEnter covers :enew buffers, which fire neither read event
    event = { "BufReadPost", "BufNewFile", "InsertEnter" },
    after = function()
        require("dropbar").setup({
            -- menus only pick files and symbols, without previewing them in the window behind
            menu = { preview = false },
            sources = { path = { preview = false } },
            bar = {
                enable = function(buf, win, _)
                    if not vim.api.nvim_win_is_valid(win) then
                        return false
                    end
                    if vim.fn.win_gettype(win) ~= "" then
                        return false
                    end
                    return not vim.tbl_contains(vim.g.ignored_ui_filetypes, vim.bo[buf].filetype)
                end,
            },
        })
    end,
}
