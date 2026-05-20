local set_padding = function(options)
    options.padding_left = options.padding_left or 3
    options.padding_right = options.padding_right or 3
    return options
end

sbar.add_label_item = function(name, options)
    options = set_padding(options)

    options.icon = options.icon or {}
    options.icon.drawing = false

    options.label = options.label or {}

    if options.label.padding_left == nil then
        options.label.padding_left = 7
    end

    if options.label.padding_right == nil then
        options.label.padding_right = 7
    end

    local item = sbar.add("item", name, options)
    return item
end

sbar.add_icon_item = function(name, options)
    options = set_padding(options)

    options.label = options.label or {}
    options.label.drawing = false

    options.icon = options.icon or {}

    if options.icon.padding_left == nil then
        options.icon.padding_left = 7
    end

    if options.icon.padding_right == nil then
        options.icon.padding_right = 7
    end

    local item = sbar.add("item", name, options)
    return item
end

sbar.add_item = function(name, options)
    options = set_padding(options)

    local item = sbar.add("item", name, options)
    return item
end

sbar.add_graph = function(name, width, options)
    local graph = sbar.add("graph", name, width, options)
    return graph
end

sbar.add_space = function(name, options)
    local space = sbar.add("space", name, options)
    return space
end

sbar.add_event = function(name)
    sbar.add("event", name)
end

sbar.get_mode = function()
    local apple_color = tonumber(sbar.query("apple").icon.color)

    if apple_color == settings.mode_colors.menu then
        return "menu"
    elseif apple_color == settings.mode_colors.zen then
        return "zen"
    else
        return "default"
    end
end
