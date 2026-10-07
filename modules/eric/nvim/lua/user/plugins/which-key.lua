-- group labels for <leader> prefixes
local groups = {
    b = "Buffer",
    c = "Code action",
    f = "Find",
    g = "Git",
    h = "Hunk",
    l = "LSP",
    r = "Rename",
    s = "Search",
    t = "Toggle",
    w = "Workspace",
    x = "Diagnostics",
}

return {
    "which-key.nvim",
    after = function()
        local spec = {}
        for key, group in pairs(groups) do
            table.insert(spec, { "<leader>" .. key, group = group })
        end
        require("which-key").setup({
            preset = "modern",
            icons = { keys = { BS = "󰌍 " } },
            win = { border = "rounded", padding = { 0, 0 } },
            spec = spec,
        })
    end,
}
