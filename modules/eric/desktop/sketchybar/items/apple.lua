local icons = require("icons")

local apple = sbar.add_icon_item("apple", {
    position = "left",
    icon = {
        font = { size = 16.0 },
        string = icons.apple,
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

        sbar.close_popups()

        sbar.set("smhkd", { drawing = switch })
        sbar.set("yabai", { drawing = switch })
        sbar.set("front_app", { drawing = switch })
        sbar.set("/cpu\\..*/", { drawing = switch })
        sbar.set("battery", { drawing = switch })
        sbar.set("sleep", { drawing = switch })
        sbar.set("wifi", { drawing = switch })
        sbar.set("calendar", { icon = { drawing = switch } })
        sbar.set("weather", { drawing = switch })

        sbar.set("/space\\..*/", { background = { drawing = switch }, label = { drawing = switch } })
    else
        sbar.exec(settings.helpers_dir .. "menus -s 0")
    end
end

sbar.add_event("toggle_zen")

apple:subscribe("toggle_zen", function(env)
    toggle_zen()
end)

apple:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "left" then
        toggle_zen()
    end
    if env.BUTTON == "right" then
        sbar.trigger("swap_menus_and_spaces", { direction = 1 })
    end
end)
