return {
    "bufferline.nvim",
    after = function()
        require("bufferline").setup({ highlights = require("catppuccin.special.bufferline").get_theme() })
    end,
}
