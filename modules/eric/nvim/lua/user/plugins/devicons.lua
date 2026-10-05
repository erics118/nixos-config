-- colors are hardcoded catppuccin mocha hex values
-- so they don't depend on catppuccin's load order
local justfile = {
    icon = "󱚣",
    name = "Justfile",
    -- mocha peach
    color = "#fab387",
}

return {
    "nvim-web-devicons",
    -- bufferline, alpha, nvim-tree, and telescope read icons at setup
    priority = 900,
    after = function()
        require("nvim-web-devicons").setup({
            override_by_extension = {
                astro = {
                    icon = "",
                    name = "Astro",
                    -- mocha red
                    color = "#f38ba8",
                },
                norg = {
                    icon = "",
                    name = "Neorg",
                    -- mocha green
                    color = "#a6e3a1",
                },
            },
            override_by_filename = {
                [".envrc"] = {
                    icon = "",
                    name = "envrc",
                    -- mocha yellow
                    color = "#f9e2af",
                },
                [".editorconfig"] = {
                    icon = "",
                    name = "EditorConfig",
                    -- mocha green
                    color = "#a6e3a1",
                },
                [".luacheckrc"] = {
                    icon = "󰢱",
                    name = "LuacheckRC",
                    -- mocha blue
                    color = "#89b4fa",
                },
                [".Justfile"] = justfile,
                [".justfile"] = justfile,
                ["Justfile"] = justfile,
                ["justfile"] = justfile,
            },
        })
    end,
}
