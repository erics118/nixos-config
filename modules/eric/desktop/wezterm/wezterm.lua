local wezterm = require("wezterm")

local c = wezterm.config_builder()
c:set_strict_mode(true)

require("keys").apply_to_config(c)

-- behavior

-- nix builds report a commit hash as the version, which the update check
-- compares against release tags as strings
c.check_for_updates = false
c.exit_behavior = "Close"

c.skip_close_confirmation_for_processes_named = {
    "bash",
    "sh",
    "zsh",
    "fish",
    "nu",
    -- windows
    "cmd.exe",
    "pwsh.exe",
    "powershell.exe",
    -- wsl
    "wsl.exe",
    "wslhost.exe",
    "conhost.exe",
}

-- closing a tab returns to the one used before it, not its left neighbor
c.switch_to_last_active_tab_when_closing_tab = true

-- yabai doesn't focus on hover, so the click that focuses a window also reaches the pane
c.swallow_mouse_click_on_window_focus = false

-- double-click stops at punctuation and tmux pane borders
c.selection_word_boundary = " \t\n{[}]()\"'`,;:│"

-- super+click opens owner/repo#123 as a github issue or pr
c.hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(c.hyperlink_rules, {
    regex = [[\b([\w.-]+/[\w.-]+)#(\d+)\b]],
    format = "https://github.com/$1/issues/$2",
})

-- quick select greys out the screen's colors so its labels stand out
c.quick_select_remove_styling = true

-- no beep or flash, a bell only marks its tab (see bar.lua)
c.audible_bell = "Disabled"

-- domains
c.unix_domains = {
    { name = "unix" },
}
c.ssh_domains = {
    { name = "narwhal", remote_address = "narwhal", multiplexing = "None" },
}

-- input
c.send_composed_key_when_left_alt_is_pressed = false
-- programs run directly in wezterm can tell Tab from Ctrl+I, Enter from Ctrl+M
-- tmux gets the same through its own extended-keys setting
c.enable_kitty_keyboard = true

-- text
c.font = wezterm.font("Hack Nerd Font")
c.font_size = 12.0
c.command_palette_font_size = 12.0
c.freetype_load_target = "Light"
c.default_cursor_style = "SteadyBar"
c.underline_thickness = 2.5

-- window
if wezterm.target_triple:find("linux") then
    c.window_decorations = "NONE"
else
    c.window_decorations = "RESIZE | TITLE | MACOS_FORCE_ENABLE_SHADOW | MACOS_USE_BACKGROUND_COLOR_AS_TITLEBAR_COLOR"
end

c.window_padding = {
    left = 12,
    right = 12,
    top = 0,
    bottom = 12,
}
c.window_content_alignment = {
    horizontal = "Center",
    vertical = "Center",
}
c.adjust_window_size_when_changing_font_size = false
c.window_background_opacity = 0.95
c.macos_window_background_blur = 20

-- metal on macos and vulkan on linux, instead of opengl
c.front_end = "WebGpu"

-- match the 120hz promotion display
c.max_fps = 120

-- dim unfocused panes
c.inactive_pane_hsb = {
    saturation = 1.0,
    brightness = 0.6,
}

-- scrollback
c.scrollback_lines = 10000
c.mouse_wheel_scrolls_tabs = false

-- colors
local theme = wezterm.color.get_builtin_schemes()["Catppuccin Mocha"]

theme.tab_bar.background = "rgba(0, 0, 0, 0)"

c.color_schemes = {
    ["Catppuccin Mocha"] = theme,
}

c.color_scheme = "Catppuccin Mocha"

require("bar").apply_to_config(c, {
    dividers = "slant_right",
    indicator = {
        leader = {
            off = "",
            on = "",
        },
    },
    tabs = {
        numerals = "arabic",
        pane_count = "superscript",
        tab_format = {
            active = "{tab_index}: {tab_title}{pane_count}",
            inactive = "{tab_index}: {tab_title}{pane_count}",
        },
    },
})

wezterm.on("format-window-title", function(tab)
    local workspace = wezterm.mux.get_active_workspace()
    local prefix = workspace ~= "default" and "[" .. workspace .. "] " or ""
    return prefix .. tab.active_pane.title
end)

return c
