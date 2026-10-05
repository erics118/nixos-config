vim.keymap.set("n", "<leader>sr", "<cmd>GrugFar<CR>", { silent = true, desc = "Search and replace" })

return {
    "grug-far.nvim",
    cmd = "GrugFar",
    after = function()
        require("grug-far").setup({})
    end,
}
