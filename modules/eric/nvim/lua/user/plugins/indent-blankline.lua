return {
    "indent-blankline.nvim",
    event = require("user.utils.lazy").file_events,
    after = function()
        require("ibl").setup({
            indent = { char = "▏" },
            scope = { enabled = true, show_start = false, show_end = false },
            exclude = { filetypes = vim.g.ignored_ui_filetypes },
        })
    end,
}
