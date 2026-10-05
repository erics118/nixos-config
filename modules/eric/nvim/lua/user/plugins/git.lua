-- fugitive has no config and stays in start: it is cheap, and it defines too many :G* commands to list as lazy triggers
-- [c/]c and the ih textobject live in gitsigns' on_attach (user/gitsigns_attach.lua)
-- for lua callbacks and buffer scoping
local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc })
end

local function selected(fn)
    return function()
        require("gitsigns")[fn]({ vim.fn.line("."), vim.fn.line("v") })
    end
end

map("n", "<leader>gd", "<cmd>Gvdiffsplit<CR>", "Git diff")
map("n", "<leader>ng", "<cmd>Neogit<cr>", "Neogit")

-- on a staged hunk, stage_hunk unstages it
map("n", "<leader>hs", "<cmd>Gitsigns stage_hunk<CR>", "Stage hunk")
map("n", "<leader>hr", "<cmd>Gitsigns reset_hunk<CR>", "Reset hunk")
map("x", "<leader>hs", selected("stage_hunk"), "Stage selected lines")
map("x", "<leader>hr", selected("reset_hunk"), "Reset selected lines")
map("n", "<leader>hS", "<cmd>Gitsigns stage_buffer<CR>", "Stage buffer")
map("n", "<leader>hR", "<cmd>Gitsigns reset_buffer<CR>", "Reset buffer")
map("n", "<leader>hp", "<cmd>Gitsigns preview_hunk<CR>", "Preview hunk")
map("n", "<leader>hb", function()
    require("gitsigns").blame_line({ full = true })
end, "Blame line")
map("n", "<leader>hd", "<cmd>Gitsigns diffthis<CR>", "Diff current buffer")
map("n", "<leader>hD", "<cmd>Gitsigns diffthis ~<CR>", "Diff against last commit")
map("n", "<leader>tb", "<cmd>Gitsigns toggle_current_line_blame<CR>", "Toggle blame lines")
map("n", "<leader>td", "<cmd>Gitsigns preview_hunk_inline<CR>", "Preview hunk inline")

return {
    {
        "gitsigns.nvim",
        after = function()
            require("gitsigns").setup({
                current_line_blame = false,
                current_line_blame_formatter = "<author>, <author_time:%R> - <summary> | <abbrev_sha>",
                on_attach = require("user.gitsigns_attach"),
            })
        end,
    },
    {
        "neogit",
        cmd = "Neogit",
        -- neogit requires codediff modules, and lz.n only loads codediff on its command
        before = function()
            require("lz.n").trigger_load("codediff.nvim")
        end,
        after = function()
            require("neogit").setup({ diff_viewer = "codediff", integrations = { codediff = true } })
        end,
    },
    {
        -- :CodeDiff for working-tree changes, :CodeDiff history for commits
        "codediff.nvim",
        cmd = "CodeDiff",
        before = function()
            -- its file watcher downloads a binary into the plugin dir, which is read-only in the nix store
            -- without it, codediff refreshes by polling
            vim.env.CODEDIFF_WATCHER_NO_AUTO_INSTALL = "1"
        end,
    },
}
