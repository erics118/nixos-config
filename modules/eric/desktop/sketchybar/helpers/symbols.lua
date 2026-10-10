local renderer = settings.helpers_dir .. "symbol_image"
local dir = os.getenv("HOME") .. "/.cache/sketchybar/symbols/"
os.execute("mkdir -p '" .. dir .. "'")

-- point width of a 2x png, read from the ihdr chunk
local function png_width(path)
    local file = io.open(path, "rb")
    if not file then
        return 0
    end
    local header = file:read(24)
    file:close()
    return header and #header == 24 and string.unpack(">I4", header, 17) / 2 or 0
end

-- renders an sf symbol to a png on first use, then passes its path and point width to callback
-- value is the symbol's variable value, or the fill level for the battery symbols symbol_image.m draws itself
-- color is a 0xAARRGGBB number, or a string the helper takes as is, like "multicolor:0xAARRGGBB"
return function(symbol, color, size, value, callback)
    local value_arg = value and string.format("%.2f", value) or ""
    local color_arg = type(color) == "string" and color or string.format("0x%08x", color)
    local path = string.format("%s%s.%s.%g%s.png", dir, symbol, color_arg, size, value and "." .. value_arg or "")

    sbar.exec(
        string.format("[ -f '%s' ] || '%s' %s %s %g '%s' %s", path, renderer, symbol, color_arg, size, path, value_arg),
        function()
            callback(path, png_width(path))
        end
    )
end
