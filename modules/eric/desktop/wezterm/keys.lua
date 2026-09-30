local wezterm = require("wezterm")

local act = wezterm.action

local is_mac = wezterm.target_triple:find("darwin") ~= nil
local MOD = is_mac and "CMD" or "CTRL|SHIFT"
local SMOD = is_mac and "SHIFT|CMD" or "CTRL|ALT"

local shortcuts = {}

local map = function(key, mods, action)
    if type(mods) == "string" then
        table.insert(shortcuts, { key = key, mods = mods, action = action })
    elseif type(mods) == "table" then
        for _, mod in pairs(mods) do
            table.insert(shortcuts, { key = key, mods = mod, action = action })
        end
    end
end

wezterm.GLOBAL.enable_tab_bar = true

local toggleTabBar = wezterm.action_callback(function(window)
    wezterm.GLOBAL.enable_tab_bar = not wezterm.GLOBAL.enable_tab_bar
    window:set_config_overrides({
        enable_tab_bar = wezterm.GLOBAL.enable_tab_bar,
    })
end)

local openUrl = act.QuickSelectArgs({
    label = "open url",
    patterns = { "https?://\\S+" },
    action = wezterm.action_callback(function(window, pane)
        local url = window:get_selection_text_for_pane(pane)
        wezterm.open_with(url)
    end),
})

local function runs_tmux(info)
    if info.executable:find("tmux$") or info.executable:find("mosh%-client$") then
        return true
    end
    -- rtmux over autossh runs a remote "tmux new ..." or "sesh-pick ..." command
    for _, arg in ipairs(info.argv) do
        if arg:find("^tmux ") or arg:find("^sesh%-pick") then
            return true
        end
    end
    -- t attaches through sesh, which stays the foreground parent of tmux
    for _, child in pairs(info.children) do
        if runs_tmux(child) then
            return true
        end
    end
    return false
end

local function in_tmux(pane)
    local info = pane:get_foreground_process_info()
    return info ~= nil and runs_tmux(info)
end

-- send the tmux prefix (default C-b) + keys when tmux (local, or remote via
-- rtmux) owns the pane. outside tmux the key does nothing
local function to_tmux(keys)
    return wezterm.action_callback(function(window, pane)
        if in_tmux(pane) then
            window:perform_action(act.SendString("\x02" .. keys), pane)
        end
    end)
end

map("a", "LEADER", act.AttachDomain("unix"))

-- use 'Backslash' to split horizontally
map("\\", "LEADER", act.SplitHorizontal({ domain = "CurrentPaneDomain" }))
-- and 'Equals' to split vertically
map("=", "LEADER", act.SplitVertical({ domain = "CurrentPaneDomain" }))
map(
    "+",
    "LEADER",
    act.PromptInputLine({
        description = "command to run in new pane",
        action = wezterm.action_callback(function(window, pane, line)
            if line then
                window:perform_action(
                    act.SplitPane({
                        direction = "Down",
                        command = { args = { "zsh", "-c", line } },
                    }),
                    pane
                )
            end
        end),
    })
)
-- map 1-9 to switch to tab 1-9, 0 for the last tab. leader or MOD+alt digits
-- pick wezterm tabs, the bare MOD digits pick tmux windows
for i = 1, 9 do
    map(tostring(i), { "LEADER", MOD .. "|ALT" }, act.ActivateTab(i - 1))
    map(tostring(i), MOD, to_tmux(tostring(i)))
end
map("0", { "LEADER" }, act.ActivateTab(-1))
-- 'hjkl' to move between panes
map("h", { "LEADER" }, act.ActivatePaneDirection("Left"))
map("j", { "LEADER" }, act.ActivatePaneDirection("Down"))
map("k", { "LEADER" }, act.ActivatePaneDirection("Up"))
map("l", { "LEADER" }, act.ActivatePaneDirection("Right"))
-- spawn & close
map("c", "LEADER", act.SpawnTab("CurrentPaneDomain"))
map("x", "LEADER", act.CloseCurrentPane({ confirm = true }))
map("w", { "LEADER", MOD .. "|ALT" }, act.CloseCurrentTab({ confirm = true }))
map("t", MOD .. "|ALT", act.SpawnTab("CurrentPaneDomain"))
-- native tab keys drive tmux windows
map("t", { MOD }, to_tmux("c"))
map("w", { MOD }, to_tmux("&"))
map("n", { SMOD }, act.SpawnWindow)
-- prev/next window, same keys as wezterm's default tab switching
map("[", SMOD, to_tmux("p"))
map("{", { MOD, SMOD }, to_tmux("p"))
map("]", SMOD, to_tmux("n"))
map("}", { MOD, SMOD }, to_tmux("n"))
-- sesh picker
map("k", { MOD }, to_tmux("s"))
-- tmux prefix, sent unchecked so it also reaches tmux over plain ssh
map("s", { MOD }, act.SendString("\x02"))
-- the linux leader is ctrl-a, so pressing it twice sends a real ctrl-a
if not is_mac then
    map("a", "LEADER|CTRL", act.SendKey({ key = "a", mods = "CTRL" }))
