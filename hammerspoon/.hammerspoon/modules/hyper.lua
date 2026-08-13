local M = {}

local caffeinateWatcher = nil
local f19Tap = nil
local ui = nil

local cheatsheet = nil

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
    for _, item in ipairs(items) do
        if not groups[item.group] then
            groups[item.group] = {}
        end
        table.insert(groups[item.group], item)
    end

    local headerHeight = 1.35
    local groupGap = 0.45
    local groupCount = 0
    for _ in pairs(groups) do groupCount = groupCount + 1 end
    local totalRows = #items + (groupCount * (headerHeight + groupGap))
    local targetHeight = math.ceil(totalRows / columnCount)

    -- Treat categories as masonry blocks. Categories taller than the target
    -- column height are split into untitled continuation blocks; every other
    -- category remains intact.
    local blocks = {}
    for group, groupItems in pairs(groups) do
        local firstChunkSize = math.max(1, math.floor(targetHeight - headerHeight))
        local itemIndex = 1
        local part = 1

        repeat
            local hasHeader = part == 1
            local chunkCapacity = hasHeader and firstChunkSize or math.floor(targetHeight)
            local chunkSize = math.min(chunkCapacity, #groupItems - itemIndex + 1)
            local rows = {}
            if hasHeader then
                table.insert(rows, { isHeader = true, text = group })
            end
            for offset = 0, chunkSize - 1 do
                table.insert(rows, groupItems[itemIndex + offset])
            end

            itemIndex = itemIndex + chunkSize
            local isFinalPart = itemIndex > #groupItems
            table.insert(blocks, {
                group = group,
                height = chunkSize + (hasHeader and headerHeight or 0)
                    + (isFinalPart and groupGap or 0),
                part = part,
                rows = rows,
            })
            part = part + 1
        until itemIndex > #groupItems
    end

    local columns = {}
    for index = 1, columnCount do columns[index] = {} end
    local columnHeights = {}
    for index = 1, columnCount do columnHeights[index] = 0 end

    local function placeBlock(block, targetColumn)
        for _, row in ipairs(block.rows) do
            table.insert(columns[targetColumn], row)
        end
        columnHeights[targetColumn] = columnHeights[targetColumn] + block.height
    end

    local blocksByGroup = {}
    for _, block in ipairs(blocks) do
        blocksByGroup[block.group] = blocksByGroup[block.group] or {}
        table.insert(blocksByGroup[block.group], block)
    end

    local splitGroups = {}
    local intactBlocks = {}
    for group, groupBlocks in pairs(blocksByGroup) do
        table.sort(groupBlocks, function(a, b) return a.part < b.part end)
        if #groupBlocks > 1 then
            local totalHeight = 0
            for _, block in ipairs(groupBlocks) do totalHeight = totalHeight + block.height end
            table.insert(splitGroups, {
                blocks = groupBlocks,
                group = group,
                totalHeight = totalHeight,
            })
        else
            table.insert(intactBlocks, groupBlocks[1])
        end
    end

    table.sort(splitGroups, function(a, b)
        if a.totalHeight ~= b.totalHeight then return a.totalHeight > b.totalHeight end
        return a.group < b.group
    end)

    -- Keep split categories visually connected by placing their chunks in
    -- adjacent columns before filling the remaining space with intact blocks.
    for _, splitGroup in ipairs(splitGroups) do
        local maxStartColumn = math.max(1, columnCount - #splitGroup.blocks + 1)
        local bestStartColumn = 1
        local bestResultingHeight = nil
        for startColumn = 1, maxStartColumn do
            local resultingHeight = 0
            for partIndex, block in ipairs(splitGroup.blocks) do
                local columnIndex = startColumn + partIndex - 1
                resultingHeight = math.max(resultingHeight,
                    columnHeights[columnIndex] + block.height)
            end
            if not bestResultingHeight or resultingHeight < bestResultingHeight then
                bestStartColumn = startColumn
                bestResultingHeight = resultingHeight
            end
        end

        for partIndex, block in ipairs(splitGroup.blocks) do
            placeBlock(block, bestStartColumn + partIndex - 1)
        end
    end

    table.sort(intactBlocks, function(a, b)
        if a.height ~= b.height then return a.height > b.height end
        return a.group < b.group
    end)

    for _, block in ipairs(intactBlocks) do
        local targetColumn = 1
        for columnIndex = 2, columnCount do
            if columnHeights[columnIndex] < columnHeights[targetColumn] then
                targetColumn = columnIndex
            end
        end
        placeBlock(block, targetColumn)
    end

    return columns, columnHeights
end

local function showCheatsheet(bindings)
    local items = visibleBindings(bindings)
    if #items == 0 then return end

    local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
    local screenFrame = screen:frame()
    local columnCount = #items > 20 and 3 or 2
    local columns = layoutColumns(items, columnCount)
    local outerPadding = ui.outerPadding + 8
    local gutter = ui.gutter
    local contentTop = 28
    local contentBottom = contentTop
    for _, column in ipairs(columns) do
        local cursor = contentTop
        local columnBottom = contentTop
        for _, item in ipairs(column) do
            if item.isHeader then
                columnBottom = cursor + 22
                cursor = cursor + 30
            else
                columnBottom = cursor + 24
                cursor = cursor + 28
            end
        end
        contentBottom = math.max(contentBottom, columnBottom)
    end
    local width = math.min(screenFrame.w - 80,
        columnCount * 310 + outerPadding * 2 + gutter * (columnCount - 1))
    local height = math.min(screenFrame.h - 80, contentBottom + 20)
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
    }

    local columnWidth = (width - outerPadding * 2 - gutter * (columnCount - 1)) / columnCount
    for columnIndex, column in ipairs(columns) do
        local x = outerPadding + (columnIndex - 1) * (columnWidth + gutter)
        local y = contentTop
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
    local f19GestureHandlers = nil
    local f19Down = false

    local function actionWasPerformed()
        hideCheatsheet()
        if f19GestureHandlers and f19GestureHandlers.cancel then
            f19GestureHandlers.cancel()
        end
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

    function hyper:setF19GestureHandlers(handlers)
        f19GestureHandlers = handlers
    end

    local function pressF19()
        if f19Down then return end
        f19Down = true
        hideCheatsheet()
        if f19GestureHandlers and f19GestureHandlers.pressed then
            f19GestureHandlers.pressed()
        end
        modal:enter()
    end

    local function releaseF19()
        if not f19Down then return end
        f19Down = false
        hideCheatsheet()
        if f19GestureHandlers and f19GestureHandlers.released then
            f19GestureHandlers.released()
        end
        modal:exit()
    end

    modal:bind({}, "tab", function()
        showCheatsheet(bindings)
    end)

    -- Track the physical F19 key directly. A normal hotkey binding is released
    -- when Shift changes, even though F19 is still held, which would interrupt
    -- a move/resize gesture while switching modes.
    local f19KeyCode = hs.keycodes.map.f19
    f19Tap = hs.eventtap.new({
        hs.eventtap.event.types.keyDown,
        hs.eventtap.event.types.keyUp,
    }, function(event)
        if event:getKeyCode() ~= f19KeyCode then return false end

        if event:getType() == hs.eventtap.event.types.keyDown then
            local isRepeat = event:getProperty(
                hs.eventtap.event.properties.keyboardEventAutorepeat) ~= 0
            -- If macOS ever dropped the previous key-up, a fresh physical
            -- press repairs the stale modal state instead of requiring an
            -- extra press solely to unlock it.
            if f19Down and not isRepeat then
                releaseF19()
            end
            pressF19()
        else
            releaseF19()
        end
        return true
    end)
    f19Tap:start()

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
    hs.f19Cheatsheet = M

    return hyper
end

return M
