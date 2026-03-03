hs.window.animationDuration = 0

hs.alert.defaultStyle.fillColor   = { white = 0, alpha = 0.5 }
hs.alert.defaultStyle.strokeColor = { white = 0, alpha = 0 }
hs.alert.defaultStyle.strokeWidth = 0
hs.alert.defaultStyle.textSize    = 14
hs.alert.defaultStyle.radius      = 8
hs.alert.defaultStyle.atScreenEdge = 1
hs.alert.defaultStyle.fadeInDuration  = 0.1
hs.alert.defaultStyle.fadeOutDuration = 0.1

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
local btInFlight = {}

local function toggleBluetooth(mac, name)
    if btInFlight[mac] then
        hs.alert.show(name .. " already in progress")
        return
    end
    local connected = hs.execute(blueutil .. " --is-connected " .. mac):gsub("%s+", "") == "1"
    local action = connected and "--disconnect" or "--connect"
    hs.alert.show(name .. (connected and " disconnecting..." or " connecting..."))
    btInFlight[mac] = true
    local timer
    local task = hs.task.new(blueutil, function(exitCode)
        btInFlight[mac] = nil
        if not timer then return end
        timer:stop(); timer = nil
        hs.alert.show(exitCode == 0
            and (name .. (connected and " disconnected" or " connected"))
            or (name .. " error"))
    end, {action, mac})
    task:start()
    timer = hs.timer.doAfter(10, function()
        btInFlight[mac] = nil
        task:terminate()
        hs.alert.show(name .. " not found")
        timer = nil
    end)
end

hyper:bind({}, "1", function() toggleBluetooth("a0-a3-09-16-cc-1f", "AirPods") end)
hyper:bind({}, "2", function() toggleBluetooth("ac-80-0a-7a-c0-98", "XM5") end)

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

hyper:bind({}, "u", function()
    pinMode = not pinMode
    hs.alert.show(pinMode and "Pin mode ON" or "Pin mode OFF")
    maximizeAllOnScreen()
end)

hyper:bind({}, "h", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    win:moveToScreen(win:screen():next())
    local center = hs.geometry.rectMidPoint(win:frame())
    hs.mouse.absolutePosition(center)
end)

-- ============================================================
-- TextEdit: Shift+Enter → [ ]
-- ============================================================
local textEditShiftEnter = hs.hotkey.new({"shift"}, "return", function()
    hs.eventtap.keyStrokes("\n[ ] ")
end)

local function handleAppChange(appName, eventType, app)
    if eventType == hs.application.watcher.activated then
        if app and app:bundleID() == "com.apple.TextEdit" then
            textEditShiftEnter:enable()
        else
            textEditShiftEnter:disable()
        end
    end
end

local textEditWatcher = hs.application.watcher.new(handleAppChange)
textEditWatcher:start()

-- ============================================================
-- Auto-reload (ReloadConfiguration spoon)
-- ============================================================
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration.watch_paths = {hs.configdir}
spoon.ReloadConfiguration:start()

hs.alert.show("Hammerspoon config loaded")

