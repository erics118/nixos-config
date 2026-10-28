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

-- folders shrink to one letter, keeping the parent folder whole when it fits
local function shorten_path(file)
    local short = vim.fn.fnamemodify(file, ":~:.")
    for _, keep in ipairs({ { -2, -1 }, { -1 } }) do
        if #short <= 46 then
            break
        end
        short = require("plenary.path"):new(vim.fn.fnamemodify(file, ":~:.")):shorten(1, keep)
    end
    if #short > 46 then
        -- U+2026 ellipsis
        short = "\226\128\166" .. string.sub(short, -45)
    end
    return short
end

-- numbered buttons for up to 9 recent files under the folder nvim was opened in, like <leader>fr
local function recent_file_buttons()
    local buttons = {}
    local cwd = vim.fn.getcwd()
    for _, file in ipairs(vim.v.oldfiles) do
        if #buttons == 9 then
            break
        end
        if vim.fn.filereadable(file) == 1 and vim.fs.relpath(cwd, file) then
            local key = tostring(#buttons + 1)
            table.insert(buttons, button(key, shorten_path(file), "edit " .. vim.fn.fnameescape(file)))
        end
    end
    return buttons
end

-- the global <C-d>zz would scroll the dashboard off center
-- here half-page keys only move the cursor, by the same 'scroll' amount
-- AlphaReady, not FileType: noautocmd below keeps the dashboard from firing FileType
vim.api.nvim_create_autocmd("User", {
    desc = "Move the cursor without scrolling on the dashboard",
    group = vim.api.nvim_create_augroup("UserAlphaScroll", { clear = true }),
    pattern = "AlphaReady",
    callback = function()
        for key, motion in pairs({ ["<C-d>"] = "j", ["<C-u>"] = "k" }) do
            vim.keymap.set("n", key, function()
                vim.cmd("normal! " .. vim.wo.scroll .. motion)
            end, { buf = 0, desc = "Move cursor half a page" })
        end
    end,
})

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
                { type = "group", val = recent_file_buttons },
                padding(2),

                {
                    type = "group",
                    val = {
                        button("n", "New file", "ene | startinsert"),
                        padding(1),
                        button("SPC fd", "Find file", "Telescope find_files"),
                        padding(1),
                        button("SPC fg", "Live grep", "Telescope live_grep"),
                        padding(1),
                        button("q", "Quit", "qa"),
                    },
                },
                padding(1),
                {
                    type = "text",
                    val = "Neovim v" .. tostring(vim.version()),
                    opts = { hl = "Constant", position = "center" },
                },
            },
            opts = { noautocmd = true },
        })
    end,
}
