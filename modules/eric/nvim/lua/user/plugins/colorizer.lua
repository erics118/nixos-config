local filetypes = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "python",
    "sh",
    "bash",
    "zsh",
    "fish",
    "html",
    "css",
    "scss",
    "json",
    "jsonc",
}

vim.keymap.set("n", "<leader>tC", "<cmd>ColorizerToggle<CR>", { silent = true, desc = "Toggle colorizer" })

return {
    "nvim-colorizer.lua",
    ft = filetypes,
    cmd = "ColorizerToggle",
    after = function()
        require("colorizer").setup({
            -- other filetypes stay off until toggled with <leader>tC
            filetypes = filetypes,
            user_default_options = {
                RGB = true,
                RRGGBB = true,
                names = false,
                RRGGBBAA = true,
                mode = "background",
                tailwind = "both",
                virtualtext = " ",
            },
        })
    end,
}
