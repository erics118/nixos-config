local render_symbol = require("helpers.symbols")

local status_script = "osascript -l JavaScript $CONFIG_DIR/helpers/wifi/status.js"
local scan_script = "osascript -l JavaScript $CONFIG_DIR/helpers/wifi/scan.js"

local wifi = sbar.add_item("wifi", {
    position = "right",
    padding_left = 2,
    padding_right = 1,
    icon = {
        string = "",
        width = 34,
        padding_left = 0,
        padding_right = 0,
        background = {
            drawing = true,
            image = { scale = 0.5, padding_left = 7 },
        },
    },
    label = { drawing = false },
    update_freq = 10,
    popup = { align = "center", height = 24 },
})

local dim = colors.with_alpha(colors.text, 0.6)

local status = { power = false, name = "", strength = 0 }
local networks = {}
local show_other = false
local joining = nil

local update_popup, update_status

local function add_header(name, text)
    return sbar.add_item(name, {
        position = "popup." .. wifi.name,
        drawing = false,
        padding_left = 12,
        icon = {
            string = text,
            font = { style = "Semibold" },
            color = dim,
            padding_left = 0,
            padding_right = 0,
        },
        label = {
            font = { style = "Semibold" },
            color = dim,
            padding_left = 6,
            padding_right = 12,
        },
        background = { drawing = false },
    })
end

local function join(network)
    joining = network.name
    update_popup()

    local name = network.name:gsub("'", "'\\''")
    sbar.exec("networksetup -setairportnetwork en0 '" .. name .. "'", function()
        joining = nil
        update_status()
    end)
end

local function add_rows(prefix, count)
    local rows = {}
    for i = 1, count do
        local row = { network = nil }
        row.item = sbar.add_item(prefix .. "." .. i, {
            position = "popup." .. wifi.name,
            drawing = false,
            padding_left = 12,
            icon = {
                string = "",
                width = 25,
                padding_left = 0,
                padding_right = 0,
                background = {
                    drawing = true,
                    image = { scale = 0.5 },
                },
            },
            label = {
                font = { style = "Regular" },
                padding_left = 8,
                padding_right = 12,
            },
            background = { drawing = false },
        })
        row.item:subscribe("mouse.clicked", function(env)
            if row.network and row.network.name ~= status.name then
                join(row.network)
            end
        end)
        rows[i] = row
    end
    return rows
end

local hotspot_header = add_header("wifi_hotspot_header", "Personal Hotspot")
local hotspot_rows = add_rows("wifi_hotspot", 2)
local known_header = add_header("wifi_known_header", "Known Networks")
local known_rows = add_rows("wifi_known", 6)
local other_header = add_header("wifi_other_header", "Other Networks")
local other_rows = add_rows("wifi_other", 6)

local settings = sbar.add_item("wifi_settings", {
    position = "popup." .. wifi.name,
    padding_left = 12,
    icon = { drawing = false },
    label = {
        string = "Wi-Fi Settings...",
        font = { style = "Regular" },
        padding_left = 0,
        padding_right = 12,
    },
    background = { drawing = false },
})

local function show_rows(rows, list, visible)
    for i, row in ipairs(rows) do
        local network = visible and list[i] or nil
        row.network = network
        if not network then
            row.item:set({ drawing = false })
        else
            local connected = network.name == status.name
            local symbol = network.hotspot and "personalhotspot" or "wifi"
            local value = not network.hotspot and network.strength or nil
            if network.name == joining then
                symbol, value = "progress.indicator", nil
            end
            render_symbol(symbol, connected and colors.blue or colors.text, 15, value, function(path)
                row.item:set({
                    drawing = true,
                    icon = { background = { image = path } },
                    label = network.name .. (network.secure and "  " .. icons.lock or ""),
                })
            end)
        end
    end
end

function update_popup()
    local hotspots, known, other = {}, {}, {}
    local found = false

    for _, network in ipairs(networks) do
        if network.name == status.name then
            found = true
            -- the connected access point, not the strongest one the scan saw
            network.strength = status.strength
        end
        if network.hotspot then
            table.insert(hotspots, network)
        elseif network.known then
            table.insert(known, network)
        else
            table.insert(other, network)
        end
    end

    if status.name ~= "" and not found then
        table.insert(known, { name = status.name, strength = status.strength, known = true })
    end

    table.sort(known, function(a, b)
        if (a.name == status.name) ~= (b.name == status.name) then
            return a.name == status.name
        end
        return a.strength > b.strength
    end)

    local power = status.power
    hotspot_header:set({ drawing = power and #hotspots > 0 })
    known_header:set({ drawing = power and #known > 0 })
    other_header:set({
        drawing = power and #other > 0,
        label = show_other and icons.chevron_down or icons.chevron_right,
    })
    show_rows(hotspot_rows, hotspots, power)
    show_rows(known_rows, known, power)
    show_rows(other_rows, other, power and show_other)
end

function update_status()
    sbar.exec(status_script, function(result)
        if type(result) ~= "table" then
            return
        end
        status = result

        local symbol = status.power and "wifi" or "wifi.slash"
        local value = status.power and (status.name ~= "" and status.strength or 0) or nil
        local connected = status.name ~= ""
        render_symbol(symbol, colors.text, 15, value, function(path)
            wifi:set({
                icon = {
                    width = connected and 30 or 34,
                    background = { image = path },
                },
                label = { drawing = connected, string = status.name },
            })
        end)

        update_popup()
    end)
end

local function scan(args)
    sbar.exec(scan_script .. " " .. args, function(result)
        if type(result) == "table" then
            networks = result
            update_popup()
        end
    end)
end

wifi:subscribe({ "routine", "forced", "wifi_change", "system_woke" }, update_status)

scan("cached")

wifi:subscribe("mouse.clicked", function(env)
    local drawing = wifi:query().popup.drawing
    sbar.toggle_popup(wifi.name)

    if drawing == "off" then
        update_status()
        update_popup()
        scan("cached")
        scan("")
    end
end)

other_header:subscribe("mouse.clicked", function(env)
    show_other = not show_other
    update_popup()
end)

settings:subscribe("mouse.clicked", function(env)
    wifi:set({ popup = { drawing = false } })
    sbar.exec('open "x-apple.systempreferences:com.apple.wifi-settings-extension"')
end)
