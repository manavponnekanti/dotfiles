local function loadModule(name)
    return dofile(hs.configdir .. "/modules/" .. name .. ".lua")
end

-- Modules are loaded explicitly so each file can keep its state private.
local alerts = loadModule("alerts")
local hyperModule = loadModule("hyper")
local apps = loadModule("apps")
local windows = loadModule("windows")

alerts.setup()

-- Apps is set up first so windows can temporarily intercept app shortcuts
-- while the opposite-app chooser is open.
local hyper = hyperModule.setup()
apps.setup(hyper, alerts)
windows.setup(hyper, alerts, apps)

hyper:bind({ "shift" }, "r", hs.reload)

alerts.show("Config loaded")
