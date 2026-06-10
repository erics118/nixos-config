local weather = sbar.add_item("weather", {
    icon = {
        font = {
            family = "Hack Nerd Font Mono",
            style = "Regular",
            size = 25.0,
        },
    },
    position = "right",
    update_freq = 600,
})

local weather_key_path = os.getenv("HOME") .. "/.config/sops-nix/secrets/api/weather"

local function add_weather_item(name, icon)
    return sbar.add_item("weather_" .. name, {
        position = "popup.weather",
        icon = {
            string = icon,
            font = {
                family = "Hack Nerd Font Mono",
                style = "Regular",
                size = 20.0,
            },
            align = "center",
            width = 32,
        },
        background = { drawing = false },
    })
end

local weather_condition = add_weather_item("condition", "")
local weather_feels_like = add_weather_item("feels_like", "󰔏")
local weather_low = add_weather_item("low", "󱃃")
local weather_high = add_weather_item("high", "󱃂")
local weather_humidity = add_weather_item("humidity", "")
local weather_precipitation = add_weather_item("precipitation", "󰖗")
local weather_wind = add_weather_item("wind", "")
local weather_aqi = add_weather_item("aqi", "󰵃")
local weather_sunrise = add_weather_item("sunrise", "")
local weather_sunset = add_weather_item("sunset", "")

weather:subscribe("mouse.clicked", function(env)
    weather:set({ popup = { drawing = "toggle" } })
end)

-- must be one of: f c
-- used for temp, feelslike
local temperature_unit = "c"

-- must be one of: km miles
-- used for vis
local visibility_unit = "miles"

-- must be one of: in mm
-- used for precip
local precipitation_amount_unit = "in"

-- must be one of: mph kph
-- used for wind_speed
local wind_speed_unit = "mph"

-- must be one of: mb in
-- used for pressure
local pressure_unit = "mb"

local function degrees_to_direction(degrees)
    -- Handle degrees greater than 360
    degrees = degrees % 360

    -- Calculate the cardinal direction
    if (degrees >= 0 and degrees < 22.5) or (degrees >= 337.5 and degrees <= 360) then
        return "󱦲" -- N
    elseif degrees >= 22.5 and degrees < 67.5 then
        return "󱦴" -- NE
    elseif degrees >= 67.5 and degrees < 112.5 then
        return "󱦰" -- E
    elseif degrees >= 112.5 and degrees < 157.5 then
        return "󱦷" -- SE
    elseif degrees >= 157.5 and degrees < 202.5 then
        return "󱦳" -- S
    elseif degrees >= 202.5 and degrees < 247.5 then
        return "󱦶" -- SW
    elseif degrees >= 247.5 and degrees < 292.5 then
        return "󱦱" -- W
    elseif degrees >= 292.5 and degrees < 337.5 then
        return "󱦵" -- NW
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

local weather_icons_day = {
    sunny = "",
    ["partly cloudy"] = "",
    cloudy = "",
    overcast = "",
    mist = "",
    ["patchy rain possible"] = "",
    ["patchy snow possible"] = "",
    ["patchy sleet possible"] = "",
    ["patchy freezing drizzle possible"] = "",
    ["thundery outbreaks possible"] = "",
    ["blowing snow"] = "",
    blizzard = "",
    fog = "",
    ["freezing fog"] = "",
    ["patchy light drizzle"] = "",
    ["light drizzle"] = "",
    ["freezing drizzle"] = "",
    ["heavy freezing drizzle"] = "",
    ["patchy light rain"] = "",
    ["light rain"] = "",
    ["moderate rain at times"] = "",
    ["moderate rain"] = "",
    ["heavy rain at times"] = "",
    ["heavy rain"] = "",
    ["light freezing rain"] = "",
    ["moderate or heavy freezing rain"] = "",
    ["light sleet"] = "",
    ["moderate or heavy sleet"] = "",
    ["patchy light snow"] = "",
    ["light snow"] = "",
    ["patchy moderate snow"] = "",
    ["moderate snow"] = "",
    ["patchy heavy snow"] = "",
    ["heavy snow"] = "",
    ["ice pellets"] = "",
    ["light rain shower"] = "",
    ["moderate or heavy rain shower"] = "",
    ["torrential rain shower"] = "",
    ["light sleet showers"] = "",
    ["moderate or heavy sleet showers"] = "",
    ["light snow showers"] = "",
    ["moderate or heavy snow showers"] = "",
    ["light showers of ice pellets"] = "",
    ["moderate or heavy showers of ice pellets"] = "",
    ["patchy light rain with thunder"] = "",
    ["moderate or heavy rain with thunder"] = "",
    ["patchy light snow with thunder"] = "",
    ["moderate or heavy snow with thunder"] = "",
}

