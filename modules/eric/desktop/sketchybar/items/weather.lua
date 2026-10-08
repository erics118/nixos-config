local render_symbol = require("helpers.symbols")

local weather = sbar.add_item("weather", {
    icon = {
        string = "",
        padding_left = 0,
        padding_right = 0,
        background = {
            drawing = true,
            image = { scale = 0.5, padding_left = 7 },
        },
    },
    position = "right",
    padding_left = 2,
    padding_right = 1,
    update_freq = 600,
    popup = { align = "left", height = 24 },
})

local weather_key_path = "/run/secrets/api/weatherapi"

local dim = colors.with_alpha(colors.text, 0.6)

local function add_row(name, color, text)
    return sbar.add_item("weather_" .. name, {
        position = "popup." .. weather.name,
        padding_left = 12,
        icon = { drawing = false },
        label = {
            string = text,
            color = color,
            padding_left = 0,
            padding_right = 12,
        },
        background = { drawing = false },
    })
end

local weather_title = add_row("title", colors.text)
local weather_feels_like = add_row("feels_like", colors.text)
local weather_humidity = add_row("humidity", colors.text)
local weather_wind = add_row("wind", colors.text)
add_row("today_header", dim, "Today")
local weather_range = add_row("range", colors.text)
local weather_sun = add_row("sun", colors.text)

-- aqi in the icon and uv in the label so each gets its own color
local weather_air = sbar.add_item("weather_air", {
    position = "popup." .. weather.name,
    padding_left = 12,
    icon = {
        font = { style = "Medium" },
        padding_left = 0,
        padding_right = 12,
    },
    label = {
        padding_left = 0,
        padding_right = 12,
    },
    background = { drawing = false },
})

weather:subscribe("mouse.clicked", function(env)
    sbar.toggle_popup(weather.name)
end)

-- must be one of: f c
-- used for temp, feelslike
local temperature_unit = "c"

-- must be one of: mph kph
-- used for wind_speed
local wind_speed_unit = "mph"

local function degrees_to_direction(degrees)
    -- Handle degrees greater than 360
    degrees = degrees % 360

    -- Calculate the cardinal direction
    if (degrees >= 0 and degrees < 22.5) or (degrees >= 337.5 and degrees <= 360) then
        return "􀄨" -- N
    elseif degrees >= 22.5 and degrees < 67.5 then
        return "􀄯" -- NE
    elseif degrees >= 67.5 and degrees < 112.5 then
        return "􀄫" -- E
    elseif degrees >= 112.5 and degrees < 157.5 then
        return "􀄱" -- SE
    elseif degrees >= 157.5 and degrees < 202.5 then
        return "􀄩" -- S
    elseif degrees >= 202.5 and degrees < 247.5 then
        return "􀄰" -- SW
    elseif degrees >= 247.5 and degrees < 292.5 then
        return "􀄪" -- W
    elseif degrees >= 292.5 and degrees < 337.5 then
        return "􀄮" -- NW
    else
        return "?"
    end
end

local function round_temperature(temperature)
    -- Round the temperature
    local rounded = math.floor(temperature + 0.5)
    if temperature_unit == "f" then
        return rounded .. "°F"
    else
        return rounded .. "°C"
    end
end

