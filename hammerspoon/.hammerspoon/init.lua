local function loadModule(name)
    return dofile(hs.configdir .. "/modules/" .. name .. ".lua")
end

local alerts = loadModule("alerts")
local hyperModule = loadModule("hyper")
local apps = loadModule("apps")
local bluetooth = loadModule("bluetooth")
local menuSearch = loadModule("menu_search")
local timer = loadModule("timer")
local windows = loadModule("windows")

alerts.setup()

local hyper = hyperModule.setup()
apps.setup(hyper)
bluetooth.setup(hyper)
menuSearch.setup(hyper)
timer.setup(hyper)
windows.setup(hyper)

hyper:bind({ "shift" }, "r", hs.reload)

hs.alert.show("Config loaded")
