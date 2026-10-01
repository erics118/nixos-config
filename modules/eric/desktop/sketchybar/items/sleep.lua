local sleep = sbar.add_icon_item("sleep", {
    position = "right",
    padding_left = 2,
    padding_right = 1,
    icon = {
        string = icons.circle,
        font = {
            style = "Regular",
            size = 15.0,
        },
    },
    update_freq = 60,
})

-- left click cycles these, the caffeinate args identify which one is running
local modes = {
    { icon = icons.circle },
    { icon = icons.circle_half, args = "-i" },
    { icon = icons.circle_fill, args = "-di" },
}

local mode = 1
local lid_awake = false

local function update()
    sbar.exec("pmset -g; pgrep -lfx 'caffeinate -d?i'", function(info)
        lid_awake = info:find("SleepDisabled%s+1") ~= nil
        mode = 1
        for i, m in ipairs(modes) do
            if m.args and info:find("caffeinate " .. m.args .. "\n", 1, true) then
                mode = i
            end
        end
        sleep:set({
            icon = {
                string = modes[mode].icon,
                color = lid_awake and colors.orange or colors.text,
            },
        })
    end)
end

sleep:subscribe({ "forced", "routine", "system_woke" }, update)

sleep:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
        -- keeps the mac awake with the lid closed
        sbar.exec("sudo pmset -a disablesleep " .. (lid_awake and 0 or 1), update)
        return
    end

    local next = modes[mode % #modes + 1]
    local start = next.args and ("caffeinate " .. next.args .. " >/dev/null 2>&1 &") or ""
    sbar.exec("pkill -x -f 'caffeinate -d?i'; " .. start .. " sleep 0.2", update)
end)
