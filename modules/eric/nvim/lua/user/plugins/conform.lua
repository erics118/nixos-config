vim.keymap.set({ "n", "x" }, "<leader>lf", function()
    require("conform").format({ async = true })
end, { silent = true, desc = "Format buffer or range" })
vim.keymap.set("n", "<leader>li", "<cmd>ConformInfo<CR>", { silent = true, desc = "Conform formatter info" })

local prettier = { "prettier" }

return {
    "conform.nvim",
    after = function()
        require("conform").setup({
            notify_on_error = false,
            -- LSP source fixes (user/lsp_fix.lua) run first, so formatting sees their edits
            format_on_save = function(bufnr)
                require("user.lsp_fix").run(bufnr)
                return { timeout_ms = 800 }
            end,
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
