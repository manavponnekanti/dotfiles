local M = {}

local settingsKey = "flowmodoro.state"
local breakSoundName = "Glass"

local alerts = nil
local ui = nil
local palette = nil
local paletteVisible = false
local paletteHotkeys = {}
local paletteRefreshTimer = nil
local breakTimer = nil
local lastNotification = nil
local blockedAppWatcher = nil
local lastBlockedAppNotification = nil
local paletteElements = nil

local blockedAppBundleIDs = {
    ["com.apple.MobileSMS"] = true,
    ["net.whatsapp.WhatsApp"] = true,
    ["org.telegram.desktop"] = true,
    ["ph.telegra.Telegraph"] = true,
    ["ru.keepcoder.Telegram"] = true,
}

local blockedAppNames = {
    messages = true,
    telegram = true,
    whatsapp = true,
}

local paletteWidth = 420
local paletteHeight = 236

local function now()
    return os.time()
end

local function idleState()
    return {
        phase = "idle",
        accumulatedSeconds = 0,
    }
end

local function saveState(state)
    hs.settings.set(settingsKey, state)
end

local function loadState()
    local state = hs.settings.get(settingsKey)
    if type(state) ~= "table" then
        return idleState()
    end

    if state.phase == "running" then
        if type(state.startedAt) ~= "number" then
            return idleState()
        end
        state.accumulatedSeconds = math.max(0, tonumber(state.accumulatedSeconds) or 0)
        return state
    end

    if state.phase == "paused" then
        state.accumulatedSeconds = math.max(0, tonumber(state.accumulatedSeconds) or 0)
        return state
    end

    if state.phase == "break" and type(state.breakEndsAt) == "number" then
        return state
    end

    return idleState()
end

local function show(message)
    if alerts then
        alerts.show(message)
    else
        hs.alert.show(message)
    end
end

local function blockedAppDisplayName(application)
    local name = application:name() or "This app"
    return name:gsub("%.app$", "")
end

local function isBlockedApp(application)
    local bundleID = application:bundleID()
    if bundleID and blockedAppBundleIDs[bundleID] then
        return true
    end

    return blockedAppNames[blockedAppDisplayName(application):lower()] == true
end

local function blockApplicationDuringWork(application)
    if not application or loadState().phase ~= "running" or not isBlockedApp(application) then
        return false
    end

    local appName = blockedAppDisplayName(application)
    application:hide()

    lastBlockedAppNotification = hs.notify.new({
        title = "Flowmodoro",
        informativeText = appName .. " is blocked during work.",
    })
    lastBlockedAppNotification:send()
    return true
end

local function hidePalette()
    if paletteRefreshTimer then
        paletteRefreshTimer:stop()
        paletteRefreshTimer = nil
    end

    for _, hotkey in ipairs(paletteHotkeys) do
        hotkey:disable()
    end

    if palette then
        palette:hide()
    end
    paletteVisible = false
end

local function showPalette()
    hidePalette()

    local screenFrame = hs.mouse.getCurrentScreen():frame()
    palette:frame({
        x = screenFrame.x + ((screenFrame.w - paletteWidth) / 2),
        y = screenFrame.y + ((screenFrame.h - paletteHeight) / 2),
        w = paletteWidth,
        h = paletteHeight,
    })

    palette:replaceElements(paletteElements())
    palette:show()
    paletteVisible = true
    paletteRefreshTimer = hs.timer.doEvery(1, function()
        if paletteVisible then
            palette:replaceElements(paletteElements())
        end
    end)
    for _, hotkey in ipairs(paletteHotkeys) do
        hotkey:enable()
    end
end

local function togglePalette()
    if paletteVisible then
        hidePalette()
    else
        showPalette()
    end
end

local function cancelBreakTimer()
    if breakTimer then
        breakTimer:stop()
        breakTimer = nil
    end
end

local function notifyBreakComplete()
    lastNotification = hs.notify.new({
        title = "Flowmodoro",
        informativeText = "Break complete — ready for the next focus session.",
    })
    lastNotification:send()

    local sound = hs.sound.getByName(breakSoundName)
    if sound then
        sound:play()
    end
end

