local battery = sbar.add_symbol_item("battery", {
    position = "right",
    padding_left = 2,
    icon = { width = 36 },
    popup = { align = "left", height = 24 },
})

local dim = colors.with_alpha(colors.text, 0.6)

local power_source = sbar.add_popup_row(battery, "power_source", "Power Source: ?", dim)
local remaining_time = sbar.add_popup_row(battery, "remaining_time", "", dim)

-- index - 1 is the pmset powermode value
local energy_modes = {
    { name = "Automatic", symbol = "battery.100percent" },
    { name = "Low Power", symbol = "battery.25percent" },
    { name = "High Power", symbol = "arrowtriangle.right.3.battery.0percent" },
}

local energy_mode_items = {}
local mode_rows = sbar.symbol_rows(battery)

local function update_popup()
    sbar.exec("pmset -g batt; pmset -g", function(info)
        local on_ac = info:find("drawing from 'AC Power'") ~= nil
        local _, _, remaining = info:find(" (%d+:%d+) remaining")
        local _, _, mode = info:find("powermode%s+(%d)")

        power_source:set({ label = "Power Source: " .. (on_ac and "Power Adapter" or "Battery") })
        remaining_time:set({ label = remaining and remaining .. " remaining" or "No estimate" })

        for i, item in ipairs(energy_mode_items) do
            local color = tonumber(mode) == i - 1 and colors.blue or colors.text
            mode_rows.show(item, { symbol = energy_modes[i].symbol, color = color, size = 15 })
        end
    end)
end

for i, mode in ipairs(energy_modes) do
    local item = mode_rows.add("energy_mode." .. (i - 1), mode.name)

    item:subscribe("mouse.clicked", function()
        sbar.exec("/usr/bin/sudo /usr/bin/pmset -a powermode " .. (i - 1), update_popup)
    end)

    energy_mode_items[i] = item
end

update_popup()

-- info is the json sketchybar sends with battery_change
local function render(info)
    if type(info) ~= "table" then
        return
    end
    local charge, on_ac, charging = sbar.parse_battery_info(info)
    local color = sbar.battery_color(charge, on_ac, colors.green)

    local symbol = "battery"
    if charging then
        symbol = "battery.bolt"
    elseif on_ac then
        symbol = "battery.plug"
    end

    sbar.set_symbol(
        battery,
        { symbol = symbol, color = color, size = 15, value = charge / 100 },
        { label = { string = charge .. "%" } }
    )
end

battery:subscribe("battery_change", function(env)
    render(env.INFO)
end)

-- triggering battery_change makes sketchybar reread the battery and send a fresh event
local function refresh()
    sbar.trigger("battery_change")
end

battery:subscribe({ "forced", "system_woke" }, refresh)

battery:subscribe("power_source_change", function()
    refresh()
    -- macos can report "not charging" for up to a minute after plugging in
    sbar.delay(15, refresh)
    sbar.delay(60, refresh)
end)

battery:subscribe("mouse.clicked", function()
    local drawing = battery:query().popup.drawing
    sbar.toggle_popup(battery.name)

    if drawing == "off" then
        update_popup()
    end
end)
