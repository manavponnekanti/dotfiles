local M = {}
local internalGap = 1
local halfInternalGap = internalGap / 2
local unitEpsilon = 1e-9

local function defineTile(x, y, w, h)
    return {
        unit = hs.geometry.rect(x, y, w, h),
        inset = {
            left = x > unitEpsilon and halfInternalGap or 0,
            top = y > unitEpsilon and halfInternalGap or 0,
            right = x + w < 1 - unitEpsilon and halfInternalGap or 0,
            bottom = y + h < 1 - unitEpsilon and halfInternalGap or 0,
        },
    }
end

local tiles = {
    full = defineTile(0, 0, 1, 1),
    leftHalf = defineTile(0, 0, 0.5, 1),
    leftTwoThirds = defineTile(0, 0, 2 / 3, 1),
    rightHalf = defineTile(0.5, 0, 0.5, 1),
    rightThird = defineTile(2 / 3, 0, 1 / 3, 1),
    topLeft = defineTile(0, 0, 0.5, 0.5),
    topRight = defineTile(0.5, 0, 0.5, 0.5),
    bottomLeft = defineTile(0, 0.5, 0.5, 0.5),
    bottomRight = defineTile(0.5, 0.5, 0.5, 0.5),
    mainWithPin = defineTile(0, 0, 0.75, 1),
    pin = defineTile(0.75, 0, 0.25, 1),
}

-- These apps use half the screen during a layout reset; other apps maximize.
local restoreLeftHalfBundleIDs = {
    ["com.apple.MobileSMS"] = true,
    ["ru.keepcoder.Telegram"] = true,
    ["net.whatsapp.WhatsApp"] = true,
    ["com.googlecode.iterm2"] = true,
}

local function activeWindow()
    return hs.window.frontmostWindow()
end

local function isManagedWindow(win)
    if win:isFullScreen() then return false end
    if win:isStandard() then return true end

    -- A few apps expose their main window as AXDialog.
    local app = win:application()
    local mainWindow = app and app:mainWindow()
    return win:role() == "AXWindow"
        and mainWindow
        and win:id()
        and mainWindow:id() == win:id()
        or false
end

local function managedWindowsOnScreen(screen)
    local windows = {}
    for _, win in ipairs(hs.window.allWindows()) do
        if win:screen() == screen and isManagedWindow(win) then
            table.insert(windows, win)
        end
    end
    return windows
end

local function restoreTile(win, pinMode)
    local app = win:application()
    local bundleID = app and app:bundleID()
    if bundleID and restoreLeftHalfBundleIDs[bundleID] then
        return tiles.leftHalf
    end
    return pinMode and tiles.mainWithPin or tiles.full
end

local function mainAreaTile(tileDefinition, pinMode)
    if not pinMode then return tileDefinition end
    local unit = tileDefinition.unit
    return defineTile(unit.x * 0.75, unit.y, unit.w * 0.75, unit.h)
end

local function rounded(value)
    return math.floor(value + 0.5)
end

local function tileFrame(screen, tileDefinition)
    local frame = screen:fromUnitRect(tileDefinition.unit)
    local inset = tileDefinition.inset
    local x1 = rounded(frame.x1) + inset.left
    local y1 = rounded(frame.y1) + inset.top
    local x2 = rounded(frame.x2) - inset.right
    local y2 = rounded(frame.y2) - inset.bottom

    return hs.geometry.rect(x1, y1,
        math.max(1, x2 - x1), math.max(1, y2 - y1))
end

local function tile(win, tileDefinition, screen, frame)
    if not win then return end
    screen = screen or win:screen()

    win:setFrame(frame or tileFrame(screen, tileDefinition), 0)

    -- Top-left-anchored tiles cannot overflow unless an app is wider or taller
    -- than the screen itself, so avoid an unnecessary Accessibility read.
    local unit = tileDefinition.unit
    if unit.x <= unitEpsilon and unit.y <= unitEpsilon then return end

    -- Keep the app's accepted size and correct only its position when a
    -- minimum-size constraint pushes it beyond the target screen.
    local actualFrame = win:frame()
    local containedFrame = hs.geometry.copy(actualFrame):fit(screen:frame())
    if containedFrame.x ~= actualFrame.x or containedFrame.y ~= actualFrame.y then
        win:setTopLeft(containedFrame.topleft)
    end
