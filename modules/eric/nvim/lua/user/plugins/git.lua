-- fugitive has no config and stays in start: it is cheap, and it defines too many :G* commands to list as lazy triggers
local map = require("user.utils.map")

-- runs a gitsigns hunk action on the visual selection's lines
local function on_selected_lines(action)
    return function()
        require("gitsigns")[action]({ vim.fn.line("."), vim.fn.line("v") })
    end
end

-- in a diff, falls back to vim's own [c/]c motion
-- otherwise jumps between hunks
-- both keep the count
local function hunk_motion(key, direction)
    return function()
        if vim.wo.diff then
            vim.cmd.normal({ vim.v.count1 .. key, bang = true })
        else
            require("gitsigns").nav_hunk(direction)
        end
    end
end

-- buffer-local, since gitsigns attaches per buffer
local function on_gitsigns_attach(bufnr)
    local function buf_map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buf = bufnr, silent = true, desc = desc })
    end
    buf_map("n", "[c", hunk_motion("[c", "prev"), "Go to previous hunk")
    buf_map("n", "]c", hunk_motion("]c", "next"), "Go to next hunk")
    buf_map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>", "Select inside hunk")
end

map("n", "<leader>gd", "<cmd>Gvdiffsplit<CR>", "Git diff")
map("n", "<leader>gh", "<Cmd>diffget //2<CR>", "Get diff from left (ours)")
map("n", "<leader>gl", "<Cmd>diffget //3<CR>", "Get diff from right (theirs)")
map("n", "<leader>gg", "<cmd>Neogit<cr>", "Neogit")

-- on a staged hunk, stage_hunk unstages it
map("n", "<leader>hs", "<cmd>Gitsigns stage_hunk<CR>", "Stage hunk")
map("n", "<leader>hr", "<cmd>Gitsigns reset_hunk<CR>", "Reset hunk")
map("x", "<leader>hs", on_selected_lines("stage_hunk"), "Stage selected lines")
map("x", "<leader>hr", on_selected_lines("reset_hunk"), "Reset selected lines")
map("n", "<leader>hS", "<cmd>Gitsigns stage_buffer<CR>", "Stage buffer")
map("n", "<leader>hR", "<cmd>Gitsigns reset_buffer<CR>", "Reset buffer")
map("n", "<leader>hp", "<cmd>Gitsigns preview_hunk<CR>", "Preview hunk")
map("n", "<leader>hb", function()
    require("gitsigns").blame_line({ full = true })
end, "Blame line")
map("n", "<leader>hd", "<cmd>Gitsigns diffthis<CR>", "Diff current buffer")
map("n", "<leader>hD", "<cmd>Gitsigns diffthis ~<CR>", "Diff against last commit")
map("n", "<leader>tb", "<cmd>Gitsigns toggle_current_line_blame<CR>", "Toggle blame lines")
map("n", "<leader>hi", "<cmd>Gitsigns preview_hunk_inline<CR>", "Preview hunk inline")

return {
    {
        "gitsigns.nvim",
        after = function()
            require("gitsigns").setup({
                current_line_blame = false,
                current_line_blame_formatter = "<author>, <author_time:%R> - <summary> | <abbrev_sha>",
                on_attach = on_gitsigns_attach,
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
