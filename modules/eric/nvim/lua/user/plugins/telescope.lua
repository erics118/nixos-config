local extensions = {
    "telescope-fzf-native.nvim",
    "telescope-file-browser.nvim",
    "telescope-ui-select.nvim",
}

-- the first vim.ui.select call loads telescope, whose ui-select extension replaces this stub
local builtin_select = vim.ui.select
local function select_stub(...)
    require("lz.n").trigger_load("telescope.nvim")
    -- a failed load falls back to the builtin instead of recursing
    if vim.ui.select == select_stub then
        vim.ui.select = builtin_select
    end
    return vim.ui.select(...)
end
vim.ui.select = select_stub

local function picker(lhs, command, desc)
    return { lhs, "<cmd>" .. command .. "<cr>", desc = desc }
end

return {
    {
        "telescope.nvim",
        cmd = "Telescope",
        keys = {
            picker("<leader>fb", "Telescope file_browser grouped=true", "File browser"),
            picker("<leader>fd", "Telescope find_files", "Find file"),
            picker("<leader>fg", "Telescope live_grep", "Live grep"),
            picker("<leader>fh", "Telescope help_tags", "Help tags"),
            {
                "<leader>fn",
                function()
                    -- the notify picker lives in nvim-notify
                    require("lz.n").trigger_load("nvim-notify")
                    vim.cmd("Telescope notify")
                end,
                desc = "Show notifications",
            },
            picker("<leader>fr", "Telescope oldfiles", "Recent files"),
            picker("<leader>fm", "Telescope marks", "List marks"),
            picker("<leader>ft", "TodoTelescope", "Search TODOs"),
        },
        before = function()
            for _, name in ipairs(extensions) do
                vim.cmd.packadd(name)
            end
        end,
        after = function()
            local telescope = require("telescope")
            telescope.setup({
                defaults = {
                    prompt_prefix = " ",
                    selection_caret = " ",
                    -- as wide as selection_caret, or telescope shifts a row right each time the selection leaves it
                    entry_prefix = " ",
                    multi_icon = "│",
                    borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
                },
                pickers = {
                    find_files = { previewer = false, prompt_title = false, results_title = false },
                    live_grep = { previewer = true },
                    oldfiles = { cwd_only = true },
                },
                extensions = {
                    fzf = {
                        fuzzy = true,
                        override_generic_sorter = true,
                        override_file_sorter = true,
                        case_mode = "smart_case",
                    },
                    file_browser = { grouped = true, sorting_strategy = "ascending" },
                },
            })
            for _, name in ipairs({ "ui-select", "fzf", "file_browser" }) do
                telescope.load_extension(name)
            end
        end,
    },
}
