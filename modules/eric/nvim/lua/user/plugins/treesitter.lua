-- nvim-treesitter and its grammars stay in start, since highlighting needs no setup call
-- vimtex's syntax powers in_mathzone, imaps, ]], math text objects, conceal
local no_highlight = { latex = true }

vim.api.nvim_create_autocmd("FileType", {
    desc = "Start treesitter highlighting and indent",
    group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true }),
    callback = function(ev)
        local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
        if not lang or not vim.treesitter.language.add(lang) then
            return
        end
        -- undone on a later filetype change, like any ftplugin setting
        local function add_undo(command)
            local undo = vim.b[ev.buf].undo_ftplugin
            vim.b[ev.buf].undo_ftplugin = (undo and undo .. " | " or "") .. command
        end
        if not no_highlight[lang] and vim.treesitter.query.get(lang, "highlights") then
            vim.treesitter.start(ev.buf, lang)
            add_undo(("call v:lua.vim.treesitter.stop(%d)"):format(ev.buf))
        end
        if vim.treesitter.query.get(lang, "indents") then
            vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
            add_undo("setlocal indentexpr<")
        end
    end,
})

return {
    -- auto-close/rename HTML tags
    "nvim-ts-autotag",
    -- loaded once the screen is drawn, so the first insert doesn't wait on it
    event = { "DeferredUIEnter", "InsertEnter" },
    after = function()
        require("nvim-ts-autotag").setup({})
    end,
}
