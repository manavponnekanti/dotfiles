local M = {}
local alerts = nil

local function showAlert(message, ...)
    if alerts then
        return alerts.show(message, ...)
    end
    return hs.alert.show(message, ...)
end

function M.setup(meh, alertModule)
    alerts = alertModule
    local pinMode = false

    local restoreLeftHalfBundleIDs = {
        ["com.apple.MobileSMS"] = true,
        ["ru.keepcoder.Telegram"] = true,
        ["net.whatsapp.WhatsApp"] = true,
    }

    local finderBundleID = "com.apple.finder"

    local function activeWindow()
        return hs.window.focusedWindow() or hs.window.frontmostWindow()
    end

    local function standardWindowsOnScreen(screen)
        local windows = {}
        for _, win in ipairs(hs.window.visibleWindows()) do
            if win:screen() == screen and win:isStandard() then
                table.insert(windows, win)
            end
        end
        return windows
    end

    local function usableWidth(screenFrame)
        return pinMode and math.floor(screenFrame.w * 0.75) or screenFrame.w
    end

    local function setWindowFrame(win, x, w, anchorRightEdge)
        if not win then return end

        local sf = win:screen():frame()
        if anchorRightEdge then
            local rightEdge = math.floor(x + w + 0.5)
            w = math.ceil(w)
            x = rightEdge - w
        else
            x = math.floor(x + 0.5)
            w = math.floor(w + 0.5)
        end

        win:setFrame(hs.geometry.rect(x, sf.y, w, sf.h), 0)

        if anchorRightEdge then
            local actual = win:frame()
            local rightEdge = x + w
            if math.abs((actual.x + actual.w) - rightEdge) > 1 then
                win:setFrame(hs.geometry.rect(rightEdge - actual.w, sf.y, actual.w, sf.h), 0)
            end
        end
    end

    local function setWindowVerticalFrame(win, y, h, anchorBottomEdge)
        if not win then return end

        local f = win:frame()
        win:setFrame(hs.geometry.rect(f.x, y, f.w, h), 0)

        if anchorBottomEdge then
            local actual = win:frame()
            local bottomEdge = y + h
            if math.abs((actual.y + actual.h) - bottomEdge) > 1 then
                win:setFrame(hs.geometry.rect(actual.x, bottomEdge - actual.h, actual.w, actual.h), 0)
            end
        end
    end

    local function moveWindowToRightQuarter(win)
        if not win then return end

        local sf = win:screen():frame()
        setWindowFrame(win, sf.x + (sf.w * 0.75), sf.w * 0.25, true)
    end

    local function moveWindowToLeftHalf(win)
        if not win then return end

        local sf = win:screen():frame()
        setWindowFrame(win, sf.x, sf.w * 0.5)
    end

    local function moveWindowToLeftTwoThirds(win)
        if not win then return end

        local sf = win:screen():frame()
        setWindowFrame(win, sf.x, sf.w * (2 / 3))
    end

    local function moveWindowToRightThird(win)
        if not win then return end

        local sf = win:screen():frame()
        setWindowFrame(win, sf.x + (sf.w * (2 / 3)), sf.w * (1 / 3), true)
    end

    local function isFinderWindow(win)
        local app = win and win:application()
        return app and app:bundleID() == finderBundleID or false
    end

    local function isDownloadsWindow(win)
        return win and win:title() == "Downloads" or false
    end

    local function shouldRestoreToLeftHalf(win)
        local app = win and win:application()
        if not app then return false end

        local bundleID = app:bundleID()
        return bundleID and restoreLeftHalfBundleIDs[bundleID] or false
    end

    local function maximizeWindow(win)
        if not win then return end
        local sf = win:screen():frame()
        setWindowFrame(win, sf.x, usableWidth(sf))
    end

    local function moveWindowVertically(win, side)
        if not win then return end

        local sf = win:screen():frame()
        local topEdge = sf.y

        if side == "bottom" then
            setWindowVerticalFrame(win, topEdge + (sf.h * 0.5), sf.h * 0.5, true)
        else
            setWindowVerticalFrame(win, topEdge, sf.h * 0.5)
        end
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
        local restoredFinderWindows = {}
        local downloadsWindow = nil
        local otherFinderWindow = nil

        for _, win in ipairs(windows) do
            if isFinderWindow(win) then
                if isDownloadsWindow(win) then
                    downloadsWindow = downloadsWindow or win
                else
                    otherFinderWindow = otherFinderWindow or win
                end
            end
        end

        if downloadsWindow and otherFinderWindow then
            moveWindowToLeftTwoThirds(otherFinderWindow)
            moveWindowToRightThird(downloadsWindow)
            restoredFinderWindows[otherFinderWindow] = true
            restoredFinderWindows[downloadsWindow] = true
        end

        for _, win in ipairs(windows) do
            if restoredFinderWindows[win] then
                -- Already positioned as part of the Finder two-window layout.
            elseif shouldRestoreToLeftHalf(win) then
                moveWindowToLeftHalf(win)
            else
                maximizeWindow(win)
            end
        end
    end

    local function restoreAllOnScreen()
        local screen = hs.screen.mainScreen()
        restoreWindows(standardWindowsOnScreen(screen))
    end

    local function moveWindow(win, direction, size)
        if not win then return end
        local sf = win:screen():frame()
        local availW = usableWidth(sf)
        local x = direction == "left" and sf.x or (sf.x + availW * (1 - size))
        local w = availW * size
        setWindowFrame(win, x, w, direction == "right")
    end

    meh:bind({}, "j", function()
        moveWindow(activeWindow(), "left", 0.5)
    end)

    meh:bind({ "cmd" }, "j", function()
        moveWindow(activeWindow(), "left", 2 / 3)
    end)

    meh:bind({}, "k", function()
        maximizeWindow(activeWindow())
    end)

    meh:bind({}, "return", function()
        moveWindowVertically(activeWindow(), "top")
    end)

    meh:bind({ "cmd" }, "return", function()
        moveWindowVertically(activeWindow(), "bottom")
    end)

    meh:bind({}, "l", function()
        moveWindow(activeWindow(), "right", 0.5)
    end)

    meh:bind({ "cmd" }, "l", function()
        moveWindow(activeWindow(), "right", 1 / 3)
    end)

    meh:bind({}, ";", function()
        if pinMode then
            moveWindowToRightQuarter(activeWindow())
        else
            restoreAllOnScreen()
        end
    end)

    meh:bind({}, "u", function()
        pinMode = not pinMode
        showAlert(pinMode and "Pin mode ON" or "Pin mode OFF")
        if pinMode then
            maximizeAllOnScreen()
        else
            restoreAllOnScreen()
        end
    end)

    meh:bind({}, "h", function()
        local win = activeWindow()
        if not win then return end
        win:moveToScreen(win:screen():next())
        local center = hs.geometry.rectMidPoint(win:frame())
        hs.mouse.absolutePosition(center)
    end)
end

return M
