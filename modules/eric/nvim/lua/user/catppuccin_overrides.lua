return function(colors)
    return {
        -- shared selection background (pmenu, telescope)
        Selection = { bg = colors.surface1 },
        -- floats
        NormalFloat = { bg = colors.surface0 },
        FloatBorder = { fg = colors.overlay0, bg = colors.surface0 },
        NvimTreeWinSeparator = { link = "FloatBorder" },
        -- git status colors shared with starship and vscode
        NvimTreeGitNewIcon = { fg = colors.green },
        NvimTreeGitStagedIcon = { fg = colors.green },
        NvimTreeGitMergeIcon = { fg = colors.mauve },
        NvimTreeGitIgnoredIcon = { fg = colors.overlay0 },
        WhichKeyBorder = { link = "FloatBorder" },
        -- telescope
        TelescopeBorder = { link = "FloatBorder" },
        TelescopeTitle = { fg = colors.text },
        TelescopeSelection = { link = "Selection" },
        TelescopeSelectionCaret = { link = "Selection" },
        -- pmenu
        PmenuSel = { link = "Selection" },
        -- bufferline
        BufferLineTabSeparator = { link = "FloatBorder" },
        BufferLineSeparator = { link = "FloatBorder" },
        BufferLineOffsetSeparator = { link = "FloatBorder" },
        --
        FidgetTitle = { fg = colors.subtext1 },
        FidgetTask = { fg = colors.subtext0 },

        NotifyBackground = { bg = colors.base },
        NotifyINFOBorder = { link = "NotifyINFOTitle" },
        NotifyINFOIcon = { link = "NotifyINFOTitle" },
        NotifyINFOTitle = { fg = colors.pink },
    }
end
