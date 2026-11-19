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

-- How far a frame sticks out past the screen's edges, summed over all four.
local function overflow(x, y, w, h, frame)
    return math.max(0, frame.x - x) + math.max(0, x + w - (frame.x + frame.w))
        + math.max(0, frame.y - y) + math.max(0, y + h - (frame.y + frame.h))
end

-- The nearest top-left to (x, y) that keeps a window of this size on screen.
local function onScreen(x, y, size, frame)
    return math.max(frame.x, math.min(x, frame.x + frame.w - size.w)),
        math.max(frame.y, math.min(y, frame.y + frame.h - size.h))
end

-- Resize the focused window only; nothing here touches any other window.
local function tile(unit)
    local win = activeWindow()
    if not win then return end

    -- win:screen() reads the frame to find the screen; read it once here and
    -- reuse it. A window left on a display that has just been unplugged has no
    -- screen, and indexing that nil would throw out of the hotkey callback.
    local current = win:frame()
    local screen = hs.screen.find(current)
    if not screen then return end

    local frame = screen:frame()
    local x1 = rounded(frame.x + frame.w * unit[1])
    local y1 = rounded(frame.y + frame.h * unit[2])
    local x2 = rounded(frame.x + frame.w * (unit[1] + unit[3]))
    local y2 = rounded(frame.y + frame.h * (unit[2] + unit[4]))

    -- Only inset edges that sit inside the screen; screen edges stay flush.
    if x2 < frame.x + frame.w then x2 = x2 - gap end
    if y2 < frame.y + frame.h then y2 = y2 - gap end

    local w, h = x2 - x1, y2 - y1

    -- One size write and one position write, never win:setFrame(): it writes
    -- the size on both sides of the move, and the app lays out and redraws
    -- after every write, so Calendar took twice as long. As in Rectangle,
    -- resize first when moving at the old size would leave the window hanging
    -- off screen. Unlike Rectangle, only when the new size fits where the
    -- window already is: macOS squeezes a resize that runs past the screen
    -- edge, and undoing that costs a second resize. Otherwise move first,
    -- which also avoids the in-place redraw that flashes in Electron apps.
    local resizes = current.w ~= w or current.h ~= h
    local sizeFirst = resizes
        and overflow(current.x, current.y, w, h, frame) <= 1
        and overflow(x1, y1, current.w, current.h, frame) > 1

    -- An app may refuse a size below its minimum (Calendar is wider than half a
    -- laptop screen). Resizing first reads back the size it accepted, so the
    -- window is placed once, already on screen.
    if sizeFirst then
        win:setSize({ w = w, h = h })
        local x, y = onScreen(x1, y1, win:size(), frame)
        win:setTopLeft({ x = x, y = y })
        return
    end

    if current.x ~= x1 or current.y ~= y1 then win:setTopLeft({ x = x1, y = y1 }) end
    if resizes then win:setSize({ w = w, h = h }) end

    -- Moving first can still leave a refused size hanging off a right or bottom
    -- edge; slide it back on. A top-left-anchored tile can only overflow if the
    -- app is bigger than the screen, so skip the read.
    if unit[1] == 0 and unit[2] == 0 then return end

    local x, y = onScreen(x1, y1, win:size(), frame)
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
