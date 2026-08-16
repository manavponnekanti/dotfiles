-- Keep Hammerspoon's local CLI available for config inspection and reloads.
require("hs.ipc")

local ui = require("modules.ui")
local alerts = require("modules.alerts")
local cheatsheetModule = require("modules.cheatsheet")
local hyperModule = require("modules.hyper")
local apps = require("modules.apps")
local windows = require("modules.windows")
local airpods = require("modules.airpods")
local deeplinks = require("modules.deeplinks")
local passwords = require("modules.passwords")
local flowmodoro = require("modules.flowmodoro")

hs.window.animationDuration = 0

alerts.setup()

local cheatsheet = cheatsheetModule.new(ui)
local hyper = hyperModule.setup(cheatsheet)

-- Command modules claim their keys before apps derives its assignable keys.
-- Add future shortcut-owning modules above apps.setup for automatic exclusion.
windows.setup(hyper, alerts)
airpods.setup(hyper, alerts)
deeplinks.setup(hyper)
passwords.setup(hyper, alerts)
flowmodoro.setup(hyper, alerts, ui)
apps.setup(hyper, alerts)

alerts.show("Config loaded")