local function completeBreakIfDue()
    local state = loadState()
    if state.phase ~= "break" then
        cancelBreakTimer()
        return
    end

    local remaining = state.breakEndsAt - now()
    if remaining > 0 then
        cancelBreakTimer()
        breakTimer = hs.timer.doAfter(remaining, completeBreakIfDue)
        return
    end

    cancelBreakTimer()
    saveState(idleState())
    notifyBreakComplete()
end

local function restoreBreakTimer()
    local state = loadState()
    if state.phase ~= "break" then
        cancelBreakTimer()
        return
    end

    completeBreakIfDue()
end

local function elapsedSeconds(state, timestamp)
    local elapsed = math.max(0, tonumber(state.accumulatedSeconds) or 0)
    if state.phase == "running" then
        elapsed = elapsed + math.max(0, timestamp - state.startedAt)
    end
    return elapsed
end

local function formatDuration(seconds)
    local totalSeconds = math.max(0, math.floor(seconds + 0.5))
    local minutes = math.floor(totalSeconds / 60)
    local remainder = totalSeconds % 60
    return string.format("%d:%02d", minutes, remainder)
end

paletteElements = function()
    local timestamp = now()
    local state = loadState()
    local phase = state.phase
    local displayTime = "0:00"
    local statusColor = ui.colors.muted

    if phase == "running" then
        displayTime = formatDuration(elapsedSeconds(state, timestamp))
        statusColor = ui.colors.success
    elseif phase == "paused" then
        displayTime = formatDuration(state.accumulatedSeconds)
    elseif phase == "break" then
        displayTime = formatDuration(math.max(0, state.breakEndsAt - timestamp))
    end

    local elements = {
        {
            type = "rectangle",
            frame = { x = 0, y = 0, w = paletteWidth, h = paletteHeight },
            action = "fill",
            fillColor = ui.colors.surface,
            roundedRectRadii = { xRadius = ui.radius, yRadius = ui.radius },
        },
        {
            type = "text",
            frame = { x = ui.outerPadding, y = 14, w = 250, h = 30 },
            text = "Flowmodoro",
            textColor = ui.colors.primary,
            textFont = ui.font,
            textSize = ui.sizes.title,
        },
        {
            type = "text",
            frame = { x = 270, y = 17, w = paletteWidth - 270 - ui.outerPadding, h = 22 },
            text = phase:upper(),
            textAlignment = "right",
            textColor = statusColor,
            textFont = ui.font,
            textSize = ui.sizes.section,
        },
        {
            type = "rectangle",
            frame = {
                x = ui.outerPadding,
                y = 44,
                w = paletteWidth - ui.outerPadding * 2,
                h = 1,
            },
            action = "fill",
            fillColor = ui.colors.divider,
        },
        {
            type = "text",
            frame = { x = ui.outerPadding, y = 57, w = paletteWidth - ui.outerPadding * 2, h = 46 },
            text = displayTime,
            textAlignment = "center",
            textColor = ui.colors.secondary,
            textFont = ui.font,
            textSize = 36,
        },
    }

    local rows = {
        { "j", "Start / Resume", 116 },
        { "k", "Pause", 144 },
        { "l", "Break", 172 },
        { ";", "Reset", 200 },
    }

    local textStyle = { font = ui.font, size = ui.sizes.body }
    local hintWidth = 0
    local captionWidth = 0
    for _, row in ipairs(rows) do
        hintWidth = math.max(hintWidth,
            math.ceil(hs.drawing.getTextDrawingSize(ui.hint(row[1]), textStyle).w))
        captionWidth = math.max(captionWidth,
            math.ceil(hs.drawing.getTextDrawingSize(row[2], textStyle).w))
    end

    local columnGap = 12
    local listWidth = hintWidth + columnGap + captionWidth
    local listX = math.floor((paletteWidth - listWidth) / 2)
    local captionX = listX + hintWidth + columnGap

    for _, row in ipairs(rows) do
        table.insert(elements, {
            type = "text",
            frame = { x = listX, y = row[3], w = hintWidth, h = 24 },
            text = ui.hint(row[1]),
            textAlignment = "right",
            textColor = ui.colors.muted,
            textFont = ui.font,
            textSize = ui.sizes.body,
        })
        table.insert(elements, {
            type = "text",
            frame = { x = captionX, y = row[3], w = captionWidth, h = 24 },
            text = row[2],
            textColor = ui.colors.secondary,
            textFont = ui.font,
            textSize = ui.sizes.body,
        })
    end

    return elements
