local M = {}

function M.setup(hyper)
    local bluetoothHelper = hs.configdir .. "/bluetooth-toggle.js"
    local btBusy = false

    local function showBluetoothError(name, detail)
        hs.alert.show(name .. " error")
        if detail and detail ~= "" then
            print(detail)
        end
    end

    local function toggleBluetooth(mac, name)
        if btBusy then return end
        btBusy = true
        local task = hs.task.new("/usr/bin/osascript", function(exitCode, stdOut, stdErr)
            btBusy = false
            if exitCode ~= 0 then
                showBluetoothError(name, stdErr)
                return
            end

            local ok, result = pcall(hs.json.decode, stdOut or "")
            if not ok or type(result) ~= "table" then
                showBluetoothError(name, stdOut)
                return
            end

            if result.ok then
                hs.alert.show((result.name or name) ..
                    (result.action == "disconnect" and " disconnected" or " connected"))
                return
            end

            local message = ({
                ["missing-address"] = "missing address",
                ["unsupported-macos"] = "requires macOS 10.15+",
                ["bluetooth-permission"] = "needs Bluetooth permission",
                ["not-found"] = "not found",
                ["toggle-failed"] = "error",
            })[result.error] or "error"

            hs.alert.show((result.name or name) .. " " .. message)
            if result.detail then
                print(result.detail)
            end
        end, { "-l", "JavaScript", bluetoothHelper, mac })

        if not task then
            btBusy = false
            showBluetoothError(name)
            return
        end

        hs.alert.show(name .. " toggling...")
        task:start()
    end

    hyper:bind({}, "1", function() toggleBluetooth("ac-80-0a-7a-c0-98", "XM5") end)
end

return M
