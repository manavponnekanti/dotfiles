local function loadModule(name)
    return dofile(hs.configdir .. "/modules/" .. name .. ".lua")
end

local alerts = loadModule("alerts")
local meh = loadModule("meh")
local apps = loadModule("apps")
local windows = loadModule("windows")

alerts.setup()

apps.setup(meh, alerts)
windows.setup(meh, alerts)

meh:bind({ "cmd" }, "r", hs.reload)

alerts.show("Config loaded")
