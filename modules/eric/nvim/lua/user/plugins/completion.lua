local function luasnip_forward()
    local ls = require("luasnip")
    if ls.expand_or_jumpable() then
        ls.expand_or_jump()
        return true
    end
end

local function luasnip_backward()
    local ls = require("luasnip")
    if ls.jumpable(-1) then
        ls.jump(-1)
        return true
    end
end

-- fall back to the builtin key (digraph, newline) when no snippet is active
vim.keymap.set({ "i", "s" }, "<C-j>", function()
    if not luasnip_forward() then
        vim.api.nvim_feedkeys(vim.keycode("<C-j>"), "n", false)
    end
end, { silent = true, desc = "Snippet jump forward" })
vim.keymap.set({ "i", "s" }, "<C-k>", function()
    if not luasnip_backward() then
        vim.api.nvim_feedkeys(vim.keycode("<C-k>"), "n", false)
    end
end, { silent = true, desc = "Snippet jump back" })

return {
    {
        "luasnip",
        -- loaded once the screen is drawn, so the first insert doesn't wait on it
        event = { "DeferredUIEnter", "InsertEnter" },
        after = function()
            require("luasnip").config.setup({
                enable_autosnippets = true,
                -- re-enterable snippets so <C-k> jumps back after the last node
                keep_roots = true,
                link_children = true,
                exit_roots = false,
                -- roots stay unlinked: <Tab> both jumps and indents, so a linked root would steal it
                link_roots = false,
                -- drop a snippet once the cursor leaves its region, also when o/A start insert elsewhere
                region_check_events = { "CursorMoved", "InsertEnter" },
                delete_check_events = "TextChanged",
            })
        end,
    },
    {
        -- loaded at startup: its plugin/ script adds completion capabilities
        -- to vim.lsp.config("*"), which must happen before any server starts
        "blink.cmp",
        after = function()
            require("blink.cmp").setup({
                keymap = {
                    preset = "none",
                    ["<C-Space>"] = { "show" },
                    ["<C-e>"] = { "cancel", "fallback" },
                    ["<C-n>"] = { "select_next", "fallback" },
                    ["<C-p>"] = { "select_prev", "fallback" },
                    -- confirms only an item picked with <C-n>/<C-p>, otherwise a newline
                    ["<CR>"] = { "accept", "fallback" },
                    ["<Tab>"] = { "select_and_accept", luasnip_forward, "fallback" },
                    ["<S-Tab>"] = { luasnip_backward, "fallback" },
                },
                completion = {
                    list = { selection = { preselect = false, auto_insert = false } },
                    documentation = { auto_show = true },
                    menu = {
                        draw = {
                            columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "kind" } },
                            components = { label = { width = { fill = true, max = 50 } } },
                        },
                    },
                },
                snippets = { preset = "luasnip" },
                sources = {
                    default = { "lsp", "snippets", "buffer", "path" },
                    -- vimtex completes through its omnifunc
                    per_filetype = { tex = { "omni", "snippets", "lsp", "buffer", "path" } },
                    providers = {
                        -- buffer words show alongside lsp items, not only when lsp has none
                        lsp = { fallbacks = {} },
                        -- texlab is fallback so commands aren't duplicated
                        omni = { fallbacks = { "lsp", "buffer", "path" } },
                    },
                },
                cmdline = {
                    -- the cmdline preset selects with <Left>/<Right>, so the cursor could not move while the menu shows
                    keymap = { preset = "cmdline", ["<Left>"] = false, ["<Right>"] = false },
                    completion = { menu = { auto_show = true } },
                },
            })
        end,
    },
}
