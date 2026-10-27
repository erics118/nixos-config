return {
    inside_background_padding = 7,
    between_icon_label_padding = 3,
    outer_padding = 3,
    -- the C helpers, linked by sketchybar.nix
    helpers_dir = os.getenv("HOME") .. "/.local/share/sketchybar_helpers/",
    ignored_apps = { Raycast = true, Finder = true, Dropover = true, ["CleanShot X"] = true },
    -- lua patterns for window titles to skip, per app
    -- rex's settings window stays in yabai's list after it closes
    ignored_titles = { ["Rex Beta"] = "^Settings %- " },
}
