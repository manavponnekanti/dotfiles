local M = {}

local blueutilPath = "/opt/homebrew/bin/blueutil"
local deviceAddress = "54-2a-43-0d-49-cf"
local deviceName = "Manav's AirPods Pro"
-- blueutil waits on the Bluetooth stack, which can stop answering altogether.
-- Without a cap a hung connect latches activeTask and leaves the binding dead
-- until the next config reload.
local connectTimeout = 15
local activeTask = nil
local activeTimeout = nil

local function clearActiveTask()
    if activeTimeout then
        activeTimeout:stop()
        activeTimeout = nil
    end
    activeTask = nil
end

local function connectAirPods(alerts)
    if activeTask then
        alerts.show("AirPods connection already in progress")
        return
    end

    local task
    task = hs.task.new(blueutilPath, function(exitCode, _, stderr)
        if task ~= activeTask then return end
        clearActiveTask()

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
        clearActiveTask()
        alerts.show("Could not start blueutil")
        return
    end

    -- Cleared before terminate() so the task's own callback sees a stale task
    -- and stays quiet; only one alert reaches the screen.
    activeTimeout = hs.timer.doAfter(connectTimeout, function()
        if task ~= activeTask then return end
        clearActiveTask()
        task:terminate()
        alerts.show("Could not connect " .. deviceName)
    end)
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
