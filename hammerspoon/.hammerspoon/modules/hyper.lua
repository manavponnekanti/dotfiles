local M = {}

local caffeinateWatcher = nil

function M.setup()
    local hyper = hs.hotkey.modal.new()

    hs.hotkey.bind({}, "f19",
        function() hyper:enter() end,
        function() hyper:exit() end
    )

    caffeinateWatcher = hs.caffeinate.watcher.new(function(event)
        if event == hs.caffeinate.watcher.systemDidWake
            or event == hs.caffeinate.watcher.screensDidUnlock then
            hyper:exit()
        end
    end)
    caffeinateWatcher:start()

    return hyper
end

return M