end

local function startStopwatch()
    local timestamp = now()
    local state = loadState()

    if state.phase == "running" then
        show("Flowmodoro already running • " .. formatDuration(elapsedSeconds(state, timestamp)))
        return
    end

    if state.phase == "break" then
        cancelBreakTimer()
        state = idleState()
    end

    local accumulated = state.phase == "paused" and state.accumulatedSeconds or 0
    saveState({
        phase = "running",
        accumulatedSeconds = accumulated,
        startedAt = timestamp,
    })

    blockApplicationDuringWork(hs.application.frontmostApplication())

    show(accumulated > 0 and "Flowmodoro resumed" or "Flowmodoro started")
end

local function pauseStopwatch()
    local timestamp = now()
    local state = loadState()

    if state.phase ~= "running" then
        show(state.phase == "paused" and "Flowmodoro already paused" or "Flowmodoro is not running")
        return
    end

    local elapsed = elapsedSeconds(state, timestamp)
    saveState({
        phase = "paused",
        accumulatedSeconds = elapsed,
    })
    show("Flowmodoro paused • " .. formatDuration(elapsed))
end

local function stopStopwatch()
    local timestamp = now()
    local state = loadState()

    if state.phase ~= "running" and state.phase ~= "paused" then
        show(state.phase == "break" and "Flowmodoro break already active" or "Flowmodoro stopped • no work time")
        return
    end

    local elapsed = elapsedSeconds(state, timestamp)
    local breakMinutes = math.floor((elapsed / 300) + 0.5)

    cancelBreakTimer()
    if breakMinutes < 1 then
        saveState(idleState())
        show("Flowmodoro stopped • " .. formatDuration(elapsed) .. " • no break")
        return
    end

    saveState({
        phase = "break",
        breakEndsAt = timestamp + (breakMinutes * 60),
    })
    restoreBreakTimer()
    show(string.format("Flowmodoro stopped • %s • %d min break", formatDuration(elapsed), breakMinutes))
end

local function resetFlowmodoro()
    cancelBreakTimer()
    saveState(idleState())
    show("Flowmodoro reset")
end

function M.setup(hyper, alertModule, uiModule)
    alerts = alertModule
    ui = uiModule

    blockedAppWatcher = hs.application.watcher.new(function(_, eventType, application)
        if eventType == hs.application.watcher.activated then
            blockApplicationDuringWork(application)
        end
    end)
    blockedAppWatcher:start()

    palette = hs.canvas.new({ x = 0, y = 0, w = paletteWidth, h = paletteHeight })
        :level("floating")

    -- Reserve 2 from dynamic app assignment and toggle the visual palette.
    hyper:bind({}, "2", {
        group = "Focus",
        description = "Flowmodoro controls",
    }, togglePalette)

    local function paletteAction(key, action)
        table.insert(paletteHotkeys, hs.hotkey.new({}, key, function()
            if not paletteVisible then return end
            hidePalette()
            action()
        end))
    end
    paletteAction("j", startStopwatch)
    paletteAction("k", pauseStopwatch)
    paletteAction("l", stopStopwatch)
    paletteAction(";", resetFlowmodoro)
    table.insert(paletteHotkeys, hs.hotkey.new({}, "escape", function()
        if paletteVisible then hidePalette() end
    end))

    restoreBreakTimer()
    blockApplicationDuringWork(hs.application.frontmostApplication())

    -- Expose a small console API for inspection without leaking internal state.
    M.toggle = togglePalette
    M.dismiss = hidePalette
    M.isVisible = function() return paletteVisible end
    M.canvasInfo = function()
        return {
            alpha = palette:alpha(),
            elements = #palette,
            frame = palette:frame(),
            occluded = palette:isOccluded(),
            visible = palette:isVisible(),
        }
    end
    hs.flowmodoro = M
end

return M
