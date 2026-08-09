local M = {}

local blueutilPath = "/opt/homebrew/bin/blueutil"
local deviceAddress = "54-2a-43-0d-49-cf"
local deviceName = "Manav's AirPods Pro"
local alerts = nil
local activeTask = nil

local function showAlert(message)
    if alerts then
        return alerts.show(message)
    end
    return hs.alert.show(message)
end

local function runBlueutil(arguments, callback)
    local task
    task = hs.task.new(blueutilPath, function(exitCode, stdout, stderr)
        if task ~= activeTask then return end

        activeTask = nil
        callback(exitCode, stdout, stderr)
    end, arguments)

    if not task then
        showAlert("Could not start blueutil")
        return
    end

    activeTask = task
    if not task:start() then
        activeTask = nil
        showAlert("Could not start blueutil")
    end
end

local function toggle()
    if activeTask then
        local task = activeTask
        activeTask = nil
        task:terminate()
        showAlert("AirPods request cancelled")
        return
    end

    runBlueutil({ "--is-connected", deviceAddress }, function(statusCode, stdout, stderr)
        if statusCode ~= 0 then
            showAlert("Could not check " .. deviceName)
            print(stderr)
            return
        end

        local connected = stdout:match("1") ~= nil
        local action = connected and "--disconnect" or "--connect"

        showAlert(connected and "AirPods disconnecting..." or "AirPods connecting...")
        runBlueutil({ action, deviceAddress }, function(exitCode, _, actionError)
            if exitCode ~= 0 then
                showAlert("Could not " .. (connected and "disconnect " or "connect ") .. deviceName)
                print(actionError)
                return
            end

            showAlert((connected and "Disconnected " or "Connected ") .. deviceName)
        end)
    end)
end

function M.setup(hyper, alertModule)
    alerts = alertModule
    hyper:bind({ "shift" }, "b", {
        group = "Utilities",
        description = "Toggle AirPods",
    }, toggle)
end

return M