local weather_icons_night = {
    clear = "",
    ["partly cloudy"] = "",
    cloudy = "",
    overcast = "",
    mist = "",
    ["patchy rain possible"] = "",
    ["patchy snow possible"] = "",
    ["patchy sleet possible"] = "",
    ["patchy freezing drizzle possible"] = "",
    ["thundery outbreaks possible"] = "",
    ["blowing snow"] = "",
    blizzard = "",
    fog = "",
    ["freezing fog"] = "",
    ["patchy light drizzle"] = "",
    ["light drizzle"] = "",
    ["freezing drizzle"] = "",
    ["heavy freezing drizzle"] = "",
    ["patchy light rain"] = "",
    ["light rain"] = "",
    ["moderate rain at times"] = "",
    ["moderate rain"] = "",
    ["heavy rain at times"] = "",
    ["heavy rain"] = "",
    ["light freezing rain"] = "",
    ["moderate or heavy freezing rain"] = "",
    ["light sleet"] = "",
    ["moderate or heavy sleet"] = "",
    ["patchy light snow"] = "",
    ["light snow"] = "",
    ["patchy moderate snow"] = "",
    ["moderate snow"] = "",
    ["patchy heavy snow"] = "",
    ["heavy snow"] = "",
    ["ice pellets"] = "",
    ["light rain shower"] = "",
    ["moderate or heavy rain shower"] = "",
    ["torrential rain shower"] = "",
    ["light sleet showers"] = "",
    ["moderate or heavy sleet showers"] = "",
    ["light snow showers"] = "",
    ["moderate or heavy snow showers"] = "",
    ["light showers of ice pellets"] = "",
    ["moderate or heavy showers of ice pellets"] = "",
    ["patchy light rain with thunder"] = "",
    ["moderate or heavy rain with thunder"] = "",
    ["patchy light snow with thunder"] = "",
    ["moderate or heavy snow with thunder"] = "",
}

local function get_condition_icon(condition, is_day)
    if is_day then
        return weather_icons_day[condition]
    else
        return weather_icons_night[condition]
    end
end

-- # utils #######################################################################

-- #  cloud
-- #  cloudy

-- #  thermometer
-- #  horizon
-- #  hot
-- #  humidity

-- #  moonrise
-- #  moonset

-- #  sunrise
-- #  sunset

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

local function set_air_quality_color(air_quality_index)
    if air_quality_index < 51 then
        return colors.green, "Good"
    elseif air_quality_index < 101 then
        return colors.yellow, "Moderate"
    elseif air_quality_index < 151 then
        return colors.orange, "Unhealthy for Sensitive Groups"
    elseif air_quality_index < 201 then
        return colors.red, "Unhealthy"
    elseif air_quality_index < 301 then
        return colors.purple, "Very Unhealthy"
    else
        return colors.purple, "Hazardous"
    end
end

local function set_weather_unavailable(message)
    weather:set({
        icon = { string = "􀇔" },
        label = { string = message or "N/A" },
    })
    weather_condition:set({ icon = { string = "􀇔" }, label = { string = message or "Unavailable" } })
    weather_feels_like:set({ label = { string = "Feels Like: --" } })
    weather_low:set({ label = { string = "Low: --" } })
    weather_high:set({ label = { string = "High: --" } })
    weather_humidity:set({ label = { string = "Humidity: --" } })
    weather_precipitation:set({ label = { string = "--" } })
    weather_wind:set({ label = { string = "Wind: --" } })
    weather_aqi:set({ label = { string = "AQI: --" } })
    weather_sunrise:set({ label = { string = "Sunrise: --" } })
    weather_sunset:set({ label = { string = "Sunset: --" } })
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

weather:subscribe({ "forced", "routine" }, function()
    local api_key = read_weather_api_key()
    if not api_key then
        set_weather_unavailable("No API Key")
        -- sops may not have decrypted yet, retry soon
        sbar.exec("sleep 5 && sketchybar --trigger forced")
        return
    end

    sbar.exec(
        '/usr/bin/curl -fsSL "https://api.weatherapi.com/v1/forecast.json?key='
            .. api_key
            .. '&q=auto:ip&days=1&aqi=yes&alerts=no"',
        function(data)
            if
                type(data) ~= "table"
                or type(data.current) ~= "table"
                or type(data.forecast) ~= "table"
                or type(data.forecast.forecastday) ~= "table"
                or type(data.forecast.forecastday[1]) ~= "table"
            then
                set_weather_unavailable("Unavailable")
                return
            end

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
            local icon = get_condition_icon(condition, is_day) or "􀇔"
            local precipitation_amount =
                format_number(current["precip_" .. precipitation_amount_unit], " " .. precipitation_amount_unit)
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

            weather:set({
                icon = {
                    string = icon,
                },
                label = {
                    string = temp,
                },
            })
            weather_condition:set({ icon = { string = icon }, label = { string = condition } })

            weather_feels_like:set({ label = { string = "Feels Like: " .. feels_like } })
            weather_low:set({ label = { string = "Low: " .. low } })
            weather_high:set({ label = { string = "High: " .. high } })
            weather_humidity:set({ label = { string = "Humidity: " .. humidity_percentage } })
            weather_precipitation:set({ label = { string = precipitation_amount } })
            weather_wind:set({ label = { string = "Wind: " .. wind_direction .. " " .. wind_speed } })
            weather_aqi:set({
                label = { string = "AQI: " .. air_quality_index .. " " .. air_quality_category },
                icon = { color = air_quality_color },
            })
            weather_sunrise:set({ label = { string = "Sunrise: " .. sunrise } })
            weather_sunset:set({ label = { string = "Sunset: " .. sunset } })
        end
    )
end)
