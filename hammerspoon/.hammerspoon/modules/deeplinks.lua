local M = {}

function M.setup(hyper)
    hyper:bind({ "cmd" }, "r", {
        group = "Utilities",
        description = "Reload Hammerspoon",
    }, hs.reload)

    hyper:bind({}, "r", {
        group = "Alfred",
        description = "Browse Downloads",
    }, function()
        hs.urlevent.openURL("alfred://runtrigger/com.mbp.misc/browse-dl/")
    end)

    hyper:bind({ "cmd" }, "y", {
        group = "Alfred",
        description = "Browse Y3",
    }, function()
        hs.urlevent.openURL("alfred://runtrigger/com.mbp.misc/browse-y3/")
    end)

    hyper:bind({}, "3", {
        group = "Shottr",
        description = "Capture fullscreen",
    }, function()
        hs.urlevent.openURL("shottr://grab/fullscreen")
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
