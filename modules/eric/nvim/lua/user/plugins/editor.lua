local map = require("user.utils.map")

local function flash(mode)
    return function()
        require("flash")[mode]()
    end
end

map({ "n", "x", "o" }, "s", flash("jump"), "Flash")
-- visual S stays with nvim-surround
map({ "n", "o" }, "S", flash("treesitter"), "Flash Treesitter")
map("o", "r", flash("remote"), "Remote Flash")
map({ "o", "x" }, "R", flash("treesitter_search"), "Treesitter Search")
-- <C-f> stays the default 'cedit' key that opens the cmdline window
map("c", "<C-s>", flash("toggle"), "Toggle Flash Search")

return {
    {
        "flash.nvim",
        after = function()
            require("flash").setup({})
        end,
    },
    {
        "todo-comments.nvim",
        event = require("user.utils.lazy").file_events,
        cmd = { "TodoTelescope", "TodoTrouble", "TodoQuickFix", "TodoLocList" },
        after = function()
            require("todo-comments").setup({})
        end,
    },
    {
        -- loaded at startup: :enew buffers fire no read/new-file event, so lazy maps never appeared
        "nvim-surround",
        after = function()
            require("nvim-surround").setup({
                surrounds = { C = { add = { { "```", "" }, { "", "```" } } } },
            })
        end,
    },
    {
        "render-markdown.nvim",
        -- only filetypes with an installed treesitter parser
        ft = "markdown",
        after = function()
            require("render-markdown").setup({
                file_types = { "markdown" },
                render_modes = true,
                win_options = { conceallevel = { rendered = 0 } },
                bullet = { enabled = false },
                checkbox = { enabled = false },
                html = { enabled = false },
                code = { border = "thick" },
                sign = { enabled = false },
                latex = { enabled = false },
                -- lsp hover floats are nofile markdown, styled by user/lsp.lua instead
                overrides = { buftype = { nofile = { enabled = false } } },
            })
        end,
    },
}
