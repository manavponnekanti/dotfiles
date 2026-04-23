local M = {}

function M.setup(hyper)
    local countdownCanvas = nil
    local countdownTimer = nil
    local countdownRemaining = 0

    local function stopCountdown()
        if countdownTimer then
            countdownTimer:stop()
            countdownTimer = nil
        end
        if countdownCanvas then
            countdownCanvas:delete()
            countdownCanvas = nil
        end
    end

    local function updateCountdown()
        countdownRemaining = countdownRemaining - 1
        if countdownRemaining <= 0 then
            stopCountdown()
            hs.alert.show("Block finished! 🧱🎉")
            return
        end
        if countdownCanvas then
            countdownCanvas:elementAttribute(2, "text",
                string.format("%d:%02d", countdownRemaining // 60, countdownRemaining % 60))
        end
    end

    local function startCountdown()
        local screen = hs.screen.mainScreen()
        local sf = screen:frame()
        local w, h = 120, 40
        countdownRemaining = 25 * 60

        countdownCanvas = hs.canvas.new({ x = sf.x + sf.w - w - 10, y = sf.y + 10, w = w, h = h })
        countdownCanvas:level(hs.canvas.windowLevels.floating)
        countdownCanvas:appendElements(
            { type = "rectangle", fillColor = { white = 0, alpha = 0.45 }, roundedRectRadii = { xRadius = 8, yRadius = 8 } },
            {
                type = "text",
                text = "25:00",
                textColor = { white = 1 },
                textSize = 20,
                textAlignment = "center",
                frame = { x = 0, y = "20%", w = "100%", h = "80%" }
            }
        )
        countdownCanvas:show()
        countdownTimer = hs.timer.doEvery(1, updateCountdown)
    end

    hyper:bind({}, "2", function()
        if countdownTimer then
            stopCountdown()
            hs.alert.show("Womp Womp: timer cancelled")
        else
            startCountdown()
        end
    end)
end

return M
