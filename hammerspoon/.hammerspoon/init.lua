-- Keep Hammerspoon's local CLI available for config inspection and reloads.
require("hs.ipc")

-- The core is not optional: without ui, alerts and the hyper modal there is
-- nothing for a feature module to attach to, so failing here should be loud.
local ui = require("modules.ui")
local alerts = require("modules.alerts")
local cheatsheetModule = require("modules.cheatsheet")
local hyperModule = require("modules.hyper")

hs.window.animationDuration = 0

-- Cap how long a single Accessibility request may block Hammerspoon. The macOS
-- default is ~6s, so one busy app (e.g. Outlook mid-sync) could stall every
-- hotkey. Raise this if tiling a slow app starts silently failing.
hs.window.timeout(1)

alerts.setup()

local cheatsheet = cheatsheetModule.new(ui)
local hyper = hyperModule.setup(cheatsheet)

-- A feature module that fails to load or set up used to abort the whole config,
-- leaving no bindings at all — not even the reload shortcut. Collect failures
-- instead and keep whatever did load.
local failures = {}

local function feature(name, setup)
    local ok, result = pcall(require, "modules." .. name)
    if ok then
        ok, result = pcall(setup, result)
    end
    if not ok then
        table.insert(failures, name)
        print("modules." .. name .. " failed: " .. tostring(result))
    end
end

-- Command modules claim their keys before apps derives its assignable keys.
-- Add future shortcut-owning modules above the apps entry for automatic
-- exclusion.
feature("windows", function(m) m.setup(hyper) end)
feature("airpods", function(m) m.setup(hyper, alerts) end)
feature("deeplinks", function(m) m.setup(hyper) end)
feature("flowmodoro", function(m) m.setup(hyper, alerts, ui) end)
feature("apps", function(m) m.setup(hyper, alerts) end)

if #failures == 0 then
    alerts.show("Config loaded")
else
    alerts.show("Config loaded without " .. table.concat(failures, ", "))
end
