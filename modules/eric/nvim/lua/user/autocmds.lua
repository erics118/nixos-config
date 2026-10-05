local ui_guard = require("user.ui_guard")

local function group(name)
    return vim.api.nvim_create_augroup(name, { clear = true })
end

local misc = group("UserAutocmds")
local checktime = group("checktime")
local float_style = group("UserLspFloatStyle")
local lsp = group("UserLspConfig")
local numbertoggle = group("numbertoggle")

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
    desc = "Reload file if changed on disk",
    group = checktime,
    -- checktime is invalid in the q: cmdline window (E11)
    command = "if mode() != 'c' && getcmdwintype() ==# '' | checktime | endif",
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Style LSP floating windows (hover, signature help)",
    group = float_style,
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

vim.api.nvim_create_autocmd("LspAttach", {
    desc = "Set LSP keymaps the attached server supports",
    group = lsp,
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
    group = lsp,
    callback = function(ev)
        local client = vim.lsp.get_client_by_id(ev.data.client_id)
        if client and client.server_capabilities.inlayHintProvider and ui_guard.is_file_backed_buffer(ev.buf) then
            vim.lsp.inlay_hint.enable(vim.g.inlay_hints_enabled, { bufnr = ev.buf })
        end
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Enable spell checking and word wrap for prose, tex, gitcommit",
    group = misc,
    pattern = { "text", "tex", "markdown", "gitcommit" },
    -- skip markdown hover floats
    command = "if win_gettype() !=# 'popup' | setlocal spell spelllang=en_us wrap linebreak breakindent | endif",
})

-- true opens nvim-tree on every launch, not only for a directory argument
local open_tree_on_startup = false

vim.api.nvim_create_autocmd("VimEnter", {
    desc = "Open nvim-tree on startup",
    group = misc,
    once = true,
    callback = function(data)
        if vim.o.diff then
            return
        end

        local is_dir = data.file ~= "" and vim.fn.isdirectory(data.file) == 1
        if not (open_tree_on_startup or is_dir) then
            return
        end

        -- skip when launched directly into a special buffer
        if data.file ~= "" and not is_dir and vim.bo[data.buf].buftype ~= "" then
            return
        end

        vim.cmd("NvimTreeOpen")
        vim.cmd("wincmd p")
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Set 4 space indentation",
    group = misc,
    pattern = { "c", "cpp", "java", "python", "rust", "tex" },
    command = "setlocal shiftwidth=4 tabstop=4 softtabstop=4",
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Stop vimtex reindenting the line when typing } or ]",
    group = misc,
    pattern = "tex",
    command = "setlocal indentkeys-=} indentkeys-=]",
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Label vimtex surround/toggle mappings in which-key",
    group = misc,
    pattern = "tex",
    callback = function(ev)
        require("which-key").add({
            { "ds", group = "Delete surrounding", buffer = ev.buf },
            { "cs", group = "Change surrounding", buffer = ev.buf },
            { "ts", group = "Toggle", buffer = ev.buf },
            { "ts$", desc = "Toggle inline/display math", buffer = ev.buf },
            { "tse", desc = "Toggle environment", buffer = ev.buf },
            { "tss", desc = "Toggle env star", buffer = ev.buf },
            { "tsd", desc = "Toggle delimiter modifier", buffer = ev.buf },
            { "tsf", desc = "Toggle fraction", buffer = ev.buf },
            { "tsc", desc = "Toggle command star", buffer = ev.buf },
            { "dse", desc = "Delete environment", buffer = ev.buf },
            { "dsd", desc = "Delete delimiter", buffer = ev.buf },
            { "dsc", desc = "Delete command", buffer = ev.buf },
            { "cse", desc = "Change environment", buffer = ev.buf },
            { "csd", desc = "Change delimiter", buffer = ev.buf },
            { "csc", desc = "Change command", buffer = ev.buf },
        })
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Prevent nvim-tree window from scrolling horizontally",
    group = misc,
    pattern = "NvimTree",
    command = "setlocal sidescrolloff=0",
})

vim.api.nvim_create_autocmd("WinResized", {
    desc = "Remember nvim-tree width when manually resized",
    group = misc,
    callback = function()
        -- only remember width while the tree is a sidebar next to other windows
        -- skip when it is the sole window (would save full width)
        local wins = vim.tbl_filter(function(w)
            return vim.api.nvim_win_get_config(w).relative == ""
        end, vim.api.nvim_tabpage_list_wins(0))
        if #wins <= 1 then
            return
        end

        for _, win in ipairs(vim.v.event.windows) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].filetype == "NvimTree" then
                vim.g.nvim_tree_width = vim.api.nvim_win_get_width(win)
            end
        end
    end,
})

vim.api.nvim_create_autocmd("VimResized", {
    desc = "Automatically resize windows when the host window size changes.",
    group = misc,
    command = "wincmd =",
})

vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight yanked text",
    group = misc,
    callback = function()
        vim.hl.on_yank({ timeout = 200 })
    end,
})

-- smarter relative numbers
vim.api.nvim_create_autocmd({ "InsertEnter", "BufLeave", "WinLeave", "FocusLost" }, {
    desc = "Disable rnu when leaving active window",
    group = numbertoggle,
    callback = function()
        ui_guard.ft_guard(function()
            vim.opt_local.rnu = false
        end)
    end,
})

vim.api.nvim_create_autocmd({ "InsertLeave", "BufEnter", "WinEnter", "FocusGained" }, {
    desc = "Enable rnu when entering active window",
    group = numbertoggle,
    callback = function()
        ui_guard.ft_guard(function()
            vim.opt_local.rnu = vim.wo.number
        end)
    end,
})

vim.api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineLeave" }, {
    desc = "Toggle rnu around cmdline",
    group = numbertoggle,
    callback = function(data)
        ui_guard.ft_guard(function()
            vim.opt_local.rnu = data.event == "CmdlineLeave" and vim.wo.number
            vim.cmd("redraw")
        end)
    end,
})
