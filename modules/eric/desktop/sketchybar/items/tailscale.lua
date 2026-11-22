-- the cli comes from the tailscale app, outside launchd's PATH
local cli = "/usr/local/bin/tailscale"

-- the logo's dots fill 0.73 of its canvas and carry little ink
-- 19 makes the grid about 14pt, between the 12.5pt height and 16.5pt width of the 15pt wifi glyph
local logo_size = 19

-- the bar shows these short names in place of the tailnet, keyed by `tailscale switch --list` tailnet
local short_names = {
    ["ericshen118@gmail.com"] = "e",
    ["erics118.github"] = "g",
    ["cornellev.org.github"] = "c",
}

local tailscale = sbar.add_symbol_item("tailscale", {
    position = "right",
    padding_left = 2,
    padding_right = 1,
    icon = { width = 34 },
    label = { drawing = false },
    update_freq = 60,
    popup = { align = "left", height = 24 },
})

local dim = colors.with_alpha(colors.text, 0.6)

local running = false
local tailnet = ""
local profiles = {}
local switching = nil

local update_popup, update_status

sbar.add_popup_row(tailscale, "tailscale_header", "Tailnets", dim)

local symbol_rows = sbar.symbol_rows(tailscale)
local rows = {}
for i = 1, 6 do
    ---@type { item: table, profile: { id: string, tailnet: string, selected: boolean }? }
    local row = { profile = nil }
    row.item = symbol_rows.add("tailscale_tailnet." .. i)
    row.item:subscribe("mouse.clicked", function()
        local profile = row.profile
        if not profile or profile.selected or switching then
            return
        end
        switching = profile.id
        update_popup()
        sbar.exec(cli .. " switch " .. profile.id, function()
            switching = nil
            update_status()
        end)
    end)
    rows[i] = row
end

local toggle_row = sbar.add_popup_row(tailscale, "tailscale_toggle", "Connect")

function update_popup()
    for i, row in ipairs(rows) do
        local profile = profiles[i]
        row.profile = profile
        if not profile then
            row.item:set({ drawing = false })
        else
            local spinning = profile.id == switching
            symbol_rows.show(row.item, {
                symbol = spinning and "progress.indicator" or "tailscale",
                color = profile.selected and running and colors.blue or colors.text,
                size = spinning and 15 or logo_size,
            }, profile.tailnet)
        end
    end
    toggle_row:set({ label = running and "Disconnect" or "Connect" })
end

function update_status()
    sbar.exec(cli .. " status --json --peers=false", function(result)
        if type(result) ~= "table" then
            return
        end
        running = result.BackendState == "Running"
        tailnet = result.CurrentTailnet and result.CurrentTailnet.Name or ""

        local connected = running and tailnet ~= ""
        sbar.set_symbol(tailscale, {
            symbol = running and "tailscale" or "tailscale.off",
            color = colors.text,
            size = logo_size,
            labeled = connected,
        }, { label = { drawing = connected, string = short_names[tailnet] or tailnet } })

        sbar.exec(cli .. " switch --list --json", function(list)
            if type(list) == "table" then
                profiles = list
            end
            update_popup()
        end)
    end)
end

tailscale:subscribe({ "routine", "forced", "system_woke" }, update_status)

local function toggle()
    sbar.exec(cli .. (running and " down" or " up"), update_status)
end

tailscale:subscribe("mouse.clicked", function(env)
    if env.BUTTON == "right" then
        toggle()
        return
    end
    local drawing = tailscale:query().popup.drawing
    sbar.toggle_popup(tailscale.name)
    if drawing == "off" then
        update_status()
    end
end)

toggle_row:subscribe("mouse.clicked", toggle)
