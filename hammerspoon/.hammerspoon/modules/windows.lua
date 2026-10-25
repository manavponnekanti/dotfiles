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
    return app and app:mainWindow() or nil
end

local function rounded(value)
    return math.floor(value + 0.5)
end

-- Resize the focused window only. Nothing here reads or moves any other window,
-- so each shortcut costs a single Accessibility write.
local function tile(unit)
    local win = activeWindow()
    if not win then return end

    local frame = win:screen():frame()
    local x1 = rounded(frame.x + frame.w * unit[1])
    local y1 = rounded(frame.y + frame.h * unit[2])
    local x2 = rounded(frame.x + frame.w * (unit[1] + unit[3]))
    local y2 = rounded(frame.y + frame.h * (unit[2] + unit[4]))

    -- Only inset edges that sit inside the screen; screen edges stay flush.
    if x2 < frame.x + frame.w then x2 = x2 - gap end
    if y2 < frame.y + frame.h then y2 = y2 - gap end

    win:setFrame(hs.geometry.rect(x1, y1, x2 - x1, y2 - y1), 0)

    -- Top-left-anchored tiles cannot overflow unless an app is wider or taller
    -- than the screen itself, so avoid an unnecessary Accessibility read.
    if unit[1] == 0 and unit[2] == 0 then return end

    -- Keep the app's accepted size and correct only its position when a
    -- minimum-size constraint pushes it beyond the target screen.
    local actual = win:frame()
    local contained = hs.geometry.copy(actual):fit(frame)
    if contained.x ~= actual.x or contained.y ~= actual.y then
        win:setTopLeft(contained.topleft)
    end
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

        win:moveToScreen(win:screen():next(), false, true, 0)
        hs.mouse.absolutePosition(win:frame().center)
    end)
end

return M
