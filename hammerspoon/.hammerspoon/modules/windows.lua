local M = {}
local alerts = nil

local function showAlert(message, ...)
    if alerts then
        return alerts.show(message, ...)
    end
    return hs.alert.show(message, ...)
end

function M.setup(meh, alertModule, appModule)
    alerts = alertModule
    local pinMode = false

    -- These apps use half the screen during a full reset; other apps maximize.
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
        -- Pin mode only rearranges windows that are currently visible.
        local windows = {}
        for _, win in ipairs(hs.window.visibleWindows()) do
            if win:screen() == screen and win:isStandard() then
                table.insert(windows, win)
            end
        end
        return windows
    end

    local function standardRestorableWindows()
        -- allWindows includes hidden and minimized windows. Reset their geometry
        -- without changing whether their application is hidden.
        local windows = {}
        for _, win in ipairs(hs.window.allWindows()) do
            if win:isStandard() and not win:isFullScreen() then
                table.insert(windows, win)
            end
        end
        return windows
    end

    local function largestScreen()
        -- A reset consolidates every restorable window onto the display with most area.
        local largest = hs.screen.mainScreen()
        local largestFrame = largest:frame()
        local largestArea = largestFrame.w * largestFrame.h

        for _, screen in ipairs(hs.screen.allScreens()) do
            local frame = screen:frame()
            local area = frame.w * frame.h
            if area > largestArea then
                largest = screen
                largestArea = area
            end
        end

        return largest
    end

    local function usableWidth(screenFrame)
        -- Pin mode reserves the rightmost quarter of the screen.
        return pinMode and math.floor(screenFrame.w * 0.75) or screenFrame.w
    end

    local function setWindowFrame(win, x, w, anchorRightEdge, screen)
        if not win then return end

        -- Pixel rounding avoids gaps. Some apps enforce minimum widths, so a
        -- corrective pass preserves the requested right edge when necessary.
        local sf = (screen or win:screen()):frame()
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

    local function moveWindowToLeftHalf(win, screen)
        if not win then return end

        screen = screen or win:screen()
        local sf = screen:frame()
        setWindowFrame(win, sf.x, sf.w * 0.5, false, screen)
    end

    local function moveWindowToLeftTwoThirds(win, screen)
        if not win then return end

        screen = screen or win:screen()
        local sf = screen:frame()
        setWindowFrame(win, sf.x, sf.w * (2 / 3), false, screen)
    end

    local function moveWindowToRightThird(win, screen)
        if not win then return end

        screen = screen or win:screen()
        local sf = screen:frame()
        setWindowFrame(win, sf.x + (sf.w * (2 / 3)), sf.w * (1 / 3), true, screen)
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

    local function maximizeWindow(win, screen)
        if not win then return end
        screen = screen or win:screen()
        local sf = screen:frame()
        setWindowFrame(win, sf.x, usableWidth(sf), false, screen)
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

    local function restoreWindows(windows, screen)
        -- Finder gets a special two-window layout when both a Downloads window
        -- and another Finder window are already open. Reset never creates either.
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
            moveWindowToLeftTwoThirds(otherFinderWindow, screen)
            moveWindowToRightThird(downloadsWindow, screen)
            restoredFinderWindows[otherFinderWindow] = true
            restoredFinderWindows[downloadsWindow] = true
        end

        for _, win in ipairs(windows) do
            if restoredFinderWindows[win] then
                -- Already positioned as part of the Finder two-window layout.
            elseif shouldRestoreToLeftHalf(win) then
                moveWindowToLeftHalf(win, screen)
            else
                maximizeWindow(win, screen)
            end
        end
    end

    local function restoreAllOnScreen()
        local screen = largestScreen()
        local windows = standardRestorableWindows()

        -- Moving screens and resizing immediately can race macOS, hence the
        -- short one-shot delay before applying final frames.
        for _, win in ipairs(windows) do
            if win:screen() ~= screen then
                win:moveToScreen(screen, false, true, 0)
            end
        end

        hs.timer.doAfter(0.1, function()
            restoreWindows(windows, screen)
        end)
    end

    local screenCount = #hs.screen.allScreens()
    local restoreTimer = nil

    -- Screen notifications can arrive in bursts while docking. Debounce them and
    -- reset only when the number of connected displays actually changes.
    M.screenWatcher = hs.screen.watcher.new(function()
        local newScreenCount = #hs.screen.allScreens()
        if newScreenCount == screenCount then return end

        screenCount = newScreenCount

        if restoreTimer then
            restoreTimer:stop()
        end

        restoreTimer = hs.timer.doAfter(0.5, function()
            restoreTimer = nil
            restoreAllOnScreen()
        end)
    end):start()

    local function moveWindow(win, direction, size, screen)
        if not win then return end
        screen = screen or win:screen()
        local sf = screen:frame()
        local availW = usableWidth(sf)
        local x = direction == "left" and sf.x or (sf.x + availW * (1 - size))
        local w = availW * size
        setWindowFrame(win, x, w, direction == "right", screen)
    end

    local pairing = nil
    local chooser
    -- App icons are immutable enough to cache until the next Hammerspoon reload.
    -- false is cached too, preventing repeated lookups for missing icons.
    local appIconCache = {}

    local function appIcon(bundleID)
        local cached = appIconCache[bundleID]
        if cached ~= nil then
            return cached or nil
        end

        local image = hs.image.imageFromAppBundle(bundleID)
        appIconCache[bundleID] = image or false
        return image
    end

    local function dismissChooser()
        pairing = nil
        if chooser and chooser:isVisible() then
            chooser:hide()
        end
    end

    local function chooseOppositeApp(bundleID)
        local currentPairing = pairing
        if not currentPairing or not bundleID then return false end

        dismissChooser()

        -- Stack every standard window from the selected app in the opposite tile.
        -- Excluding sourceID allows two windows of the same app to sit side by side.
        local tiledWindows = {}
        for _, app in ipairs(hs.application.applicationsForBundleID(bundleID)) do
            app:unhide()

            for _, win in ipairs(app:allWindows()) do
                if win:isStandard() and win:id() ~= currentPairing.sourceID then
                    moveWindow(win, currentPairing.oppositeDirection,
                        currentPairing.oppositeSize, currentPairing.screen)
                    table.insert(tiledWindows, win)
                end
            end
        end

        if #tiledWindows == 0 then
            showAlert("No matching windows")
            return false
        end

        tiledWindows[1]:focus()
        return true
    end

    chooser = hs.chooser.new(function(choice)
        if not choice then
            if not chooser:isVisible() then
                pairing = nil
            end
            return
        end

        if not chooseOppositeApp(choice.bundleID) then
            pairing = nil
        end
    end)
        :searchSubText(true)

    local function applicationChoices()
        -- Enumerate inexpensive application records rather than every window.
        -- kind() == 1 limits the chooser to ordinary Dock applications.
        local choices = {}
        local seenBundleIDs = {}

        for _, app in ipairs(hs.application.runningApplications()) do
            local bundleID = app:bundleID()
            local name = app:name()
            if app:kind() == 1 and bundleID and name and not seenBundleIDs[bundleID] then
                seenBundleIDs[bundleID] = true
                table.insert(choices, {
                    text = name,
                    subText = bundleID,
                    image = appIcon(bundleID),
                    bundleID = bundleID,
                })
            end
        end

        table.sort(choices, function(a, b)
            return a.text:lower() < b.text:lower()
        end)
        return choices
    end

    local function showOppositeChooser(source, direction, size, command)
        pairing = {
            command = command,
            sourceID = source:id(),
            screen = source:screen(),
            oppositeDirection = direction == "left" and "right" or "left",
            oppositeSize = 1 - size,
        }

        local leftPercent = math.floor((direction == "left" and size or (1 - size)) * 100 + 0.5)
        local rightPercent = 100 - leftPercent
        chooser
            :placeholderText(string.format("Choose the opposite app (%d/%d)", leftPercent, rightPercent))
            :query("")
            :choices(applicationChoices())
            :show()
    end

    local function tileAndChoose(direction, size, command)
        -- Repeating the active tiling command is a toggle that closes the chooser.
        if pairing and chooser:isVisible() and pairing.command == command then
            dismissChooser()
            return
        end

        local source = pairing and hs.window.get(pairing.sourceID) or activeWindow()
        dismissChooser()
        if not source then return end

        moveWindow(source, direction, size)
        showOppositeChooser(source, direction, size, command)
    end

    if appModule then
        -- While choosing, Meh+<app key> selects that app instead of toggling it.
        appModule.setShortcutHandler(function(_, bundleID)
            if not pairing or not chooser:isVisible() then return false end
            if not bundleID then return true end

            chooseOppositeApp(bundleID)
            return true
        end)
    end

    -- Horizontal tiling commands open the complementary-app chooser.
    meh:bind({}, "j", function()
        tileAndChoose("left", 0.5, "left-half")
    end)

    meh:bind({ "cmd" }, "j", function()
        tileAndChoose("left", 0.7, "left-70")
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
        tileAndChoose("right", 0.5, "right-half")
    end)

    meh:bind({ "cmd" }, "l", function()
        tileAndChoose("right", 0.3, "right-30")
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
        local targetScreen = win:screen():next()
        local windowID = win:id()

        win:moveToScreen(targetScreen, false, true, 0)

        hs.timer.doAfter(0.1, function()
            local movedWindow = hs.window.get(windowID)
            if not movedWindow then return end

            maximizeWindow(movedWindow, targetScreen)
            local center = hs.geometry.rectMidPoint(movedWindow:frame())
            hs.mouse.absolutePosition(center)
        end)
    end)
end

return M
