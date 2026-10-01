local render_symbol = require("helpers.symbols")

local battery = sbar.add_item("battery", {
    position = "right",
    padding_left = 2,
    icon = {
        string = "",
        width = 36,
        padding_left = 0,
        padding_right = 0,
        background = {
            drawing = true,
            image = { scale = 0.5, padding_left = 7 },
        },
    },
    popup = { align = "center", height = 24 },
})

local dim = colors.with_alpha(colors.text, 0.6)

local function add_text_row(name, text, style, color)
    return sbar.add_item(name, {
        position = "popup." .. battery.name,
        padding_left = 12,
        icon = { drawing = false },
        label = {
            string = text,
            font = { style = style },
            color = color,
            padding_left = 0,
            padding_right = 12,
        },
        background = { drawing = false },
    })
end

local power_source = add_text_row("power_source", "Power Source: ?", "Regular", dim)
local remaining_time = add_text_row("remaining_time", "", "Regular", dim)

-- index - 1 is the pmset powermode value
local energy_modes = {
    { name = "Automatic", symbol = "battery.100percent" },
    { name = "Low Power", symbol = "battery.25percent" },
    { name = "High Power", symbol = "arrowtriangle.right.3.battery.0percent" },
}

local energy_mode_items = {}

local function update_popup()
    sbar.exec("pmset -g batt; pmset -g", function(info)
        local on_ac = info:find("drawing from 'AC Power'") ~= nil
        local _, _, remaining = info:find(" (%d+:%d+) remaining")
        local _, _, mode = info:find("powermode%s+(%d)")

        power_source:set({ label = "Power Source: " .. (on_ac and "Power Adapter" or "Battery") })
        remaining_time:set({ label = remaining and remaining .. " remaining" or "No estimate" })

        for i, item in ipairs(energy_mode_items) do
            local color = tonumber(mode) == i - 1 and colors.blue or colors.text
            render_symbol(energy_modes[i].symbol, color, 15, nil, function(path)
                item:set({ icon = { background = { image = path } } })
            end)
        end
    end)
end

for i, mode in ipairs(energy_modes) do
    local item = sbar.add_item("energy_mode." .. (i - 1), {
        position = "popup." .. battery.name,
        padding_left = 12,
        icon = {
            string = "",
            width = 25,
            padding_left = 0,
            padding_right = 0,
            background = {
                drawing = true,
                image = { scale = 0.5 },
            },
        },
        label = {
            string = mode.name,
            font = { style = "Regular" },
            padding_left = 8,
            padding_right = 12,
        },
        background = { drawing = false },
    })

    item:subscribe("mouse.clicked", function(env)
        sbar.exec("sudo pmset -a powermode " .. (i - 1), update_popup)
    end)

    energy_mode_items[i] = item
end

update_popup()

local function update_battery()
    sbar.exec("pmset -g batt", function(batt_info)
        local _, _, charge = batt_info:find("(%d+)%%")
        charge = tonumber(charge) or 0

        local on_ac = batt_info:find("AC Power") ~= nil
        local charging = batt_info:find("; charging") ~= nil

        local color = colors.green
        if not on_ac and charge <= 20 then
            color = colors.red
        elseif not on_ac and charge <= 40 then
            color = colors.orange
        end

        local symbol = "battery"
        if charging then
            symbol = "battery.bolt"
        elseif on_ac then
            symbol = "battery.plug"
        end

        render_symbol(symbol, color, 15, charge / 100, function(path)
            battery:set({
                icon = { background = { image = path } },
                label = { string = charge .. "%" },
            })
        end)
    end)
end

battery:subscribe({ "battery_change", "forced", "system_woke" }, update_battery)

battery:subscribe("power_source_change", function()
    update_battery()
    -- macos reports "not charging" for a few seconds after plugging in
    sbar.delay(15, update_battery)
end)

battery:subscribe("mouse.clicked", function(env)
    local drawing = battery:query().popup.drawing
    sbar.toggle_popup(battery.name)

    if drawing == "off" then
        update_popup()
    end
end)
