local M = {}

local caffeinateWatcher = nil
local f19EventTap = nil
local ui = nil

local holdDelay = 1.2
local cheatsheet = nil
local holdTimer = nil
local f19Held = false

local function bindingID(modifiers, key)
    local normalizedModifiers = {}
    for _, modifier in ipairs(modifiers) do
        table.insert(normalizedModifiers, modifier:lower())
    end
    table.sort(normalizedModifiers)

    return table.concat(normalizedModifiers, "+") .. ":" .. key:lower()
end

local function keyLabel(modifiers, key)
    local modifierLabels = {
        alt = "⌥",
        cmd = "⌘",
        ctrl = "⌃",
        shift = "⇧",
    }
    local keyLabels = {
        ["return"] = "↩",
        ["escape"] = "⎋",
        ["space"] = "Space",
        ["`"] = "`",
    }
    local labels = {}

    for _, modifier in ipairs({ "ctrl", "alt", "shift", "cmd" }) do
        for _, activeModifier in ipairs(modifiers) do
            if activeModifier:lower() == modifier then
                table.insert(labels, modifierLabels[modifier])
            end
        end
    end

    table.insert(labels, keyLabels[key:lower()] or key:lower())
    return ui.hint(table.concat(labels, " "))
end

local function hideCheatsheet()
    if cheatsheet then
        cheatsheet:hide()
    end
end

local function stopHoldTimer()
    if holdTimer then
        holdTimer:stop()
        holdTimer = nil
    end
end

local function visibleBindings(bindings)
    local visible = {}
    for _, binding in pairs(bindings) do
        local description = binding.description
        if type(description) == "function" then
            description = description()
        end

        if description and description ~= "" then
            table.insert(visible, {
                description = description,
                group = binding.group,
                key = binding.key,
                modifiers = binding.modifiers,
                order = binding.order,
            })
        end
    end

    table.sort(visible, function(a, b)
        if a.group ~= b.group then return a.group < b.group end
        if a.order ~= b.order then return a.order < b.order end
        if #a.modifiers ~= #b.modifiers then return #a.modifiers < #b.modifiers end
        return a.key < b.key
    end)
    return visible
end

