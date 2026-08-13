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
-- local windows = loadModule("windows") -- Replaced by ad-hoc F19 gestures.
local swiftshift = loadModule("swiftshift")
local airpods = loadModule("airpods")
local deeplinks = loadModule("deeplinks")
local passwords = loadModule("passwords")
local flowmodoro = loadModule("flowmodoro")

alerts.setup()

local hyper = hyperModule.setup(ui)

-- Command modules claim their keys before apps derives its assignable keys.
-- Add future shortcut-owning modules above apps.setup for automatic exclusion.
-- windows.setup(hyper, alerts, apps)
swiftshift.setup(hyper)
airpods.setup(hyper, alerts)
deeplinks.setup(hyper)
passwords.setup(hyper, alerts)
flowmodoro.setup(hyper, alerts, ui)
apps.setup(hyper, alerts)

alerts.show("Config loaded")
