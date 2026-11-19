local M = {}

-- macOS's own tiling, driven through the Window menu that AppKit adds to every
-- app. macOS resizes the window in one step, so there is no in-between frame
-- (Calendar maximised from the right half no longer passes through a left
-- tile), and it already knows an app's minimum size, so nothing overflows.
local tiles = {
    full = { "Window", "Fill" },
    leftHalf = { "Window", "Move & Resize", "Left" },
    rightHalf = { "Window", "Move & Resize", "Right" },
    topLeft = { "Window", "Move & Resize", "Top Left" },
    topRight = { "Window", "Move & Resize", "Top Right" },
    bottomLeft = { "Window", "Move & Resize", "Bottom Left" },
    bottomRight = { "Window", "Move & Resize", "Bottom Right" },
}

-- The menu item only acts on the frontmost app, and pressing it is an
-- Accessibility call: against an app that has stopped servicing its event
-- loop it blocks this thread until it times out, which freezes every hotkey,
-- so skip such an app.
local function frontApp()
    local app = hs.application.frontmostApplication()
    if not app then return nil end
    if app.isUnresponsive and app:isUnresponsive() then return nil end
    return app
end

local function activeWindow()
    local win = hs.window.focusedWindow()
    if win then return win end

    -- Some apps (Office especially) briefly report no focused window. Fall back
    -- to the frontmost app only; hs.window.frontmostWindow() would instead
    -- query every window of every running app.
    local app = frontApp()
    return app and app:mainWindow()
end

function M.setup(hyper, alerts)
    local function bind(key, description, order, path)
        hyper:bind({}, key, {
            group = "Windows",
            description = description,
            order = order,
        }, function()
            local app = frontApp()
            if not app then return end

            -- Apps without a standard Window menu (Java, some games) lack it.
            if not app:selectMenuItem(path) then
                alerts.show(app:name() .. " has no " .. path[#path] .. " command")
            end
        end)
    end

    bind("k", "Fullscreen", 10, tiles.full)
    bind("j", "Left half", 20, tiles.leftHalf)
    bind("l", "Right half", 30, tiles.rightHalf)
    bind("[", "Top-left quarter", 60, tiles.topLeft)
    bind("]", "Top-right quarter", 70, tiles.topRight)
    bind("'", "Bottom-left quarter", 80, tiles.bottomLeft)
    bind("\\", "Bottom-right quarter", 90, tiles.bottomRight)

    hyper:bind({}, "h", {
        group = "Windows",
        description = "Move to next display",
        order = 100,
    }, function()
        local win = activeWindow()
        if not win then return end

        -- A window left on a display that has just been unplugged has no
        -- screen, and indexing that nil would throw out of the hotkey callback.
        local screen = win:screen()
        if not screen then return end

        win:moveToScreen(screen:next(), false, true, 0)
        hs.mouse.absolutePosition(win:frame().center)
    end)
end

return M
