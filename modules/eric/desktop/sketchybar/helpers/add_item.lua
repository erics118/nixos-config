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
