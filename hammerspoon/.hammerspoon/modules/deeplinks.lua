local M = {}

local copyLinkTask = nil

-- Run the AppleScript in the background so Hammerspoon isn't blocked while
-- Safari responds (hs.osascript.applescript is synchronous).
local function copySafariLink()
    if copyLinkTask and copyLinkTask:isRunning() then return end
    copyLinkTask = hs.task.new("/usr/bin/osascript", function(exitCode, _, stderr)
        if exitCode ~= 0 and stderr and stderr ~= "" then print(stderr) end
    end, {
        "-e", 'tell application "Safari" to set pageURL to URL of current tab of front window',
        "-e", "set the clipboard to pageURL",
    })
    if copyLinkTask then copyLinkTask:start() end
end

function M.setup(hyper)
    hyper:bind({ "cmd" }, "c", {
        group = "Safari",
        description = "Copy current tab link",
    }, copySafariLink)

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

    hyper:bind({ "cmd" }, "y", {
        group = "Alfred",
        description = "Browse Y3",
    }, function()
        hs.urlevent.openURL("alfred://runtrigger/com.mbp.misc/browse-y3/")
    end)

    --[[]
    hyper:bind({}, "3", {
        group = "Shottr",
        description = "Capture fullscreen",
    }, function()
        hs.urlevent.openURL("shottr://grab/fullscreen")
    end)
--]]
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
