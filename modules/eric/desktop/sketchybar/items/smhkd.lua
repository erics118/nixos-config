local colors = require("colors")

sbar.add_event("smhkd_sequence")

local smhkd = sbar.add_label_item("smhkd", {
    label = {
        string = "default",
    },
})

local sequence_colors = {
    ["default"] = colors.text,
    ["hyper + a"] = colors.yellow,
    ["hyper + y"] = colors.blue,
    -- disabled = colors.red,
    -- yabai = colors.purple,
    -- resize = colors.green,
}

smhkd:subscribe("smhkd_sequence", function(env)
    -- sketchybar drops empty trigger vars, so an exited sequence arrives as nil
    local sequence = env.SEQUENCE or "default"
    sequence = sequence:gsub("ralt %+ rshift %+ rcmd %+ rctrl", "hyper")

    local color = sequence_colors[sequence] or colors.text

    sbar.animate("tanh", 6, function()
        smhkd:set({
            label = {
                string = sequence,
                color = color,
            },
            background = {
                border_color = color == colors.text and colors.item.border or color,
            },
        })
    end)
end)
