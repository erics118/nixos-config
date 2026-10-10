local wezterm = require("wezterm")
local keys = require("keys")

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
}

-- nested tables merge key by key, anything else replaces
local function merge(base, over)
    for k, v in pairs(over) do
        if type(v) == "table" and type(base[k]) == "table" then
            merge(base[k], v)
        else
            base[k] = v
        end
    end
    return base
end

-- right-hand divider glyph per style
local dividers = {
    slant_right = utf8.char(0xe0bc),
    slant_left = utf8.char(0xe0b8),
    arrows = utf8.char(0xe0b0),
    rounded = utf8.char(0xe0b4),
}

-- the divider after each tab, empty when dividers is false
local div = ""

-- conforming to https://github.com/wez/wezterm/commit/e4ae8a844d8feaa43e1de34c5cc8b4f07ce525dd
-- exporting an apply_to_config function, which sets the tab bar options on the config
M.apply_to_config = function(c, opts)
    merge(config, opts or {})
    div = config.dividers and assert(dividers[config.dividers], "unknown dividers: " .. tostring(config.dividers)) or ""

    -- set wezterm config options according to the merged config
    c.use_fancy_tab_bar = false
    c.tab_bar_at_bottom = config.position == "bottom"
    c.tab_max_width = config.max_width

    -- built before wezterm resolves a palette, so colors come from the configured scheme
    local scheme = (c.color_schemes or {})[c.color_scheme] or wezterm.color.get_builtin_schemes()[c.color_scheme]
    assert(scheme, "bar.lua needs c.color_scheme set before apply_to_config")
    local new_tab = scheme.tab_bar.new_tab
    local new_tab_style = wezterm.format({
        { Background = { Color = new_tab.bg_color } },
        { Foreground = { Color = new_tab.fg_color } },
        { Text = " + " },
        { Background = { Color = scheme.background } },
        { Foreground = { Color = new_tab.bg_color } },
        { Text = div },
    })

    -- TODO: plus sign config
    c.tab_bar_style = {
        new_tab = new_tab_style,
        new_tab_hover = new_tab_style,
    }
end

-- digits 0-9 in each pane_count style
local digit_styles = {
    superscript = { "⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹" },
    subscript = { "₀", "₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈", "₉" },
}

local function styled_number(number, style)
    return (tostring(number):gsub("%d", function(d)
        return digit_styles[style][tonumber(d) + 1]
    end))
end

local roman_numerals = { "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ", "Ⅶ", "Ⅷ", "Ⅸ", "Ⅹ", "Ⅺ", "Ⅻ" }

-- a bell in a background tab marks it until the tab is next shown
wezterm.on("bell", function(window, pane)
    local tab = pane:tab()
    if tab and tab:tab_id() ~= window:active_tab():tab_id() then
        wezterm.GLOBAL["bell_tab_" .. tab:tab_id()] = true
    end
end)

