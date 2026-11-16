local M = {}

local settingsKey = "flowmodoro.state"
local shortcutName = "Flowmodoro-hs"
local minimumSessionSeconds = 10 * 60
-- application:kill() is a polite quit request, which an app sitting on a save
-- or confirm sheet can ignore indefinitely. Escalate after this long so a
-- blocked app cannot quietly stay open for the rest of the session.
local killEscalationSeconds = 5
-- shortcuts(1) has no timeout of its own; cap it so a stuck run cannot leak
-- its input file and its shortcutTasks entry.
local shortcutTimeout = 30

local alerts = nil
local ui = nil
local palette = nil
local paletteModal = nil
local paletteVisible = false
local paletteRefreshTimer = nil
local textMeasurer = nil
local blockedAppWatcher = nil
local lastBlockedAppNotification = nil
local notifiedBlockedAppPIDs = {}
local pendingKills = {}
local paletteElements = nil
local shortcutTasks = {}

local blockedAppBundleIDs = {
    ["com.apple.MobileSMS"] = true,
    ["net.whatsapp.WhatsApp"] = true,
    ["org.telegram.desktop"] = true,
    ["ph.telegra.Telegraph"] = true,
    ["ru.keepcoder.Telegram"] = true,
    ["com.automattic.beeper.desktop"] = true,
}

local blockedAppNames = {
    messages = true,
    telegram = true,
    whatsapp = true,
}

local paletteWidth = 340
local paletteHeight = 165

local function now()
    return os.time()
end

local function idleState()
    return {
        phase = "idle",
    }
end

-- State is persisted to hs.settings but read from memory: the palette polls it
-- every second and the app watcher checks it on every app switch.
local cachedState = nil

local function saveState(state)
    cachedState = state
    hs.settings.set(settingsKey, state)
end

local function readPersistedState()
    local state = hs.settings.get(settingsKey)
    if type(state) ~= "table" then
        return idleState()
    end

    if state.phase == "running" then
        if type(state.startedAt) ~= "number" then
            return idleState()
        end
        return {
            phase = "running",
            startedAt = state.startedAt,
        }
    end

    return idleState()
end

local function loadState()
    if not cachedState then
        cachedState = readPersistedState()
    end
    return cachedState
end

local function show(message)
    if alerts then
        alerts.show(message)
    else
        hs.alert.show(message)
    end
end

local function runShortcutWithInput(name, input, silent)
    local inputPath = os.tmpname()
    local inputFile, fileError = io.open(inputPath, "w")
    if not inputFile then
        if not silent then
            show("Flowmodoro could not run " .. name .. " • " .. tostring(fileError))
        end
        return false
    end
    inputFile:write(input)
    inputFile:close()

    local task
    local watchdog

    -- Runs once, from whichever gets there first: the task's own exit or the
    -- watchdog below. The shortcutTasks entry doubles as the guard.
    local function finish()
        if watchdog then
            watchdog:stop()
            watchdog = nil
        end
        shortcutTasks[task] = nil
        os.remove(inputPath)
    end

    task = hs.task.new("/usr/bin/shortcuts", function(exitCode, _, stderr)
        if not shortcutTasks[task] then return end
        finish()
        if exitCode ~= 0 and not silent then
            local detail = tostring(stderr or ""):gsub("%s+$", "")
            show("Flowmodoro could not run " .. name .. " • "
                .. (detail ~= "" and detail or "unknown Shortcuts error"))
        end
    end, { "run", name, "--input-path", inputPath })

    if not task then
        os.remove(inputPath)
        if not silent then
            show("Flowmodoro could not start " .. name)
        end
        return false
    end

    shortcutTasks[task] = true
    if not task:start() then
        finish()
        if not silent then
            show("Flowmodoro could not start " .. name)
        end
        return false
    end

    watchdog = hs.timer.doAfter(shortcutTimeout, function()
        if not shortcutTasks[task] then return end
        finish()
        task:terminate()
        if not silent then
            show("Flowmodoro gave up waiting for " .. name)
        end
    end)
    return true
