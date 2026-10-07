-- texlab's forward search, available once texlab attaches
vim.keymap.set("n", "<leader>lv", "<cmd>LspTexlabForward<CR>", { silent = true, desc = "LaTeX forward search" })

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
        vim.g.vimtex_env_toggle_math_map = { ["$"] = "\\[", ["\\["] = "$" }
    end,
}
