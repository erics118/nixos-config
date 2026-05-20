-- Require the sketchybar module
sbar = require("sketchybar")
require("helpers.add_item")

colors = require("colors")
icons = require("icons")
settings = require("settings")

-- Bundle the entire initial configuration into a single message to sketchybar

sbar.begin_config()

require("default")

require("bar")

require("items")

sbar.end_config()

-- Run the event loop of the sketchybar module (without this there will be no
-- callback functions executed in the lua module)
sbar.event_loop()
