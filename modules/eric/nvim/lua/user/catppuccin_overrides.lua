return function(colors)
    return {
        -- shared selection background (pmenu, telescope)
        Selection = { bg = colors.surface1 },
        -- floats
        NormalFloat = { bg = colors.surface0 },
        FloatBorder = { fg = colors.overlay0, bg = colors.surface0 },
        NvimTreeWinSeparator = { link = "FloatBorder" },
        -- git status colors for nvim-tree icons
        NvimTreeGitNewIcon = { fg = colors.green },
        NvimTreeGitStagedIcon = { fg = colors.green },
        NvimTreeGitMergeIcon = { fg = colors.mauve },
        NvimTreeGitIgnoredIcon = { fg = colors.overlay0 },
        WhichKeyBorder = { link = "FloatBorder" },
        -- centered cmdline (user/cmdline.lua)
        CmdlineBorder = { fg = colors.mauve },
        -- message float (user/cmdline.lua)
        MsgBorder = { fg = colors.overlay0 },
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
        NotifyBackground = { bg = colors.base },
        NotifyINFOBorder = { link = "NotifyINFOTitle" },
        NotifyINFOIcon = { link = "NotifyINFOTitle" },
        NotifyINFOTitle = { fg = colors.pink },
    }
end
