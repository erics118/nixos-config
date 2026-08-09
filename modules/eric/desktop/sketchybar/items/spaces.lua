local app_icons = require("helpers.app_icons")

local spaces = {}

for i = 1, 10, 1 do
    local space = sbar.add_space("space." .. i, {
        space = i,
        icon = {
            padding_left = 7,
            padding_right = 3,
            string = i,
            color = colors.text,
            highlight_color = colors.red,
        },
        label = {
            padding_left = 3,
            padding_right = 3,
            color = colors.text,
            highlight_color = colors.text,
            font = "sketchybar-app-font:Regular:13.0",
        },
        padding_right = 1,
        padding_left = i == 1 and 4 or 2,
        background = {
            color = colors.item.bg,
            border_width = 2,
            border_color = colors.item.border,
        },
        popup = {
            background = {
                border_width = 5,
                border_color = colors.black,
            },
        },
    })

    spaces[i] = space

    local space_popup = sbar.add_item("space_popup." .. i, {
        position = "popup." .. space.name,
        padding_left = 5,
        padding_right = 0,
        background = {
            drawing = true,
            image = {
                corner_radius = 9,
                scale = 0.14,
            },
        },
    })

    space:subscribe("space_change", function(env)
        local selected = env.SELECTED == "true"
        space:set({
            icon = { highlight = selected },
            label = { highlight = selected },
            background = { border_color = selected and colors.item.highlighted_border or colors.item.border },
        })
    end)

    space:subscribe("mouse.clicked", function(env)
        if env.BUTTON == "left" then
            sbar.exec("yabai -m space --focus " .. env.SID .. " 2>/dev/null")
        else
            space_popup:set({ background = { image = "space." .. env.SID } })
            space:set({ popup = { drawing = "toggle" } })
        end
    end)

    space:subscribe("mouse.exited", function(_)
        space:set({ popup = { drawing = false } })
    end)
end

local space_window_observer = sbar.add_item("space_window_observer", {
    drawing = false,
    updates = true,
})

-- local spaces_indicator = sbar.add_item("spaces_indicator", {
--     padding_left = 3,
--     padding_right = 0,
--     icon = {
--         padding_left = 8,
--         padding_right = 9,
--         color = colors.grey,
--         string = icons.switch.on,
--     },
--     label = {
--         width = 0,
--         padding_left = 0,
--         padding_right = 8,
--         string = "Spaces",
--         color = colors.item.bg,
--     },
--     background = {
--         color = colors.with_alpha(colors.grey, 0.0),
--         border_color = colors.with_alpha(colors.item.bg, 0.0),
--     },
-- })

local function has_value(tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local window_query = [[
yabai -m query --windows space,title,app,is-sticky,stack-index,is-hidden 2>/dev/null | jq '
  map(select((."is-sticky" or ."is-hidden" or (.title == "")) | not))
  | sort_by(.space, ."stack-index")
  | group_by(.space)
  | map({ (.[0].space|tostring): map(.app) })
  | add
' || echo '{}']]

space_window_observer:subscribe({ "space_windows_change" }, function(env)
    sbar.exec(window_query, function(window_data)
        if type(window_data) ~= "table" then
            window_data = {}
        end

        for i = 1, 10, 1 do
            local apps = window_data[tostring(i)] or {}

            local label = ""

            for _, app in ipairs(apps) do
                if not has_value(settings.ignored_apps, app) then
                    local icon = app_icons[app] or app_icons["Default"]
                    label = label .. icon
                end
            end

            if label == "" then
                label = "  "
            end

            spaces[i]:set({ label = label })
        end
    end)
end)

-- spaces_indicator:subscribe("mouse.entered", function(env)
--     sbar.animate("tanh", 20, function()
--         spaces_indicator:set({
--             background = {
--                 color = { alpha = 1.0 },
--                 border_color = { alpha = 1.0 },
--             },
--             icon = { color = colors.item.bg },
--             label = { width = "dynamic" }
--         })
--     end)
-- end)
--
-- spaces_indicator:subscribe("mouse.exited", function(env)
--     sbar.animate("tanh", 20, function()
--         spaces_indicator:set({
--             background = {
--                 color = { alpha = 0.0 },
--                 border_color = { alpha = 0.0 },
--             },
--             icon = { color = colors.grey },
--             label = { width = 0, }
--         })
--     end)
-- end)
--
-- spaces_indicator:subscribe("mouse.clicked", function(env)
--     sbar.trigger("swap_menus_and_spaces")
-- end)
