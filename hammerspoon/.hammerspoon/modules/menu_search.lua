local M = {}

local chooser = nil
local chooserApp = nil

local function copyTable(source)
    local copied = {}
    for _, value in ipairs(source) do
        table.insert(copied, value)
    end
    return copied
end

local function isEmptyTitle(title)
    return not title or title:gsub("%s+", "") == ""
end

local function modifierEnabled(modifiers, name)
    if type(modifiers) == "string" then
        return modifiers:find(name) ~= nil
    end

    if type(modifiers) == "table" then
        if modifiers[name] then return true end

        for _, modifier in pairs(modifiers) do
            if modifier == name then return true end
        end
    end

    return false
end

local function shortcutText(item)
    local modifiers = item.AXMenuItemCmdModifiers
    local key = item.AXMenuItemCmdChar

    if not key or key == "" then
        return nil
    end

    local parts = {}
    if modifierEnabled(modifiers, "cmd") then table.insert(parts, "⌘") end
    if modifierEnabled(modifiers, "alt") then table.insert(parts, "⌥") end
    if modifierEnabled(modifiers, "ctrl") then table.insert(parts, "⌃") end
    if modifierEnabled(modifiers, "shift") then table.insert(parts, "⇧") end
    table.insert(parts, key:upper())

    return table.concat(parts, "")
end

local function menuChildren(item)
    if type(item.AXChildren) == "table" and #item.AXChildren > 0 then
        return item.AXChildren
    end

    local children = {}
    for _, child in ipairs(item) do
        if type(child) == "table" then
            table.insert(children, child)
        end
    end

    if #children > 0 then
        return children
    end

    return nil
end

local flattenMenuItems

local function addChoice(item, path, choices, seenPaths)
    local pathKey = table.concat(path, "\0")
    if seenPaths[pathKey] then return end
    seenPaths[pathKey] = true

    local subText = table.concat(path, " > ")
    local shortcut = shortcutText(item)
    if shortcut then
        subText = subText .. "    " .. shortcut
    end

    table.insert(choices, {
        text = path[#path],
        subText = subText,
        path = path,
    })
end

local function flattenMenuItem(item, parentPath, choices, seenPaths)
    if type(item) ~= "table" then return end

    local title = item.AXTitle
    local path = parentPath

    if not isEmptyTitle(title) then
        path = copyTable(parentPath)
        table.insert(path, title)
    end

    local children = menuChildren(item)
    if children then
        flattenMenuItems(children, path, choices, seenPaths)
        return
    end

    if #path == 0 then return end
    addChoice(item, path, choices, seenPaths)
end

flattenMenuItems = function(items, parentPath, choices, seenPaths)
    if type(items) ~= "table" then return end

    local children = menuChildren(items)
    if children then
        for _, item in ipairs(children) do
            flattenMenuItem(item, parentPath, choices, seenPaths)
        end
        return
    end

    for _, item in ipairs(items) do
        local title = item.AXTitle

        if not isEmptyTitle(title) then
            flattenMenuItem(item, parentPath, choices, seenPaths)
        end
    end
end

local function buildChoices(menuItems)
    if not menuItems then
        return {}
    end

    local choices = {}
    flattenMenuItems(menuItems, {}, choices, {})

    table.sort(choices, function(a, b)
        return a.subText:lower() < b.subText:lower()
    end)

    return choices
end

local function selectChoice(app, choice)
    if not choice then return end

    local ok, selected = pcall(function()
        return app:selectMenuItem(choice.path)
    end)

    if not ok or not selected then
        hs.alert.show("Menu item failed")
    end
end

local function showChooser()
    if chooser and chooser:isVisible() then
        chooser:hide()
        return
    end

    local app = hs.application.frontmostApplication()
    if not app then
        hs.alert.show("No frontmost app")
        return
    end

    local ok, menuItems = pcall(function()
        return app:getMenuItems()
    end)

    if not ok or not menuItems then
        hs.alert.show("Menu load failed")
        print("menu_search: getMenuItems failed for " .. (app:name() or "unknown app"))
        return
    end

    local choices = buildChoices(menuItems)
    if #choices == 0 then
        hs.alert.show("No menu items found")
        print("menu_search: no menu items found for " .. (app:name() or "unknown app"))
        return
    end

    chooser = chooser or hs.chooser.new(function(choice)
        selectChoice(chooserApp, choice)
    end)

    chooserApp = app
    chooser:choices(choices)
    chooser:query("")
    chooser:placeholderText("Search " .. (app:name() or "current app") .. " menus")
    chooser:searchSubText(true)
    chooser:show()
end

function M.setup(hyper)
    hyper:bind({}, "r", showChooser)
end

return M
