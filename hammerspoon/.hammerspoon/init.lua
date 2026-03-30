hs.window.animationDuration = 0

hs.alert.defaultStyle.strokeWidth = 0
hs.alert.defaultStyle.fillColor = { white = 0, alpha = 0.45 }
hs.alert.defaultStyle.strokeColor = { white = 1, alpha = 0 }
hs.alert.defaultStyle.textColor = { white = 1, alpha = 0.9 }
hs.alert.defaultStyle.textSize = 18
hs.alert.defaultStyle.radius = 12
hs.alert.defaultStyle.padding = 10
hs.alert.defaultStyle.atScreenEdge = 2
hs.alert.defaultStyle.fadeInDuration = 0.08
hs.alert.defaultStyle.fadeOutDuration = 0.12

local originalAlertShow = hs.alert.show
local currentAlertId = nil

hs.alert.show = function(...)
    if currentAlertId then
        hs.alert.closeSpecific(currentAlertId, 0)
        currentAlertId = nil
    end

    currentAlertId = originalAlertShow(...)
    return currentAlertId
end

-- ============================================================
-- Hyper Modal (F19 as modifier)
-- ============================================================
local hyper = hs.hotkey.modal.new()

hs.hotkey.bind({}, "f19",
    function() hyper:enter() end,
    function() hyper:exit()  end
)

local caffeinateWatcher = hs.caffeinate.watcher.new(function(event)
    if event == hs.caffeinate.watcher.systemDidWake
       or event == hs.caffeinate.watcher.screensDidUnlock then
        hyper:exit()
    end
end)
caffeinateWatcher:start()

-- ============================================================
-- App Launcher/Switcher/Toggler
-- ============================================================
local defaultBindings = {
    ["\\"] = "com.apple.Passwords",
    a = "com.googlecode.iterm2",
    b = "net.imput.helium",
    c = "com.apple.iCal",
    d = "com.hnc.Discord",
    e = "com.apple.FaceTime",
    f = "com.apple.finder",
    g = "com.anthropic.claudefordesktop",
    i = "com.apple.MobileSMS",
    m = "com.apple.mail",
    n = "net.shinyfrog.bear",
    o = "md.obsidian",
    p = "com.apple.Preview",
    q = "net.ankiweb.launcher",
    r = "com.apple.reminders",
    s = "com.apple.systempreferences",
    t = "ru.keepcoder.Telegram",
    v = "com.microsoft.VSCode",
    w = "net.whatsapp.WhatsApp",
    x = "com.microsoft.Excel",
    y = "com.spotify.client",
}

local overrides = hs.settings.get("appBindingOverrides") or {}
local appBindings = {}
for k, v in pairs(defaultBindings) do appBindings[k] = v end
for k, v in pairs(overrides) do appBindings[k] = v end

local function focusApp(bundleID)
    hs.application.launchOrFocusByBundleID(bundleID)
end

local assignableKeys = {"a","b","c","d","e","f","g","i","m","n","o","p",
                        "q","r","s","t","v","w","x","y","z","\\"}

local assignMode = false

for _, key in ipairs(assignableKeys) do
    hyper:bind({}, key, function()
        if assignMode then
            assignMode = false
            local app = hs.application.frontmostApplication()
            if not app then return end
            local bundleID = app:bundleID()
            local name = app:name()
            appBindings[key] = bundleID
            overrides[key] = bundleID
            hs.settings.set("appBindingOverrides", overrides)
            hs.alert.show("F19+" .. key .. " → " .. name)
        elseif appBindings[key] then
            focusApp(appBindings[key])
        end
    end)
end

hyper:bind({}, "`", function()
    assignMode = not assignMode
    hs.alert.show(assignMode and "Assign mode: press a key" or "Assign mode off")
end)

-- ============================================================
-- Bluetooth Audio Toggle
-- ============================================================
local blueutil = "/opt/homebrew/bin/blueutil"
local btBusy = false

local function toggleBluetooth(mac, name)
    if btBusy then return end
    local connected = hs.execute(blueutil .. " --is-connected " .. mac):gsub("%s+", "") == "1"
    local action = connected and "--disconnect" or "--connect"
    hs.alert.show(name .. (connected and " disconnecting..." or " connecting..."))
    btBusy = true
    local timeout
    local task = hs.task.new(blueutil, function(exitCode)
        btBusy = false
        if not timeout then return end
        timeout:stop(); timeout = nil
        hs.alert.show(exitCode == 0
            and (name .. (connected and " disconnected" or " connected"))
            or (name .. " error"))
    end, {action, mac})
    task:start()
    timeout = hs.timer.doAfter(10, function()
        btBusy = false
        task:terminate()
        hs.alert.show(name .. " not found")
        timeout = nil
    end)
end

