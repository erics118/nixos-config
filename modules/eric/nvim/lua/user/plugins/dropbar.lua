return {
    "dropbar.nvim",
    event = require("user.utils.lazy").file_events,
    after = function()
        -- the default keeps its guards for floats, existing winbars, files over 1 MiB, and buffers with nothing to show
        local default_enable = require("dropbar.configs").opts.bar.enable
        require("dropbar").setup({
            -- menus only pick files and symbols, without previewing them in the window behind
            menu = { preview = false },
            sources = { path = { preview = false } },
            bar = {
                enable = function(buf, win, info)
                    return default_enable(buf, win, info)
                        and not vim.tbl_contains(vim.g.ignored_ui_filetypes, vim.bo[buf].filetype)
                end,
            },
        })
    end,
}
