return {
    "indent-blankline.nvim",
    -- InsertEnter covers :enew buffers, which fire neither read event
    event = { "BufReadPost", "BufNewFile", "InsertEnter" },
    after = function()
        require("ibl").setup({
            indent = { char = "▏" },
            scope = { enabled = true, show_start = false, show_end = false },
            exclude = { filetypes = vim.g.ignored_ui_filetypes },
        })
    end,
}
