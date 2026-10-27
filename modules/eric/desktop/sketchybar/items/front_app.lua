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

local renames = {
    ["Firefox Developer Edition"] = "Firefox",
    ["Microsoft Word"] = "Word",
    ["Microsoft Excel"] = "Excel",
    ["Microsoft PowerPoint"] = "PowerPoint",
    ["Microsoft Outlook"] = "Outlook",
    ["Microsoft Teams"] = "Teams",
    ["Microsoft OneNote"] = "OneNote",
    ["Parallels Desktop"] = "Parallels",
    ["Jellyfin Desktop"] = "Jellyfin",
    ["Mullvad VPN"] = "Mullvad",
    ["Code"] = "VS Code",
}

front_app:subscribe("user_app_switched", function(env)
    front_app:set({ label = { string = renames[env.INFO] or env.INFO } })
end)
