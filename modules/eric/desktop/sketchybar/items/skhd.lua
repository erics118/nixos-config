sbar.add_event("skhd_mode_changed")

local skhd = sbar.add_item("skhd", {
    icon = {
        drawing = false,
    },
    label = {
        string = "default",
        padding_left = 8,
        padding_right = 8,
    },
    background = {
        color = colors.item.bg,
        border_width = 2,
        border_color = colors.item.border,
    },
    position = "left",
})

skhd:subscribe("skhd_mode_changed", function(env)
    local mode = env.INFO
    local mode_colors = {
        default = colors.text,
        activate = colors.yellow,
        disabled = colors.red,
        yabai = colors.purple,
        -- move = colors.light_blue,
        -- resize = colors.green,
    }

    local color = mode_colors[mode] or colors.blue

    sbar.animate("sin", 10, function()
        skhd:set({
            label = {
                string = mode,
                color = color,
            },
            background = {
                border_color = color == colors.text and colors.item.border or color,
            }
        })
    end)
end)
