local status_script = "osascript -l JavaScript $CONFIG_DIR/helpers/wifi/status.js"
local scan_script = "osascript -l JavaScript $CONFIG_DIR/helpers/wifi/scan.js"

local wifi = sbar.add_symbol_item("wifi", {
    position = "right",
    padding_left = 2,
    padding_right = 1,
    icon = { width = 34 },
    label = { drawing = false },
    update_freq = 60,
    popup = { align = "left", height = 24 },
})

local dim = colors.with_alpha(colors.text, 0.6)

local status = { power = false, name = "", strength = 0 }
local networks = {}
local show_other = false
local joining = nil
local rows = sbar.symbol_rows(wifi)

local update_popup, update_status

local function add_header(name, text)
    return sbar.add_item(name, {
        position = "popup." .. wifi.name,
        drawing = false,
        padding_left = 12,
        icon = {
            string = text,
            font = { style = "Medium" },
            color = dim,
            padding_left = 0,
            padding_right = 0,
        },
        label = {
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
    local list = {}
    for i = 1, count do
        ---@type { item: table, network: { name: string, strength: integer, known: boolean }? }
        local row = { network = nil }
        row.item = rows.add(prefix .. "." .. i)
        row.item:subscribe("mouse.clicked", function()
            if row.network and row.network.name ~= status.name then
                join(row.network)
            end
        end)
        list[i] = row
    end
    return list
end

local hotspot_header = add_header("wifi_hotspot_header", "Personal Hotspot")
local hotspot_rows = add_rows("wifi_hotspot", 2)
local known_header = add_header("wifi_known_header", "Known Networks")
local known_rows = add_rows("wifi_known", 6)
local other_header = add_header("wifi_other_header", "Other Networks")
local other_rows = add_rows("wifi_other", 6)

local settings_row = sbar.add_popup_row(wifi, "wifi_settings", "Wi-Fi Settings...")

local function show_rows(group, list, visible)
    for i, row in ipairs(group) do
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
            rows.show(
                row.item,
                { symbol = symbol, color = connected and colors.blue or colors.text, size = 15, value = value },
                network.name .. (network.secure and "  " .. icons.lock or "")
            )
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

        local connected = status.name ~= ""
        sbar.set_symbol(wifi, {
            symbol = status.power and "wifi" or "wifi.slash",
            color = colors.text,
            size = 15,
            value = status.power and status.strength or nil,
            labeled = connected,
        }, { label = { drawing = connected, string = status.name } })

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

wifi:subscribe("mouse.clicked", function()
    local drawing = wifi:query().popup.drawing
    sbar.toggle_popup(wifi.name)

    if drawing == "off" then
        update_status()
        update_popup()
        scan("cached")
        scan("")
    end
end)

other_header:subscribe("mouse.clicked", function()
    show_other = not show_other
    update_popup()
end)

settings_row:subscribe("mouse.clicked", function()
    wifi:set({ popup = { drawing = false } })
    sbar.exec('open "x-apple.systempreferences:com.apple.wifi-settings-extension"')
end)
