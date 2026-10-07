local map = require("user.utils.map")

map("n", "<leader>lv", "<Cmd>VimtexView<CR>", "LaTeX forward search")

vim.api.nvim_create_autocmd("FileType", {
    desc = "Stop vimtex reindenting the line when typing } or ]",
    group = vim.api.nvim_create_augroup("UserLatexIndent", { clear = true }),
    pattern = "tex",
    command = "setlocal indentkeys-=} indentkeys-=]",
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Label vimtex surround/toggle mappings in which-key",
    group = vim.api.nvim_create_augroup("UserLatexWhichKey", { clear = true }),
    pattern = "tex",
    callback = function(ev)
        require("which-key").add({
            { "ds", group = "Delete surrounding", buffer = ev.buf },
            { "cs", group = "Change surrounding", buffer = ev.buf },
            { "ts", group = "Toggle", buffer = ev.buf },
            { "ts$", desc = "Toggle inline/display math", buffer = ev.buf },
            { "tse", desc = "Toggle environment", buffer = ev.buf },
            { "tss", desc = "Toggle env star", buffer = ev.buf },
            { "tsd", desc = "Toggle delimiter modifier", buffer = ev.buf },
            { "tsf", desc = "Toggle fraction", buffer = ev.buf },
            { "tsc", desc = "Toggle command star", buffer = ev.buf },
            { "dse", desc = "Delete environment", buffer = ev.buf },
            { "dsd", desc = "Delete delimiter", buffer = ev.buf },
            { "dsc", desc = "Delete command", buffer = ev.buf },
            { "cse", desc = "Change environment", buffer = ev.buf },
            { "csd", desc = "Change delimiter", buffer = ev.buf },
            { "csc", desc = "Change command", buffer = ev.buf },
        })
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Load luasnip and the LaTeX snippets",
    group = vim.api.nvim_create_augroup("UserLatexSnippets", { clear = true }),
    pattern = "tex",
    once = true,
    callback = function()
        require("lz.n").trigger_load("luasnip")
        require("user.latex_snippets")
    end,
})

return {
    -- loaded at startup: skim inverse search runs VimtexInverseSearch headlessly before any tex buffer opens
    "vimtex",
    before = function()
        vim.g.vimtex_compiler_method = "latexmk"
        vim.g.vimtex_quickfix_mode = 0
        vim.g.vimtex_view_method = "skim"
        -- forward search focuses skim, like displayline without -g
        vim.g.vimtex_view_skim_activate = 1
        vim.g.vimtex_env_toggle_math_map = { ["$"] = "\\[", ["\\["] = "$" }
    end,
}