end

local function sendCommand(command, silent)
    runShortcutWithInput(shortcutName, tostring(command), silent)
end

local function toggleBackgroundSounds()
    sendCommand("bs", true)
end

local function switchBackgroundSound()
    sendCommand("change", true)
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

-- A graceful quit can hang on a confirm sheet, leaving the app open for the
-- rest of the session. Check back and force it — but only while the session is
-- still running, since a stop in the meantime means the app may live.
local function escalateKill(pid)
    if not pid or pendingKills[pid] then return end

    pendingKills[pid] = hs.timer.doAfter(killEscalationSeconds, function()
        pendingKills[pid] = nil
        if loadState().phase ~= "running" then return end

        -- Re-check what holds the pid: the graceful quit may have completed
        -- and the number been reused, and -9 on an unrelated app is worse than
        -- a blocked app staying open.
        local survivor = hs.application.applicationForPID(pid)
        if survivor and isBlockedApp(survivor) then survivor:kill9() end
    end)
end

local function blockApplicationDuringWork(application)
    if not application or loadState().phase ~= "running" or not isBlockedApp(application) then
        return false
    end

    local appName = blockedAppDisplayName(application)
    local pid = application:pid()
    application:kill()
    escalateKill(pid)

    if not pid or not notifiedBlockedAppPIDs[pid] then
        if pid then notifiedBlockedAppPIDs[pid] = true end
        lastBlockedAppNotification = hs.notify.new({
            title = "Flowmodoro",
            informativeText = appName .. " was closed during work.",
        })
        lastBlockedAppNotification:send()
    end
    return true
end

local function terminateRunningBlockedApps()
    for _, application in ipairs(hs.application.runningApplications()) do
        blockApplicationDuringWork(application)
    end
end

local function startBlockedAppWatcher()
    if blockedAppWatcher then
        blockedAppWatcher:start()
        terminateRunningBlockedApps()
    end
end

local function stopBlockedAppWatcher()
    if blockedAppWatcher then
        blockedAppWatcher:stop()
    end

    for pid, pending in pairs(pendingKills) do
        pending:stop()
        pendingKills[pid] = nil
    end
end

local function hidePalette()
    if paletteRefreshTimer then
        paletteRefreshTimer:stop()
        paletteRefreshTimer = nil
    end

    if palette then
        palette:hide()
    end
    paletteVisible = false
end

local function showPalette()
    hidePalette()

    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    if not screen then return end
    local screenFrame = screen:frame()
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
end

local function togglePalette()
    if paletteVisible then
        paletteModal:exit()
    else
        paletteModal:enter()
    end
end

local function elapsedSeconds(state, timestamp)
    return math.max(0, timestamp - state.startedAt)
end

local function formatDuration(seconds)
    local totalSeconds = math.max(0, math.floor(seconds + 0.5))
    local minutes = math.floor(totalSeconds / 60)
    local remainder = totalSeconds % 60
    return string.format("%d:%02d", minutes, remainder)
end

-- The row labels never change, so measure them once instead of every second.
local cachedRowLayout = nil
local function paletteRowLayout()
    if cachedRowLayout then return cachedRowLayout end

    local rows = {
        { "j", "Start / Stop", 73 },
        { "b", "Toggle Background Sounds", 101 },
        { "s", "Switch Background Sound", 129 },
    }

    local hintWidth = 0
    local captionWidth = 0
    for _, row in ipairs(rows) do
        hintWidth = math.max(hintWidth,
            math.ceil(textMeasurer:minimumTextSize(ui.hint(row[1])).w))
        captionWidth = math.max(captionWidth,
            math.ceil(textMeasurer:minimumTextSize(row[2]).w))
    end

    local columnGap = 12
    local listWidth = hintWidth + columnGap + captionWidth
    local listX = math.floor((paletteWidth - listWidth) / 2)

    cachedRowLayout = {
        rows = rows,
        hintWidth = hintWidth,
        captionWidth = captionWidth,
        listX = listX,
        captionX = listX + hintWidth + columnGap,
    }
    return cachedRowLayout
