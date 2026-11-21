local M = {}

function M.setup(hyper)
    local function bind(modifiers, key, description, order, action)
        hyper:bind(modifiers, key, {
            group = "Windows",
            description = description,
            order = order,
        }, function()
            local win = hs.window.focusedWindow()
            if win then action(win) end
        end)
    end

    local function tile(modifiers, key, description, order, x, y, w, h)
        bind(modifiers, key, description, order, function(win)
            win:moveToUnit({ x, y, w, h })
        end)
    end

    tile({}, "k", "Fullscreen", 10, 0, 0, 1, 1)
    tile({}, "j", "Left half", 20, 0, 0, 1 / 2, 1)
    tile({}, "l", "Right half", 30, 1 / 2, 0, 1 / 2, 1)
    tile({ "cmd" }, "j", "Left ⅔", 40, 0, 0, 2 / 3, 1)
    tile({ "cmd" }, "l", "Right ⅓", 50, 2 / 3, 0, 1 / 3, 1)
    tile({}, "[", "Top-left quarter", 60, 0, 0, 1 / 2, 1 / 2)
    tile({}, "]", "Top-right quarter", 70, 1 / 2, 0, 1 / 2, 1 / 2)
    tile({}, "'", "Bottom-left quarter", 80, 0, 1 / 2, 1 / 2, 1 / 2)
    tile({}, "\\", "Bottom-right quarter", 90, 1 / 2, 1 / 2, 1 / 2, 1 / 2)

    bind({}, "h", "Move to next display", 100, function(win)
        win:moveToScreen(win:screen():next())
        hs.mouse.absolutePosition(win:frame().center)
    end)
end

return M