hyper:bind({}, "1", function() toggleBluetooth("ac-80-0a-7a-c0-98", "XM5") end)

-- ============================================================
-- 25-Minute Countdown Timer (F19 + 2)
-- ============================================================
local countdownCanvas = nil
local countdownTimer = nil
local countdownRemaining = 0

local function stopCountdown()
    if countdownTimer then countdownTimer:stop(); countdownTimer = nil end
    if countdownCanvas then countdownCanvas:delete(); countdownCanvas = nil end
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

    countdownCanvas = hs.canvas.new({x = sf.x + sf.w - w - 10, y = sf.y + 10, w = w, h = h})
    countdownCanvas:level(hs.canvas.windowLevels.floating)
    countdownCanvas:appendElements(
        { type = "rectangle", fillColor = {white = 0, alpha = 0.45}, roundedRectRadii = {xRadius = 8, yRadius = 8} },
        { type = "text", text = "25:00", textColor = {white = 1}, textSize = 20,
          textAlignment = "center", frame = {x = 0, y = "20%", w = "100%", h = "80%"} }
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

-- ============================================================
-- Window Management
-- ============================================================
local tileMargin = 8
local tileGap = 8
local tileWidths = { left = {0.5, 2/3}, right = {0.5, 1/3} }
local tileRepeatTimeout = 1.2
local lastTileAction = {
    direction = nil,
    index = 0,
    windowId = nil,
    timer = nil,
}

local function focusedWindow()
    local win = hs.window.focusedWindow()
    if win and win:isStandard() then
        return win
    end
end

local function insetFrame(frame)
    return hs.geometry.rect(
        frame.x + tileMargin,
        frame.y + tileMargin,
        math.max(frame.w - (tileMargin * 2), 1),
        math.max(frame.h - (tileMargin * 2), 1)
    )
end

local function tiledFrame(screenFrame, direction, size)
    local innerOffset = tileGap / 2
    local x = screenFrame.x + tileMargin

    if direction == "right" then
        x = screenFrame.x + screenFrame.w * (1 - size) + innerOffset
    end

    return hs.geometry.rect(
        x,
        screenFrame.y + tileMargin,
        math.max(screenFrame.w * size - tileMargin - innerOffset, 1),
        math.max(screenFrame.h - (tileMargin * 2), 1)
    )
end

local function tileFocusedWindow(frame, anchorRight)
    local win = focusedWindow()
    if not win then return end

    win:setFrame(frame)

    if anchorRight then
        local actual = win:frame()
        if actual.w > frame.w + 1 then
            win:setFrame(hs.geometry.rect(
                frame.x + frame.w - actual.w,
                frame.y,
                actual.w,
                frame.h
            ))
        end
    end
end

local function clearTileRepeat()
    if lastTileAction.timer then
        lastTileAction.timer:stop()
    end

    lastTileAction.direction = nil
    lastTileAction.index = 0
    lastTileAction.windowId = nil
    lastTileAction.timer = nil
end

local function refreshTileRepeat(direction, index, windowId)
    if lastTileAction.timer then
        lastTileAction.timer:stop()
    end

    lastTileAction.direction = direction
    lastTileAction.index = index
    lastTileAction.windowId = windowId
    lastTileAction.timer = hs.timer.doAfter(tileRepeatTimeout, clearTileRepeat)
end

local function moveWindow(direction)
    local win = focusedWindow()
    if not win then return end

    local screen = win:screen()
    local sf = screen:frame()
    local sizeList = tileWidths[direction]
    local windowId = win:id()
    local nextIdx = 1

    if windowId
        and lastTileAction.direction == direction
        and lastTileAction.windowId == windowId then
        nextIdx = (lastTileAction.index % #sizeList) + 1
    end

    tileFocusedWindow(tiledFrame(sf, direction, sizeList[nextIdx]), direction == "right")
    refreshTileRepeat(direction, nextIdx, windowId)
end

local function maximizeWindow()
    local win = focusedWindow()
    if not win then return end

    clearTileRepeat()
    tileFocusedWindow(insetFrame(win:screen():frame()), false)
end

hyper:bind({}, "j", function() moveWindow("left") end)

hyper:bind({}, "k", maximizeWindow)

hyper:bind({}, "l", function() moveWindow("right") end)

hyper:bind({}, "h", function()
    local win = hs.window.focusedWindow()
    if not win then return end

    clearTileRepeat()
    win:moveToScreen(win:screen():next())
    local center = hs.geometry.rectMidPoint(win:frame())
    hs.mouse.absolutePosition(center)
end)

-- ============================================================
-- Reload config (Cmd+Shift+R)
-- ============================================================
hs.hotkey.bind({"cmd", "shift"}, "r", hs.reload)

hs.alert.show("Config loaded")
