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
local function update_color()
    if sbar.get_mode() ~= "zen" then
        calendar:set({ label = { color = colors.text } })
        return
    end

    sbar.battery_status(function(charge, on_ac)
        local color = colors.text
        if not on_ac and charge <= 10 then
            color = colors.red
        elseif not on_ac and charge <= 30 then
            color = colors.orange
        end
        calendar:set({ label = { color = color } })
    end)
end

calendar:subscribe({ "forced", "routine", "system_woke" }, function(env)
    calendar:set({ icon = os.date("%a %b %d"), label = os.date("%H:%M") })
    update_color()
end)

calendar:subscribe({ "mode_change", "battery_change", "power_source_change" }, update_color)
