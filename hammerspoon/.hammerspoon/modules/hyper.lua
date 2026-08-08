local M = {}

local caffeinateWatcher = nil

function M.setup()
    local hyper = hs.hotkey.modal.new()
    local hyperModifiers = { {}, { "shift" } }

    for _, modifiers in ipairs(hyperModifiers) do
        hs.hotkey.bind(modifiers, "f19",
            function() hyper:enter() end,
            function() hyper:exit() end
        )
    end

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
