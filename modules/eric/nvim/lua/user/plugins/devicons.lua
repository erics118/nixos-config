return {
    "nvim-web-devicons",
    -- bufferline, alpha, nvim-tree, and telescope read icons at setup
    -- loads after catppuccin (priority 1000), so its palette is ready here
    priority = 900,
    after = function()
        local p = require("catppuccin.palettes").get_palette()
        local justfile = { icon = "󱚣", name = "Justfile", color = p.peach }
        require("nvim-web-devicons").setup({
            override_by_extension = {
                astro = {
                    icon = "",
                    name = "Astro",
                    color = p.red,
                },
                norg = {
                    icon = "",
                    name = "Neorg",
                    color = p.green,
                },
            },
            override_by_filename = {
                [".envrc"] = {
                    icon = "",
                    name = "envrc",
                    color = p.yellow,
                },
                [".editorconfig"] = {
                    icon = "",
                    name = "EditorConfig",
                    color = p.green,
                },
                [".luacheckrc"] = {
                    icon = "󰢱",
                    name = "LuacheckRC",
                    color = p.blue,
                },
                [".Justfile"] = justfile,
                [".justfile"] = justfile,
                ["Justfile"] = justfile,
                ["justfile"] = justfile,
            },
        })
    end,
}
