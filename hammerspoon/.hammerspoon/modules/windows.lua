local M = {}

function M.setup(hyper)
    local pinMode = false

    local sizes = { left = { 0.5, 2 / 3 }, right = { 0.5, 1 / 3 } }
    local finderBundleID = "com.apple.finder"
    local finderFolders = {
        downloads = {
            title = "Downloads",
            path = os.getenv("HOME") .. "/Downloads",
        },
        screenshots = {
            title = "Screenshots",
            path = os.getenv("HOME") .. "/Documents/Screenshots",
        },
    }
    local screenUnits = {
        leftHalf = { x = 0, y = 0, w = 0.5, h = 1 },
        rightQuarter = { x = 0.75, y = 0, w = 0.25, h = 1 },
        topRightQuarter = { x = 0.5, y = 0, w = 0.5, h = 0.5 },
        bottomRightQuarter = { x = 0.5, y = 0.5, w = 0.5, h = 0.5 },
    }
    local restoreLeftHalfBundleIDs = {
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

    local function setWindowFrame(win, x, y, w, h, anchorRightEdge)
        if not win then return end

        local rect = hs.geometry.rect(x, y, w, h)
        win:setFrame(rect)

        if anchorRightEdge then
            local actual = win:frame()
            local rightEdge = rect.x + rect.w
            if math.abs((actual.x + actual.w) - rightEdge) > 1 then
                win:setFrame(hs.geometry.rect(rightEdge - actual.w, rect.y, actual.w, rect.h))
            end
        end
    end

    local function moveWindowToScreenUnit(win, screen, unit, anchorRightEdge)
        if not win then return end

        local sf = screen:frame()
        setWindowFrame(
            win,
            sf.x + (sf.w * unit.x),
            sf.y + (sf.h * unit.y),
            sf.w * unit.w,
            sf.h * unit.h,
            anchorRightEdge
        )
    end

    local function moveWindowToRightQuarter(win)
        if not win then return end

        moveWindowToScreenUnit(win, win:screen(), screenUnits.rightQuarter, true)
    end

    local function moveWindowToLeftHalf(win)
        if not win then return end

        moveWindowToScreenUnit(win, win:screen(), screenUnits.leftHalf)
    end

    local function shouldRestoreAppToLeftHalf(app)
        local bundleID = app:bundleID()
        return bundleID and restoreLeftHalfBundleIDs[bundleID] or false
    end

    local function maximizeWindow(win)
        if not win then return end
        local sf = win:screen():frame()
        setWindowFrame(win, sf.x, sf.y, usableWidth(sf), sf.h)
    end

    local function centerWindow(win)
        if not win then return end

        local sf = win:screen():frame()
        local availW = usableWidth(sf)
        local w = availW * 0.5
        local x = sf.x + ((availW - w) / 2)
        setWindowFrame(win, x, sf.y, w, sf.h)
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
            local app = win:application()
            if app and app:bundleID() == finderBundleID then
                -- Finder gets a fixed three-window layout in restoreAllOnScreen().
            elseif app and shouldRestoreAppToLeftHalf(app) then
                moveWindowToLeftHalf(win)
            else
                maximizeWindow(win)
            end
        end
    end

    local function openFinderFolder(path)
        hs.execute(string.format("open -a Finder %q", path))
    end

    local function openDefaultFinderWindow()
        hs.osascript.applescript([[
tell application "Finder"
    make new Finder window
end tell
]])
    end

    local function arrangeFinderWindows(screen, openMissing)
        local finder = hs.application.get(finderBundleID)
        if not finder then
            hs.application.launchOrFocusByBundleID(finderBundleID)
            finder = hs.application.get(finderBundleID)
        end

        if not finder then return end
        finder:unhide()

        local mainWindow
        local downloadsWindow
        local screenshotsWindow

        for _, win in ipairs(standardWindowsForApp(finder)) do
            local title = win:title()
            if title == finderFolders.downloads.title then
                downloadsWindow = downloadsWindow or win
            elseif title == finderFolders.screenshots.title then
                screenshotsWindow = screenshotsWindow or win
            else
                mainWindow = mainWindow or win
            end
        end

        if openMissing then
            local openedWindow = false
            if not mainWindow then
                openDefaultFinderWindow()
                openedWindow = true
            end
            if not downloadsWindow then
                openFinderFolder(finderFolders.downloads.path)
                openedWindow = true
            end
            if not screenshotsWindow then
                openFinderFolder(finderFolders.screenshots.path)
                openedWindow = true
            end
            if openedWindow then
                hs.timer.doAfter(0.2, function()
                    arrangeFinderWindows(screen, false)
                end)
            end
        end

        moveWindowToScreenUnit(mainWindow, screen, screenUnits.leftHalf)
        moveWindowToScreenUnit(downloadsWindow, screen, screenUnits.topRightQuarter, true)
        moveWindowToScreenUnit(screenshotsWindow, screen, screenUnits.bottomRightQuarter, true)
    end

    local function restoreAllOnScreen()
        local screen = hs.screen.mainScreen()
        restoreWindows(standardWindowsOnScreen(screen))
        arrangeFinderWindows(screen, true)
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
        setWindowFrame(win, x, sf.y, w, sf.h, direction == "right")
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
