-- loaded here, before any item spawns a lasting child like cpu_load
-- its load-time shell commands wait on children, so loading it later hangs the config
local render_symbol = require("helpers.symbols")

local set_padding = function(options)
    options.padding_left = options.padding_left or settings.outer_padding
    options.padding_right = options.padding_right or settings.outer_padding
    return options
end

sbar.add_label_item = function(name, options)
    options = set_padding(options)

    options.icon = options.icon or {}
    options.icon.drawing = false

    options.label = options.label or {}

    if options.label.padding_left == nil then
        options.label.padding_left = settings.inside_background_padding
    end

    if options.label.padding_right == nil then
        options.label.padding_right = settings.inside_background_padding
    end

    local item = sbar.add("item", name, options)
    return item
end

sbar.add_icon_item = function(name, options)
    options = set_padding(options)

    options.label = options.label or {}
    options.label.drawing = false

    options.icon = options.icon or {}

    if options.icon.padding_left == nil then
        options.icon.padding_left = settings.inside_background_padding
    end

    if options.icon.padding_right == nil then
        options.icon.padding_right = settings.inside_background_padding
    end

    local item = sbar.add("item", name, options)
    return item
end

sbar.add_item = function(name, options)
    options = set_padding(options)

    local item = sbar.add("item", name, options)
    return item
end

sbar.add_popup_row = function(parent, name, text, color)
    return sbar.add_item(name, {
        position = "popup." .. parent.name,
        padding_left = 12,
        icon = { drawing = false },
        label = {
            string = text,
            color = color,
            padding_left = 0,
            padding_right = 12,
        },
        background = { drawing = false },
    })
end

-- an item whose icon is a symbol image, drawn with sbar.set_symbol
sbar.add_symbol_item = function(name, options)
    options.icon = options.icon or {}
    options.icon.string = ""
    options.icon.padding_left = 0
    options.icon.padding_right = 0
    options.icon.background = {
        drawing = true,
        image = { scale = 0.5, padding_left = settings.inside_background_padding },
    }
    return sbar.add_item(name, options)
end

-- spec is { symbol, color, size, value, labeled }, the first four as helpers/symbols.lua takes them
-- renders the symbol into the item's icon and sets props in the same update
-- the icon is padded like a font icon: 7pt before, then 3pt before a label or 7pt with none
sbar.set_symbol = function(item, spec, props)
    props = props or {}
    render_symbol(spec.symbol, spec.color, spec.size, spec.value, function(path, width)
        local after = spec.labeled == false and settings.inside_background_padding
            or settings.between_icon_label_padding
        props.icon = props.icon or {}
        props.icon.width = width + settings.inside_background_padding + after
        props.icon.background = { image = path }
        item:set(props)
    end)
end

-- popup rows with a symbol icon and a label, made hidden by add and drawn by show
-- rows of one group share the widest icon's width, so their labels line up
sbar.symbol_rows = function(parent)
    local items = {}
    local slot = 0
    local rows = {}

    function rows.add(name, label)
        local item = sbar.add_item(name, {
            position = "popup." .. parent.name,
            drawing = false,
            padding_left = 12,
            icon = {
                string = "",
                padding_left = 0,
                padding_right = 0,
                background = { drawing = true, image = { scale = 0.5 } },
            },
            label = { string = label, padding_left = 8, padding_right = 12 },
            background = { drawing = false },
        })
        table.insert(items, item)
        return item
    end

    -- spec is { symbol, color, size, value }, and label replaces the row's label when given
    function rows.show(item, spec, label)
        render_symbol(spec.symbol, spec.color, spec.size, spec.value, function(path, width)
            if width > slot then
                slot = width
                for _, other in ipairs(items) do
                    other:set({ icon = { width = slot } })
                end
            end
            item:set({ drawing = true, icon = { width = slot, background = { image = path } }, label = label })
        end)
    end

    return rows
end

sbar.add_graph = function(name, width, options)
    local graph = sbar.add("graph", name, width, options)
    return graph
end

sbar.add_space = function(name, options)
    local space = sbar.add("space", name, options)
    return space
end

-- notification is an optional distributed notification that fires the event
sbar.add_event = function(name, notification)
    if notification then
        sbar.add("event", name, notification)
    else
        sbar.add("event", name)
    end
end

-- invisible item that only listens for events
-- updates defaults on, since a hidden item gets no events while updates is when_shown
sbar.add_watcher = function(name, options)
    options = options or {}
    options.drawing = false
    if options.updates == nil then
        options.updates = true
    end
    return sbar.add("item", name, options)
