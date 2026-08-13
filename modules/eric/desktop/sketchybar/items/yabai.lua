-- event triggered by yabai on window focus of the same app, as sketchybar doesn't handle this
sbar.add_event("window_focused")

-- manually trigger yabai update
sbar.add_event("yabai")

local yabai = sbar.add_icon_item("yabai", {
    updates = true,
    background = { drawing = false },
})

local window_query =
    "yabai -m query --windows is-sticky,is-floating,sub-layer,has-fullscreen-zoom,stack-index --window 2>/dev/null || echo err"
local space_query = "yabai -m query --spaces type --space 2>/dev/null || echo err"

yabai:subscribe({ "front_app_switched", "window_focused", "forced", "yabai" }, function(env)
    sbar.exec(window_query, function(window_data)
        sbar.exec(space_query, function(space_data)
            local c = colors.text

            local space_type = type(space_data) == "table" and space_data.type or nil

            if type(window_data) == "table" then
                -- color represents window state
                if window_data["is-sticky"] then
                    -- sticky also means it acts like floating
                    c = colors.green
                elseif window_data["is-floating"] or (space_type == "float") then
                    -- either is a floating window or the entire space is floating
                    c = colors.purple
                elseif window_data["has-fullscreen-zoom"] then
                    -- fullscreen zoom
                    c = colors.red
                else
                    -- managed window, bsp or stack
                    c = colors.blue
                end
            end

            -- icon represent space state
            local icon = nil
            if space_type == "bsp" then
                icon = icons.yabai_grid
            elseif space_type == "stack" then
                icon = icons.yabai_stack
            elseif space_type == "float" then
                icon = icons.yabai_float
                if c ~= colors.text then
                    c = colors.purple
                end
            end

            yabai:set({
                drawing = sbar.get_mode() == "default" and icon ~= nil,
                icon = { color = c, string = icon, width = icon and 25 or 0 },
            })
        end)
    end)
end)
