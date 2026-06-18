local colors = require("colors")

sbar.bar({
    sticky = true,
    height = 33,
    color = colors.bar_color,
    blur_radius = 100,
    font_smoothing = "on",
    topmost = true,
    display = "all",
    hidden = false,
    position = "top",
    padding_left = 10,
    padding_right = 10,
    -- y_offset = -2,
})
