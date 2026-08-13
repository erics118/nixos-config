-- Equivalent to the --default domain
sbar.default({
    updates = "when_shown",
    icon = {
        font = {
            family = "SF Pro",
            style = "Bold",
            size = 13.0,
            typographical_width = true,
        },
        color = colors.text,
        padding_left = settings.inside_background_padding,
        padding_right = settings.between_icon_label_padding,
        background = { image = { corner_radius = 9 } },
    },
    label = {
        font = {
            family = "SF Pro",
            style = "Semibold",
            size = 13.0,
            typographical_width = true,
        },
        color = colors.text,
        padding_left = settings.between_icon_label_padding,
        padding_right = settings.inside_background_padding,
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
    padding_left = settings.outer_padding,
    padding_right = settings.outer_padding,
    scroll_texts = true,
})
