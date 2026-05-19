local M = {}

local assignableKeys = { "0", "1", "2", "5", "6", "7", "8", "9",
    "a", "b", "c", "d", "e", "f", "g", "i", "m", "n", "o", "p",
    "q", "s", "t", "v", "w", "x", "y", "z" }

local appBindingsPath = hs.configdir .. "/app_bindings.lua"

local function serializeBindings(bindings)
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
        hs.alert.show("app_bindings.lua error")
        print("app_bindings.lua must return a table")
    else
        hs.alert.show(loaded:match("cannot open") and "Missing app_bindings.lua" or "app_bindings.lua error")
        print(loaded)
    end
    return {}
end

local function showBindingSaveError(saveErr)
    hs.alert.show("Binding save failed")
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

function M.setup(hyper)
    local appBindings = loadAppBindings()
    local assignMode = false

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
            hs.alert.show("F19+" .. key .. " cleared")
        else
            local ok, saveErr = updateAppBinding(key, bundleID)
            if not ok then
                showBindingSaveError(saveErr)
                return
            end
            hs.alert.show("F19+" .. key .. " → " .. name)
        end
    end

    hyper:bind({}, "4", function()
        hs.eventtap.keyStroke({ "cmd", "alt", "shift", "ctrl" }, "4")
    end)

    hyper:bind({}, "3", function()
        hs.eventtap.keyStroke({ "cmd", "alt", "shift", "ctrl" }, "3")
    end)

    hyper:bind({ "shift" }, "d", function()
        hs.eventtap.keyStroke({ "cmd", "alt", "shift", "ctrl" }, "d")
    end)

    hyper:bind({ "shift" }, "p", function()
        hs.eventtap.keyStroke({ "cmd", "alt", "shift", "ctrl" }, "p")
    end)

    hyper:bind({ "shift" }, "a", function()
        hs.eventtap.keyStroke({ "cmd", "alt", "shift", "ctrl" }, "a")
    end)

    hyper:bind({}, "space", function()
        hs.eventtap.keyStroke({ "cmd", "alt", "shift", "ctrl" }, "space")
    end)

    for _, key in ipairs(assignableKeys) do
        hyper:bind({}, key, function()
            if assignMode then
                assignMode = false
                assignFrontmostApp(key)
            elseif appBindings[key] then
                toggleApp(appBindings[key])
            end
        end)
    end

    hyper:bind({}, "`", function()
        assignMode = not assignMode
        hs.alert.show(assignMode and "Assign mode: press a key" or "Assign mode off")
    end)
end

return M
