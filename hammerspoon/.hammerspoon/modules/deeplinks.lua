local M = {}

function M.setup(hyper)
    hyper:bind({ "cmd" }, "r", {
        group = "Utilities",
        description = "Reload Hammerspoon",
    }, hs.reload)

    hyper:bind({ "cmd" }, "d", {
        group = "Alfred",
        description = "Browse Downloads",
    }, function()
        hs.urlevent.openURL("alfred://runtrigger/com.mbp.misc/browse-dl/")
    end)

    hyper:bind({}, "4", {
        group = "Shottr",
        description = "Show Shottr",
    }, function()
        hs.urlevent.openURL("shottr://show")
    end)

    hyper:bind({}, "5", {
        group = "Shottr",
        description = "Capture scrolling area",
    }, function()
        hs.urlevent.openURL("shottr://grab/scrolling")
    end)
end

return M