-- custom tab bar
wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
    local colours = conf.resolved_palette.tab_bar

    local active_tab_index = 0
    for _, t in ipairs(tabs) do
        if t.is_active == true then
            active_tab_index = t.tab_index
        end
    end

    -- the scheme's red
    local active_bg = conf.resolved_palette.ansi[2]
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
        e_bg = active_bg
    end

    -- now we format the tab string

    -- a lone pane shows no count
    local pane_count = ""
    if config.tabs.pane_count then
        local n = #wezterm.mux.get_tab(tab.tab_id):panes()
        pane_count = styled_number(n == 1 and "" or n, config.tabs.pane_count)
    end

    local index_i = config.tabs.numerals == "roman" and roman_numerals[tab.tab_index + 1] or tab.tab_index + 1

    local title = tab.is_active and config.tabs.tab_format.active or config.tabs.tab_format.inactive

    local workspace = wezterm.mux.get_active_workspace()

    -- replace placeholders
    title = title:gsub("{tab_index}", index_i)
    -- function replacements, since a "%" in a title is special in a gsub replacement string
    title = title:gsub("{workspace}", function()
        return workspace
    end)

    local tab_title = tab.active_pane.title
    -- mosh prepends [mosh] to the title
    tab_title = tab_title:gsub("^%[mosh[^%]]*%]%s*", "")

    -- tmux prefixes its title with ✗, ‼, ✓ or • while any of its windows is flagged (see tmux/main.conf)
    local tmux_alert
    for marker, kind in pairs({ ["✗ "] = "fail", ["‼ "] = "bell", ["✓ "] = "ok", ["• "] = "activity" }) do
        if tab_title:sub(1, #marker) == marker then
            tmux_alert = kind
            tab_title = tab_title:sub(#marker + 1)
        end
    end

    -- then tmux's window count as [N] when it has more than one, shown in place of the pane count
    local tmux_windows = tab_title:match("^%[(%d+)%] ")
    if tmux_windows then
        tab_title = tab_title:sub(#tmux_windows + 4)
        if config.tabs.pane_count then
            pane_count = " (" .. tmux_windows .. ")"
        end
    end
    title = title:gsub("{pane_count}", pane_count)

    -- a background tab's number turns bold red after a failed command, peach after a bell,
    -- green after a successful command, or blue after new output, like tmux's tabline.
    -- tmux's flags last until that tmux window is visited, so the colour survives switching tabs
    local alert_fg
    local bell_key = "bell_tab_" .. tab.tab_id
    if tab.is_active then
        wezterm.GLOBAL[bell_key] = nil
    elseif tmux_alert == "fail" then
        alert_fg = "#f38ba8"
    elseif wezterm.GLOBAL[bell_key] or tmux_alert == "bell" then
        alert_fg = "#fab387"
    elseif tmux_alert == "ok" then
        alert_fg = "#a6e3a1"
    elseif tmux_alert == "activity" then
        alert_fg = "#89b4fa"
    else
        -- tmux marks its own new output in the title, while this check counts a spinner redraw too
        for _, p in ipairs(wezterm.mux.get_tab(tab.tab_id):panes()) do
            if p:has_unseen_output() then
                local info = p:get_foreground_process_info()
                if not (info and keys.runs_tmux(info)) then
                    alert_fg = "#89b4fa"
                end
            end
        end
    end

    -- columns besides the title: the format minus the 11 of "{tab_title}",
    -- plus 3 for the 2 padding spaces and the divider
    local filler_width = wezterm.column_width(title) - 11 + 3
    -- the first tab also draws the leader pill's divider, see below
    if config.indicator.leader.enabled and tab.tab_index == 0 then
        filler_width = filler_width + wezterm.column_width(div)
    end
    if (wezterm.column_width(tab_title) + filler_width) > max_width then
        -- 1 for ellipsis
        -- floored at 0, since truncate_right errors on a negative width when a tab is narrower than its fixed parts
        local new_title_width = math.max(0, max_width - filler_width - 1)
        tab_title = wezterm.truncate_right(tab_title, new_title_width) .. "…"
    end

    title = title:gsub("{tab_title}", function()
        return tab_title
    end)

    -- padding
    title = " " .. title .. " "

    local res = {
        { Background = { Color = s_bg } },
        { Foreground = { Color = s_fg } },
        { Text = title },
        { Background = { Color = e_bg } },
        { Foreground = { Color = e_fg } },
        { Text = div },
    }

    -- split the title around the number so only the number takes the alert colour
    local i = alert_fg and title:find(tostring(index_i), 1, true)
    if i then
        local j = i + #tostring(index_i)
        res[3] = { Text = title:sub(1, i - 1) }
        table.insert(res, 4, { Foreground = { Color = alert_fg } })
        table.insert(res, 5, { Attribute = { Intensity = "Bold" } })
        table.insert(res, 6, { Text = title:sub(i, j - 1) })
        table.insert(res, 7, { Attribute = { Intensity = "Normal" } })
        table.insert(res, 8, { Foreground = { Color = s_fg } })
        table.insert(res, 9, { Text = title:sub(j) })
    end

    -- the first tab also draws the divider after the leader pill
    if config.indicator.leader.enabled and tab.tab_index == 0 then
        table.insert(res, 1, { Text = div })
        table.insert(res, 1, { Foreground = { Color = conf.resolved_palette.ansi[5] } })
        table.insert(res, 1, { Background = { Color = s_bg } })
    end

    return res
end)

wezterm.on("update-status", function(window, _pane)
    local leader_cfg, mode_cfg = config.indicator.leader, config.indicator.mode
    local active_kt = window:active_key_table() ~= nil
    local show = leader_cfg.enabled or (active_kt and mode_cfg.enabled)

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
    if leader_cfg.enabled then
        local leader_text = window:leader_is_active() and leader_cfg.on or leader_cfg.off
        leader = wezterm.format({
            { Foreground = { Color = palette.background } },
            { Background = { Color = palette.ansi[5] } },
            { Text = " " .. leader_text .. " " },
        })
    end

    local mode = ""
    if mode_cfg.enabled then
        local mode_text = mode_cfg.names[window:active_key_table()] or ""
        mode = wezterm.format({
            { Foreground = { Color = palette.background } },
            { Background = { Color = palette.ansi[5] } },
            { Attribute = { Intensity = "Bold" } },
            { Text = mode_text },
            "ResetAttributes",
        })
    end

    window:set_left_status(leader .. mode)
end)

return M
