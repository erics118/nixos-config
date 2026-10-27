-- keys and popups on top of the app's defaults, which settings > shortcuts lists

local terminal = "com.superlogical.terminal"

-- the window and layer that hold block_id.
-- bindings and actions find their tab from ctx.block_id, since the server's active window can be another tab
local function find_block(view, block_id)
    for _, window in ipairs(view and view.windows or {}) do
        for _, layer in ipairs(window.layers) do
            for _, block in ipairs(layer.blocks) do
                if block.block_id == block_id then
                    return window, layer
                end
            end
        end
    end
end

local function foreground(block_id)
    local process = rex.block.call(terminal, "process", { block_id = block_id })
    return process and process.foreground
end

-- unbind unused hotkeys
rex.unbind("cmd+enter")
rex.unbind("cmd+d")

-- programs that take ctrl-h/j/k/l themselves, matched against the foreground process name.
-- a tmux client, or rtmux's mosh-client, hands them to the tmux inside
local own_nav_keys = { "vim", "fzf", "tmux", "mosh-client" }

local function owns_nav_keys(block_id)
    local name = (foreground(block_id) or {}).name or ""
    for _, program in ipairs(own_nav_keys) do
        if name:find(program, 1, true) then
            return true
        end
    end
    return false
end

-- ctrl-h/j/k/l move between panes, stopping at the window edge.
-- returning false sends the key on to the terminal.
-- focus_direction starts from the active window's focused block, so the pressed one is focused first
for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
    rex.bind("ctrl+" .. key, function(ctx)
        if owns_nav_keys(ctx.block_id) then
            return false
        end
        rex.session.focus_block({ block_id = ctx.block_id })
        rex.session.focus_direction({ direction = direction })
        return true
    end)
end

for _, direction in ipairs({ "left", "right", "up", "down" }) do
    rex.bind("ctrl+cmd+" .. direction, "pane.resize", { direction = direction })
end

-- tmux's prefix z
rex.bind("cmd+z", "pane.zoom")

-- between shell prompts, which zsh marks with OSC 133 (see zsh/terminal.zsh), as terminal.app and ghostty do
rex.bind("cmd+up", "client.prompt.previous")
rex.bind("cmd+down", "client.prompt.next")

-- pastes a clipboard image's path, first copying the image to a pane on another rex server (rex-image-paste in rex.nix)
require("rex-image-paste").setup()
rex.bind("cmd+shift+v", "image_paste")

-- closing a pane or tab that runs anything but a shell asks first.
-- the key enters a one-shot confirm mode, whose key hints rex shows, where enter closes and escape cancels
local shells = { zsh = true, bash = true, sh = true, fish = true, nu = true }

-- a block's foreground program by argv0, since claude's executable is named after its version.
-- argv0 can be a path, and a login shell's starts with a dash
local function program(block_id)
    local process = foreground(block_id)
    return process and ((process.argv0 or process.name or ""):match("[^/]*$"):gsub("^%-", ""))
end

local function busy_program(block_ids)
    for _, block_id in ipairs(block_ids) do
        local name = program(block_id)
        if name and not shells[name] then
            return name
        end
    end
end

-- every block in the window that holds block_id
local function window_blocks(block_id)
    local window = find_block(rex.session.view({}), block_id)
    if not window then
        return { block_id }
    end
    local ids = {}
    for _, layer in ipairs(window.layers) do
        for _, block in ipairs(layer.blocks) do
            table.insert(ids, block.block_id)
        end
    end
    return ids
end

local function guarded_close(name, title, key, close, blocks)
    -- action names allow no dashes
    local action = (name:gsub("-", "_"))
    rex.mode(name, { exclusive = true })
    rex.bind(name .. "/enter", close)
    rex.action({
        name = action,
        title = title,
        run = function(ctx)
            local busy = busy_program(blocks(ctx.block_id))
            if not busy then
                rex.client.queue(close)
                return
            end
            rex.client.queue("client.mode.enter", { name = name, once = true })
        end,
    })
    rex.bind(key, action)
end

guarded_close("confirm-close", "Close Pane, Asking When Busy", "cmd+w", "pane.close", function(block_id)
    return { block_id }
end)
guarded_close("confirm-close-tab", "Close Tab, Asking When Busy", "alt+cmd+w", "client.tab.close", window_blocks)

-- a popup is a program in a floating layer over the tab of the pane that pressed its key.
-- its key hides it by detaching its pane, which keeps running, and shows it again.
-- its label, "popup:<name> <block id>", finds it again and names the pane that opened it
local function popup_label(name, opener)
    return "popup:" .. name .. " " .. opener
end

-- the popup's name and opener, or nil for a pane that isn't a popup
local function parse_popup(label)
    return (label or ""):match("^popup:(%S+) (%S+)$")
end

-- popups that close instead of hiding, since rext's list and client would be stale when shown again
local closes_on_hide = { projects = true }

-- rex focuses some other pane when a focused popup goes away, so its opener is focused first
local function return_focus(window, block)
    local _, opener = parse_popup(block.label)
    if opener and window.focused_block_id == block.block_id then
        rex.session.focus_block({ block_id = opener })
    end