end

paletteElements = function()
    local timestamp = now()
    local state = loadState()
    local phase = state.phase
    local displayTime = "0:00"

    if phase == "running" then
        displayTime = formatDuration(elapsedSeconds(state, timestamp))
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
            frame = { x = ui.outerPadding, y = 14, w = paletteWidth - ui.outerPadding * 2, h = 46 },
            text = displayTime,
            textAlignment = "center",
            textColor = ui.colors.secondary,
            textFont = ui.font,
            textSize = 36,
        },
    }

    local layout = paletteRowLayout()
    local rows = layout.rows
    local hintWidth = layout.hintWidth
    local captionWidth = layout.captionWidth
    local listX = layout.listX
    local captionX = layout.captionX

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

local function toggleStopwatch()
    local timestamp = now()
    local state = loadState()

    if state.phase ~= "running" then
        saveState({
            phase = "running",
            startedAt = timestamp,
        })

        startBlockedAppWatcher()
        sendCommand("start")
        show("Flowmodoro started")
        return
    end

    local elapsed = elapsedSeconds(state, timestamp)
    stopBlockedAppWatcher()
    saveState(idleState())

    if elapsed < minimumSessionSeconds then
        sendCommand(0)
        show("Flowmodoro discarded • " .. formatDuration(elapsed)
            .. " • must reach " .. formatDuration(minimumSessionSeconds))
        return
    end

    local focusedSeconds = math.floor(elapsed + 0.5)
    local breakSeconds = focusedSeconds / 5
    sendCommand(focusedSeconds)
    show(string.format("Flowmodoro stopped • %s • %s break",
        formatDuration(elapsed), formatDuration(breakSeconds)))
end

function M.setup(hyper, alertModule, uiModule)
    alerts = alertModule
    ui = uiModule

    blockedAppWatcher = hs.application.watcher.new(function(_, eventType, application)
        if eventType == hs.application.watcher.launched
            or eventType == hs.application.watcher.activated then
            blockApplicationDuringWork(application)
        elseif eventType == hs.application.watcher.terminated and application then
            local pid = application:pid()
            if pid then
                notifiedBlockedAppPIDs[pid] = nil
                local pending = pendingKills[pid]
                if pending then
                    pending:stop()
                    pendingKills[pid] = nil
                end
            end
        end
    end)

    palette = hs.canvas.new({ x = 0, y = 0, w = paletteWidth, h = paletteHeight })
        :level("floating")
    textMeasurer = hs.canvas.new({})
    textMeasurer:canvasDefaultFor("textFont", ui.font)
    textMeasurer:canvasDefaultFor("textSize", ui.sizes.body)

    paletteModal = hs.hotkey.modal.new()
    function paletteModal:entered()
        showPalette()
    end
    function paletteModal:exited()
        hidePalette()
    end

    -- Reserve 2 from dynamic app assignment and toggle the visual palette.
    hyper:bind({}, "2", {
        group = "Focus",
        description = "Flowmodoro controls",
    }, togglePalette)

    local function paletteAction(key, action)
        paletteModal:bind({}, key, function()
            paletteModal:exit()
            action()
        end)
    end
    paletteAction("j", toggleStopwatch)
    paletteAction("b", toggleBackgroundSounds)
    paletteAction("s", switchBackgroundSound)
    paletteModal:bind({}, "escape", function() paletteModal:exit() end)

    if loadState().phase == "running" then
        startBlockedAppWatcher()
        sendCommand("start")
    end

    -- A small console API for inspection without leaking internal state:
    -- require("modules.flowmodoro").isVisible()
    M.toggle = togglePalette
    M.dismiss = function()
        if paletteVisible then paletteModal:exit() end
    end
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
end

return M
