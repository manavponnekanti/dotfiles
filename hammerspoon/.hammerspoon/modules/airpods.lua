local M = {}

local blueutilPath = "/opt/homebrew/bin/blueutil"
local deviceAddress = "54-2a-43-0d-49-cf"
local deviceName = "Manav's AirPods Pro"
local activeTask = nil

local function connectAirPods(alerts)
    if activeTask then
        alerts.show("AirPods connection already in progress")
        return
    end

    local task
    task = hs.task.new(blueutilPath, function(exitCode, _, stderr)
        if task ~= activeTask then return end
        activeTask = nil

        if exitCode == 0 then
            alerts.show("Connected " .. deviceName)
        else
            alerts.show("Could not connect " .. deviceName)
            if stderr and stderr ~= "" then print(stderr) end
        end
    end, { "--connect", deviceAddress })

    if not task then
        alerts.show("Could not start blueutil")
        return
    end

    activeTask = task
    alerts.show("Connecting AirPods…")
    if not task:start() then
        activeTask = nil
        alerts.show("Could not start blueutil")
    end
end

function M.setup(hyper, alertModule)
    hyper:bind({ "cmd" }, "b", {
        group = "Utilities",
        description = "Connect AirPods",
    }, function()
        connectAirPods(alertModule)
    end)
end

return M
