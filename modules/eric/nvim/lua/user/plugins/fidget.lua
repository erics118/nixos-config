return {
    "fidget.nvim",
    event = "LspAttach",
    after = function()
        require("fidget").setup({
            notification = { window = { winblend = 0 } },
            progress = {
                display = { done_icon = "󰗡", progress_icon = { pattern = "dots" } },
                ignore = { "copilot" },
            },
        })
    end,
}
