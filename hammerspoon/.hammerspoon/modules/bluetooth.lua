local M = {}

function M.setup(hyper)
    local blueutil = "/opt/homebrew/bin/blueutil"
    local btBusy = false

    local function commandOutput(stdOut, stdErr)
        return table.concat({ stdErr or "", stdOut or "" }, "\n")
    end

    local function showBluetoothError(name, detail)
        hs.alert.show(name .. " error")
        if detail and detail:gsub("%s+", "") ~= "" then
            print(detail)
        end
    end

    local function runBlueutil(args, callback, timeoutSeconds)
        local finished = false
        local task
        local timeoutTimer

        local function done(exitCode, stdOut, stdErr)
            if finished then return end
            finished = true
            if timeoutTimer then
                timeoutTimer:stop()
                timeoutTimer = nil
            end
            callback(exitCode, stdOut or "", stdErr or "")
        end

        task = hs.task.new(blueutil, function(exitCode, stdOut, stdErr)
            done(exitCode, stdOut, stdErr)
        end, args)

        if not task then
            done(-1, "", "Could not start blueutil")
            return
        end

        timeoutTimer = hs.timer.doAfter(timeoutSeconds or 8, function()
            if finished then return end
            task:terminate()
            done(124, "", "blueutil timed out: " .. table.concat(args, " "))
        end)

        task:start()
    end

    local function finishToggle(name, action)
        btBusy = false
        hs.alert.show(name .. (action == "disconnect" and " disconnected" or " connected"))
    end

    local function runDeviceAction(mac, name, action)
        runBlueutil({ "--" .. action, mac }, function(exitCode, stdOut, stdErr)
            if exitCode ~= 0 then
                btBusy = false
                showBluetoothError(name, commandOutput(stdOut, stdErr))
                return
            end

            finishToggle(name, action)
        end, 12)
    end

    local function connectDevice(mac, name)
        runBlueutil({ "--power" }, function(exitCode, stdOut, stdErr)
            if exitCode ~= 0 then
                btBusy = false
                showBluetoothError(name, commandOutput(stdOut, stdErr))
                return
            end

            if stdOut:match("^%s*0%s*$") then
                runBlueutil({ "--power", "1" }, function(powerExitCode, powerStdOut, powerStdErr)
                    if powerExitCode ~= 0 then
                        btBusy = false
                        showBluetoothError(name, commandOutput(powerStdOut, powerStdErr))
                        return
                    end

                    hs.timer.doAfter(1, function()
                        runDeviceAction(mac, name, "connect")
                    end)
                end)
            else
                runDeviceAction(mac, name, "connect")
            end
        end)
    end

    local function toggleBluetooth(mac, name)
        if btBusy then return end
        btBusy = true

        hs.alert.show(name .. " toggling...")
        runBlueutil({ "--is-connected", mac }, function(exitCode, stdOut, stdErr)
            if exitCode ~= 0 then
                btBusy = false
                showBluetoothError(name, commandOutput(stdOut, stdErr))
                return
            end

            if stdOut:match("^%s*1%s*$") then
                runDeviceAction(mac, name, "disconnect")
            else
                connectDevice(mac, name)
            end
        end)
    end

    hyper:bind({}, "1", function() toggleBluetooth("ac-80-0a-7a-c0-98", "XM5") end)
    hyper:bind({}, "3", function() toggleBluetooth("54-2a-43-0d-49-cf", "AirPods Pro") end)
end

return M