end

local function hide_popup(window, layer)
    local block = layer.blocks[1]
    return_focus(window, block)
    if closes_on_hide[parse_popup(block.label)] then
        rex.session.close_layer({ layer_id = layer.layer_id })
    else
        rex.session.detach_block({ block_id = block.block_id })
    end
end

-- runs the popup's program, or a login shell, then closes the popup through popup_closed.
-- a failed program waits for enter, since closing at once would hide its error
local popup_wrapper = [[
if [ $# -eq 0 ]; then
    "${SHELL:-/bin/sh}" -l
else
    "$@"
    status=$?
    if [ "$status" -ne 0 ] && [ "$status" -ne 130 ]; then
        printf 'exited with status %s, press enter to close ' "$status"
        read -r _
    fi
fi
exec rex do popup_closed
]]

-- the tab's first tiled pane. a hidden pane floats only from a tab's layout, so it goes beside this one first
local function tiled_anchor(window)
    for _, layer in ipairs(window.layers) do
        if layer.kind == "tiled" and layer.blocks[1] then
            return layer.blocks[1].block_id
        end
    end
end

local function check(_, err)
    if err then
        error(err, 0)
    end
end

-- bounds are { x, y, w, h } as window fractions, and no command starts a shell.
-- a session has at most one popup of each name, which its key brings to the pressing pane's tab.
-- a new one starts in the folder of the pane's program, since zsh reports no folder for pwd to return
local function toggle_popup(ctx, name, bounds, command)
    local window, ctx_layer = find_block(rex.session.view({}), ctx.block_id)
    if not window then
        return
    end
    for _, layer in ipairs(window.layers) do
        if layer.kind == "floating" and parse_popup(layer.blocks[1].label) == name then
            hide_popup(window, layer)
            return
        end
    end
    -- a key pressed in another popup opens this one for that popup's opener
    local opener = ctx.block_id
    if ctx_layer.kind == "floating" then
        for _, block in ipairs(ctx_layer.blocks) do
            local _, other = parse_popup(block.label)
            opener = block.block_id == ctx.block_id and other or opener
        end
    end
    local process = foreground(opener)
    -- other popups in the tab hide, and floating panes that aren't popups stay
    for _, layer in ipairs(window.layers) do
        if layer.kind == "floating" and parse_popup(layer.blocks[1].label) then
            hide_popup(window, layer)
        end
    end
    -- hidden, or showing in another tab, which move_block moves from directly
    local blocks, err = rex.session.list_blocks({})
    check(blocks, err)
    for _, block in ipairs(blocks.blocks) do
        if parse_popup(block.label) == name then
            local anchor = tiled_anchor(window)
            if not anchor then
                error("this tab has no tiled pane to show " .. name .. " over", 0)
            end
            check(rex.session.set_block_label({ block_id = block.block_id, label = popup_label(name, opener) }))
            check(rex.session.move_block({ block_id = block.block_id, anchor_block_id = anchor }))
            check(rex.session.float_block({ block_id = block.block_id, bounds = bounds }))
            check(rex.session.focus_block({ block_id = block.block_id }))
            return
        end
    end
    check(rex.session.new_layer({
        window_id = window.window_id,
        bounds = bounds,
        focus = true,
        layout = rex.layout.block({
            flavor = terminal .. ".shell",
            label = popup_label(name, opener),
            options = {
                command = { "/bin/sh", "-c", popup_wrapper, "popup", unpack(command or {}) },
                cwd = process and process.cwd,
            },
        }),
    }))
end

-- the action and key for a popup.
-- command is an argv list, a function of ctx that returns one, or nil for a shell
local function popup(name, title, key, bounds, command)
    -- popup labels split their fields on whitespace
    assert(not name:find("%s"), "popup name has whitespace: " .. name)
    rex.action({
        name = name,
        title = title,
        run = function(ctx)
            toggle_popup(ctx, name, bounds, type(command) == "function" and command(ctx) or command)
        end,
    })
    rex.bind(key, name)
end

popup("files", "Files", "cmd+e", { 0.05, 0.05, 0.9, 0.9 }, { "yazi" })
popup("scratch", "Scratch Shell", "cmd+j", { 0, 0.6, 1, 0.4 })
-- rext switches the app that pressed the key, which a new popup terminal can't tell it
popup("projects", "Projects", "cmd+p", { 0.3, 0.2, 0.4, 0.6 }, function(ctx)
    return { "env", "REX_CLIENT=" .. (ctx.client_id or ""), "REXT_POPUP=1", "rext" }
end)

-- run by a popup's wrapper once its program exits, from inside the popup
rex.action({
    name = "popup_closed",
    title = "Close Popup",
    run = function(ctx)
        local window, layer = find_block(rex.session.view({}), ctx.block_id)
        if layer and layer.kind == "floating" then
            return_focus(window, layer.blocks[1])
            rex.session.close_layer({ layer_id = layer.layer_id })
        end
    end,
})
