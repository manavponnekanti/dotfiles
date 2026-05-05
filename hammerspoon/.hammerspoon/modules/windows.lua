local M = {}

function M.setup(hyper)
    local pinMode = false

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
        for _, win in ipairs(windows) do
            if shouldRestoreToLeftHalf(win) then
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

    hyper:bind({}, "j", function()
        moveWindow(hs.window.focusedWindow(), "left", 0.5)
    end)

    hyper:bind({ "shift" }, "j", function()
        moveWindow(hs.window.focusedWindow(), "left", 2 / 3)
    end)

    hyper:bind({}, "k", function()
        maximizeWindow(hs.window.focusedWindow())
    end)

    hyper:bind({}, "return", function()
        moveWindowVertically(hs.window.focusedWindow(), "top")
    end)

    hyper:bind({ "shift" }, "return", function()
        moveWindowVertically(hs.window.focusedWindow(), "bottom")
    end)

    hyper:bind({}, "l", function()
        moveWindow(hs.window.focusedWindow(), "right", 0.5)
    end)

    hyper:bind({ "shift" }, "l", function()
        moveWindow(hs.window.focusedWindow(), "right", 1 / 3)
    end)

    hyper:bind({}, ";", function()
        if pinMode then
            moveWindowToRightQuarter(hs.window.focusedWindow())
        else
            restoreAllOnScreen()
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

    hyper:bind({}, "h", function()
        local win = hs.window.focusedWindow()
        if not win then return end
        win:moveToScreen(win:screen():next())
        local center = hs.geometry.rectMidPoint(win:frame())
        hs.mouse.absolutePosition(center)
    end)
end

return M
