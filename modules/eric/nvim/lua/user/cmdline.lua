local api = vim.api
local ui2 = require("vim._core.ui2")

-- the pager closes with <Esc> as well as ui2's own q
api.nvim_create_autocmd("FileType", {
    pattern = "pager",
    callback = function(ev)
        vim.keymap.set("n", "<Esc>", "<Cmd>wincmd c<CR>", { buf = ev.buf, desc = "Close pager" })
    end,
})

-- the centered cmdline is a float with no fill, only a mauve border
-- ui2 already maps Normal to MsgArea here, but floats draw with NormalFloat
api.nvim_create_autocmd("FileType", {
    pattern = "cmd",
    callback = function()
        vim.wo.winhighlight = vim.wo.winhighlight .. ",NormalFloat:MsgArea,FloatBorder:CmdlineBorder"
    end,
})

-- the message float has no fill either, only its border
api.nvim_create_autocmd("FileType", {
    pattern = "msg",
    callback = function()
        vim.wo.winhighlight = vim.wo.winhighlight .. ",NormalFloat:MsgArea,FloatBorder:MsgBorder"
    end,
})

-- the cmdline and messages get their own windows, so statusline redraws can't cover them
-- the bottom output row would sit on the statusline, so list and :! output opens in the pager above it
-- every other message times out in a float
ui2.enable({
    msg = {
        -- read by ui2 (ui2.lua defaults) but missing from :h ui2
        target = "msg",
        targets = {
            list_cmd = "pager",
            shell_cmd = "pager",
            shell_out = "pager",
            shell_err = "pager",
            shell_ret = "pager",
        },
    },
})

-- ui2.wins is private ui2 state, not a stable API
local function cmd_win()
    local win = ui2.wins.cmd
    return win and api.nvim_win_is_valid(win) and win
end

-- ui2 puts dialogs and expanded output on the bottom row, which is the statusline at 'cmdheight' 0
-- they go just above it instead, like ui2 places the pager
-- overrides a private ui2 function and reads ui2.wins, neither a stable API
local messages = require("vim._core.ui2.messages")
local set_pos = messages.set_pos
messages.set_pos = function(...)
    set_pos(...)
    for _, type in ipairs({ "cmd", "dialog" }) do
        local win = ui2.wins[type]
        if api.nvim_win_is_valid(win) then
            local cfg = api.nvim_win_get_config(win)
            if not cfg.hide and cfg.relative == "laststatus" and cfg.row ~= 0 then
                api.nvim_win_set_config(win, { relative = "laststatus", anchor = "SW", row = 0, col = 0 })
            end
        end
    end
end

-- ui2 sets 'cmdheight' to 1 while the cmdline shows, which pushes the statusline up
-- the centered window needs no bottom row, so it goes back to 0
-- overrides a private ui2 function, and vim._with is a private Neovim helper, neither a stable API
local cmdline = require("vim._core.ui2.cmdline")
local cmdline_show = cmdline.cmdline_show
cmdline.cmdline_show = function(...)
    cmdline_show(...)
    if vim.o.cmdheight ~= 0 then
        vim._with({ noautocmd = true, o = { splitkeep = "screen" } }, function()
            vim.o.cmdheight = 0
        end)
    end
end

local group = api.nvim_create_augroup("UserCmdline", { clear = true })

-- ui2 has no position option, so the cmdline window is moved to the center while typing
-- ui2 owns this window and may reposition it in ways this doesn't expect
api.nvim_create_autocmd("CmdlineEnter", {
    group = group,
    callback = function()
        local win = cmd_win()
        if not win then
            return
        end
        local width = math.min(80, vim.o.columns - 4)
        local row = math.floor((vim.o.lines - 3) / 2)
        local col = math.floor((vim.o.columns - width - 2) / 2)
        api.nvim_win_set_config(win, { relative = "editor", row = row, col = col, width = width, border = "rounded" })
        -- blink.cmp anchors its cmdline menu here, (1, 0)-indexed
        vim.g.ui_cmdline_pos = { row + 2, col + 1 }
    end,
})

-- back to ui2's default spot, which its own placement of dialogs and expanded output starts from
-- moved only once ui2 has hidden it, so the old text never draws over the statusline
-- overrides a private ui2 function and reads cmdline.level, neither a stable API
local cmdline_hide = cmdline.cmdline_hide
cmdline.cmdline_hide = function(...)
    cmdline_hide(...)
    local win = cmd_win()
    if not win or cmdline.level ~= 0 then
        return
    end
    api.nvim_win_set_config(win, { relative = "laststatus", row = 1, col = 0, width = 10000, border = "none" })
    vim.g.ui_cmdline_pos = nil
end
