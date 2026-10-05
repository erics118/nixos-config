-- "SPC fd" becomes the lhs "<leader>fd"
-- `command` is an Ex command: <CR> on the button and the key both run it without echoing it
local function button(shortcut, text, command)
    local lhs = shortcut:gsub("SPC", "<leader>"):gsub(" ", "")
    return {
        type = "button",
        val = text,
        on_press = function()
            vim.cmd(command)
        end,
        opts = {
            shortcut = shortcut,
            -- width of longest button text
            width = 50,
            align_shortcut = "right",
            hl_shortcut = "Keyword",
            position = "center",
            keymap = { "n", lhs, "<Cmd>" .. command .. "<CR>", { noremap = true, silent = true, nowait = true } },
        },
    }
end

local function padding(n)
    return { type = "padding", val = n }
end

local header = {
    "  ,-.       _,---._ __  / \\  ",
    " /  )    .-'       `./ /   \\ ",
    "(  (   ,'            `/    /|",
    " \\  `-\"             \\'\\   / |",
    "  `.              ,  \\ \\ /  |",
    "   /`.          ,'-`----Y   |",
    "  (            ;        |   '",
    "  |  ,-.    ,-'         |  / ",
    "  |  | (   |            | /  ",
    "  )  |  \\  `.___________|/   ",
    "  `--'   `--'                ",
}

return {
    "alpha-nvim",
    after = function()
        require("alpha").setup({
            layout = {
                padding(2),
                { type = "text", val = header, opts = { hl = "Type", position = "center" } },
                padding(2),

                -- recent files, populated from vim.v.oldfiles at startup
                { type = "text", val = "Recent files", opts = { hl = "SpecialComment", position = "center" } },
                padding(1),
                { type = "group", val = require("user.dashboard_recent") },
                padding(2),

                {
                    type = "group",
                    val = {
                        button("n", "  New file", "ene | startinsert"),
                        padding(1),
                        button("SPC fd", "  Find file", "Telescope find_files"),
                        padding(1),
                        button("SPC fg", "  Live grep", "Telescope live_grep"),
                        padding(1),
                        button("q", "  Quit", "qa"),
                    },
                },
                padding(1),
                {
                    type = "text",
                    val = "neovim v" .. tostring(vim.version()),
                    opts = { hl = "Constant", position = "center" },
                },
            },
            opts = { noautocmd = true },
        })
    end,
}
