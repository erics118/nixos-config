local wezterm = require("wezterm")

local c = wezterm.config_builder()
c:set_strict_mode(true)

require("keys").apply_to_config(c)

-- c.default_prog = { "/bin/zsh" }

-- updates
c.check_for_updates = true
c.check_for_updates_interval_seconds = 86400

c.skip_close_confirmation_for_processes_named = {
    "bash",
    "sh",
    "zsh",
    "fish",
    "tmux",
    "nu",
    -- wsl
    "cmd.exe",
    "pwsh.exe",
    "powershell.exe",
    -- windows wsl
    "wsl.exe",
    "wslhost.exe",
    "conhost.exe",
}

c.unix_domains = {
    { name = "unix" },
}
c.ssh_domains = {
    { name = "squid", remote_address = "squid", multiplexing = "None" },
    { name = "narwhal", remote_address = "narwhal", multiplexing = "None" },
}
c.send_composed_key_when_left_alt_is_pressed = false
c.font = wezterm.font("Hack Nerd Font")
c.font_size = 12.0

-- window
if wezterm.target_triple:find("linux") then
    c.window_decorations = "NONE"
else
    c.window_decorations = "RESIZE | TITLE | MACOS_FORCE_ENABLE_SHADOW | MACOS_USE_BACKGROUND_COLOR_AS_TITLEBAR_COLOR"
end

c.window_padding = {
    left = 12,
    right = 12,
    top = 12,
    bottom = 12,
}

-- scroll bar
c.enable_scroll_bar = true
c.min_scroll_bar_height = "4cell"
c.scrollback_lines = 10000

-- dim unfocused panes
c.inactive_pane_hsb = {
    saturation = 1.0,
    brightness = 0.6,
}

-- c.window_close_confirmation = "NeverPrompt"

c.adjust_window_size_when_changing_font_size = false
c.exit_behavior = "Close"
c.default_cursor_style = "SteadyBar"
c.underline_thickness = 2.5
c.command_palette_font_size = 12.0

c.window_frame = {
    font_size = 12.0,
}

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
    clock = {
        enabled = false,
    },
})

wezterm.on("format-window-title", function(tab)
    local workspace = wezterm.mux.get_active_workspace()
    local prefix = workspace ~= "default" and "[" .. workspace .. "] " or ""
    return prefix .. tab.active_pane.title
end)

return c
