-- pinned, with no runtime theme switching
-- everything else reads colors through catppuccin.palettes.get_palette()
local flavour = "mocha"

return {
    "catppuccin-nvim",
    -- other plugins read its palette at setup
    priority = 1000,
    after = function()
        require("catppuccin").setup({
            flavour = flavour,
            transparent_background = true,
            styles = { comments = { "italic" } },
            term_colors = true,
            lsp_styles = {
                virtual_text = {
                    errors = { "italic" },
                    hints = { "italic" },
                    warnings = { "italic" },
                    information = { "italic" },
                },
                underlines = {
                    errors = { "undercurl" },
                    hints = { "undercurl" },
                    warnings = { "undercurl" },
                    information = { "undercurl" },
                },
            },
            integrations = {
                blink_cmp = true,
                lsp_trouble = true,
                nvimtree = true,
                which_key = true,
                indent_blankline = { enabled = true },
                gitsigns = true,
                neogit = true,
                notify = true,
                grug_far = true,
                nvim_surround = true,
            },
            highlight_overrides = { all = require("user.catppuccin_overrides") },
        })
        vim.cmd.colorscheme("catppuccin-" .. flavour)
        vim.env.BAT_THEME = "catppuccin-" .. flavour
    end,
}
