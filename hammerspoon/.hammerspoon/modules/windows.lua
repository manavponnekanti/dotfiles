local M = {}

function M.setup(hyper, alerts)
    local function bind(modifiers, key, description, order, action)
        hyper:bind(modifiers, key, {
            group = "Windows",
            description = description,
            order = order,
        }, action)
    end

    -- Hammerspoon moves the window itself (animated over animationDuration).
    local function withWindow(fn)
        return function()
            local win = hs.window.focusedWindow()
            if win then fn(win) end
        end
    end

    -- macOS's own tiling, through the Window menu AppKit gives every app.
    local function native(modifiers, key, description, order, path)
        bind(modifiers, key, description, order, function()
            local app = hs.application.frontmostApplication()
            if app and not app:selectMenuItem(path) then
                alerts.show(app:name() .. " has no " .. path[#path] .. " command")
            end
        end)
    end

    local function unit(modifiers, key, description, order, x, y, w, h)
        bind(modifiers, key, description, order, withWindow(function(win)
            win:moveToUnit({ x, y, w, h })
        end))
    end

    local function moveResize(item) return { "Window", "Move & Resize", item } end

    native({}, "k", "Fullscreen", 10, { "Window", "Fill" })
    native({}, "j", "Left half", 20, moveResize("Left"))
    native({}, "l", "Right half", 30, moveResize("Right"))
    unit({ "cmd" }, "j", "Left ⅔", 40, 0, 0, 2 / 3, 1)
    unit({ "cmd" }, "l", "Right ⅓", 50, 2 / 3, 0, 1 / 3, 1)
    native({}, "[", "Top-left quarter", 60, moveResize("Top Left"))
    native({}, "]", "Top-right quarter", 70, moveResize("Top Right"))
    native({}, "'", "Bottom-left quarter", 80, moveResize("Bottom Left"))
    native({}, "\\", "Bottom-right quarter", 90, moveResize("Bottom Right"))

    bind({}, "h", "Move to next display", 100, withWindow(function(win)
        win:moveToScreen(win:screen():next())
        hs.mouse.absolutePosition(win:frame().center)
    end))
end

return M
