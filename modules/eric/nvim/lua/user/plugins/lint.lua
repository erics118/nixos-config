return {
    "nvim-lint",
    after = function()
        local lint = require("lint")
        lint.linters_by_ft = {
            nix = { "statix", "deadnix" },
            dockerfile = { "hadolint" },
            markdown = { "markdownlint-cli2" },
        }
        vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
            -- lint on open too, not only after the first save
            desc = "Run nvim-lint",
            group = vim.api.nvim_create_augroup("UserLint", { clear = true }),
            callback = function()
                lint.try_lint()
            end,
        })
    end,
}
