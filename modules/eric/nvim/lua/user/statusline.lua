-- the statusline shows the search count, so the cmdline doesn't repeat [1/32]
vim.opt.shortmess:append("S")
-- otherwise the quickfix ftplugin sets its own statusline, which replaces this global one
vim.g.qf_disable_statusline = 1

local mode_info = {
    n = { "NORMAL", "blue" },
    i = { "INSERT", "green" },
    v = { "VISUAL", "mauve" },
    V = { "V-LINE", "mauve" },
    ["\22"] = { "V-BLOCK", "mauve" },
    s = { "SELECT", "mauve" },
    S = { "S-LINE", "mauve" },
    ["\19"] = { "S-BLOCK", "mauve" },
    R = { "REPLACE", "red" },
    c = { "COMMAND", "peach" },
    r = { "PROMPT", "peach" },
    ["!"] = { "SHELL", "peach" },
    t = { "TERMINAL", "teal" },
}

-- nerd font powerline glyphs
local sep_left = "\238\130\184" -- U+E0B8
local sep_right = "\238\130\186" -- U+E0BA
local thin_left = "\238\130\185" -- U+E0B9
local branch_icon = "\238\130\160" -- U+E0A0
local diff_items = {
    { "added", "+", "GitSignsAdd" },
    { "changed", "~", "GitSignsChange" },
    { "removed", "-", "GitSignsDelete" },
}
local diag_items = {
    { vim.diagnostic.severity.ERROR, "\243\176\133\154 ", "DiagnosticError" },
    { vim.diagnostic.severity.WARN, "\243\176\128\170 ", "DiagnosticWarn" },
    { vim.diagnostic.severity.INFO, "\243\176\139\189 ", "DiagnosticInfo" },
    { vim.diagnostic.severity.HINT, "\243\176\140\182 ", "DiagnosticHint" },
}

-- a = mode block, b = gray section, c = transparent middle
local function set_statusline_hl()
    local p = require("catppuccin.palettes").get_palette()
    for _, color in ipairs({ "blue", "green", "mauve", "red", "peach", "teal" }) do
        vim.api.nvim_set_hl(0, "StlA_" .. color, { fg = p.crust, bg = p[color], bold = true })
        vim.api.nvim_set_hl(0, "StlSepAB_" .. color, { fg = p[color], bg = p.surface0 })
        vim.api.nvim_set_hl(0, "StlSepAC_" .. color, { fg = p[color] })
    end
    vim.api.nvim_set_hl(0, "StlB", { fg = p.text, bg = p.surface0 })
    vim.api.nvim_set_hl(0, "StlBThin", { fg = p.overlay0, bg = p.surface0 })
    vim.api.nvim_set_hl(0, "StlSepBC", { fg = p.surface0 })
    for _, item in ipairs(vim.list_extend(vim.deepcopy(diff_items), diag_items)) do
        local fg = vim.api.nvim_get_hl(0, { name = item[3], link = false }).fg
        vim.api.nvim_set_hl(0, "StlB_" .. item[3], { fg = fg, bg = p.surface0 })
    end
end
set_statusline_hl()

-- % in names would be read as statusline items
local function escape_percent(s)
    return (s:gsub("%%", "%%%%"))
end

