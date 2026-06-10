-- Execute the event provider binary which provides the event "cpu_update" for
-- the cpu load data, which is fired every 2.0 seconds.
sbar.exec("killall cpu_load &> /dev/null; $CONFIG_DIR/helpers/event_providers/cpu_load/bin/cpu_load cpu_update 2.0")

local cpu_user = sbar.add_graph("cpu.user", 30, {
    position = "right",
    graph = {
        color = colors.blue,
        fill_color = colors.with_alpha(colors.blue, 0.2),
    },
    background = {
        height = 22,
        color = { alpha = 0 },
        border_color = { alpha = 0 },
        drawing = true,
    },
    y_offset = -2,
    icon = { drawing = false },
    label = { drawing = false },
    padding_left = -39,
    padding_right = 0,
})

local cpu_sys = sbar.add_graph("cpu.sys", 30, {
    position = "right",
    graph = {
        color = colors.red,
        fill_color = colors.with_alpha(colors.red, 0.2),
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

cpu_user:subscribe("cpu_update", function(env)
    local load = tonumber(env.user_load) + tonumber(env.sys_load)
    if 0 > load or load > 100 then
        return
    end

    cpu_user:push({ load / 100. })
end)

cpu_sys:subscribe("cpu_update", function(env)
    local load = tonumber(env.sys_load)
    if 0 > load or load > 100 then
        return
    end

    cpu_sys:push({ load / 100. })

    local total = tonumber(env.total_load)
    cpu_sys:set({ label = total .. "%" })
end)
