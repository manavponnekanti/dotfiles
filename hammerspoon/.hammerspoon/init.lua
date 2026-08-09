local function loadModule(name)
    return dofile(hs.configdir .. "/modules/" .. name .. ".lua")
end

-- Keep Hammerspoon's local CLI available for config inspection and reloads.
require("hs.ipc")

-- Modules are loaded explicitly so each file can keep its state private.
local ui = loadModule("ui")
local alerts = loadModule("alerts")
local hyperModule = loadModule("hyper")
local apps = loadModule("apps")
local windows = loadModule("windows")
local airpods = loadModule("airpods")
local deeplinks = loadModule("deeplinks")
local flowmodoro = loadModule("flowmodoro")

alerts.setup()

local hyper = hyperModule.setup(ui)

-- Command modules claim their keys before apps derives its assignable keys.
-- Add future shortcut-owning modules above apps.setup for automatic exclusion.
windows.setup(hyper, alerts, apps)
airpods.setup(hyper, alerts)
deeplinks.setup(hyper)
flowmodoro.setup(hyper, alerts, ui)
apps.setup(hyper, alerts)

alerts.show("Config loaded")
