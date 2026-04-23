local M = {}

function M.setup(hyper)
    local pinMode = false

    local sizes = { left = { 0.5, 2 / 3 }, right = { 0.5, 1 / 3 } }
    local restoreRightThirdBundleIDs = {
        ["com.apple.MobileSMS"] = true,
        ["ru.keepcoder.Telegram"] = true,
        ["net.whatsapp.WhatsApp"] = true,
    }

    local function standardWindowsOnScreen(screen)
        local windows = {}
        for _, win in ipairs(hs.window.visibleWindows()) do
            if win:screen() == screen and win:isStandard() then
                table.insert(windows, win)
            end
        end
        return windows
    end

    local function standardWindowsForApp(app)
        local windows = {}
        if not app then return windows end

        for _, win in ipairs(app:allWindows()) do
            if win:isStandard() then
                table.insert(windows, win)
            end
        end

        return windows
    end

    local function focusedAppWindows()
        local win = hs.window.focusedWindow()
        local app = win and win:application()
        return standardWindowsForApp(app)
    end

    local function usableWidth(screenFrame)
        return pinMode and math.floor(screenFrame.w * 0.75) or screenFrame.w
    end

    local function setWindowFrame(win, x, w, anchorRightEdge)
        if not win then return end

        local sf = win:screen():frame()
        win:setFrame(hs.geometry.rect(x, sf.y, w, sf.h))

        if anchorRightEdge then
            local actual = win:frame()
            local rightEdge = x + w
            if math.abs((actual.x + actual.w) - rightEdge) > 1 then
                win:setFrame(hs.geometry.rect(rightEdge - actual.w, sf.y, actual.w, sf.h))
            end
        end
    end

    local function moveWindowToRightQuarter(win)
        if not win then return end

        local sf = win:screen():frame()
        setWindowFrame(win, sf.x + (sf.w * 0.75), sf.w * 0.25, true)
    end

    local function moveWindowToRightThird(win)
        if not win then return end

        local sf = win:screen():frame()
        local availW = usableWidth(sf)
        local w = availW / 3
        local x = sf.x + (availW - w)
        setWindowFrame(win, x, w, true)
    end

    local function shouldRestoreToRightThird(win)
        local app = win and win:application()
        if not app then return false end

        local bundleID = app:bundleID()
        return bundleID and restoreRightThirdBundleIDs[bundleID] or false
    end

    local function maximizeWindow(win)
        if not win then return end
        local sf = win:screen():frame()
        setWindowFrame(win, sf.x, usableWidth(sf))
    end

    local function centerWindow(win)
        if not win then return end

        local sf = win:screen():frame()
        local availW = usableWidth(sf)
        local w = availW * 0.5
        local x = sf.x + ((availW - w) / 2)
        setWindowFrame(win, x, w)
    end

    local function maximizeWindows(windows)
        for _, win in ipairs(windows) do
            maximizeWindow(win)
        end
    end

    local function maximizeAllOnScreen()
        local screen = hs.screen.mainScreen()
        maximizeWindows(standardWindowsOnScreen(screen))
    end

    local function restoreWindows(windows)
        for _, win in ipairs(windows) do
            if shouldRestoreToRightThird(win) then
                moveWindowToRightThird(win)
            else
                maximizeWindow(win)
            end
        end
    end

    local function restoreAllOnScreen()
        local screen = hs.screen.mainScreen()
        restoreWindows(standardWindowsOnScreen(screen))
    end

    local function moveWindow(win, direction)
        if not win then return end
        local f = win:frame()
        local sf = win:screen():frame()
        local availW = usableWidth(sf)
        local curX = (f.x - sf.x) / availW
        local curW = f.w / availW
        local tol = 0.05

        local sizeList = sizes[direction]
        local nextIdx = 1
        for i, size in ipairs(sizeList) do
            local expX = direction == "left" and 0 or (1 - size)
            if math.abs(curW - size) < tol and math.abs(curX - expX) < tol then
                nextIdx = (i % #sizeList) + 1
                break
            end
        end

        local size = sizeList[nextIdx]
        local x = direction == "left" and sf.x or (sf.x + availW * (1 - size))
        local w = availW * size
        setWindowFrame(win, x, w, direction == "right")
    end

    local function bindWindowAction(key, action)
        hyper:bind({}, key, function()
            action(hs.window.focusedWindow())
        end)

        hyper:bind({ "shift" }, key, function()
            for _, win in ipairs(focusedAppWindows()) do
                action(win)
            end
        end)
    end

    bindWindowAction("j", function(win) moveWindow(win, "left") end)

    bindWindowAction("k", maximizeWindow)

    bindWindowAction("'", centerWindow)

    bindWindowAction("l", function(win) moveWindow(win, "right") end)

    hyper:bind({}, ";", function()
        if pinMode then
            moveWindowToRightQuarter(hs.window.focusedWindow())
        else
            restoreAllOnScreen()
        end
    end)

    hyper:bind({ "shift" }, ";", function()
        local windows = focusedAppWindows()
        if pinMode then
            for _, win in ipairs(windows) do
                moveWindowToRightQuarter(win)
            end
        else
            restoreWindows(windows)
        end
    end)

    hyper:bind({}, "u", function()
        pinMode = not pinMode
        hs.alert.show(pinMode and "Pin mode ON" or "Pin mode OFF")
        if pinMode then
            maximizeAllOnScreen()
        else
            restoreAllOnScreen()
        end
    end)

    hyper:bind({ "shift" }, "u", function()
        pinMode = not pinMode
        hs.alert.show(pinMode and "Pin mode ON" or "Pin mode OFF")

        local windows = focusedAppWindows()
        if pinMode then
            maximizeWindows(windows)
        else
            restoreWindows(windows)
        end
    end)

    hyper:bind({}, "h", function()
        local win = hs.window.focusedWindow()
        if not win then return end
        win:moveToScreen(win:screen():next())
        local center = hs.geometry.rectMidPoint(win:frame())
        hs.mouse.absolutePosition(center)
    end)
end

return M
