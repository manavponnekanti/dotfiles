local function loadModule(name)
    return dofile(hs.configdir .. "/modules/" .. name .. ".lua")
end

local alerts = loadModule("alerts")
local hyperModule = loadModule("hyper")
local apps = loadModule("apps")
local windows = loadModule("windows")

alerts.setup()

local hyper = hyperModule.setup()
apps.setup(hyper)
windows.setup(hyper)

hyper:bind({ "shift" }, "r", hs.reload)

hs.alert.show("Config loaded")
