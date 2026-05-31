local wezterm = require("wezterm")

local M = {}

-- default configuration
local config = {
    position = "bottom",
    max_width = 50,
    dividers = "slant_right",
    indicator = {
        leader = {
            enabled = true,
            off = " ",
            on = " ",
        },
        mode = {
            enabled = true,
            names = {
                resize_mode = "RESIZE",
                copy_mode = "VISUAL",
                search_mode = "SEARCH",
            },
        },
    },
    tabs = {
        numerals = "arabic",
        pane_count = "superscript",
        tab_format = {
            active = "{tab_index}: {tab_title}{pane_count}",
            inactive = "{tab_index}: {tab_title}{pane_count}",
        },
    },
    clock = {
        enabled = true,
        format = "%H:%M:%S",
    },
}

-- parsed config
local C = {}

local function tableMerge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k] or false) == "table" then
                tableMerge(t1[k] or {}, t2[k] or {})
            else
                t1[k] = v
            end
        else
            t1[k] = v
        end
    end
    return t1
end

local dividers = {
    slant_right = {
        left = utf8.char(0xe0be),
        right = utf8.char(0xe0bc),
    },
    slant_left = {
        left = utf8.char(0xe0ba),
        right = utf8.char(0xe0b8),
    },
    arrows = {
        left = utf8.char(0xe0b2),
        right = utf8.char(0xe0b0),
    },
    rounded = {
        left = utf8.char(0xe0b6),
        right = utf8.char(0xe0b4),
    },
}

-- conforming to https://github.com/wez/wezterm/commit/e4ae8a844d8feaa43e1de34c5cc8b4f07ce525dd
-- exporting an apply_to_config function, even though we don't change the users config
M.apply_to_config = function(c, opts)
    -- make the opts arg optional
    if not opts then
        opts = {}
    end

    -- combine user config with defaults
    config = tableMerge(config, opts)
    C.div = {
        l = "",
        r = "",
    }

    if config.dividers then
        C.div.l = dividers[config.dividers].left
        C.div.r = dividers[config.dividers].right
    end

    C.leader = {
        enabled = config.indicator.leader.enabled and true,
        off = config.indicator.leader.off,
        on = config.indicator.leader.on,
    }

    C.mode = {
        enabled = config.indicator.mode.enabled,
        names = config.indicator.mode.names,
    }

    C.tabs = {
        numerals = config.tabs.numerals,
        pane_count_style = config.tabs.pane_count,
        tab_format = {
            active = config.tabs.tab_format.active,
            inactive = config.tabs.tab_format.inactive,
        },
    }

    C.clock = {
        enabled = config.clock.enabled,
        format = config.clock.format,
    }

    -- set wezterm config options according to the parsed config
    c.use_fancy_tab_bar = false
    c.tab_bar_at_bottom = config.position == "bottom"
    c.tab_max_width = config.max_width

    local new_tab_style = wezterm.format({
        { Background = { Color = "#313244" } },
        { Foreground = { Color = "#cdd6f4" } },
        { Text = " + " },
        { Background = { Color = "#1E1E2E" } },
        { Foreground = { Color = "#313244" } },
        { Text = C.div.r },
    })

    -- TODO: plus sign config
    c.tab_bar_style = {
        new_tab = new_tab_style,
        new_tab_hover = new_tab_style,
    }
end

-- superscript/subscript
local function numberStyle(number, script)
    local scripts = {
        superscript = {
            "⁰",
            "¹",
            "²",
            "³",
            "⁴",
            "⁵",
            "⁶",
            "⁷",
            "⁸",
            "⁹",
        },
        subscript = {
            "₀",
            "₁",
            "₂",
            "₃",
            "₄",
            "₅",
            "₆",
            "₇",
            "₈",
            "₉",
        },
    }
    local numbers = scripts[script]
    local number_string = tostring(number)
    local result = ""
    for i = 1, #number_string do
        local char = number_string:sub(i, i)
        local num = tonumber(char)
        if num then
            result = result .. numbers[num + 1]
        else
            result = result .. char
        end
    end
    return result
end

local roman_numerals = {
    "Ⅰ",
    "Ⅱ",
    "Ⅲ",
    "Ⅳ",
    "Ⅴ",
    "Ⅵ",
    "Ⅶ",
    "Ⅷ",
    "Ⅸ",
    "Ⅹ",
    "Ⅺ",
    "Ⅻ",
}

