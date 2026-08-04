local function loadModule(name)
    return dofile(hs.configdir .. "/modules/" .. name .. ".lua")
end

-- Modules are loaded explicitly so each file can keep its state private.
local alerts = loadModule("alerts")
local meh = loadModule("meh")
local apps = loadModule("apps")
local windows = loadModule("windows")

alerts.setup()

-- Apps is set up first so windows can temporarily intercept app shortcuts
-- while the opposite-app chooser is open.
apps.setup(meh, alerts)
windows.setup(meh, alerts, apps)

meh:bind({ "cmd" }, "r", hs.reload)

alerts.show("Config loaded")