end

function M.setup(hyper, alertModule)
    local pinMode = false

    local function restoreWindow(win, screen, frames)
        if not win then return end
        local tileDefinition = restoreTile(win, pinMode)
        local frame = tileDefinition == tiles.leftHalf and frames.leftHalf or frames.default
        tile(win, tileDefinition, screen, frame)
    end

    local function restoreScreen(screen, priorityWindow)
        if not screen then return end
        local windows = managedWindowsOnScreen(screen)
        local frames = {
            default = tileFrame(screen, pinMode and tiles.mainWithPin or tiles.full),
            leftHalf = tileFrame(screen, tiles.leftHalf),
        }
        local priorityID = priorityWindow and priorityWindow:id()
        if priorityID then
            for index, win in ipairs(windows) do
                if win:id() == priorityID then
                    windows[1], windows[index] = windows[index], windows[1]
                    break
                end
            end
        end

        for _, win in ipairs(windows) do
            restoreWindow(win, screen, frames)
        end
    end

    local function restoreActiveScreen()
        local win = activeWindow()
        if win then restoreScreen(win:screen(), win) end
    end

    local function bind(modifiers, key, description, order, pressedFn)
        hyper:bind(modifiers, key, {
            group = "Windows",
            description = description,
            order = order,
        }, pressedFn)
    end

    bind({}, "j", "Left half", 10, function()
        tile(activeWindow(), mainAreaTile(tiles.leftHalf, pinMode))
    end)

    bind({ "cmd" }, "j", "Left ⅔", 20, function()
        tile(activeWindow(), mainAreaTile(tiles.leftTwoThirds, pinMode))
    end)

    bind({}, "l", "Right half", 30, function()
        tile(activeWindow(), mainAreaTile(tiles.rightHalf, pinMode))
    end)

    bind({ "cmd" }, "l", "Right ⅓", 40, function()
        tile(activeWindow(), mainAreaTile(tiles.rightThird, pinMode))
    end)

    bind({}, "[", "Top-left quarter", 50, function()
        tile(activeWindow(), mainAreaTile(tiles.topLeft, pinMode))
    end)

    bind({}, "]", "Top-right quarter", 60, function()
        tile(activeWindow(), mainAreaTile(tiles.topRight, pinMode))
    end)

    bind({}, "'", "Bottom-left quarter", 70, function()
        tile(activeWindow(), mainAreaTile(tiles.bottomLeft, pinMode))
    end)

    bind({}, "\\", "Bottom-right quarter", 80, function()
        tile(activeWindow(), mainAreaTile(tiles.bottomRight, pinMode))
    end)

    bind({}, "k", "Maximize window", 90, function()
        local win = activeWindow()
        if not win then return end
        if pinMode then
            tile(win, tiles.mainWithPin)
        else
            win:maximize(0)
        end
    end)

    bind({}, ";", "Restore layout / pin window", 100, function()
        if pinMode then
            tile(activeWindow(), tiles.pin)
        else
            restoreActiveScreen()
        end
    end)

    bind({}, "u", "Toggle pin mode", 110, function()
        local win = activeWindow()
        local screen = win and win:screen() or hs.screen.mainScreen()
        pinMode = not pinMode
        alertModule.show(pinMode and "Pin mode ON" or "Pin mode OFF")
        restoreScreen(screen, win)
    end)

    bind({}, "h", "Move to next display", 120, function()
        local win = activeWindow()
        if not win then return end

        local targetScreen = win:screen():next()
        local tileDefinition = restoreTile(win, pinMode)

        tile(win, tileDefinition, targetScreen)
        hs.mouse.absolutePosition(win:frame().center)
    end)
end

return M