local function table_concat(t1, t2)
    for i = 1, #t2 do
        t1[#t1 + 1] = t2[i]
    end
    return t1
end

-- custom tab bar
wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
    local colours = conf.resolved_palette.tab_bar

    local active_tab_index = 0
    for _, t in ipairs(tabs) do
        if t.is_active == true then
            active_tab_index = t.tab_index
        end
    end

    -- TODO: make colors configurable
    local rainbow = {
        conf.resolved_palette.ansi[2],
        conf.resolved_palette.indexed[16],
        conf.resolved_palette.ansi[4],
        conf.resolved_palette.ansi[3],
        conf.resolved_palette.ansi[5],
        conf.resolved_palette.ansi[6],
    }

    local i = tab.tab_index % 6
    local active_bg = rainbow[i + 1]
    local active_fg = colours.background
    local inactive_bg = colours.inactive_tab.bg_color
    local inactive_fg = colours.inactive_tab.fg_color
    local new_tab_bg = colours.new_tab.bg_color

    local s_bg, s_fg, e_bg, e_fg

    -- each tab title contains: padding tab_title padding divider
    -- this way the logic for dividers is very simple

    -- assume this is a tab in the middle of all the tabs
    if tab.is_active then
        s_bg = active_bg
        s_fg = active_fg
        e_bg = inactive_bg
        e_fg = active_bg
    else
        s_bg = inactive_bg
        s_fg = inactive_fg
        e_bg = inactive_bg
        e_fg = inactive_bg
    end

    -- the last tab
    if tab.tab_index == #tabs - 1 then
        e_bg = new_tab_bg
    end

    -- the tab before the active one
    if tab.tab_index == active_tab_index - 1 then
        e_bg = rainbow[(i + 1) % 6 + 1]
    end

    -- now we format the tab string

    local pane_count = ""
    if C.tabs.pane_count_style then
        local tab_index = wezterm.mux.get_tab(tab.tab_id)
        local muxpanes = tab_index:panes()
        local count = #muxpanes == 1 and "" or tostring(#muxpanes)
        pane_count = numberStyle(count, C.tabs.pane_count_style)
    end

    local index_i
    if C.tabs.numerals == "roman" then
        index_i = roman_numerals[tab.tab_index + 1]
    else
        index_i = tab.tab_index + 1
    end

    local title
    if tab.is_active then
        title = C.tabs.tab_format.active
    else
        title = C.tabs.tab_format.inactive
    end

    local workspace = wezterm.mux.get_active_workspace()

    -- replace placeholders
    title = title:gsub("{tab_index}", index_i)
    title = title:gsub("{pane_count}", pane_count)
    title = title:gsub("{workspace}", workspace)

    -- for measuring length
    -- 11 for {tab_title}
    -- 3 for padding, 2 spaces, 1 char
    -- 1 for ellipsis
    -- 2 for testing purposes
    local tab_title = tab.active_pane.title

    local filler_width = #title - 11 + 3 + 1
    if (#tab_title + filler_width) > max_width then
        -- 1 for ellipsis
        local new_title_width = max_width - filler_width - 1
        wezterm.log_info(new_title_width)
        tab_title = wezterm.truncate_right(tab_title, new_title_width) .. "…"
    end

    title = title:gsub("{tab_title}", tab_title)

    -- padding
    title = " " .. title .. " "

    local res = {
        { Background = { Color = s_bg } },
        { Foreground = { Color = s_fg } },
        { Text = title },
        { Background = { Color = e_bg } },
        { Foreground = { Color = e_fg } },
        { Text = C.div.r },
    }

    -- for first tab, add additional divider for leader
    if C.leader.enabled then
        if tab.tab_index == 0 then
            local divider = {
                { Background = { Color = s_bg } },
                { Foreground = { Color = conf.resolved_palette.ansi[5] } },
                { Text = C.div.r },
            }
            res = table_concat(divider, res)
        end
    end

    return res
end)

wezterm.on("update-status", function(window, _pane)
    local active_kt = window:active_key_table() ~= nil
    local show = C.leader.enabled or (active_kt and C.mode.enabled)

    if not show then
        window:set_left_status("")
        return
    end

    local present, conf = pcall(window.effective_config, window)
    if not present then
        return
    end

    local palette = conf.resolved_palette

    local leader = ""
    if C.leader.enabled then
        local leader_text = C.leader.off
        if window:leader_is_active() then
            leader_text = C.leader.on
        end
        leader = wezterm.format({
            { Foreground = { Color = palette.background } },
            { Background = { Color = palette.ansi[5] } },
            { Text = " " .. leader_text .. " " },
        })
    end

    local mode = ""
    if C.mode.enabled then
        local mode_text = ""
        local active = window:active_key_table()
        if C.mode.names[active] ~= nil then
            mode_text = C.mode.names[active] .. ""
        end
        mode = wezterm.format({
            { Foreground = { Color = palette.background } },
            { Background = { Color = palette.ansi[5] } },
            { Attribute = { Intensity = "Bold" } },
            { Text = mode_text },
            "ResetAttributes",
        })
    end

    window:set_left_status(leader .. mode)

    if C.clock.enabled then
        local time = wezterm.time.now():format(C.clock.format)
        window:set_right_status(wezterm.format({
            { Background = { Color = palette.tab_bar.background } },
            { Foreground = { Color = palette.ansi[6] } },
            { Text = time },
        }))
    end
end)

return M