-- sf symbol names
local weather_icons_day = {
    sunny = "sun.max.fill",
    clear = "sun.max.fill",
    ["partly cloudy"] = "cloud.sun.fill",
    cloudy = "cloud.fill",
    overcast = "smoke.fill",
    mist = "cloud.fog.fill",
    ["patchy rain possible"] = "cloud.sun.rain.fill",
    ["patchy snow possible"] = "sun.snow.fill",
    ["patchy sleet possible"] = "cloud.sleet.fill",
    ["patchy freezing drizzle possible"] = "cloud.sleet.fill",
    ["thundery outbreaks possible"] = "cloud.sun.bolt.fill",
    ["blowing snow"] = "wind.snow",
    blizzard = "wind.snow",
    fog = "cloud.fog.fill",
    ["freezing fog"] = "cloud.fog.fill",
    ["patchy light drizzle"] = "cloud.drizzle.fill",
    ["light drizzle"] = "cloud.drizzle.fill",
    ["freezing drizzle"] = "cloud.sleet.fill",
    ["heavy freezing drizzle"] = "cloud.sleet.fill",
    ["patchy light rain"] = "cloud.sun.rain.fill",
    ["light rain"] = "cloud.rain.fill",
    ["moderate rain at times"] = "cloud.rain.fill",
    ["moderate rain"] = "cloud.rain.fill",
    ["heavy rain at times"] = "cloud.heavyrain.fill",
    ["heavy rain"] = "cloud.heavyrain.fill",
    ["light freezing rain"] = "cloud.sleet.fill",
    ["moderate or heavy freezing rain"] = "cloud.sleet.fill",
    ["light sleet"] = "cloud.sleet.fill",
    ["moderate or heavy sleet"] = "cloud.sleet.fill",
    ["patchy light snow"] = "cloud.snow.fill",
    ["light snow"] = "cloud.snow.fill",
    ["patchy moderate snow"] = "cloud.snow.fill",
    ["moderate snow"] = "cloud.snow.fill",
    ["patchy heavy snow"] = "cloud.snow.fill",
    ["heavy snow"] = "cloud.snow.fill",
    ["ice pellets"] = "cloud.hail.fill",
    ["light rain shower"] = "cloud.sun.rain.fill",
    ["moderate or heavy rain shower"] = "cloud.heavyrain.fill",
    ["torrential rain shower"] = "cloud.heavyrain.fill",
    ["light sleet showers"] = "cloud.sleet.fill",
    ["moderate or heavy sleet showers"] = "cloud.sleet.fill",
    ["light snow showers"] = "cloud.snow.fill",
    ["moderate or heavy snow showers"] = "cloud.snow.fill",
    ["light showers of ice pellets"] = "cloud.hail.fill",
    ["moderate or heavy showers of ice pellets"] = "cloud.hail.fill",
    ["patchy light rain with thunder"] = "cloud.bolt.rain.fill",
    ["moderate or heavy rain with thunder"] = "cloud.bolt.rain.fill",
    ["patchy light snow with thunder"] = "cloud.bolt.rain.fill",
    ["moderate or heavy snow with thunder"] = "cloud.bolt.rain.fill",
    ["patchy rain nearby"] = "cloud.sun.rain.fill",
    ["patchy snow nearby"] = "sun.snow.fill",
    ["patchy sleet nearby"] = "cloud.sleet.fill",
    ["patchy freezing drizzle nearby"] = "cloud.sleet.fill",
    ["thundery outbreaks in nearby"] = "cloud.sun.bolt.fill",
    ["patchy light rain in area with thunder"] = "cloud.bolt.rain.fill",
    ["patchy light snow in area with thunder"] = "cloud.bolt.rain.fill",
    ["moderate or heavy rain in area with thunder"] = "cloud.bolt.rain.fill",
    ["moderate or heavy snow in area with thunder"] = "cloud.bolt.rain.fill",
    dust = "sun.dust.fill",
    ["blowing dust"] = "sun.dust.fill",
    ["dust storm"] = "sun.dust.fill",
    ["saharan dust"] = "sun.dust.fill",
    ["dust haze"] = "sun.dust.fill",
    haze = "sun.haze.fill",
    ["smoky haze"] = "smoke.fill",
    smoke = "smoke.fill",
    smog = "smoke.fill",
    ["severe smog"] = "smoke.fill",
    sandstorm = "sun.dust.fill",
    ["severe sandstorm"] = "sun.dust.fill",
}

