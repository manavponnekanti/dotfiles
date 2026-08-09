local M = {}

function M.setup(hyper)
    hyper:bind({ "shift" }, "r", {
        group = "System",
        description = "Reload Hammerspoon",
    }, hs.reload)

    hyper:bind({}, "r", {
        group = "Files",
        description = "Browse Downloads",
    }, function()
        hs.urlevent.openURL("alfred://runtrigger/com.mbp.misc/browse-dl/")
    end)

    hyper:bind({ "shift" }, "y", {
        group = "Files",
        description = "Browse Y3",
    }, function()
        hs.urlevent.openURL("alfred://runtrigger/com.mbp.misc/browse-y3/")
    end)

end

return M
