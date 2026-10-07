return {
    "nvim-lint",
    after = function()
        local lint = require("lint")
        lint.linters_by_ft = {
            nix = { "statix", "deadnix" },
            dockerfile = { "hadolint" },
            markdown = { "markdownlint-cli2" },
        }
        -- base markdownlint config for every project
        -- a project .markdownlint.* file replaces it, and a .markdownlint-cli2.* file merges with it
        lint.linters["markdownlint-cli2"].args =
            { "--config", vim.fs.joinpath(vim.fn.stdpath("config"), "markdownlint.jsonc"), "-" }
        vim.api.nvim_create_autocmd({ "FileType", "BufWritePost" }, {
            -- lint on open too, not only after the first save
            -- FileType, since BufReadPost runs before filetype detection here and finds no linter
            desc = "Run nvim-lint",
            group = vim.api.nvim_create_augroup("UserLint", { clear = true }),
            callback = function(ev)
                -- skip scratch buffers like LSP hover floats, which are markdown too
                if vim.bo[ev.buf].buftype ~= "" then
                    return
                end
                -- try_lint lints the current buffer, which a FileType event need not be
                vim.api.nvim_buf_call(ev.buf, lint.try_lint)
            end,
        })
    end,
}
