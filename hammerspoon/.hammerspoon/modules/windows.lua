local M = {}

-- One pixel between neighbouring tiles so adjacent window edges stay visible.
-- Taken off the right/bottom edge only, which keeps every frame integral.
local gap = 1

-- Fractions of the screen's usable frame: x, y, width, height.
local tiles = {
    full = { 0, 0, 1, 1 },
    leftHalf = { 0, 0, 1 / 2, 1 },
    rightHalf = { 1 / 2, 0, 1 / 2, 1 },
    leftTwoThirds = { 0, 0, 2 / 3, 1 },
    rightThird = { 2 / 3, 0, 1 / 3, 1 },
    topLeft = { 0, 0, 1 / 2, 1 / 2 },
    topRight = { 1 / 2, 0, 1 / 2, 1 / 2 },
    bottomLeft = { 0, 1 / 2, 1 / 2, 1 / 2 },
    bottomRight = { 1 / 2, 1 / 2, 1 / 2, 1 / 2 },
}

local function activeWindow()
    local win = hs.window.focusedWindow()
    if win then return win end

    -- Some apps (Office especially) briefly report no focused window. Fall back
    -- to the frontmost app only; hs.window.frontmostWindow() would instead
    -- query every window of every running app.
    local app = hs.application.frontmostApplication()
    if not app then return nil end

    -- app:mainWindow() is an Accessibility read (AXMainWindow). Against an app
    -- that has stopped servicing its event loop it blocks this thread until it
    -- times out, which freezes every hotkey, so skip it in that case.
    if app.isUnresponsive and app:isUnresponsive() then return nil end

    return app:mainWindow()
end

local function rounded(value)
    return math.floor(value + 0.5)
end

-- Resize the focused window only; nothing here touches any other window.
local function tile(unit)
    local win = activeWindow()
    if not win then return end

    -- A window left on a display that has just been unplugged has no screen,
    -- and indexing that nil would throw out of the hotkey callback.
    local screen = win:screen()
    if not screen then return end

    local frame = screen:frame()
    local x1 = rounded(frame.x + frame.w * unit[1])
    local y1 = rounded(frame.y + frame.h * unit[2])
    local x2 = rounded(frame.x + frame.w * (unit[1] + unit[3]))
    local y2 = rounded(frame.y + frame.h * (unit[2] + unit[4]))

    -- Only inset edges that sit inside the screen; screen edges stay flush.
    if x2 < frame.x + frame.w then x2 = x2 - gap end
    if y2 < frame.y + frame.h then y2 = y2 - gap end

    -- Position, then size: two Accessibility writes. win:setFrame() writes the
    -- size on both sides of the move, and the app lays out and redraws after
    -- every write, so Calendar took three times as long and Electron apps
    -- flashed at the new size in the old place before moving.
    win:setTopLeft({ x = x1, y = y1 })
    win:setSize({ w = x2 - x1, h = y2 - y1 })

    -- An app may refuse a size below its minimum (Calendar is wider than half a
    -- laptop screen), leaving a right or bottom tile hanging off the screen.
    -- Slide it back on at the size the app accepted. A top-left-anchored tile
    -- can only overflow if the app is bigger than the screen, so skip the read.
    if unit[1] == 0 and unit[2] == 0 then return end

    local size = win:size()
    local x = math.max(frame.x, math.min(x1, frame.x + frame.w - size.w))
    local y = math.max(frame.y, math.min(y1, frame.y + frame.h - size.h))
    if x ~= x1 or y ~= y1 then win:setTopLeft({ x = x, y = y }) end
end

function M.setup(hyper)
    local function bind(modifiers, key, description, order, unit)
        hyper:bind(modifiers, key, {
            group = "Windows",
            description = description,
            order = order,
        }, function()
            tile(unit)
        end)
    end

    bind({}, "k", "Fullscreen", 10, tiles.full)
    bind({}, "j", "Left half", 20, tiles.leftHalf)
    bind({}, "l", "Right half", 30, tiles.rightHalf)
    bind({ "cmd" }, "j", "Left ⅔", 40, tiles.leftTwoThirds)
    bind({ "cmd" }, "l", "Right ⅓", 50, tiles.rightThird)
    bind({}, "[", "Top-left quarter", 60, tiles.topLeft)
    bind({}, "]", "Top-right quarter", 70, tiles.topRight)
    bind({}, "'", "Bottom-left quarter", 80, tiles.bottomLeft)
    bind({}, "\\", "Bottom-right quarter", 90, tiles.bottomRight)

    hyper:bind({}, "h", {
        group = "Windows",
        description = "Move to next display",
        order = 100,
    }, function()
        local win = activeWindow()
        if not win then return end

        local screen = win:screen()
        if not screen then return end

        win:moveToScreen(screen:next(), false, true, 0)
        hs.mouse.absolutePosition(win:frame().center)
    end)
end

return M
