return function(bufnr)
    local gs = require("gitsigns")
    local wk = require("which-key")

    wk.add({
        -- fall back to vim's diff motion when in a diff,
        -- otherwise jump between hunks; both keep the count
        {
            "[c",
            function()
                if vim.wo.diff then
                    vim.cmd.normal({ vim.v.count1 .. "[c", bang = true })
                else
                    gs.nav_hunk("prev")
                end
            end,
            desc = "Go to previous hunk",
            mode = "n",
            buffer = bufnr,
        },
        {
            "]c",
            function()
                if vim.wo.diff then
                    vim.cmd.normal({ vim.v.count1 .. "]c", bang = true })
                else
                    gs.nav_hunk("next")
                end
            end,
            desc = "Go to next hunk",
            mode = "n",
            buffer = bufnr,
        },

        {
            "ih",
            ":<C-U>Gitsigns select_hunk<CR>",
            desc = "Select inside hunk",
            mode = { "o", "x" },
            buffer = bufnr,
        },
    })
end
