return {
    "nvim-autopairs",
    event = require("user.utils.lazy").insert_events,
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
