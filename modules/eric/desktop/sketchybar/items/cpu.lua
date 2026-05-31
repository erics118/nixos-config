-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
sbar.exec("killall cpu_load &> /dev/null; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0")

local cpu = sbar.add_graph("cpu", 60, {
    position = "right",
    graph = {
        color = colors.blue,
    },
    background = {
        height = 22,
        color = { alpha = 0 },
        border_color = { alpha = 0 },
        drawing = true,
    },
    y_offset = -2,
    icon = { drawing = false },
    label = {
        string = "??%",
        font = {
            style = "Bold",
            size = 10.0,
        },
        align = "right",
        padding_right = 0,
        width = 0,
        y_offset = 4,
    },
    padding_right = 9,
})

cpu:subscribe("cpu_update", function(env)
    -- Also available: env.user_load, env.sys_load
    local load = tonumber(env.total_load)
    if 0 > load or load > 100 then
        return
    end

    cpu:push({ load / 100. })

    local color = colors.blue
    if load > 30 then
        if load < 60 then
            color = colors.yellow
        elseif load < 80 then
            color = colors.orange
        else
            color = colors.red
        end
    end

    cpu:set({
        graph = { color = color },
        label = load .. "%",
    })
end)
