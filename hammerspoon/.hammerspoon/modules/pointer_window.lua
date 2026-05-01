local M = {}

local dragTap = nil

function M.setup(hyper)
    local active = false
    local targetWindow = nil
    local startMouse = nil
    local startFrame = nil
    local mode = nil
    local minWidth = 120
    local minHeight = 80
    local eventTypes = hs.eventtap.event.types

    local function pointInFrame(point, frame)
        return point.x >= frame.x
            and point.x <= frame.x + frame.w
            and point.y >= frame.y
            and point.y <= frame.y + frame.h
    end

    local function windowAtPoint(point)
        for _, win in ipairs(hs.window.orderedWindows()) do
            if win:isStandard() and pointInFrame(point, win:frame()) then
                return win
            end
        end
        return nil
    end

    local function currentMode()
        local modifiers = hs.eventtap.checkKeyboardModifiers()
        return modifiers.shift and "resize" or "move"
    end

    local function resetStartState(nextMode)
        mode = nextMode
        startMouse = hs.mouse.absolutePosition()
        startFrame = targetWindow and targetWindow:frame() or nil
    end

    local function stop()
        active = false
        targetWindow = nil
        startMouse = nil
        startFrame = nil
        mode = nil

        if dragTap then
            dragTap:stop()
        end
    end

    local function setTargetFrame(frame)
        local ok, err = pcall(function()
            targetWindow:setFrame(frame, 0)
        end)

        if not ok then
            print(err)
            stop()
        end
    end

    local function updateWindow()
        if not active or not targetWindow then return end

        local nextMode = currentMode()
        if nextMode ~= mode then
            resetStartState(nextMode)
        end

        if not startMouse or not startFrame then return end

        local mouse = hs.mouse.absolutePosition()
        local dx = mouse.x - startMouse.x
        local dy = mouse.y - startMouse.y

        if mode == "resize" then
            setTargetFrame(hs.geometry.rect(
                startFrame.x,
                startFrame.y,
                math.max(minWidth, startFrame.w + dx),
                math.max(minHeight, startFrame.h + dy)
            ))
        else
            setTargetFrame(hs.geometry.rect(
                startFrame.x + dx,
                startFrame.y + dy,
                startFrame.w,
                startFrame.h
            ))
        end
    end

    local function start()
        local mouse = hs.mouse.absolutePosition()
        targetWindow = windowAtPoint(mouse)
        if not targetWindow then return end

        active = true
        resetStartState(currentMode())

        if not dragTap then
            dragTap = hs.eventtap.new({ eventTypes.mouseMoved, eventTypes.flagsChanged }, function(event)
                if event:getType() == eventTypes.mouseMoved then
                    updateWindow()
                elseif active then
                    resetStartState(currentMode())
                end

                return false
            end)
        end

        dragTap:start()
    end

    hyper:onPressed(start)
    hyper:onReleased(stop)
end

return M
