local M = {}
local alerts = nil

local allAssignableKeys = {}
for keyCode = string.byte("0"), string.byte("9") do
    table.insert(allAssignableKeys, string.char(keyCode))
end
for keyCode = string.byte("a"), string.byte("z") do
    table.insert(allAssignableKeys, string.char(keyCode))
end

local appBindingsPath = hs.configdir .. "/app_bindings.lua"

local function serializeBindings(bindings)
    -- Keep the generated file deterministic and pleasant to edit by hand.
    local keys = {}
    for key in pairs(bindings) do
        table.insert(keys, key)
    end
    table.sort(keys)

    local lines = { "return {" }
    for _, key in ipairs(keys) do
        table.insert(lines, string.format("    [%q] = %q,", key, bindings[key]))
    end
    table.insert(lines, "}")

    return table.concat(lines, "\n") .. "\n"
end

local function saveAppBindings(bindings)
    local temporaryPath = appBindingsPath .. ".tmp"
    local file, openErr = io.open(temporaryPath, "w")
    if not file then
        return false, openErr
    end

    local ok, writeErr = file:write(serializeBindings(bindings))
    if not ok then
        file:close()
        os.remove(temporaryPath)
        return false, writeErr
    end

    local closed, closeErr = file:close()
    if not closed then
        os.remove(temporaryPath)
        return false, closeErr
    end

    local renamed, renameErr = os.rename(temporaryPath, appBindingsPath)
    if not renamed then
        os.remove(temporaryPath)
        return false, renameErr
    end

    return true
end

local function loadAppBindings()
    local ok, loaded = pcall(dofile, appBindingsPath)
    if ok and type(loaded) == "table" then
        return loaded
    end

    if ok then
        alerts.show("app_bindings.lua error")
        print("app_bindings.lua must return a table")
    else
        local detail = tostring(loaded)
        alerts.show(detail:match("cannot open") and "Missing app_bindings.lua" or "app_bindings.lua error")
        print(detail)
    end
    return {}
end

local function showBindingSaveError(saveErr)
    alerts.show("Binding save failed")
    if saveErr then
        print(saveErr)
    end
end

-- Raise the app's topmost window, or hide the app when it is already in front.
-- Deliberately does nothing else: no re-layout, no unminimizing, no touching
-- the app's other windows. macOS decides which window that is.
--
-- Accessibility calls are the hazard here. Each is a synchronous round trip
-- into the target app, and an app that has stopped servicing its event loop
-- answers none of them, so this thread waits out init.lua's hs.window.timeout
-- cap -- measured at 1001ms per call against a stopped app, with no hotkey
-- firing meanwhile. Against a responsive app every call below costs the same
-- 0.03-0.07ms, so what matters is how many of them a keypress makes, not which
-- ones: two in the common case, and nothing Accessibility can answer that the
-- window server can answer instead.
local function toggleApp(bundleID)
    -- Exact bundle-ID lookup. hs.application.get() falls back to scanning every
    -- app's window titles when the app isn't running, which is very slow.
    local app = hs.application.applicationsForBundleID(bundleID)[1]
    if not app then
        -- False means LaunchServices has no such app: a stale binding.
        if not hs.application.launchOrFocusByBundleID(bundleID) then
            alerts.show("App not installed: " .. bundleID)
        end
        return
    end

    -- isUnresponsive() is CGSEventIsAppUnresponsive, answered by the window
    -- server about the app rather than by the app, so it cannot block; it goes
    -- first because it is free. Best-effort only: a process suspended with
    -- SIGSTOP still reads responsive, so it catches the beachball the window
    -- server has noticed and nothing else. LaunchServices is all that is left
    -- for an app in that state -- it queues the request without blocking us,
    -- and the app acts on it if it comes back.
    -- Undocumented in 1.1.1, so tolerate its absence in a future release.
    if app.isUnresponsive and app:isUnresponsive() then
        hs.application.launchOrFocusByBundleID(bundleID)
        return
    end

    -- NSWorkspace's front app, not AXFrontmost read from the app itself. A
    -- timed-out Accessibility read returns the attribute's default instead of
    -- failing, so app:isFrontmost() answers false for a wedged front app and
    -- this branch would be skipped for the app that most needs hiding.
    local front = hs.application.frontmostApplication()
    if front and front:pid() == app:pid() then
        app:hide()
        return
    end

    -- A running app with every window closed (cmd-W) only builds one again for
    -- the reopen Apple Event that LaunchServices sends, which is what a Dock
    -- click does; raised any other way it brings its menu bar forward and
    -- nothing else, which is how WhatsApp came to answer F19+w with no window.
    -- Telegram and Messages ignore reopen, as ba80653 found, so they end up
    -- where they already were. A read that times out also arrives here, since
    -- it reports no window; LaunchServices is the right answer for that too.
    local win = app:mainWindow()
    if not win then
        hs.application.launchOrFocusByBundleID(bundleID)
        return
    end

    -- hs.window:focus() ends in the same AXMain write and
    -- SetFrontProcessWithOptions pair as hs.application:activate(), plus
    -- upstream's workaround for the Finder desktop taking focus back (F19+f is
    -- Finder), and it skips activate()'s own AXFocusedWindow read for a window
    -- already in hand. SetFrontProcessWithOptions unhides a hidden app on its
    -- own, verified against both branches above, so an isHidden()/unhide()
    -- pair here would spend two more Accessibility calls, and up to a second of
    -- this thread, on something already done.
    win:focus()
