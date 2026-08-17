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
-- map 1-9 to switch to tab 1-9, 0 for the last tab
for i = 1, 9 do
    map(tostring(i), { "LEADER", MOD }, act.ActivateTab(i - 1))
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
map("t", { MOD }, act.SpawnTab("CurrentPaneDomain"))
map("w", { MOD }, act.CloseCurrentTab({ confirm = true }))
map("n", { SMOD }, act.SpawnWindow)
-- zoom states
map("z", { "LEADER" }, act.TogglePaneZoomState)
map("Z", { "LEADER" }, toggleTabBar)
-- copy & paste
map("v", "LEADER", act.ActivateCopyMode)
map("c", { MOD }, act.CopyTo("Clipboard"))
map("v", { MOD }, act.PasteFrom("Clipboard"))
map("f", { SMOD }, act.Search("CurrentSelectionOrEmptyString"))
-- rotation
map("r", { "LEADER" }, act.RotatePanes("Clockwise"))
map("r", { "LEADER|SHIFT" }, act.RotatePanes("CounterClockwise"))
-- pickerg
map(" ", "LEADER", act.QuickSelect)
map("o", { "LEADER" }, openUrl)
map("p", { "LEADER" }, act.PaneSelect({ alphabet = "asdfghjkl" }))
map("r", { "LEADER|" .. MOD }, act.ReloadConfiguration)
map("u", SMOD, act.CharSelect)
map("p", { SMOD }, act.ActivateCommandPalette)
-- view
map("-", { MOD }, act.DecreaseFontSize)
map("=", { MOD }, act.IncreaseFontSize)
map("0", { MOD }, act.ResetFontSize)
-- debug
map("l", SMOD, act.ShowDebugOverlay)
-- app
map("q", MOD, act.QuitApplication)
map("h", MOD, act.HideApplication)
map("r", "ALT|SHIFT", act.ReloadConfiguration)

-- scroll
map("UpArrow", "SHIFT", act.ScrollByLine(-1))
map("DownArrow", "SHIFT", act.ScrollByLine(1))

map("LeftArrow", MOD, act.SendKey({ key = "LeftArrow", mods = "CTRL" }))
map("RightArrow", MOD, act.SendKey({ key = "RightArrow", mods = "CTRL" }))

-- from claude code
map("Enter", "SHIFT", act.SendString("\x1b\r"))

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
        key = is_mac and "s" or "a",
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
