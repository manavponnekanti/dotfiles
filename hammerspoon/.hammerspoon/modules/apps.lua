local M = {}
local alerts = nil
-- Windows installs this handler so normal app shortcuts can select an app
-- from the tiling chooser without duplicating the hotkey bindings.
local shortcutHandler = nil

-- Every key is bound even when currently unassigned so assignment mode can use it.
local assignableKeys = { "0", "2", "5", "6", "7", "8", "9",
    "a", "b", "c", "d", "e", "f", "g", "i", "m", "n", "o", "p",
    "q", "s", "t", "v", "w", "x", "y", "z" }

local appBindingsPath = hs.configdir .. "/app_bindings.lua"

local function showAlert(message, ...)
    if alerts then
        return alerts.show(message, ...)
    end
    return hs.alert.show(message, ...)
end

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
    local file, openErr = io.open(appBindingsPath, "w")
    if not file then
        return false, openErr
    end

    local ok, writeErr = file:write(serializeBindings(bindings))
    file:close()
    if not ok then
        return false, writeErr
    end

    return true
end

local function loadAppBindings()
    local ok, loaded = pcall(dofile, appBindingsPath)
    if ok and type(loaded) == "table" then
        return loaded
    end

    if ok then
        showAlert("app_bindings.lua error")
        print("app_bindings.lua must return a table")
    else
        showAlert(loaded:match("cannot open") and "Missing app_bindings.lua" or "app_bindings.lua error")
        print(loaded)
    end
    return {}
end

local function showBindingSaveError(saveErr)
    showAlert("Binding save failed")
    if saveErr then
        print(saveErr)
    end
end

local function raiseAppWindows(app)
    if not app then return end

    app:unhide()
    app:activate(true)
end

local function toggleApp(bundleID)
    local app = hs.application.get(bundleID)
    if app and app:isFrontmost() then
        app:hide()
    else
        hs.application.launchOrFocusByBundleID(bundleID)
        raiseAppWindows(hs.application.get(bundleID))
    end
end

function M.setShortcutHandler(handler)
    shortcutHandler = handler
end

function M.setup(meh, alertModule)
    alerts = alertModule
    local appBindings = loadAppBindings()
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
            showAlert("Assign mode off")
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
            showAlert("Meh+" .. key .. " cleared")
        else
            local ok, saveErr = updateAppBinding(key, bundleID)
            if not ok then
                showBindingSaveError(saveErr)
                return
            end
            showAlert("Meh+" .. key .. " → " .. name)
        end
    end

    for _, key in ipairs(assignableKeys) do
        meh:bind({}, key, function()
            if assignMode then
                exitAssignMode(false)
                assignFrontmostApp(key)
            -- The chooser gets first refusal; otherwise this remains a normal
            -- launch/focus/hide app shortcut.
            elseif shortcutHandler and shortcutHandler(key, appBindings[key]) then
                return
            elseif appBindings[key] then
                toggleApp(appBindings[key])
            end
        end)
    end

    meh:bind({}, "`", function()
        if assignMode then
            exitAssignMode(true)
        else
            enterAssignMode()
        end
    end)
end

return M
