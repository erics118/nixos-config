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
    update_freq = 1,
    background = { drawing = false },
})

calendar:subscribe({ "forced", "routine", "system_woke" }, function(env)
    calendar:set({ icon = os.date("%a %b %d"), label = os.date("%H:%M:%S") })
end)
