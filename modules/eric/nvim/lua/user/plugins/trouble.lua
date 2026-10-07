local map = require("user.utils.map")

map("n", "<leader>xx", "<Cmd>Trouble diagnostics toggle<CR>", "Trouble diagnostics")
map("n", "<leader>xd", "<Cmd>Trouble lsp_definitions<CR>", "Trouble LSP definitions")
map("n", "<leader>xq", "<Cmd>Trouble quickfix<CR>", "Trouble quickfix")
map("n", "<leader>xl", "<Cmd>Trouble loclist<CR>", "Trouble location list")

return {
    "trouble.nvim",
    cmd = "Trouble",
    after = function()
        require("trouble").setup({ win = { padding = { left = 0 } } })
    end,
}
