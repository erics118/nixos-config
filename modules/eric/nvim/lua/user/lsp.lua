local map = require("user.utils.map")
local ui_guard = require("user.utils.ui_guard")

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
-- or in the project's node_modules/.bin, which the astro, tailwindcss, and ts_ls cmds also check
-- root_dir replaces the lspconfig one when given
local function when_installed(name, bin, root_dir)
    local config = assert(vim.lsp.config[name], name .. " has no lsp config")
    root_dir = root_dir or config.root_dir
    return function(bufnr, on_dir)
        local function start(root)
            local project_bin = root and vim.fs.joinpath(root, "node_modules/.bin", bin)
            if vim.fn.executable(bin) == 1 or (project_bin and vim.fn.executable(project_bin) == 1) then
                on_dir(root)
            end
        end
        if root_dir then
            root_dir(bufnr, start)
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
        handlers = {
            -- jsonc files (including .hujson) may use trailing commas
            -- 519 is jsonls' trailing comma code
            ["textDocument/diagnostic"] = function(err, result, ctx)
                local bufnr = vim.uri_to_bufnr(ctx.params.textDocument.uri)
                if result and result.items and vim.bo[bufnr].filetype == "jsonc" then
                    result.items = vim.tbl_filter(function(d)
                        return d.code ~= 519
                    end, result.items)
                end
                return vim.lsp.handlers["textDocument/diagnostic"](err, result, ctx)
            end,
        },
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
    tailwindcss = {
        root_dir = when_installed("tailwindcss", "tailwindcss-language-server", require("user.tailwind_root")),
    },
    taplo = {},
    -- vimtex owns compiling and the skim viewer, so texlab only completes and lints
    texlab = {
        settings = {
            texlab = {
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

vim.g.inlay_hints_enabled = true

-- non-file buffers (hover floats, plugin views) never get inlay hints
local function apply_inlay_hints(buf)
    if ui_guard.is_file_backed_buffer(buf) then
        vim.lsp.inlay_hint.enable(vim.g.inlay_hints_enabled, { bufnr = buf })
    end
end

local group = vim.api.nvim_create_augroup("UserLspConfig", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
    desc = "Set LSP keymaps the attached server supports",
    group = group,
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if not client then
            return
        end
        local maps = {
            { "gd", "textDocument/definition", vim.lsp.buf.definition, "Go to definition" },
            { "gD", "textDocument/declaration", vim.lsp.buf.declaration, "Go to declaration" },
            {
                "K",
                "textDocument/hover",
                function()
                    vim.lsp.buf.hover({ max_width = 80, max_height = 20 })
                end,
                "Hover documentation",
            },
        }
        for _, m in ipairs(maps) do
            if client:supports_method(m[2], ev.buf) then
                vim.keymap.set("n", m[1], m[3], { buf = ev.buf, desc = m[4] })
            end
        end
    end,
})

vim.api.nvim_create_autocmd("LspAttach", {
    desc = "Enable inlay hints on LSP attach",
    group = group,
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client and client.server_capabilities.inlayHintProvider then
            apply_inlay_hints(ev.buf)
        end
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Style LSP floating windows (hover, signature help)",
    group = vim.api.nvim_create_augroup("UserLspFloatStyle", { clear = true }),
    pattern = "markdown",
    callback = function(ev)
        local win = vim.api.nvim_get_current_win()
        if vim.api.nvim_win_get_config(win).relative == "" then
            return
        end
        vim.wo[win].winbar = ""
        vim.wo[win].relativenumber = false
        vim.wo[win].scrolloff = 0
        vim.wo[win].conceallevel = 0
        vim.wo[win].concealcursor = ""
        vim.wo[win].number = vim.api.nvim_buf_line_count(ev.buf) > 10

        -- skip past leading blank lines so hover doesn't open on whitespace
        local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
        local first = 1
        while first <= #lines and lines[first]:match("^%s*$") do
            first = first + 1
        end
        if first > 1 and first <= #lines then
            vim.api.nvim_win_set_cursor(win, { first, 0 })
        end
    end,
})

map("n", "<leader>k", vim.lsp.buf.signature_help, "Signature help")
map("n", "<leader>D", vim.lsp.buf.type_definition, "Type definition")
map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
map("n", "<leader>e", vim.diagnostic.open_float, "Open diagnostic float")
map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
map("n", "<leader>lr", "<Cmd>lsp restart<CR>", "Restart LSP")
map("n", "<leader>ti", function()
    vim.g.inlay_hints_enabled = not vim.g.inlay_hints_enabled
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) then
            apply_inlay_hints(buf)
        end
    end
    vim.notify("Inlay hints: " .. (vim.g.inlay_hints_enabled and "ON" or "OFF"), vim.log.levels.INFO)
end, "Toggle inlay hints")
map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
