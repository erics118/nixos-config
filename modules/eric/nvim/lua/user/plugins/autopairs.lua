return {
    "nvim-autopairs",
    -- loaded once the screen is drawn, so the first insert doesn't wait on it
    event = { "DeferredUIEnter", "InsertEnter" },
    after = function()
        local npairs = require("nvim-autopairs")
        npairs.setup({
            -- enable treesitter integration
            check_ts = true,
            -- $ omitted here so pairs still close when the next char is a closing $
            ignored_next_char = [==[[%w%%%'%[%"%.%`]]==],
        })

        local Rule = require("nvim-autopairs.rule")
        -- auto-close math delimiters, tex only
        npairs.add_rules({
            Rule("$", "$", "tex"),
            Rule("\\[", "\\]", "tex"),
        })
    end,
}
