local M = {}

local Cheatsheet = {}
Cheatsheet.__index = Cheatsheet

local function keyLabel(ui, modifiers, key)
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

    return columns
end

function Cheatsheet:setBindings(bindings)
    self.bindings = bindings or {}
    return self
end

function Cheatsheet:hide()
    if self.canvas then
        self.canvas:hide()
    end
end

function Cheatsheet:show()
    local items = visibleBindings(self.bindings)
    if #items == 0 then return end

    local ui = self.ui
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

    if not self.canvas then
        self.canvas = hs.canvas.new(frame):level("overlay")
    else
        self.canvas:frame(frame)
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
                    text = keyLabel(ui, item.modifiers, item.key),
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

    self.canvas:replaceElements(elements)
    self.canvas:show()
end

function Cheatsheet:isVisible()
    return self.canvas and self.canvas:isShowing() or false
end

function M.new(ui)
    local cheatsheet = setmetatable({
        bindings = {},
        canvas = nil,
        ui = ui,
    }, Cheatsheet)

    -- Preserve the existing console inspection helpers.
    hs.f19Cheatsheet = {
        showCheatsheet = function() cheatsheet:show() end,
        dismissCheatsheet = function() cheatsheet:hide() end,
        isCheatsheetVisible = function() return cheatsheet:isVisible() end,
    }

    return cheatsheet
end

return M
