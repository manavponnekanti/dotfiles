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

local function toggleApp(bundleID)
     local app = hs.application.get(bundleID)
     if app and app:isFrontmost() then
         app:hide()
     else
        hs.application.launchOrFocusByBundleID(bundleID)
     end
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
            toggleApp(appBindings[key])
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
local pinMode = false
local gutterWidth = 400

local sizes = { left = {0.5, 2/3}, right = {0.5, 1/3} }

local function maximizeAllOnScreen()
    local screen = hs.screen.mainScreen()
    local sf = screen:frame()
    local maxW = pinMode and (sf.w - gutterWidth) or sf.w
    for _, win in ipairs(hs.window.allWindows()) do
        if win:screen() == screen and win:isVisible() and win:isStandard() then
            win:setFrame(hs.geometry.rect(sf.x, sf.y, maxW, sf.h))
        end
    end
end

local function moveWindow(direction)
    local win = hs.window.focusedWindow()
    if not win then return end

    local f = win:frame()
    local sf = win:screen():frame()
    local availW = pinMode and (sf.w - gutterWidth) or sf.w
    local curX = (f.x - sf.x) / availW
    local curW = f.w / availW
    local tol = 0.05

    local sizeList = sizes[direction]
    local nextIdx = 1
    for i, size in ipairs(sizeList) do
        local expX = direction == "left" and 0 or (1 - size)
        if math.abs(curW - size) < tol and math.abs(curX - expX) < tol then
            nextIdx = (i % #sizeList) + 1
            break
        end
    end

    local size = sizeList[nextIdx]
    local x = direction == "left" and sf.x or (sf.x + availW * (1 - size))
    local w = availW * size
    win:setFrame(hs.geometry.rect(x, sf.y, w, sf.h))

    -- if the app enforced a minimum width, re-anchor flush to the right edge
    if direction == "right" then
        local actual = win:frame()
        if actual.w > w + 1 then
            win:setFrame(hs.geometry.rect(sf.x + availW - actual.w, sf.y, actual.w, sf.h))
        end
    end
end

hyper:bind({}, "j", function() moveWindow("left") end)

hyper:bind({}, "k", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local sf = win:screen():frame()
    local maxW = pinMode and (sf.w - gutterWidth) or sf.w
    win:setFrame(hs.geometry.rect(sf.x, sf.y, maxW, sf.h))
end)

hyper:bind({}, "l", function() moveWindow("right") end)

hyper:bind({}, ";", function() maximizeAllOnScreen() end)

local function positionGutterWindows()
    local screen = hs.screen.mainScreen()
    local sf = screen:frame()
    local gutterX = sf.x + sf.w - gutterWidth

    local remindersApp = hs.application.get("com.apple.reminders")
    local remindersWin = remindersApp and remindersApp:mainWindow()
    if remindersWin then
        remindersWin:setFrame(hs.geometry.rect(gutterX, sf.y + sf.h / 2, gutterWidth, sf.h / 2))
    end

    local ftApp = hs.application.get("com.apple.FaceTime")
    local ftWin = ftApp and ftApp:mainWindow()
    if ftWin then
        ftWin:setTopLeft(hs.geometry.point(gutterX, sf.y))
    end
end

hyper:bind({}, "u", function()
    pinMode = not pinMode
    hs.alert.show(pinMode and "Pin mode ON" or "Pin mode OFF")
    maximizeAllOnScreen()
    if pinMode then positionGutterWindows() end
end)

hyper:bind({}, "h", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    win:moveToScreen(win:screen():next())
    local center = hs.geometry.rectMidPoint(win:frame())
    hs.mouse.absolutePosition(center)
end)

-- ============================================================
-- Reload config (Cmd+Shift+R)
-- ============================================================
hs.hotkey.bind({"cmd", "shift"}, "r", hs.reload)

hs.alert.show("Config loaded")
