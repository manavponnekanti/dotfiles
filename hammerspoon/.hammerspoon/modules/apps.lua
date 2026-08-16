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
        showAlert("app_bindings.lua error")
        print("app_bindings.lua must return a table")
    else
        local detail = tostring(loaded)
        showAlert(detail:match("cannot open") and "Missing app_bindings.lua" or "app_bindings.lua error")
        print(detail)
    end
    return {}
end

local function showBindingSaveError(saveErr)
    showAlert("Binding save failed")
    if saveErr then
        print(saveErr)
    end
end

local function toggleApp(bundleID)
    local app = hs.application.get(bundleID)
    if app and app:isFrontmost() then
        app:hide()
    else
        hs.application.launchOrFocusByBundleID(bundleID)
    end
end

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
            showAlert("F19+" .. key .. " cleared")
        else
            local ok, saveErr = updateAppBinding(key, bundleID)
            if not ok then
                showBindingSaveError(saveErr)
                return
            end
            showAlert("F19+" .. key .. " → " .. name)
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
