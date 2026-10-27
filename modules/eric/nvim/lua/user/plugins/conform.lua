local map = require("user.utils.map")

map({ "n", "x" }, "<leader>lf", function()
    require("conform").format({ async = true })
end, "Format buffer or range")
map("n", "<leader>li", "<cmd>ConformInfo<CR>", "Conform formatter info")

local prettier = { "prettier" }

return {
    "conform.nvim",
    after = function()
        require("conform").setup({
            notify_on_error = false,
            -- LSP source fixes (user/lsp_save_actions.lua) run before the write
            -- formatting runs after it in the background, so a slow formatter doesn't block :w
            format_on_save = function(bufnr)
                -- conform-internal flag, set while format_after_save rewrites the buffer
                -- the fixes already ran before the first write
                if vim.b[bufnr].conform_applying_formatting then
                    return
                end
                require("user.lsp_save_actions").run(bufnr)
            end,
            format_after_save = { timeout_ms = 800 },
            -- per-filetype lsp_format only applies when callers don't pass their own
            default_format_opts = { lsp_format = "fallback" },
            formatters = {
                -- read the project's localSettings.yaml so nvim and treefmt use one config
                latexindent = {
                    prepend_args = { "-g", "/dev/null", "-l", "localSettings.yaml" },
                    cwd = require("conform.util").root_file({ "localSettings.yaml" }),
                },
                -- treefmt-nix runs shfmt with these, so format-on-save agrees with it
                -- instead of reindenting every shell script to tabs
                shfmt = { prepend_args = { "-i", "2", "-s" } },
                -- prettier can't infer a parser from the .hujson extension
                prettier = {
                    prepend_args = function(_, ctx)
                        return ctx.filename:match("%.hujson$") and { "--parser", "jsonc" } or {}
                    end,
                },
            },
            formatters_by_ft = {
                -- trim whitespace, then let the LSP format filetypes with no entry here
                _ = { "trim_whitespace", "trim_newlines", lsp_format = "last" },
                lua = { "stylua" },
                nix = { "nixfmt" },
                sh = { "shfmt" },
                bash = { "shfmt" },

                javascript = prettier,
                javascriptreact = prettier,
                typescript = prettier,
                typescriptreact = prettier,
                astro = prettier,
                css = prettier,
                scss = prettier,
                less = prettier,
                html = prettier,
                graphql = prettier,
                vue = prettier,
                svelte = prettier,
                json = prettier,
                jsonc = prettier,
                json5 = prettier,
                yaml = prettier,
                markdown = prettier,

                toml = { "taplo" },
                just = { "just" },
                cmake = { "gersemi" },
                python = { "ruff_format", "ruff_organize_imports" },
                go = { "gofmt" },
                rust = { "rustfmt" },
                tex = { "latexindent" },
                ocaml = { "ocamlformat" },
                c = { "clang_format" },
                cpp = { "clang_format" },
                cuda = { "clang_format" },
                zig = { "zigfmt" },
                haskell = { "fourmolu" },
                elixir = { "mix" },
            },
        })
    end,
}