end

local popups = {}

-- closes every popup opened through toggle_popup, except the named one
sbar.close_popups = function(except)
    for name in pairs(popups) do
        if name ~= except then
            sbar.set(name, { popup = { drawing = false } })
        end
    end
end

-- toggles the popup of the named item and closes any other popup
sbar.toggle_popup = function(name)
    popups[name] = true
    sbar.close_popups(name)
    sbar.set(name, { popup = { drawing = "toggle" } })
end

-- left side items that trade places with the menu items
sbar.apply_to_space_items = function(conf)
    sbar.set("smhkd", conf)
    sbar.set("/space\\..*/", conf)
    sbar.set("yabai", conf)
    sbar.set("front_app", conf)
end

sbar.apply_to_menu_items = function(conf)
    sbar.set("/menu\\..*/", conf)
end

local mode = "default"

sbar.add_event("mode_change")

sbar.set_mode = function(new_mode)
    mode = new_mode
    sbar.trigger("mode_change")
end

sbar.get_mode = function()
    return mode
end

-- calls callback(charge, on_ac, charging) with the current battery state
sbar.battery_status = function(callback)
    sbar.exec("pmset -g batt", function(batt_info)
        local _, _, charge = batt_info:find("(%d+)%%")
        local on_ac = batt_info:find("AC Power") ~= nil
        local charging = on_ac and batt_info:find("; charging") ~= nil
        callback(tonumber(charge) or 0, on_ac, charging)
    end)
end

-- charge, on_ac and charging from the json sketchybar sends with battery_change
sbar.parse_battery_info = function(info)
    local charge = math.max(info.percentage or 0, 0)
    local on_ac = info.source == "AC Power"
    return charge, on_ac, on_ac and info.charging == true
end

-- on battery, red at 10% and orange at 30%, otherwise normal
sbar.battery_color = function(charge, on_ac, normal)
    if not on_ac and charge <= 10 then
        return colors.red
    elseif not on_ac and charge <= 30 then
        return colors.orange
    end
    return normal
end

-- front app switches that items should not react to
-- the lock screen briefly makes loginwindow the front app
local function front_app_ignored(app)
    return app == "loginwindow"
end

-- front_app_switched without the ignored apps, with the same INFO
-- items should subscribe to this instead of front_app_switched
sbar.add_event("user_app_switched")

sbar.add_watcher("user_app_watcher"):subscribe("front_app_switched", function(env)
    if not front_app_ignored(env.INFO) then
        sbar.trigger("user_app_switched", { INFO = env.INFO })
    end
end)

-- animate counts frames at 60 per second
local slide_frames = 10
local slide_seconds = slide_frames / 60

-- y_offset a sliding item moves out to, a negative direction slides down
local function slide_offset(direction)
    return 20 * direction
end

-- each slide bumps its channel, so a delayed step from an older slide on that channel does nothing
-- slides on other channels run independently
local slide_generations = {}

local function next_generation(channel)
    slide_generations[channel] = (slide_generations[channel] or 0) + 1
    return slide_generations[channel]
end

local function with_y_offset(conf, y_offset)
    local copy = {}
    for key, value in pairs(conf) do
        copy[key] = value
    end
    copy.y_offset = y_offset
    return copy
end

-- apply sets properties on every item being slid
-- once the items are out, hidden is applied and they wait on the far side for slide_in
sbar.slide_out = function(channel, apply, direction, hidden, on_done)
    local generation = next_generation(channel)
    local offset = slide_offset(direction)
    sbar.animate("sin", slide_frames, function()
        apply({ y_offset = offset })
    end)
    sbar.delay(slide_seconds + 0.015, function()
        if generation ~= slide_generations[channel] then
            return
        end
        apply(with_y_offset(hidden, -offset))
        if on_done then
            on_done()
        end
    end)
end

-- reveal(done) is optional and runs once the items are parked, for items that draw themselves asynchronously
sbar.slide_in = function(channel, apply, direction, shown, reveal)
    local generation = next_generation(channel)
    apply(with_y_offset(shown, -slide_offset(direction)))

    local function animate_in()
        if generation ~= slide_generations[channel] then
            return
        end
        sbar.animate("sin", slide_frames, function()
            apply({ y_offset = 0 })
        end)
    end

    if reveal then
        reveal(animate_in)
    else
        animate_in()
    end
end