local weather_icons_night = setmetatable({
    clear = "moon.stars.fill",
    sunny = "moon.stars.fill",
    ["partly cloudy"] = "cloud.moon.fill",
    ["thundery outbreaks possible"] = "cloud.moon.bolt.fill",
    ["patchy rain possible"] = "cloud.moon.rain.fill",
    ["patchy rain nearby"] = "cloud.moon.rain.fill",
    ["patchy snow possible"] = "cloud.snow.fill",
    ["patchy snow nearby"] = "cloud.snow.fill",
    ["patchy light rain"] = "cloud.moon.rain.fill",
    ["light rain"] = "cloud.moon.rain.fill",
    ["moderate rain at times"] = "cloud.moon.rain.fill",
    ["moderate rain"] = "cloud.moon.rain.fill",
    ["light rain shower"] = "cloud.moon.rain.fill",
    ["thundery outbreaks in nearby"] = "cloud.moon.bolt.fill",
    dust = "moon.dust.fill",
    ["blowing dust"] = "moon.dust.fill",
    ["dust storm"] = "moon.dust.fill",
    ["saharan dust"] = "moon.dust.fill",
    ["dust haze"] = "moon.dust.fill",
    haze = "moon.haze.fill",
    sandstorm = "moon.dust.fill",
    ["severe sandstorm"] = "moon.dust.fill",
}, { __index = weather_icons_day })

-- icon padding_left 7 plus the 3pt gap to the label, as for font icons
local function set_icon(symbol, color)
    render_symbol(symbol, color, 13, nil, function(path, width)
        weather:set({ icon = { width = width + 10, background = { image = path } } })
    end)
end

local function get_condition_icon(condition, is_day)
    if is_day then
        return weather_icons_day[condition]
    else
        return weather_icons_night[condition]
    end
end

-- # utils #######################################################################

local function set_air_quality_color(epa_index)
    if epa_index == 1 then
        return colors.green, "Good"
    elseif epa_index == 2 then
        return colors.yellow, "Moderate"
    elseif epa_index == 3 then
        return colors.orange, "Unhealthy for Sensitive Groups"
    elseif epa_index == 4 then
        return colors.red, "Unhealthy"
    elseif epa_index == 5 then
        return colors.purple, "Very Unhealthy"
    elseif epa_index == 6 then
        return colors.purple, "Hazardous"
    else
        return colors.text, "Unknown"
    end
end

local function set_uv_index_color(uv_index)
    if uv_index < 3 then
        return colors.green, "Low"
    elseif uv_index < 6 then
        return colors.yellow, "Moderate"
    elseif uv_index < 8 then
        return colors.orange, "High"
    elseif uv_index < 11 then
        return colors.red, "Very High"
    else
        return colors.purple, "Extreme"
    end
end

local function set_weather_unavailable(message)
    set_icon("exclamationmark.icloud", colors.text)
    weather:set({ label = { string = message or "N/A" } })
    weather_title:set({ label = { string = message or "Unavailable" } })
    weather_feels_like:set({ label = { string = "Feels like --" } })
    weather_humidity:set({ label = { string = "Humidity --" } })
    weather_wind:set({ label = { string = "Wind --" } })
    weather_range:set({ label = { string = "--" } })
    weather_sun:set({ label = { string = "--" } })
    weather_air:set({
        icon = { string = "AQI --", color = colors.text },
        label = { string = "UV --", color = colors.text },
    })
end

-- weatherapi gives "07:03 AM", the bar clock is 24h
local function to_24h(time)
    local hour, minute, period = (time or ""):match("(%d+):(%d+) (%a+)")
    if not hour then
        return "--"
    end
    return string.format("%02d:%s", tonumber(hour) % 12 + (period == "PM" and 12 or 0), minute)
end

local function read_weather_api_key()
    local key_file = io.open(weather_key_path, "r")
    if not key_file then
        return nil
    end

    local api_key = key_file:read("*l")
    key_file:close()

    if api_key == nil or api_key == "" then
        return nil
    end

    return api_key
end

local function format_number(value, suffix)
    if value == nil then
        return "--"
    end

    return tostring(value) .. (suffix or "")
