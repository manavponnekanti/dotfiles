hs.window.animationDuration = 0

-- ============================================================
-- Hyper Modal (F19 as modifier)
-- ============================================================
local hyper = hs.hotkey.modal.new()

local hyperActive = false

hs.hotkey.bind({}, "f19",
    function() hyperActive = true;  hyper:enter() end,
    function() hyperActive = false; hyper:exit()  end
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
local appBindings = {
    ["\\"] = "com.apple.Passwords",
    a = "com.googlecode.iterm2",
    b = "net.imput.helium",
    c = "com.apple.iCal",
    d = "com.hnc.Discord",
    e = "com.apple.FaceTime",
    f = "com.apple.finder",
    g = "com.openai.chat",
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

local function toggleApp(bundleID)
    local app = hs.application.get(bundleID)
    if app and app:isFrontmost() then
        app:hide()
    else
        hs.application.launchOrFocusByBundleID(bundleID)
    end
end

for key, bundleID in pairs(appBindings) do
    hyper:bind({}, key, function() toggleApp(bundleID) end)
end

-- ============================================================
-- Bluetooth Audio Toggle
-- ============================================================
local blueutil = "/opt/homebrew/bin/blueutil"
local btInFlight = {}

local function toggleBluetooth(mac, name)
    if btInFlight[mac] then
        hs.notify.show("Hammerspoon", "", name .. " already in progress")
        return
    end
    local connected = hs.execute(blueutil .. " --is-connected " .. mac):gsub("%s+", "") == "1"
    local action = connected and "--disconnect" or "--connect"
    hs.notify.show("Hammerspoon", "", name .. (connected and " disconnecting..." or " connecting..."))
    btInFlight[mac] = true
    local timer
    local task = hs.task.new(blueutil, function(exitCode)
        btInFlight[mac] = nil
        if not timer then return end
        timer:stop(); timer = nil
        hs.notify.show("Hammerspoon", "", exitCode == 0
            and (name .. (connected and " disconnected" or " connected"))
            or (name .. " error"))
    end, {action, mac})
    task:start()
    timer = hs.timer.doAfter(10, function()
        btInFlight[mac] = nil
        task:terminate()
        hs.notify.show("Hammerspoon", "", name .. " not found")
        timer = nil
    end)
end

hyper:bind({}, "1", function() toggleBluetooth("a0-a3-09-16-cc-1f", "AirPods") end)
hyper:bind({}, "2", function() toggleBluetooth("ac-80-0a-7a-c0-98", "XM5") end)

-- ============================================================
-- Window Management
-- ============================================================
local sizes = { left = {0.5, 2/3}, right = {0.5, 1/3} }

local function moveWindow(direction)
    local win = hs.window.focusedWindow()
    if not win then return end

    local f = win:frame()
    local sf = win:screen():frame()
    local curX = (f.x - sf.x) / sf.w
    local curW = f.w / sf.w
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
    local x = direction == "left" and sf.x or sf.x + sf.w * (1 - size)
    local w = sf.w * size
    win:setFrame(hs.geometry.rect(x, sf.y, w, sf.h))
end

hyper:bind({}, "j", function() moveWindow("left") end)

hyper:bind({}, "k", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local sf = win:screen():frame()
    win:setFrame(sf)
end)

hyper:bind({}, "l", function() moveWindow("right") end)

hyper:bind({}, ";", function()
    for _, win in ipairs(hs.window.allWindows()) do
        local sf = win:screen():frame()
        win:setFrame(sf)
    end
end)

hyper:bind({}, "h", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    win:moveToScreen(win:screen():next())
    local center = hs.geometry.rectMidPoint(win:frame())
    hs.mouse.absolutePosition(center)
end)

-- ============================================================
-- Auto-reload (ReloadConfiguration spoon)
-- ============================================================
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration.watch_paths = {hs.configdir}
spoon.ReloadConfiguration:start()

hs.notify.show("Hammerspoon", "", "Hammerspoon config loaded")

