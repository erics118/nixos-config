-- Equivalent to the --default domain
sbar.default({
    updates = "when_shown",
    icon = {
        font = {
            family = "SF Pro",
            style = "Bold",
            size = 13.0,
        },
        color = colors.text,
        padding_left = 7,
        padding_right = 3,
        background = { image = { corner_radius = 9 } },
    },
    label = {
        font = {
            family = "SF Pro",
            style = "Semibold",
            size = 13.0,
        },
        color = colors.text,
        padding_left = 3,
        padding_right = 7,
    },
    background = {
        padding_left = 0,
        padding_right = 0,
        height = 25,
        corner_radius = 9,
        border_width = 2,
        color = colors.item.bg,
        border_color = colors.item.border,
        image = {
            corner_radius = 9,
            border_color = colors.transparent,
            border_width = 1,
        },
    },
    popup = {
        height = 22,
        background = {
            border_width = 2,
            corner_radius = 9,
            border_color = colors.popup.border,
            color = colors.popup.bg,
            shadow = { drawing = true },
        },
        blur_radius = 50,
    },
    padding_left = 3,
    padding_right = 3,
    scroll_texts = true,
})
