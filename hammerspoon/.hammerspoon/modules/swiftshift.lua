local M = {}

local gesture = nil
local mouseMoveTap = nil
local updateTimer = nil
local pendingMouse = nil
local minimumWidth = 100
local minimumHeight = 80
local updateWindow = nil

local function pointInFrame(point, frame)
    return point.x >= frame.x
        and point.x < frame.x + frame.w
        and point.y >= frame.y
        and point.y < frame.y + frame.h
end

local function windowUnderMouse(point)
    -- orderedWindows() is front-to-back, so the first matching window is the
    -- visible window the gesture should affect, even when it is not focused.
    for _, win in ipairs(hs.window.orderedWindows()) do
        if not win:isFullScreen() and pointInFrame(point, win:frame()) then
            return win
        end
    end
end

local function disableEnhancedUI(win)
    local app = win:application()
    if not app then return nil end

    local element = hs.axuielement.applicationElement(app)
    if not element then return nil end

    local wasEnabled = element:attributeValue("AXEnhancedUserInterface")
    if wasEnabled == true then
        element:setAttributeValue("AXEnhancedUserInterface", false)
        return element
    end
end

local function restoreEnhancedUI()
    if gesture and gesture.enhancedUIElement then
        gesture.enhancedUIElement:setAttributeValue(
            "AXEnhancedUserInterface", true)
        gesture.enhancedUIElement = nil
    end
end

local function stopGesture()
    if gesture and pendingMouse and updateWindow then
        updateWindow(pendingMouse)
    end
    restoreEnhancedUI()
    gesture = nil
    pendingMouse = nil
    if mouseMoveTap then
        mouseMoveTap:stop()
    end
    if updateTimer then
        updateTimer:stop()
    end
end

updateWindow = function(mouse)
    if not gesture then return end

    local dx = mouse.x - gesture.mouse.x
    local dy = mouse.y - gesture.mouse.y
    local frame = gesture.frame:copy()

    if gesture.mode == "resize" then
        frame.w = math.max(minimumWidth, frame.w + dx)
        frame.h = math.max(minimumHeight, frame.h + dy)
        -- Only the bottom/right edges change, so avoid the heavier full-frame
        -- accessibility write. Some apps become laggy when both position and
        -- size are redundantly set for every update.
        gesture.window:setSize(hs.geometry.size(frame.w, frame.h))
    else
        frame.x = frame.x + dx
        frame.y = frame.y + dy
        gesture.window:setTopLeft(hs.geometry.point(frame.x, frame.y))
    end
end

local function updateMode(shiftDown)
    if not gesture then return end

    local mode = shiftDown and "resize" or "move"
    if mode == gesture.mode then return end

    -- Start the new mode from the current geometry and pointer position so the
    -- window never jumps when Shift is pressed or released mid-gesture.
    gesture.frame = gesture.window:frame()
    gesture.mouse = hs.mouse.absolutePosition()
    gesture.mode = mode
end

local function startGesture()
    stopGesture()

    local mouse = hs.mouse.absolutePosition()
    local win = windowUnderMouse(mouse)
    if not win then return end

    gesture = {
        window = win,
        frame = win:frame(),
        mouse = mouse,
        mode = hs.eventtap.checkKeyboardModifiers().shift and "resize" or "move",
        -- Chromium/Electron apps can make AX geometry writes laggy while this
        -- accessibility mode is enabled. Restore it exactly as it was when the
        -- gesture ends; native apps normally leave it disabled and are untouched.
        enhancedUIElement = disableEnhancedUI(win),
    }

    mouseMoveTap:start()
    updateTimer:start()
end

function M.setup(hyper)
    mouseMoveTap = hs.eventtap.new({
        hs.eventtap.event.types.mouseMoved,
        hs.eventtap.event.types.flagsChanged,
    }, function(event)
        if event:getType() == hs.eventtap.event.types.flagsChanged then
            updateMode(event:getFlags().shift or false)
        else
            -- F19 and Shift pressed nearly simultaneously can arrive in either
            -- order. Resolve the mode from each motion event before applying
            -- its delta, so the actual Shift state wins without a race.
            updateMode(event:getFlags().shift or false)
            -- Keep the event-tap callback cheap so a slow accessibility client
            -- cannot make macOS disable it and strand F19 in the down state.
            pendingMouse = event:location()
        end
        return false
    end)

    updateTimer = hs.timer.new(1 / 60, function()
        if not pendingMouse then return end

        local mouse = pendingMouse
        pendingMouse = nil
        updateWindow(mouse)
    end)

    hyper:setF19GestureHandlers({
        pressed = startGesture,
        released = stopGesture,
        cancel = stopGesture,
    })
end

return M
