local function map(lhs, command, desc)
    vim.keymap.set("n", lhs, "<cmd>" .. command .. "<CR>", { silent = true, desc = desc })
end

map("<leader>xx", "Trouble diagnostics toggle", "Trouble diagnostics")
map("<leader>xd", "Trouble lsp_definitions", "Trouble LSP definitions")
map("<leader>xq", "Trouble quickfix", "Trouble quickfix")
map("<leader>xl", "Trouble loclist", "Trouble location list")

return {
    "trouble.nvim",
    cmd = "Trouble",
    after = function()
        require("trouble").setup({ win = { padding = { left = 0 } } })
    end,
}