end

local key_retries = 0
local fetch_retries = 0

local function update_weather()
    local api_key = read_weather_api_key()
    if not api_key then
        set_weather_unavailable("No API Key")
        -- sops may not have decrypted yet, retry a few times
        if key_retries < 3 then
            key_retries = key_retries + 1
            sbar.delay(5, update_weather)
        end
        return
    end

    -- curl reads the url from stdin so the key stays out of process argv
    sbar.exec(
        [[printf 'url = "https://api.weatherapi.com/v1/forecast.json?key=%s&q=auto:ip&days=1&aqi=yes&alerts=no"\n' "$(cat ]]
            .. weather_key_path
            .. [[)" | /usr/bin/curl -fsSL -K -]],
        function(data)
            if
                type(data) ~= "table"
                or type(data.current) ~= "table"
                or type(data.forecast) ~= "table"
                or type(data.forecast.forecastday) ~= "table"
                or type(data.forecast.forecastday[1]) ~= "table"
            then
                -- dns is often not up yet right after wake, so keep the last data and retry
                if fetch_retries < 5 then
                    fetch_retries = fetch_retries + 1
                    sbar.delay(10, update_weather)
                else
                    set_weather_unavailable("Unavailable")
                end
                return
            end
            fetch_retries = 0

            local day = data.forecast.forecastday[1].day or {}
            local astro = data.forecast.forecastday[1].astro or {}
            local current = data.current
            local condition_data = current.condition or {}
            local temp = round_temperature(data.current["temp_" .. temperature_unit])
            local feels_like = round_temperature(current["feelslike_" .. temperature_unit])
            local low = round_temperature(day["mintemp_" .. temperature_unit])
            local high = round_temperature(day["maxtemp_" .. temperature_unit])
            local condition = (condition_data.text or "Unavailable"):lower()
            local is_day = current.is_day == 1
            local icon = get_condition_icon(condition, is_day)
            local wind_direction = current.wind_degree and degrees_to_direction(current.wind_degree) or "?"
            local wind_speed = format_number(current["wind_" .. wind_speed_unit], " " .. wind_speed_unit)
            local uv_index = math.floor(current.uv or 0)
            local uv_index_color, uv_index_category = set_uv_index_color(uv_index)
            local humidity = current.humidity
            local humidity_percentage = humidity and string.format("%.f%%", humidity) or "--"
            local sunrise = astro.sunrise or "--"
            local sunset = astro.sunset or "--"
            local air_quality = current.air_quality or {}
            local air_quality_index = air_quality["us-epa-index"] or 0
            local air_quality_color, air_quality_category = set_air_quality_color(air_quality_index)

            if icon then
                -- apple's colors, with the white parts in the text color
                set_icon(icon, string.format("multicolor:0x%08x", colors.text))
            else
                set_icon("exclamationmark.icloud", colors.text)
            end
            weather:set({ label = { string = temp } })
            weather_title:set({ label = { string = condition:gsub("^%l", string.upper) } })
            weather_feels_like:set({ label = { string = "Feels like " .. feels_like } })
            weather_humidity:set({ label = { string = "Humidity " .. humidity_percentage } })
            weather_wind:set({ label = { string = "Wind " .. wind_direction .. " " .. wind_speed } })
            weather_range:set({ label = { string = low .. " - " .. high } })
            weather_sun:set({ label = { string = to_24h(sunrise) .. " - " .. to_24h(sunset) } })
            weather_air:set({
                icon = { string = "AQI " .. air_quality_category, color = air_quality_color },
                label = { string = "UV " .. uv_index_category, color = uv_index_color },
            })
        end
    )
end

-- wifi_change fires on any primary ipv4 change, so a reconnect refreshes too
-- each event starts a fresh retry budget, or one failed chain would leave it spent
weather:subscribe({ "forced", "routine", "system_woke", "wifi_change" }, function()
    fetch_retries = 0
    update_weather()
end)