end
-- zoom states
map("z", { "LEADER" }, act.TogglePaneZoomState)
map("Z", { "LEADER" }, toggleTabBar)
-- copy & paste
map("v", "LEADER", act.ActivateCopyMode)
map("c", { MOD }, act.CopyTo("Clipboard"))
map("v", { MOD }, act.PasteFrom("Clipboard"))
map("f", "LEADER", act.Search("CurrentSelectionOrEmptyString"))
-- rotation
map("r", { "LEADER" }, act.RotatePanes("Clockwise"))
map("r", { "LEADER|SHIFT" }, act.RotatePanes("CounterClockwise"))
-- pickers
map(" ", "LEADER", act.QuickSelect)
map("o", { "LEADER" }, openUrl)
map("p", { "LEADER" }, act.PaneSelect({ alphabet = "asdfghjkl" }))
map("r", { "LEADER|" .. MOD }, act.ReloadConfiguration)
map("u", "LEADER", act.CharSelect)
map("P", "LEADER", act.ActivateCommandPalette)
-- view
map("-", { MOD }, act.DecreaseFontSize)
map("=", { MOD }, act.IncreaseFontSize)
map("0", { MOD }, act.ResetFontSize)
-- debug
map("d", "LEADER", act.ShowDebugOverlay)
-- app
map("q", MOD, act.QuitApplication)
map("h", MOD, act.HideApplication)
map("r", "ALT|SHIFT", act.ReloadConfiguration)

-- scroll
map("UpArrow", "SHIFT", act.ScrollByLine(-1))
map("DownArrow", "SHIFT", act.ScrollByLine(1))

map("LeftArrow", MOD, act.SendKey({ key = "LeftArrow", mods = "CTRL" }))
map("RightArrow", MOD, act.SendKey({ key = "RightArrow", mods = "CTRL" }))

map("Enter", "SHIFT", act.SendString("\x1b[13;2u"))
map("Enter", "CMD", act.SendString("\x1b[13;9u"))

local key_tables = {
    resize_mode = {
        { key = "h", action = act.AdjustPaneSize({ "Left", 1 }) },
        { key = "j", action = act.AdjustPaneSize({ "Down", 1 }) },
        { key = "k", action = act.AdjustPaneSize({ "Up", 1 }) },
        { key = "l", action = act.AdjustPaneSize({ "Right", 1 }) },
        { key = "LeftArrow", action = act.AdjustPaneSize({ "Left", 1 }) },
        { key = "DownArrow", action = act.AdjustPaneSize({ "Down", 1 }) },
        { key = "UpArrow", action = act.AdjustPaneSize({ "Up", 1 }) },
        { key = "RightArrow", action = act.AdjustPaneSize({ "Right", 1 }) },
    },
}

-- add a common escape sequence to all key tables
for k, _ in pairs(key_tables) do
    table.insert(key_tables[k], { key = "Escape", action = "PopKeyTable" })
    table.insert(key_tables[k], { key = "Enter", action = "PopKeyTable" })
end

local M = {}

M.apply_to_config = function(c)
    c.leader = {
        key = "a",
        mods = is_mac and "CMD" or "CTRL",
        timeout_milliseconds = math.maxinteger,
    }
    c.keys = shortcuts
    c.disable_default_key_bindings = true
    c.key_tables = key_tables
    c.mouse_bindings = {
        {
            event = { Down = { streak = 1, button = { WheelUp = 1 } } },
            mods = "NONE",
            action = wezterm.action.ScrollByLine(-3),
        },
        {
            event = { Down = { streak = 1, button = { WheelDown = 1 } } },
            mods = "NONE",
            action = wezterm.action.ScrollByLine(3),
        },
        -- disable normal click to open link
        {
            event = { Up = { streak = 1, button = "Left" } },
            mods = "NONE",
            action = act.CompleteSelection("ClipboardAndPrimarySelection"),
        },
        -- enable super+click to open link
        {
            event = { Up = { streak = 1, button = "Left" } },
            mods = "SUPER",
            action = act.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection"),
        },

        -- enable super+click to open link (inside tmux)
        {
            event = { Up = { streak = 1, button = "Left" } },
            mods = "SUPER",
            action = act.OpenLinkAtMouseCursor,
            mouse_reporting = true,
        },
        -- disable window drag
        {
            event = { Drag = { streak = 1, button = "Left" } },
            mods = "SUPER",
            action = act.Nop,
        },
        {
            event = { Down = { streak = 1, button = "Left" } },
            mods = "SUPER",
            action = act.Nop,
            mouse_reporting = true,
        },
        {
            event = { Drag = { streak = 1, button = "Left" } },
            mods = "CTRL|SHIFT",
            action = act.Nop,
        },
    }
end

return M