local function layoutColumns(items, columnCount)
    local groups = {}
    local groupOrder = {}
    for _, item in ipairs(items) do
        if not groups[item.group] then
            groups[item.group] = {}
            table.insert(groupOrder, item.group)
        end
        table.insert(groups[item.group], item)
    end

    local headerHeight = 1.35
    local groupGap = 0.45
    local totalRows = #items + (#groupOrder * (headerHeight + groupGap))
    local targetHeight = math.ceil(totalRows / columnCount)
    local columns = {}
    for index = 1, columnCount do columns[index] = {} end
    local columnHeights = {}
    for index = 1, columnCount do columnHeights[index] = 0 end

    local targetColumn = 1
    for _, group in ipairs(groupOrder) do
        local minimumEntriesAfterHeader = math.min(3, #groups[group])
        local availableHeight = targetHeight - columnHeights[targetColumn]
        if targetColumn < columnCount
            and availableHeight < headerHeight + minimumEntriesAfterHeader then
            targetColumn = targetColumn + 1
        end

        table.insert(columns[targetColumn], { isHeader = true, text = group })
        columnHeights[targetColumn] = columnHeights[targetColumn] + headerHeight
        for _, item in ipairs(groups[group]) do
            if columnHeights[targetColumn] + 1 > targetHeight and targetColumn < columnCount then
                targetColumn = targetColumn + 1
            end
            table.insert(columns[targetColumn], item)
            columnHeights[targetColumn] = columnHeights[targetColumn] + 1
        end
        columnHeights[targetColumn] = columnHeights[targetColumn] + groupGap
    end

    return columns, columnHeights
end

local function showCheatsheet(bindings)
    local items = visibleBindings(bindings)
    if #items == 0 then return end

    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local screenFrame = screen:frame()
    local columnCount = #items > 20 and 3 or 2
    local columns, columnHeights = layoutColumns(items, columnCount)
    local maxRows = math.max(table.unpack(columnHeights))
    local outerPadding = ui.outerPadding
    local gutter = ui.gutter
    local width = math.min(screenFrame.w - 80,
        columnCount * 294 + outerPadding * 2 + gutter * (columnCount - 1))
    local height = math.min(screenFrame.h - 80, math.ceil(maxRows * 28) + 62)
    local frame = {
        x = screenFrame.x + (screenFrame.w - width) / 2,
        y = screenFrame.y + (screenFrame.h - height) / 2,
        w = width,
        h = height,
    }

    if not cheatsheet then
        cheatsheet = hs.canvas.new(frame):level("overlay")
    else
        cheatsheet:frame(frame)
    end

    local elements = {
        {
            type = "rectangle",
            frame = { x = 0, y = 0, w = width, h = height },
            action = "fill",
            fillColor = ui.colors.surface,
            roundedRectRadii = { xRadius = ui.radius, yRadius = ui.radius },
        },
        {
            type = "text",
            frame = { x = outerPadding, y = 14, w = width - outerPadding * 2, h = 30 },
            text = "Cheatsheet",
            textColor = ui.colors.primary,
            textFont = ui.font,
            textSize = ui.sizes.title,
        },
    }

    local columnWidth = (width - outerPadding * 2 - gutter * (columnCount - 1)) / columnCount
    for columnIndex, column in ipairs(columns) do
        local x = outerPadding + (columnIndex - 1) * (columnWidth + gutter)
        local y = 50
        for _, item in ipairs(column) do
            if item.isHeader then
                table.insert(elements, {
                    type = "text",
                    frame = { x = x, y = y, w = columnWidth, h = 22 },
                    text = item.text:upper(),
                    textColor = ui.colors.section,
                    textFont = ui.font,
                    textSize = ui.sizes.section,
                })
                table.insert(elements, {
                    type = "rectangle",
                    frame = { x = x, y = y + 21, w = columnWidth, h = 1 },
                    action = "fill",
                    fillColor = ui.colors.divider,
                })
                y = y + 30
            else
                table.insert(elements, {
                    type = "text",
                    frame = { x = x, y = y, w = 72, h = 24 },
                    text = keyLabel(item.modifiers, item.key),
                    textAlignment = "right",
                    textColor = ui.colors.muted,
                    textFont = ui.font,
                    textSize = ui.sizes.body,
                })
                table.insert(elements, {
                    type = "text",
                    frame = { x = x + 84, y = y, w = columnWidth - 84, h = 24 },
                    text = item.description,
                    textColor = ui.colors.secondary,
                    textFont = ui.font,
                    textSize = ui.sizes.body,
                })
                y = y + 28
            end
        end
    end

    cheatsheet:replaceElements(elements)
    cheatsheet:show()
end

function M.setup(uiModule)
    ui = uiModule
    local modal = hs.hotkey.modal.new()
    local bindings = {}
    local hyper = {}

    local function restartHoldTimer()
        stopHoldTimer()
        if not f19Held then return end

        holdTimer = hs.timer.doAfter(holdDelay, function()
            holdTimer = nil
            if f19Held then showCheatsheet(bindings) end
        end)
    end

    local function actionWasPerformed()
        hideCheatsheet()
        restartHoldTimer()
    end

    function hyper:bind(modifiers, key, metadata, pressedFn, releasedFn, repeatFn)
        metadata = metadata or {}
        bindings[bindingID(modifiers, key)] = {
            description = metadata.description,
            group = metadata.group or "Other",
            key = key,
            modifiers = modifiers,
            order = metadata.order or 100,
        }

        local function wrappedPressedFn(...)
            actionWasPerformed()
            if pressedFn then return pressedFn(...) end
        end

        return modal:bind(modifiers, key, wrappedPressedFn, releasedFn, repeatFn)
    end

    function hyper:unboundKeys(modifiers, keys)
        local unbound = {}
        for _, key in ipairs(keys) do
            if not bindings[bindingID(modifiers, key)] then
                table.insert(unbound, key)
            end
        end
        return unbound
    end

    local function pressF19()
        if f19Held then return end
        f19Held = true
        hideCheatsheet()
        modal:enter()
        restartHoldTimer()
    end

    local function releaseF19()
        f19Held = false
        stopHoldTimer()
        hideCheatsheet()
        modal:exit()
    end

    local eventTypes = hs.eventtap.event.types
    f19EventTap = hs.eventtap.new({ eventTypes.keyDown, eventTypes.keyUp }, function(event)
        if event:getKeyCode() ~= hs.keycodes.map.f19 then return false end

        if event:getType() == eventTypes.keyDown then
            pressF19()
        else
            releaseF19()
        end
        return true
    end)
    f19EventTap:start()

    caffeinateWatcher = hs.caffeinate.watcher.new(function(event)
        if event == hs.caffeinate.watcher.systemDidWake
            or event == hs.caffeinate.watcher.screensDidUnlock then
            releaseF19()
        end
    end)
    caffeinateWatcher:start()

    -- Console helpers make the generated sheet inspectable without duplicating
    -- its binding registry or exposing the modal itself.
    M.showCheatsheet = function() showCheatsheet(bindings) end
    M.dismissCheatsheet = hideCheatsheet
    M.isCheatsheetVisible = function()
        return cheatsheet and cheatsheet:isShowing() or false
    end
    M.isF19Held = function() return f19Held end
    hs.f19Cheatsheet = M

    return hyper
end

return M
