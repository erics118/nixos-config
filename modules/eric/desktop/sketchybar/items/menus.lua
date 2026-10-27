local space_menu_swap = sbar.add_watcher("space_menu_swap")

sbar.add_event("swap_menus_and_spaces")

local max_items = 15
local menu_items = {}

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
        background = { drawing = false },
    })
end

-- x where menu.1 starts, right after the apple item
local function menus_start()
    local apple = sbar.query("apple")
    for _, rect in pairs(apple.bounding_rects) do
        return rect.origin[1] + rect.size[1] + apple.geometry.padding_right
    end
    return 0
end

-- app whose menus are shown, tracked in every mode so menu mode starts with the right one
local current_app = nil

-- right after a launch or a space switch the app's menu bar can still be empty
local retry_delays = { 0.15, 0.3, 0.6, 1.2 }

-- every update bumps this, so reads and retries for an older update do nothing
local menu_generation = 0

local function place_menus(entries)
    -- with a fixed width, padding_left only shifts the item, so every menu lands on its native x
    -- this also puts menus that macOS moved past the notch in the same place
    local shift = entries[1].x - menus_start()

    sbar.set("/menu\\..*/", { drawing = false })
    for id, entry in ipairs(entries) do
        if id > max_items then
            break
        end
        local next_entry = entries[id + 1]
        menu_items[id]:set({
            label = entry.title,
            drawing = true,
            padding_left = shift,
            width = next_entry and next_entry.x - entry.x or entry.width,
            click_script = settings.helpers_dir .. "menus -s " .. entry.index,
        })
    end
end

local function read_menus(generation, attempt, on_done)
    local app = current_app and (" '" .. current_app:gsub("'", "'\\''") .. "'") or ""
    sbar.exec(settings.helpers_dir .. "menus -l" .. app, function(menus)
        -- the mode can change while the menus are read
        if generation ~= menu_generation or sbar.get_mode() ~= "menu" then
            return
        end

        local entries = {}
        -- menus the app has not laid out yet report width -1
        local complete = true
        for line in string.gmatch(menus, "[^\r\n]+") do
            local title, x, width, index = line:match("^(.*)\t(%-?%d+)\t(%-?%d+)\t(%d+)$")
            if title and tonumber(width) > 0 then
                table.insert(entries, { title = title, x = tonumber(x), width = tonumber(width), index = index })
            elseif title then
                complete = false
            end
        end

        -- an empty or partial read keeps the menus already shown until a real one arrives
        local delay = retry_delays[attempt]
        if (#entries == 0 or not complete) and delay then
            sbar.delay(delay, function()
                read_menus(generation, attempt + 1, on_done)
            end)
            return
        end

        if #entries > 0 then
            place_menus(entries)
        end
        if on_done then
            on_done()
        end
    end)
end

local function update_menus(on_done)
    menu_generation = menu_generation + 1
    read_menus(menu_generation, 1, on_done)
end

space_menu_swap:subscribe({ "user_app_switched", "space_change" }, function(env)
    if env.SENDER == "user_app_switched" then
        current_app = env.INFO
    end
    if sbar.get_mode() == "menu" then
        update_menus()
    end
end)

space_menu_swap:subscribe("swap_menus_and_spaces", function(env)
    local direction = env.direction or 1

    local mode = sbar.get_mode()

    if mode == "zen" then
        sbar.trigger("toggle_zen")
        return
    end

    if mode == "menu" then
        sbar.set_mode("default")

        sbar.slide_out("swap", sbar.apply_to_menu_items, direction, { drawing = false }, function()
            sbar.slide_in("swap", sbar.apply_to_space_items, direction, { drawing = true })
        end)
    else
        sbar.set_mode("menu")

        sbar.slide_out("swap", sbar.apply_to_space_items, direction, { drawing = false }, function()
            sbar.slide_in("swap", sbar.apply_to_menu_items, direction, {}, function(done)
                update_menus(done)
            end)
        end)
    end
end)
