local function loadModule(name)
    return dofile(hs.configdir .. "/modules/" .. name .. ".lua")
end

local alerts = loadModule("alerts")
local hyperModule = loadModule("hyper")
local apps = loadModule("apps")
local bluetooth = loadModule("bluetooth")
local timer = loadModule("timer")
local windows = loadModule("windows")
local pointerWindow = loadModule("pointer_window")

alerts.setup()

local hyper = hyperModule.setup()
apps.setup(hyper)
bluetooth.setup(hyper)
timer.setup(hyper)
windows.setup(hyper)
pointerWindow.setup(hyper)

hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "r", hs.reload)

hs.alert.show("Config loaded")
