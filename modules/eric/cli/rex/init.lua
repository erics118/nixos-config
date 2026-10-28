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

-- the app's shortcuts, grouped as settings > shortcuts shows them, so this file holds the whole keymap.
-- cmd+w and alt+cmd+w are bound by guarded_close below
rex.bind("cmd+n", "client.window.new")
rex.bind("shift+cmd+w", "client.window.close")

rex.bind("shift+cmd+p", "client.palette.toggle")
rex.bind("cmd+,", "client.settings")
rex.bind("shift+cmd+,", "client.diagnostics")
rex.bind("shift+cmd+u", "client.update.accept")
rex.bind("shift+cmd+.", "client.notice.dismiss")

rex.bind("shift+cmd+n", "session.new")
rex.bind("cmd+k", "session.switch")
rex.bind("ctrl+alt+cmd+g", "session.next")
rex.bind("ctrl+alt+cmd+n", "session.previous")
rex.bind("cmd+s>r", "session.rename")
rex.bind("cmd+r", "session.refresh")
rex.bind("ctrl+alt+cmd+w", "session.open_on_web")

rex.bind("cmd+t", "client.tab.new")
rex.unbind("shift+cmd+]")
rex.bind("ctrl+tab", "client.tab.next")
rex.unbind("shift+cmd+[")
rex.bind("ctrl+shift+tab", "client.tab.previous")
for i = 1, 8 do
    rex.bind("cmd+" .. i, "client.tab.goto", { index = i })
end
-- the last tab
rex.bind("cmd+9", "client.tab.goto", { index = -1 })
rex.bind("ctrl+shift+pageup", "client.tab.move.backward")
rex.bind("ctrl+shift+pagedown", "client.tab.move.forward")

-- shift+cmd+h/j/k/l split, in place of shift+cmd+arrows
for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
    rex.unbind("shift+cmd+" .. direction)
    rex.bind("shift+cmd+" .. key, "pane.split." .. direction)
    rex.unbind("alt+cmd+" .. direction)
    rex.bind("alt+shift+cmd+" .. direction, "pane.move." .. direction)
end
rex.unbind("shift+cmd+d")
rex.bind("cmd+]", "pane.focus_next")
rex.bind("cmd+[", "pane.focus_previous")
rex.bind("alt+cmd+enter", "pane.float")
rex.unbind("shift+cmd+enter")
rex.bind("shift+cmd+g", "pane.go_to_directory")
rex.bind("ctrl+cmd+i", "pane.insert_path")
rex.bind("cmd+s>e", "pane.balance")
rex.bind("cmd+s>b", "pane.move_to_new_tab")
rex.bind("cmd+s>shift+b", "pane.move_to_tab")

-- readline keys for mac text navigation
rex.bind("cmd+backspace", "pane.send_key", { key = "ctrl+u" })
rex.bind("cmd+left", "pane.send_key", { key = "ctrl+a" })
rex.bind("cmd+right", "pane.send_key", { key = "ctrl+e" })
rex.bind("alt+left", "pane.send_key", { key = "alt+b" })
rex.bind("alt+right", "pane.send_key", { key = "alt+f" })

rex.bind("cmd+f", "client.find.open")
rex.bind("cmd+g", "client.find.next")

rex.bind("cmd+=", "client.font.increase")
rex.unbind("shift+cmd+=")
rex.bind("cmd+-", "client.font.decrease")
rex.bind("cmd+0", "client.font.reset")
rex.unbind("cmd+/")
rex.bind("cmd+.", "client.sidebar.activity.toggle")
rex.unbind("shift+cmd+s")
rex.bind("ctrl+cmd+s", "client.sidebar.toggle")
rex.bind("ctrl+cmd+v", "client.tab_style.toggle")

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

-- closing a pane or tab that runs anything but an idle shell asks first, in a macos alert.
-- where osascript is missing, as on a linux server, the key enters a one-shot confirm mode instead,
-- whose key hints rex shows, where enter closes and escape cancels
local shells = { zsh = true, bash = true, sh = true, fish = true, nu = true }

