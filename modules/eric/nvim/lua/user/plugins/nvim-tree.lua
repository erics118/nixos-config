local map = require("user.utils.map")

map("n", "<leader>te", "<Cmd>NvimTreeToggle<CR>", "Toggle file tree")

local group = vim.api.nvim_create_augroup("UserNvimTree", { clear = true })

-- true opens nvim-tree on every launch, not only for a directory argument
local open_tree_on_startup = false

vim.api.nvim_create_autocmd("VimEnter", {
    desc = "Open nvim-tree on startup",
    group = group,
    once = true,
    callback = function(data)
        if vim.o.diff then
            return
        end

        local is_dir = data.file ~= "" and vim.fn.isdirectory(data.file) == 1
        if not (open_tree_on_startup or is_dir) then
            return
        end

        -- skip when launched directly into a special buffer
        if data.file ~= "" and not is_dir and vim.bo[data.buf].buftype ~= "" then
            return
        end

        -- otherwise the tree roots at the directory nvim was started from
        if is_dir then
            vim.cmd.cd(data.file)
        end

        vim.cmd("NvimTreeOpen")
        vim.cmd("wincmd p")
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Prevent nvim-tree window from scrolling horizontally",
    group = group,
    pattern = "NvimTree",
    command = "setlocal sidescrolloff=0",
})

vim.api.nvim_create_autocmd("WinResized", {
    desc = "Remember nvim-tree width when manually resized",
    group = group,
    callback = function()
        -- only remember width while the tree is a sidebar next to other windows
        -- skip when it is the sole window (would save full width)
        local wins = vim.tbl_filter(function(w)
            return vim.api.nvim_win_get_config(w).relative == ""
        end, vim.api.nvim_tabpage_list_wins(0))
        if #wins <= 1 then
            return
        end

        for _, win in ipairs(vim.v.event.windows) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "NvimTree" then
                vim.g.nvim_tree_width = vim.api.nvim_win_get_width(win)
            end
        end
    end,
})

return {
    "nvim-tree.lua",
    cmd = {
        "NvimTreeOpen",
        "NvimTreeToggle",
        "NvimTreeFocus",
        "NvimTreeFindFile",
        "NvimTreeFindFileToggle",
        "NvimTreeClose",
        "NvimTreeCollapse",
    },
    after = function()
        require("nvim-tree").setup({
            hijack_cursor = true,
            select_prompts = true,
            renderer = {
                group_empty = true,
                indent_markers = { enable = true },
                highlight_git = "name",
                highlight_modified = "name",
                icons = {
                    git_placement = "right_align",
                    -- match the starship git_status symbols
                    glyphs = {
                        git = {
                            untracked = "?",
                            staged = "+",
                            unstaged = "~",
                            renamed = "»",
                            deleted = "×",
                            unmerged = "!",
                        },
                    },
                },
            },
            view = {
                preserve_window_proportions = true,
                width = function()
                    return vim.g.nvim_tree_width or 30
                end,
            },
            update_focused_file = { enable = true },
            modified = { enable = true },
            diagnostics = { enable = true, show_on_dirs = true },
            on_attach = function(bufnr)
                local api = require("nvim-tree.api")
                api.config.mappings.default_on_attach(bufnr)
                -- let <C-k> fall through to the global window-nav mapping,
                -- move the info popup to i
                pcall(vim.keymap.del, "n", "<C-k>", { buf = bufnr })
                vim.keymap.set("n", "i", api.node.show_info_popup, { buf = bufnr, desc = "nvim-tree: Info" })
            end,
            actions = { file_popup = { open_win_config = { border = "rounded" } } },
            filters = {
                -- vim regex, so the dot is escaped
                custom = { "^\\.git$", "^\\.cache$", "^\\.devenv$", "^\\.direnv$" },
                -- lua pattern matched against the full path, so anchor it to the file name
                exclude = { "/%.env[^/]*$" },
            },
        })
    end,
}
