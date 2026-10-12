local wezterm = require("wezterm")
local keys = require("keys")
local act = wezterm.action

-- each alert's colour, catppuccin mocha red, peach, green and blue as tmux's @session-alert has them
-- (see tmux/tabline.conf), and the SF Symbol the native toolbar shows it as
local alerts = {
    fail = { colour = "#f38ba8", symbol = "xmark.circle.fill" },
    bell = { colour = "#fab387", symbol = "bell.fill" },
    ok = { colour = "#a6e3a1", symbol = "checkmark.circle.fill" },
    activity = { colour = "#89b4fa", symbol = "circle.fill" },
}

-- the native toolbar's status icon for an alert, or an empty one that keeps its slot
local function alert_icon(alert)
    local known = alert and alerts[alert]
    return known and { symbol = known.symbol, color = known.colour } or {}
end

local M = {}

-- default configuration
local config = {
    position = "bottom",
    max_width = 50,
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

-- the native toolbar shows the tabs on macos (see apply_to_config)
local native = wezterm.target_triple:find("darwin") ~= nil

-- conforming to https://github.com/wez/wezterm/commit/e4ae8a844d8feaa43e1de34c5cc8b4f07ce525dd
-- exporting an apply_to_config function, which sets the tab bar options on the config
M.apply_to_config = function(c, opts)
    merge(config, opts or {})

    -- set wezterm config options according to the merged config.
    -- the native toolbar, alignment and tab shape options exist only in the erics118/wezterm fork.
    -- macos shows the tabs in its native toolbar, and other platforms draw centered pills
    c.macos_native_tab_bar = true
    c.use_fancy_tab_bar = true
    c.fancy_tab_bar_alignment = "Center"
    c.fancy_tab_bar_tab_shape = "Pill"
    c.tab_bar_at_bottom = config.position == "bottom"
    c.tab_max_width = config.max_width
    c.show_new_tab_button_in_tab_bar = false
    c.show_close_tab_button_in_tabs = false
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

-- mosh prepends [mosh] to the title
local function strip_mosh(title)
    return (title:gsub("^%[mosh[^%]]*%]%s*", ""))
end

-- this machine as tmux's #{host_short} names it
local local_host = wezterm.hostname():match("^[^.]*")

-- tmux's title is host:session: window after its markers (see tmux/main.conf), and the markers hold no ":".
-- returns the session, the host or nil for this machine, the window, and whether tmux tagged it with a host.
-- a title tmux did not set returns nil
local function split_tmux_title(title)
    local head, window_name = title:match("^(.-): (.*)$")
    if not head then
        return nil
    end
    local host, session = head:match("^(.-):(.*)$")
    if not host then
        return head, nil, window_name, false
    end
    return session, host ~= local_host and host or nil, window_name, true
end

-- a tmux title as host: session - window, the way it reads in the tabline
function M.display_title(title)
    local session, host, window_name = split_tmux_title(title)
    if not session then
        return title
    end
    return (host and host .. ": " or "") .. session .. " - " .. window_name
end

-- tmux's alert marker as an alert kind, or nil, and the title without it.
-- tmux prefixes its title with ✗, ‼, ✓ or • while any of its windows is flagged (see tmux/main.conf)
local function title_marker(title)
    for marker, kind in pairs({ ["✗ "] = "fail", ["‼ "] = "bell", ["✓ "] = "ok", ["• "] = "activity" }) do
        if title:sub(1, #marker) == marker then
            return kind, title:sub(#marker + 1)
        end
    end
    return nil, title
end

-- a tab's alert (see alerts), or nil, and its title without tmux's marker.
-- tmux's flags last until that tmux window is visited, so the alert survives switching tabs.
-- the active tab keeps only tmux's, which then comes from the session's other windows
local function tab_alert(tab_id, title, is_active)
    local tmux_alert
    tmux_alert, title = title_marker(title)
    local bell_key = "bell_tab_" .. tab_id
    if is_active then
        wezterm.GLOBAL[bell_key] = nil
        return tmux_alert, title
    elseif tmux_alert == "fail" then
        return "fail", title
    elseif wezterm.GLOBAL[bell_key] or tmux_alert == "bell" then
        return "bell", title
    elseif tmux_alert then
        return tmux_alert, title
    end
    -- tmux marks its own new output in the title, while this check counts a spinner redraw too
    for _, p in ipairs(wezterm.mux.get_tab(tab_id):panes()) do
        if p:has_unseen_output() then
            local info = p:get_foreground_process_info()
            if not (info and keys.runs_tmux(info)) then
                return "activity", title
            end
        end
    end
    return nil, title
end

-- custom tab bar
wezterm.on("format-tab-title", function(tab, tabs, panes, conf, hover, max_width)
    -- the fancy tab bar fills each pill with the title's first background.
    -- catppuccin mocha surface0 marks the active pill, half of it a hovered one, and the rest stay clear
    local bg = "rgba(0, 0, 0, 0)"
    if tab.is_active then
        bg = "#313244"
    elseif hover then
        bg = "rgba(49, 50, 68, 0.5)"
    end
    -- catppuccin mocha subtext0 dims the inactive titles
    local fg = tab.is_active and conf.resolved_palette.foreground or "#a6adc8"

    -- now we format the tab string

    -- a lone pane shows no count
    local pane_count = ""
    if config.tabs.pane_count then
        local n = #wezterm.mux.get_tab(tab.tab_id):panes()
        pane_count = styled_number(n == 1 and "" or n, config.tabs.pane_count)
    end

    local index_i = config.tabs.numerals == "roman" and roman_numerals[tab.tab_index + 1] or tab.tab_index + 1

    local title = tab.is_active and config.tabs.tab_format.active or config.tabs.tab_format.inactive
    local shows_index = title:find("{tab_index}", 1, true) ~= nil

    local workspace = wezterm.mux.get_active_workspace()

    -- replace placeholders
    title = title:gsub("{tab_index}", index_i)
    -- function replacements, since a "%" in a title is special in a gsub replacement string
    title = title:gsub("{workspace}", function()
        return workspace
    end)

    local alert, tab_title = tab_alert(tab.tab_id, strip_mosh(tab.active_pane.title), tab.is_active)

    -- then tmux's window count as [N] when it has more than one, shown in place of the pane count
    local tmux_windows = tab_title:match("^%[(%d+)%] ")
    if tmux_windows then
        tab_title = tab_title:sub(#tmux_windows + 4)
        if config.tabs.pane_count then
            pane_count = " (" .. tmux_windows .. ")"
        end
    end
    tab_title = M.display_title(tab_title)
    title = title:gsub("{pane_count}", pane_count)

    -- a background tab's number takes its alert's colour, like tmux's tabline.
    -- the native toolbar shows the alert as a status icon instead (see update-status)
    local alert_fg = not native and alert and alerts[alert].colour

    -- columns besides the title: the format minus the 11 of "{tab_title}", plus 2 for the padding spaces.
    -- the native toolbar fades a long title itself, so it gets the whole title
    local filler_width = wezterm.column_width(title) - 11 + 2
    if not native and (wezterm.column_width(tab_title) + filler_width) > max_width then
        -- 1 for ellipsis
        -- floored at 0, since truncate_right errors on a negative width when a tab is narrower than its fixed parts
        local new_title_width = math.max(0, max_width - filler_width - 1)
        tab_title = wezterm.truncate_right(tab_title, new_title_width) .. "…"
    end

    title = title:gsub("{tab_title}", function()
        return tab_title
    end)

    -- the native toolbar pads and colours the title itself, so it gets no padding or base colours
    if not native then
        title = " " .. title .. " "
    end
    local base = native and {} or { { Background = { Color = bg } }, { Foreground = { Color = fg } } }

    local res = {}
    for _, item in ipairs(base) do
        table.insert(res, item)
    end

    -- split the title around the number so only the number takes the alert colour.
    -- a format without the number gives the whole title the alert colour instead
    local i = alert_fg and shows_index and title:find(tostring(index_i), 1, true)
    if alert_fg and not shows_index then
        table.insert(res, { Foreground = { Color = alert_fg } })
        table.insert(res, { Text = title })
    elseif i then
        local j = i + #tostring(index_i)
        table.insert(res, { Text = title:sub(1, i - 1) })
        table.insert(res, { Foreground = { Color = alert_fg } })
        table.insert(res, { Attribute = { Intensity = "Bold" } })
        table.insert(res, { Text = title:sub(i, j - 1) })
        table.insert(res, "ResetAttributes")
        for _, item in ipairs(base) do
            table.insert(res, item)
        end
        table.insert(res, { Text = title:sub(j) })
    else
        table.insert(res, { Text = title })
    end

    return res
end)

-- tools run by name, since the gui adopts the login shell's PATH (see the fork's adopt_login_shell_path)
local function lines(args)
    local ok, out = wezterm.run_child_process(args)
    local result = {}
    if ok then
        for line in out:gmatch("[^\n]+") do
            table.insert(result, line)
        end
    end
    return result
end

-- the session a pane shows and its host, nil for this machine, or nil outside tmux.
-- it comes from the title tmux sets on every host, so no tmux process runs per update
local function pane_session(pane)
    local _, title = title_marker(strip_mosh(pane:get_title()))
    local session, host, _, tagged = split_tmux_title((title:gsub("^%[%d+%] ", "")))
    if tagged then
        return session, host
    end
end

-- every pane that shows a session, in any tab or window, keyed by "host:session" with an empty host for this machine.
-- it checks every pane, as sesh-pick does before handing a pick here, so a session in an inactive split is still found
local function open_tabs()
    local open = {}
    for _, mux_window in ipairs(wezterm.mux.all_windows()) do
        for _, tab in ipairs(mux_window:tabs()) do
            for _, pane in ipairs(tab:panes()) do
                -- a pane closing mid-update raises
                local ok, session, host = pcall(pane_session, pane)
                if ok and session then
                    open[(host or "") .. ":" .. session] = { pane = pane, window = mux_window }
                end
            end
        end
    end
    return open
end

-- this machine's and other hosts' sessions from the last time the menu opened, as host, name and alert.
-- a status update only reuses them, so it runs no process after the first
local local_sessions
local remote_sessions = {}

local function fetch_local()
    local rows = {}
    for _, line in ipairs(lines({ "timeout", "1", "tmux-sessions" })) do
        local name, alert = line:match("^(.-)\t(.*)$")
        if name then
            table.insert(rows, { name = name, alert = alert })
        end
    end
    local_sessions = rows
end

local function fetch_remote(open)
    local hosts, seen = {}, {}
    for key in pairs(open) do
        local host = key:match("^(.-):")
        if host ~= "" and not seen[host] then
            seen[host] = true
            table.insert(hosts, host)
        end
    end
    local rows = {}
    for _, line in ipairs(lines({ "rtmux", "--sessions", table.unpack(hosts) })) do
        local host, name, alert = line:match("^(.-)\t(.-)\t(.*)$")
        if host then
            table.insert(rows, { host = host, name = name, alert = alert })
        end
    end
    table.sort(rows, function(a, b)
        return a.host .. ":" .. a.name < b.host .. ":" .. b.name
    end)
    remote_sessions = rows
end

-- the label's icon takes a colour while the leader or a key table is active, catppuccin mocha
-- blue for the leader, mauve for copy mode, yellow for search, and teal for any other table
local mode_colours = { leader = "#89b4fa", copy_mode = "#cba6f7", search_mode = "#f9e2af", other = "#94e2d5" }

local function mode_colour(window)
    local key_table = window:active_key_table()
    if key_table then
        return mode_colours[key_table] or mode_colours.other
    elseif window:leader_is_active() then
        return mode_colours.leader
    end
end

-- the native toolbar's label is the projects menu: the pane's session over its host, or outside tmux "Projects", dimmed, over this host.
-- its menu lists this machine's sessions, then each other host's
local function update_label(window, pane)
    local open = open_tabs()
    -- a pane closing mid-update raises, and the next update fills the label
    local ok, label, host = pcall(pane_session, pane)
    if not ok then
        return
    end
    local current = label and (host or "") .. ":" .. label
    local dimmed = label == nil
    -- a checkmark marks the session this tab shows, and a dash one another tab shows
    local menu = {}
    local function add(row_host, name, alert)
        local key = (row_host or "") .. ":" .. name
        table.insert(menu, {
            id = "session:" .. key,
            title = name,
            checked = key == current,
            mixed = open[key] ~= nil,
            icon = alert_icon(alert),
        })
    end
    -- each host is a section: its name as a header, and a separator before the next host
    table.insert(menu, { title = wezterm.hostname(), header = true })
    -- the config loads where no process can run, so the first update fills the rows
    if not local_sessions then
        fetch_local()
    end
    for _, row in ipairs(local_sessions) do
        add(nil, row.name, row.alert)
    end
    local last_host
    for _, row in ipairs(remote_sessions) do
        if row.host ~= last_host then
            table.insert(menu, { title = "" })
            table.insert(menu, { title = row.host, header = true })
            last_host = row.host
        end
        add(row.host, row.name, row.alert)
    end
    window:set_toolbar_label({
        symbol = "rectangle.stack",
        symbol_color = mode_colour(window),
        title = label or "Projects",
        subtitle = host or wezterm.hostname(),
        dimmed = dimmed,
        menu = menu,
    })
end

-- a session goes to the tab that shows it, or opens in a new tab, so each tab keeps one session.
-- host is nil for this machine, and target is what t connects to, the session's name unless given
local function open_project(window, pane, host, name, target)
    local found = open_tabs()[(host or "") .. ":" .. name]
    if found then
        found.pane:activate()
        -- a window in another workspace has no gui window
        local gui = found.window:gui_window()
        if gui then
            gui:focus()
        end
        return
    end
    -- SESH_PICK_IN_PLACE makes sesh-pick connect here instead of handing the pick back (see sesh/sesh-pick.sh go)
    local args = host and { "zsh", "-lc", 'rtmux -- "$1" "$2"; exec zsh -l', "_", host, name }
        or { "zsh", "-lc", 'SESH_PICK_IN_PLACE=1 t "$1"; exec zsh -l', "_", target or name }
    window:perform_action(act.SpawnCommandInNewTab({ domain = "DefaultDomain", args = args }), pane)
end

wezterm.on("toolbar-menu-item", function(window, pane, id)
    local host, name = id:match("^session:(.-):(.*)$")
    if name then
        open_project(window, pane, host ~= "" and host or nil, name)
    end
end)

-- sesh-pick hands a local pick here as name, target and a nonce (see sesh/sesh-pick.sh)
wezterm.on("user-var-changed", function(window, pane, var, value)
    if var == "open_project" then
        local name, target = value:match("^(.-)\t([^\t]*)")
        if name then
            open_project(window, pane, nil, name, target)
        end
    end
end)

-- cmd-k or a press on the label: fetch every host's sessions, then open the projects menu
function M.show_projects(window, pane)
    fetch_local()
    fetch_remote(open_tabs())
    update_label(window, pane)
    window:show_toolbar_menu()
end

-- the fork's toolbar-label-pressed runs before the menu opens, and false keeps it from opening with stale rows
wezterm.on("toolbar-label-pressed", function(window, pane)
    M.show_projects(window, pane)
    return false
end)

-- each native tab's status icon, by tab index.
-- a tab whose pane is closing mid-update raises, and keeps an empty icon until the next update
local function update_tab_status(window)
    local active_id = window:active_tab():tab_id()
    local icons = {}
    for _, tab in ipairs(window:mux_window():tabs()) do
        local ok, alert = pcall(function()
            return tab_alert(tab:tab_id(), strip_mosh(tab:active_pane():get_title()), tab:tab_id() == active_id)
        end)
        table.insert(icons, alert_icon(ok and alert or nil))
    end
    window:set_toolbar_tab_status(icons)
end

wezterm.on("update-status", function(window, pane)
    if native then
        update_label(window, pane)
        update_tab_status(window)
    end
    local leader_cfg, mode_cfg = config.indicator.leader, config.indicator.mode
    local active_kt = window:active_key_table() ~= nil
    local show = leader_cfg.enabled or (active_kt and mode_cfg.enabled)

    -- the right side, since the traffic lights take the left of the bar
    if not show then
        window:set_right_status("")
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
            { Foreground = { Color = palette.ansi[5] } },
            { Text = " " .. leader_text .. " " },
        })
    end

    local mode = ""
    if mode_cfg.enabled then
        local mode_text = mode_cfg.names[window:active_key_table()] or ""
        mode = wezterm.format({
            { Foreground = { Color = palette.ansi[5] } },
            { Attribute = { Intensity = "Bold" } },
            { Text = mode_text },
            "ResetAttributes",
        })
    end

    window:set_right_status(mode .. leader)
end)

return M
