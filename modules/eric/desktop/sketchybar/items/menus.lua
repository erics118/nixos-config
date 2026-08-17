local menu_watcher = sbar.add_item("menu_watcher", {
    drawing = false,
    updates = false,
})

local space_menu_swap = sbar.add_item("space_menu_swap", {
    drawing = false,
    updates = true,
})

sbar.add_event("swap_menus_and_spaces")

local max_items = 15
local menu_items = {}

local base_y_offset = 0

for i = 1, max_items, 1 do
    menu_items[i] = sbar.add_label_item("menu." .. i, {
        padding_left = 0,
        padding_right = 0,
        drawing = false,
        label = {
            font = {
                style = i == 1 and "Bold" or "Regular",
            },
            padding_left = 10,
            padding_right = 10,
        },
        click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s " .. i,
        background = { drawing = false },
    })
end

local function update_menus(env, on_done)
    sbar.exec("$CONFIG_DIR/helpers/menus/bin/menus -l", function(menus)
        sbar.set("/menu\\..*/", { drawing = false })
        local id = 1
        for menu in string.gmatch(menus, "[^\r\n]+") do
            if id <= max_items then
                menu_items[id]:set({ label = menu, drawing = true })
            else
                break
            end
            id = id + 1
        end

        if on_done then
            on_done()
        end
    end)
end

menu_watcher:subscribe("front_app_switched", update_menus)

local function apply_to_space_items(conf)
    sbar.set("smhkd", conf)
    sbar.set("/space\\..*/", conf)
    sbar.set("yabai", conf)
    sbar.set("front_app", conf)
end

local function apply_to_menu_items(conf)
    sbar.set("/menu\\..*/", conf)
end

space_menu_swap:subscribe("swap_menus_and_spaces", function(env)
    env.direction = env.direction or 1

    local offset = 20 * env.direction + base_y_offset

    local mode = sbar.get_mode()

    if mode == "zen" then
        sbar.trigger("toggle_zen")
        return
    end

    if mode == "menu" then
        menu_watcher:set({ updates = false })

        sbar.animate("sin", 10, function()
            sbar.set_mode("default")

            apply_to_menu_items({ y_offset = offset })
        end)

        sbar.delay(0.18, function()
            apply_to_menu_items({ drawing = false })

            apply_to_space_items({ drawing = true, y_offset = -offset })

            sbar.animate("sin", 10, function()
                apply_to_space_items({ y_offset = base_y_offset })
            end)
        end)
    else
        menu_watcher:set({ updates = true })

        sbar.animate("sin", 10, function()
            sbar.set_mode("menu")

            apply_to_space_items({ y_offset = offset })
        end)

        sbar.delay(0.18, function()
            apply_to_space_items({ drawing = false, y_offset = base_y_offset })

            apply_to_menu_items({ y_offset = -offset })

            update_menus(nil, function()
                sbar.animate("sin", 10, function()
                    apply_to_menu_items({ y_offset = base_y_offset })
                end)
            end)
        end)
    end
end)
