local yabai = sbar.add_icon_item("yabai", {
    updates = true,
    background = { drawing = false, },
})

local yabai_bin = "/opt/homebrew/bin/yabai"
local window_query =
    yabai_bin .. " -m query --windows is-sticky,is-floating,sub-layer,has-fullscreen-zoom,stack-index --window 2>/dev/null || echo err"
local space_query = yabai_bin .. " -m query --spaces type --space 2>/dev/null || echo err"

yabai:subscribe({ "front_app_switched", "yabai_window_state", "window_focused", "forced" }, function(env)
    sbar.exec(window_query, function(window_data)
        sbar.exec(space_query, function(space_data)
            local c = colors.text
            -- local label = nil

            local space_type = type(space_data) == "table" and space_data.type or nil

            if type(window_data) == "table" then
                -- color represents window state
                if window_data["is-sticky"] then
                    -- sticky also means it acts like floating
                    c = colors.green
                elseif window_data["is-floating"] or (space_type == "float") then
                    -- either is a floating window or the entire space is floating
                    c = colors.purple
                -- elseif window_data["sub-layer"] ~= "below" then
                --     -- not below layer
                --     c = colors.yellow
                elseif window_data["has-fullscreen-zoom"] then
                    -- fullscreen zoom
                    c = colors.red
                else
                    -- managed window, bsp or stack
                    c = colors.blue
                end
            end

            -- stack indicator
            -- local stack_index = window_data["stack-index"]
            -- print(stack_index)
            -- if stack_index > 0 then -- stack
            --     local last_stack_index = sbar.exec("yabai -m query --windows --window stack.last 2>/dev/null",
            --         function(last_stack_data)
            --             return last_stack_data["stack-index"]
            --         end)
            --     label = string.format("[%s/%s]", stack_index, last_stack_index)
            -- end

            -- icon represent space state
            local icon = nil
            if space_type == "bsp" then
                icon = icons.yabai_grid
            elseif space_type == "stack" then
                icon = icons.yabai_stack
            elseif space_type == "float" then
                icon = icons.yabai_float
                if c ~= colors.text then c = colors.purple end
            end

            -- sbar.animate("sin", 10, function()
            -- print(label, icon, c)
            yabai:set({
                drawing = icon ~= nil,
                icon = { color = c, string = icon, width = icon and 25 or 0 },
                -- label = { string = label, width = label and "dynamic" or 0 },
            })

            -- sbar:bar({ border_color = c })
            -- end)
        end)
    end)
end)
