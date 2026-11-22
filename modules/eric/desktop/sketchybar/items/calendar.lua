local calendar = sbar.add_item("calendar", {
    position = "right",
    icon = {
        font = {
            style = "Heavy",
        },
        padding_left = 0,
    },
    label = {
        font = {
            features = "+tnum",
            style = "Semibold",
        },
        padding_left = 0,
        padding_right = 10,
    },
    update_freq = 10,
    background = { drawing = false },
})

-- the battery item is hidden in zen mode, so the clock warns about low battery instead
local function update_color(env)
    if sbar.get_mode() ~= "zen" then
        calendar:set({ label = { color = colors.text } })
        return
    end

    local function set_color(charge, on_ac)
        calendar:set({ label = { color = sbar.battery_color(charge, on_ac, colors.text) } })
    end

    if env and env.SENDER == "battery_change" and type(env.INFO) == "table" then
        set_color(sbar.parse_battery_info(env.INFO))
    else
        sbar.battery_status(set_color)
    end
end

local function update_time()
    calendar:set({ icon = os.date("%a %b %d"), label = os.date("%H:%M") })
end

calendar:subscribe("routine", update_time)

calendar:subscribe({ "forced", "system_woke" }, function()
    update_time()
    update_color()
end)

calendar:subscribe({ "mode_change", "battery_change", "power_source_change" }, update_color)
