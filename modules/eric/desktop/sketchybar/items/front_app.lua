local front_app = sbar.add_label_item("front_app", {
    display = "active",
    label = {
        font = {
            style = "Heavy",
        },
        padding_left = 0,
    },
    updates = true,
    background = { drawing = false },
})

front_app:subscribe("front_app_switched", function(env)
    front_app:set({ label = { string = env.INFO } })
end)