end

-- Cheatsheet descriptions call this for every binding on each show.
-- nameForBundleID() reads the name through NSBundle, which keeps its own cache:
-- 3.2ms for the first lookup of a bundle ID, 0.013ms for every one after, so a
-- cache here would save about 0.4ms per cheatsheet show and is not worth the
-- lines.
local function appName(bundleID)
    if not bundleID then return nil end
    return hs.application.nameForBundleID(bundleID) or bundleID
end

function M.setup(hyper, alertModule)
    alerts = alertModule
    local appBindings = loadAppBindings()

    -- Command modules claim their shortcuts first. App assignment inherits those
    -- exact modifier/key exclusions instead of maintaining a duplicate list.
    local assignableKeys = hyper:unboundKeys({}, allAssignableKeys)
    local assignMode = false
    local assignModeAlert = nil

    local function closeAssignModeAlert()
        if assignModeAlert then
            alerts.close(assignModeAlert, 0)
            assignModeAlert = nil
        end
    end

    local function enterAssignMode()
        assignMode = true
        closeAssignModeAlert()
        assignModeAlert = alerts.showPersistent("Assign mode: press a key")
    end

    local function exitAssignMode(showCancelledAlert)
        assignMode = false
        closeAssignModeAlert()
        if showCancelledAlert then
            alerts.show("Assign mode off")
        end
    end

    local function updateAppBinding(key, bundleID)
        local previous = appBindings[key]
        appBindings[key] = bundleID

        local ok, saveErr = saveAppBindings(appBindings)
        if ok then
            return true
        end

        appBindings[key] = previous
        return false, saveErr
    end

    local function assignFrontmostApp(key)
        local app = hs.application.frontmostApplication()
        if not app then return end

        local bundleID = app:bundleID()
        local name = app:name()
        if appBindings[key] == bundleID then
            local ok, saveErr = updateAppBinding(key, nil)
            if not ok then
                showBindingSaveError(saveErr)
                return
            end
            alerts.show("F19+" .. key .. " cleared")
        else
            local ok, saveErr = updateAppBinding(key, bundleID)
            if not ok then
                showBindingSaveError(saveErr)
                return
            end
            alerts.show("F19+" .. key .. " → " .. name)
        end
    end

    for _, key in ipairs(assignableKeys) do
        hyper:bind({}, key, {
            group = "Apps",
            description = function()
                return appName(appBindings[key])
            end,
        }, function()
            if assignMode then
                exitAssignMode(false)
                assignFrontmostApp(key)
            elseif appBindings[key] then
                toggleApp(appBindings[key])
            end
        end)
    end

    hyper:bind({}, "`", {
        group = "Apps",
        description = "Assign frontmost app",
        order = 0,
    }, function()
        if assignMode then
            exitAssignMode(true)
        else
            enterAssignMode()
        end
    end)
end

return M
