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

for i = 1, max_items, 1 do
    menu_items[i] = sbar.add_label_item("menu." .. i, {
        padding_left = 3,
        padding_right = 3,
        drawing = false,
        label = {
            font = {
                style = i == 1 and "Heavy" or "Semibold"
            },
            padding_left = 7,
            padding_right = i % 2 == 0 and 7 or 6
        },
        click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s " .. i,
        background = { drawing = false, },
    })
end

local function update_menus(env)
    sbar.exec("$CONFIG_DIR/helpers/menus/bin/menus -l", function(menus)
        sbar.set('/menu\\..*/', { drawing = false })
        local id = 1
        for menu in string.gmatch(menus, '[^\r\n]+') do
            if id < max_items then
                menu_items[id]:set({ label = menu, drawing = true })
            else
                break
            end
            id = id + 1
        end
    end)
end

menu_watcher:subscribe("front_app_switched", update_menus)

space_menu_swap:subscribe("swap_menus_and_spaces", function(env)
    env.direction = env.direction or 1
    -- sbar.animate("sin", 20, function()
    --     sbar.set("skhd", { y_offset = -30 })
    --     sbar.set("yabai", { y_offset = -30 })
    --     sbar.set('/space\\..*/', { y_offset = -30 })
    --     sbar.set("front_app", { y_offset = -30 })
    -- end)
    -- local drawing = menu_items[1]:query().geometry.drawing == "on"
    local mode = sbar.get_mode()

    if mode == "zen" then
        sbar.trigger("toggle_zen")
        return
    end

    if mode == "menu" then
        menu_watcher:set({ updates = false })

        sbar.animate("sin", 10, function()
            sbar.set("apple", { icon = { color = settings.mode_colors.default } })

            sbar.set("/menu\\..*/", { y_offset = 30 * env.direction })
        end)


        sbar.delay(0.1, function()
            sbar.set("/menu\\..*/", { drawing = false })

            sbar.set("skhd", { drawing = true, y_offset = -30 * env.direction })
            sbar.set("/space\\..*/", { drawing = true, y_offset = -30 * env.direction })
            sbar.set("yabai", { drawing = true, y_offset = -30 * env.direction })
            sbar.set("front_app", { drawing = true, y_offset = -30 * env.direction })
            sbar.set("/media.*/", { drawing = true, y_offset = -30 * env.direction })

            sbar.animate("sin", 10, function()
                sbar.set("skhd", { y_offset = 0 })
                sbar.set("/space\\..*/", { y_offset = 0 })
                sbar.set("yabai", { y_offset = 0 })
                sbar.set("front_app", { y_offset = 0 })
                sbar.set("/media.*/", { y_offset = 0 })
            end)
        end)
    else
        menu_watcher:set({ updates = true })

        sbar.animate("sin", 10, function()
            sbar.set("apple", { icon = { color = settings.mode_colors.menu } })

            sbar.set("skhd", { y_offset = 30 * env.direction })
            sbar.set("/space\\..*/", { y_offset = 30 * env.direction })
            sbar.set("yabai", { y_offset = 30 * env.direction })
            sbar.set("front_app", { y_offset = 30 * env.direction })
            sbar.set("/media.*/", { y_offset = 30 * env.direction })
        end)

        sbar.delay(0.1, function()
            sbar.set("skhd", { drawing = false, y_offset = 0 })
            sbar.set("/space\\..*/", { drawing = false, y_offset = 0 })
            sbar.set("yabai", { drawing = false, y_offset = 0 })
            sbar.set("front_app", { drawing = false, y_offset = 0 })
            sbar.set("/media.*/", { drawing = false, y_offset = 0 })

            sbar.set("/menu\\..*/", { y_offset = -30 * env.direction })
            update_menus()

            sbar.animate("sin", 10, function()
                sbar.set("/menu\\..*/", { y_offset = 0 })
            end)
        end)
        -- update_menus()
    end
end)