-- a block's program, or nil once it has exited or while its login shell is in the foreground.
-- only a login shell's argv0 starts with a dash, since a sh script or sh -c reports sh too.
-- a failed lookup counts as busy, since a wrong guess ends a running program
local function program(block_id)
    local info = rex.block.call(terminal, "process", { block_id = block_id })
    if info and info.last_exit then
        return nil
    end
    local process = info and info.foreground
    if not process then
        return "a program"
    end
    if shells[process.name] and (process.argv0 or ""):sub(1, 1) == "-" then
        return nil
    end
    -- argv0 before name, since claude's executable is named after its version
    return (process.script or process.argv0 or process.name):match("[^/]*$")
end

local function busy_programs(block_ids)
    local names = {}
    for _, block_id in ipairs(block_ids) do
        local name = program(block_id)
        if name then
            table.insert(names, name)
        end
    end
    return names
end

-- without the accessory policy the alert opens behind rex, and focus doesn't reliably return to rex after.
-- the icon follows rex's app icon setting, by the asset names rex beta gives each choice.
-- the alert cancels itself after 20 seconds, within the 30 an action gets
local alert_script = [[
ObjC.import("AppKit")
function run(argv) {
  const app = $.NSApplication.sharedApplication
  const rex = $.NSRunningApplication.runningApplicationsWithBundleIdentifier("com.superlogical.rex").firstObject
  const alert = $.NSAlert.alloc.init
  alert.messageText = argv[0]
  alert.informativeText = argv[1]
  const choice = $.NSUserDefaults.alloc.initWithSuiteName("com.superlogical.rex").stringForKey("Workspace.appIcon").js
  const chosen = choice && $.NSBundle.bundleWithURL(rex.bundleURL).imageForResource("PlainAppIcon" + choice[0].toUpperCase() + choice.slice(1) + "Beta")
  alert.icon = chosen && !chosen.isNil() ? chosen : rex.icon
  alert.addButtonWithTitle("Close")
  alert.addButtonWithTitle("Cancel")
  app.setActivationPolicy($.NSApplicationActivationPolicyAccessory)
  app.activateIgnoringOtherApps(true)
  app.performSelectorWithObjectAfterDelayInModes("abortModal", $(), 20, $([$.NSModalPanelRunLoopMode]))
  const response = alert.runModal
  rex.activateWithOptions(0)
  return response == $.NSAlertFirstButtonReturn ? "Close" : "Cancel"
}
]]

-- true or false for the alert's answer, or nil where osascript can't run
local function confirm(title, text)
    local reply = rex.exec({ "osascript", "-l", "JavaScript", "-e", alert_script, title, text }, { timeout = 25 })
    if not reply then
        return nil
    end
    return reply.ok and reply.stdout:match("^Close") ~= nil
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

-- what is the noun in the alert, close the client action, and close_by_id(ctx) closes the pressed pane's own,
-- since the alert can move the app's focus away from it
local function guarded_close(name, title, key, what, close, blocks, close_by_id)
    -- action names allow no dashes
    local action = (name:gsub("-", "_"))
    rex.mode(name, { exclusive = true })
    rex.bind(name .. "/enter", close)
    rex.action({
        name = action,
        title = title,
        run = function(ctx)
            local busy = busy_programs(blocks(ctx.block_id))
            if #busy == 0 then
                rex.client.queue(close)
                return
            end
            local running = table.concat(busy, ", ") .. (#busy == 1 and " is" or " are")
            local confirmed = confirm(
                "Close " .. what .. "?",
                running .. " still running. If you close the " .. what:lower() .. ", it will be killed."
            )
            if confirmed == nil then
                rex.client.queue("client.mode.enter", { name = name, once = true })
            elseif confirmed then
                close_by_id(ctx)
            end
        end,
    })
    rex.bind(key, action)
end

guarded_close("confirm-close", "Close Pane, Asking When Busy", "cmd+w", "Pane", "pane.close", function(block_id)
    return { block_id }
end, function(ctx)
    rex.call("block.close", { session_id = ctx.session_id, block_id = ctx.block_id })
end)
guarded_close(
    "confirm-close-tab",
    "Close Tab, Asking When Busy",
    "alt+cmd+w",
    "Tab",
    "client.tab.close",
    window_blocks,
    function(ctx)
        local window = find_block(rex.session.view({}), ctx.block_id)
        if window then
            rex.session.close_window({ window_id = window.window_id })
        end
    end
)

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
