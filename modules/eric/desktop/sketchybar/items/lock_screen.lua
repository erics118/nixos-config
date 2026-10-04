local lock_watcher = sbar.add_watcher("lock_watcher")

sbar.add_event("screen_locked", "com.apple.screenIsLocked")
sbar.add_event("screen_unlocked", "com.apple.screenIsUnlocked")

local function apply_to_left_items(conf)
    sbar.apply_to_space_items(conf)
    sbar.apply_to_menu_items(conf)
end

lock_watcher:subscribe("screen_locked", function(_)
    sbar.slide_out("lock", apply_to_left_items, 1, { lock_screen = false })
end)

lock_watcher:subscribe("screen_unlocked", function(_)
    sbar.slide_in("lock", apply_to_left_items, 1, { lock_screen = true })
end)
