local wezterm = require("wezterm")

local M = {}

M.is_mac = wezterm.target_triple:find("darwin") ~= nil

-- runs last in wezterm.lua, so these override the shared values
M.apply_to_config = function(c)
    if M.is_mac then
        c.window_decorations =
            "RESIZE | TITLE | MACOS_FORCE_ENABLE_SHADOW | MACOS_USE_BACKGROUND_COLOR_AS_TITLEBAR_COLOR"
        c.window_frame.font = wezterm.font("SF Pro", { weight = "Regular", stretch = "Normal" })
    else
        -- linux keeps the default title bar
        c.font_size = 10.0
        -- hyprland.nix installs noto sans
        c.window_frame.font = wezterm.font("Noto Sans", { weight = "Regular", stretch = "Normal" })
    end
end

return M
