vim.diagnostic.config({
    -- an error sign wins over a warning on the same line
    severity_sort = true,
    virtual_text = { current_line = true },
    jump = {
        -- open the diagnostic float after ]d/[d jumps
        on_jump = function(diagnostic, bufnr)
            if diagnostic then
                vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
            end
        end,
    },
})

-- for servers whose lspconfig cmd is a function: neovim only skips a missing binary when cmd is a list,
-- so these would warn on every open outside a devshell. start them only when the binary is on PATH
-- or in the project's node_modules/.bin, which their cmd also checks
local function when_installed(name, bin)
    local config = assert(vim.lsp.config[name], name .. " has no lsp config")
    return function(bufnr, on_dir)
        local function start(root)
            local project_bin = root and vim.fs.joinpath(root, "node_modules/.bin", bin)
            if vim.fn.executable(bin) == 1 or (project_bin and vim.fn.executable(project_bin) == 1) then
                on_dir(root)
            end
        end
        if config.root_dir then
            config.root_dir(bufnr, start)
        else
            start(vim.fs.root(bufnr, config.root_markers))
        end
    end
end

-- server configs beyond nvim-lspconfig's defaults
-- schemastore is required in before_init, so its schema tables load only when the server starts
local servers = {
    astro = { root_dir = when_installed("astro", "astro-ls") },
    bashls = {},
    clangd = {
        cmd = {
            "clangd",
            -- probe the compile_commands driver so libc++/pkg headers resolve
            "--query-driver=/nix/store/*/bin/*clang++,/nix/store/*/bin/*clang,/nix/store/*/bin/*g++,/nix/store/*/bin/*gcc,/nix/store/*/bin/*c++,/nix/store/*/bin/*cc,/usr/bin/clang++,/usr/bin/clang,/usr/bin/g++,/usr/bin/gcc,/usr/bin/c++,/usr/bin/cc,/opt/homebrew/bin/*",
            "--completion-style=detailed",
            "-j=8",
        },
    },
    cmake = {},
    cssls = {
        -- tailwind v4 at-rules (@theme, @custom-variant, @utility) are not in
        -- cssls' known-at-rule list; tailwindcss-language-server validates them
        settings = {
            css = { lint = { unknownAtRules = "ignore" } },
            scss = { lint = { unknownAtRules = "ignore" } },
            less = { lint = { unknownAtRules = "ignore" } },
        },
    },
    dockerls = {},
    eslint = {},
    gopls = {},
    hls = { settings = { haskell = { formattingProvider = "fourmolu" } } },
    html = {},
    jdtls = { root_dir = when_installed("jdtls", "jdtls") },
    jsonls = {
        settings = { json = { validate = { enable = true } } },
        before_init = function(_, config)
            config.settings.json.schemas = require("schemastore").json.schemas()
        end,
    },
    lua_ls = {},
    marksman = {},
    nextls = {},
    nixd = {},
    ocamllsp = {
        -- ocaml-lsp reads these from settings (didChangeConfiguration), not init_options
        settings = {
            codelens = { enable = true },
            extendedHover = { enable = true },
            inlayHints = { hintPatternVariables = true, hintLetBindings = true, hintFunctionParams = true },
        },
    },
    -- types
    pyright = {},
    -- lint + code actions
    ruff = {
        -- leave hover to pyright, cleared on init so Neovim never maps K to ruff's empty hover
        on_init = function(client)
            client.server_capabilities.hoverProvider = false
        end,
    },
    rust_analyzer = {
        settings = {
            ["rust-analyzer"] = {
                cargo = { features = "all" },
                check = { command = "clippy", extraArgs = { "--no-deps" } },
                inlayHints = {
                    bindingModeHints = { enable = true },
                    closureReturnTypeHints = { enable = "always" },
                    lifetimeElisionHints = { enable = "always" },
                },
            },
        },
    },
    -- Tailwind's upstream filetype list is very broad
    -- only activate it when the nearest package.json declares Tailwind
    tailwindcss = { root_dir = require("user.tailwind_root") },
    taplo = {},
    texlab = {
        settings = {
            texlab = {
                build = {
                    executable = "latexmk",
                    args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f" },
                    -- vimtex owns compiling (\ll), so saving doesn't start a second latexmk
                    onSave = false,
                    forwardSearchAfter = false,
                },
                forwardSearch = {
                    executable = "/Applications/Nix Apps/Skim.app/Contents/SharedSupport/displayline",
                    args = { "-r", "%l", "%p", "%f" },
                },
                chktex = { onEdit = true, onOpenAndSave = true },
                diagnosticsDelay = 300,
                formatterLineLength = 100,
                latexFormatter = "none",
            },
        },
    },
    ts_ls = { root_dir = when_installed("ts_ls", "typescript-language-server") },
    -- spell-check across all buffers
    typos_lsp = {},
    yamlls = {
        settings = {
            yaml = {
                -- schemastore.nvim supplies the schemas instead of the built-in store
                schemaStore = { enable = false, url = "" },
                suggest = { parentSkeletonSelectedFirst = true },
            },
        },
        before_init = function(_, config)
            config.settings.yaml.schemas = require("schemastore").yaml.schemas()
        end,
    },
    zls = {},
}

for name, config in pairs(servers) do
    vim.lsp.config(name, config)
    vim.lsp.enable(name)
end

local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { silent = true, desc = desc })
end

map("<leader>k", vim.lsp.buf.signature_help, "Signature help")
map("<leader>lr", "<Cmd>lsp restart<CR>", "Restart LSP")
map("<leader>ti", function()
    vim.g.inlay_hints_enabled = not vim.g.inlay_hints_enabled
    vim.lsp.inlay_hint.enable(vim.g.inlay_hints_enabled)
    vim.notify("Inlay hints: " .. (vim.g.inlay_hints_enabled and "ON" or "OFF"), vim.log.levels.INFO)
end, "Toggle inlay hints")
map("<leader>wa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
map("<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
