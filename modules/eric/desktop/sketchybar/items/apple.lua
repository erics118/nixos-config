local colors = require("colors")
local icons = require("icons")

local apple = sbar.add_icon_item("apple", {
    position = "left",
    icon = {
        font = { size = 16.0 },
        string = icons.apple,
        color = settings.mode_colors.default,
    },
    padding_left = 3,
    padding_right = 3,
    background = { drawing = false },
    updates = true,
    -- y_offset = 2,
})

local function toggle_zen()
    local mode = sbar.get_mode()

    -- showing spaces
    if mode == "default" or mode == "zen" then
        -- zen can only be enabled from the spaces mode
        sbar.set_mode(mode == "default" and "zen" or "default")

        local switch = mode ~= "default"

        -- popups
        if sbar.query("weather").popup.drawing == "on" then
            sbar.set("weather", { popup = { drawing = false } })
        end
        if sbar.query("battery").popup.drawing == "on" then
            sbar.set("battery", { popup = { drawing = false } })
        end

        sbar.set("smhkd", { drawing = switch })
        sbar.set("yabai", { drawing = switch })
        sbar.set("front_app", { drawing = switch })
        sbar.set("/cpu\\..*/", { drawing = switch })
        sbar.set("battery", { drawing = switch })
        sbar.set("calendar", { icon = { drawing = switch } })
        -- sbar.set("/media.*/", { drawing = switch })
        sbar.set("weather", { drawing = switch })

        sbar.set("/space\\..*/", { background = { drawing = switch }, label = { drawing = switch } })
    else
        sbar.exec("$CONFIG_DIR/helpers/menus/bin/menus -s 0")
    end
end

sbar.add_event("toggle_zen")

apple:subscribe("toggle_zen", function(env)
    toggle_zen()
end)

-- local a = 0
-- local paused = false

apple:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "left" then
        toggle_zen()
    end
    if env.BUTTON == "right" then
        sbar.trigger("swap_menus_and_spaces", { direction = 1 })
    end
end)

-- apple:subscribe("mouse.scrolled", function(env)
--     if sbar.get_mode() == "zen" then
--         return
--     end

--     local delta = tonumber(env.SCROLL_DELTA) or 0
--     a = a + math.abs(delta)

--     print(delta, a, paused)

--     if a > 20 and not paused then
--         a = -10000
--         paused = true
--         sbar.trigger("swap_menus_and_spaces", { direction = delta < 0 and 1 or -1 })
--     end
-- end)

--[[
   -- logic

    -- if encounter a >= 20, then scroll once
    -- then set paused to true, until we encounter a abs(delta) <= 2
    -- then, set paused to false

    if paused and math.abs(delta) <= 2 then
        print("unpaused")
        paused = false
    end

    if a >= 20 and not paused then
        print("scrolled, paused")
        sbar.trigger("swap_menus_and_spaces", { direction = delta < 0 and 1 or -1 })
        paused = true
    end

--]]
