local ui_guard = require("user.utils.ui_guard")

local function group(name)
    return vim.api.nvim_create_augroup(name, { clear = true })
end

local misc = group("UserAutocmds")
local checktime = group("checktime")
local numbertoggle = group("numbertoggle")

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
    desc = "Reload file if changed on disk",
    group = checktime,
    -- checktime is invalid in the q: cmdline window (E11)
    command = "if mode() != 'c' && getcmdwintype() ==# '' | checktime | endif",
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Enable spell checking and word wrap for prose, tex, gitcommit",
    group = misc,
    pattern = { "text", "tex", "markdown", "gitcommit" },
    -- skip markdown hover floats
    command = "if win_gettype() !=# 'popup' | setlocal spell spelllang=en_us wrap linebreak breakindent | endif",
})

vim.api.nvim_create_autocmd("FileType", {
    desc = "Set 4 space indentation",
    group = misc,
    pattern = { "c", "cpp", "java", "python", "rust", "tex" },
    command = "setlocal shiftwidth=4 tabstop=4 softtabstop=4",
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
-- not on focus changes, whose redraw makes tmux mark the window as having new output
vim.api.nvim_create_autocmd({ "InsertEnter", "BufLeave", "WinLeave" }, {
    desc = "Disable rnu when leaving active window",
    group = numbertoggle,
    callback = function()
        ui_guard.in_editor_window(function()
            vim.opt_local.rnu = false
        end)
    end,
})

vim.api.nvim_create_autocmd({ "InsertLeave", "BufEnter", "WinEnter" }, {
    desc = "Enable rnu when entering active window",
    group = numbertoggle,
    callback = function()
        ui_guard.in_editor_window(function()
            vim.opt_local.rnu = vim.wo.number
        end)
    end,
})

vim.api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineLeave" }, {
    desc = "Toggle rnu around cmdline",
    group = numbertoggle,
    callback = function(data)
        ui_guard.in_editor_window(function()
            vim.opt_local.rnu = data.event == "CmdlineLeave" and vim.wo.number
            vim.cmd("redraw")
        end)
    end,
})
