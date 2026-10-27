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
}

local hyper_groups = { alt = true, shift = true, cmd = true, ctrl = true }

-- one key from each of the four groups, either side, becomes hyper
-- extra modifier keys stay listed
-- the right key counts toward hyper since caps lock sends the right keys
local function name_hyper(chord)
    local tokens = {}
    for token in (chord .. " + "):gmatch("(.-) %+ ") do
        tokens[#tokens + 1] = token
    end

    local used = {}
    for i = 1, #tokens - 1 do
        local side, group = tokens[i]:match("^([lr]?)(%a+)$")
        if hyper_groups[group] and (not used[group] or side == "r") then
            used[group] = i
        end
    end
    if not (used.alt and used.shift and used.cmd and used.ctrl) then
        return chord
    end

    local out = { "hyper" }
    for i, token in ipairs(tokens) do
        local group = token:match("^[lr]?(%a+)$")
        if used[group] ~= i then
            out[#out + 1] = token
        end
    end
    return table.concat(out, " + ")
end

smhkd:subscribe("smhkd_sequence", function(env)
    -- sketchybar drops empty trigger vars, so an exited sequence arrives as nil
    local sequence = env.SEQUENCE or "default"
    local chords = {}
    for chord in (sequence .. " ; "):gmatch("(.-) ; ") do
        chords[#chords + 1] = name_hyper(chord)
    end
    sequence = table.concat(chords, " ; ")

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
