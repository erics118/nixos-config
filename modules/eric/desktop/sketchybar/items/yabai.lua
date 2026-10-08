-- event triggered by yabai on every window focus, since front_app_switched misses focus changes within one app
sbar.add_event("window_focused")

-- manually trigger yabai update
sbar.add_event("yabai")

local yabai = sbar.add_icon_item("yabai", {
    updates = true,
    icon = { padding_left = 2 },
    background = { drawing = false },
})

local window_query =
    "yabai -m query --windows is-sticky,is-floating,sub-layer,has-fullscreen-zoom,stack-index --window 2>/dev/null || echo err"
local space_query = "yabai -m query --spaces type --space 2>/dev/null || echo err"

local function render(window_data, space_data)
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
        icon = { color = c, string = icon, width = icon and 18 or 0 },
    })
end

-- one space switch fires several of these events, so a burst runs one update plus at most one rerun
local running, dirty = false, false
local function update()
    if running then
        dirty = true
        return
    end
    running = true

    local window_data, space_data
    local pending = 2
    local function done()
        pending = pending - 1
        if pending > 0 then
            return
        end
        render(window_data, space_data)
        running = false
        if dirty then
            dirty = false
            update()
        end
    end

    -- the two queries are independent, so they run at the same time
    sbar.exec(window_query, function(result)
        window_data = result
        done()
    end)
    sbar.exec(space_query, function(result)
        space_data = result
        done()
    end)
end

-- space and display changes can change the layout shown, even when no window takes focus
yabai:subscribe({ "user_app_switched", "window_focused", "forced", "yabai", "space_change", "display_change" }, update)
