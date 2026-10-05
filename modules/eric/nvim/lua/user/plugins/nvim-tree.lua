-- user/autocmds.lua opens the tree on VimEnter for a directory argument
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
                icons = { git_placement = "right_align" },
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
