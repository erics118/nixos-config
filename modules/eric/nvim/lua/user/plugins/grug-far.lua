local map = require("user.utils.map")

map("n", "<leader>sr", "<cmd>GrugFar<CR>", "Search and replace")

return {
    "grug-far.nvim",
    cmd = "GrugFar",
    after = function()
        require("grug-far").setup({})
    end,
}