-- %l and %c always describe the window that owns the statusline
-- so when rendering for another window, pos holds that window's values as plain text
local function render(pos)
    local mode = vim.api.nvim_get_mode().mode
    local info = mode_info[mode:sub(1, 1)] or { mode:upper(), "blue" }
    local color = info[2]

    -- section b: branch, diff, diagnostics, split by thin separators
    local b = {}
    -- non-file buffers (tree, help, terminal) fall back to the cwd's branch
    local head = vim.b.gitsigns_head or (vim.bo.buftype ~= "" and vim.g.gitsigns_head)
    if head and head ~= "" then
        b[#b + 1] = "%#StlB#" .. branch_icon .. " " .. escape_percent(head)
    end
    local diff = vim.b.gitsigns_status_dict
    if diff then
        local parts = {}
        for _, d in ipairs(diff_items) do
            if (diff[d[1]] or 0) > 0 then
                parts[#parts + 1] = "%#StlB_" .. d[3] .. "#" .. d[2] .. diff[d[1]]
            end
        end
        if #parts > 0 then
            b[#b + 1] = table.concat(parts, " ")
        end
    end
    local counts = vim.diagnostic.count(0)
    local diags = {}
    for _, d in ipairs(diag_items) do
        if (counts[d[1]] or 0) > 0 then
            diags[#diags + 1] = "%#StlB_" .. d[3] .. "#" .. d[2] .. counts[d[1]]
        end
    end
    if #diags > 0 then
        b[#b + 1] = table.concat(diags, " ")
    end

    -- the hidden cmdline row can't show "recording @a", so the mode block does
    local rec = vim.fn.reg_recording()
    local mode_text = rec ~= "" and info[1] .. " REC @" .. rec or info[1]

    -- %< after the mode: on a narrow screen the sections after it truncate, not the mode
    local left = "%#StlA_" .. color .. "# " .. mode_text .. " %<"
    if #b > 0 then
        left = left
            .. "%#StlSepAB_"
            .. color
            .. "#"
            .. sep_left
            .. "%#StlB# "
            .. table.concat(b, " %#StlBThin#" .. thin_left .. " ")
            .. " "
            .. "%#StlSepBC#"
            .. sep_left
    else
        left = left .. "%#StlSepAC_" .. color .. "#" .. sep_left
    end

    -- section c: search count
    local mid = ""
    if vim.v.hlsearch == 1 then
        -- runs on every redraw, so keep the scan short
        local ok, sc = pcall(vim.fn.searchcount, { maxcount = 999, timeout = 20 })
        if ok and (sc.total or 0) > 0 then
            -- incomplete: 1 = timed out, 2 = more than maxcount matches
            local function count(n)
                return n > sc.maxcount and (">" .. sc.maxcount) or tostring(n)
            end
            local total = sc.incomplete == 1 and "?" or count(sc.total)
            mid = "%#StatusLine# [" .. count(sc.current) .. "/" .. total .. "]"
        end
    end

    -- right side: filetype, then position (mode color)
    local right = ""
    local ft = vim.bo.filetype
    if ft ~= "" then
        local ok, devicons = pcall(require, "nvim-web-devicons")
        local icon, icon_hl
        if ok then
            icon, icon_hl = devicons.get_icon_by_filetype(ft)
        end
        right = (icon and ("%#" .. (icon_hl or "StatusLine") .. "#" .. icon .. " ") or "")
            .. "%#StatusLine#"
            .. escape_percent(ft)
            .. " "
    end
    right = right
        .. "%#StlSepAC_"
        .. color
        .. "#"
        .. sep_right
        .. "%#StlA_"
        .. color
        .. "# "
        .. (pos and pos.cursor or "%l:%c")
        .. " "

    return left .. mid .. "%#StatusLine#%=" .. right
end

-- a focused float (telescope prompt) would otherwise supply the bar's buffer info
-- show the previous normal window instead; g:statusline_winid is the float too
function _G.Statusline()
    if vim.api.nvim_win_get_config(0).relative ~= "" then
        local prev = vim.fn.win_getid(vim.fn.winnr("#"))
        if prev ~= 0 and vim.api.nvim_win_get_config(prev).relative == "" then
            return vim.api.nvim_win_call(prev, function()
                return render({ cursor = vim.fn.line(".") .. ":" .. vim.fn.col(".") })
            end)
        end
    end
    return render()
end

vim.o.statusline = "%!v:lua.Statusline()"

local group = vim.api.nvim_create_augroup("UserStatusline", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_statusline_hl })
-- these change what the statusline shows without a redraw of their own
vim.api.nvim_create_autocmd({ "ModeChanged", "DiagnosticChanged" }, {
    group = group,
    callback = function()
        vim.cmd.redrawstatus()
    end,
})
-- scheduled, since reg_recording() still names the register during RecordingLeave
vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
    group = group,
    callback = function()
        vim.schedule(vim.cmd.redrawstatus)
    end,
})
vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "GitSignsUpdate",
    callback = function()
        vim.cmd.redrawstatus()
    end,
})
