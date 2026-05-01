local M = {}

local caffeinateWatcher = nil
local f19Tap = nil
local f19Hotkey = nil

function M.setup()
    local hyper = hs.hotkey.modal.new()
    local pressedCallbacks = {}
    local releasedCallbacks = {}
    local f19Down = false

    function hyper:onPressed(callback)
        table.insert(pressedCallbacks, callback)
    end

    function hyper:onReleased(callback)
        table.insert(releasedCallbacks, callback)
    end

    function hyper:isPressed()
        return f19Down
    end

    local function notify(callbacks)
        for _, callback in ipairs(callbacks) do
            local ok, err = xpcall(callback, debug.traceback)
            if not ok then
                print(err)
            end
        end
    end

    local function pressF19()
        if f19Down then return end

        f19Down = true
        hyper:enter()
        notify(pressedCallbacks)
    end

    local function releaseF19()
        if not f19Down then return end

        f19Down = false
        notify(releasedCallbacks)
        hyper:exit()
    end

    local eventTypes = hs.eventtap.event.types
    local f19KeyCode = hs.keycodes.map.f19
    f19Tap = hs.eventtap.new({ eventTypes.keyDown, eventTypes.keyUp }, function(event)
        if event:getKeyCode() ~= f19KeyCode then
            return false
        end

        if event:getType() == eventTypes.keyDown then
            pressF19()
        else
            releaseF19()
        end

        return true
    end)
    f19Tap:start()
    f19Hotkey = hs.hotkey.bind({}, "f19", pressF19, releaseF19)

    caffeinateWatcher = hs.caffeinate.watcher.new(function(event)
        if event == hs.caffeinate.watcher.systemDidWake
            or event == hs.caffeinate.watcher.screensDidUnlock then
            releaseF19()
        end
    end)
    caffeinateWatcher:start()

    return hyper
end

return M
