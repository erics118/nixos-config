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

local state_cmd = "pmset -g; pgrep -lfx 'caffeinate -di'; pgrep -lf '/bin/keepawake$'"

local function parse(info)
    return {
        display = info:find("caffeinate -di\n", 1, true) ~= nil,
        holder = info:find("/bin/keepawake\n", 1, true) ~= nil,
        lid = info:find("SleepDisabled%s+1") ~= nil,
    }
end

local toggle_display = "pkill -x -f 'caffeinate -di' || { caffeinate -di >/dev/null 2>&1 & }"

-- keeps the mac awake with the lid closed
-- waits up to 5s for keepawake to apply or undo the setting, since sbar.exec has no usable timeout
local toggle_lid = [=[
i=0
if pkill -f '/bin/keepawake$'; then
    while [ $i -lt 100 ] && pgrep -f '/bin/keepawake$' >/dev/null; do sleep 0.05; i=$((i + 1)); done
else
    keepawake >/dev/null 2>&1 &
    while [ $i -lt 100 ] && kill -0 $! 2>/dev/null && ! pmset -g | grep -q 'SleepDisabled[[:space:]]*1'; do
        sleep 0.05
        i=$((i + 1))
    done
fi]=]

local function render(info)
    local state = parse(info)
    sleep:set({
        icon = {
            string = state.display and icons.circle_fill or icons.circle,
            color = state.lid and colors.orange or colors.text,
        },
    })
end

local function update()
    sbar.exec(state_cmd, function(info)
        -- a keepawake killed with -9 cannot reset the setting itself
        local state = parse(info)
        if state.lid and not state.holder then
            sbar.exec("/usr/bin/sudo /usr/bin/pmset -a disablesleep 0\n" .. state_cmd, render)
            return
        end
        render(info)
    end)
end

sleep:subscribe({ "forced", "routine", "system_woke" }, update)

-- the shell decides what to toggle, so a click never acts on a stale read
sleep:subscribe("mouse.clicked", function(env)
    local toggle = env.BUTTON == "right" and toggle_lid or toggle_display
    sbar.exec(toggle .. "\n" .. state_cmd, render)
end)
