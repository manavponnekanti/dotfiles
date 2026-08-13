local M = {}

local controlCenterBundleID = "com.apple.controlcenter"
local bluetoothMenuItemID = "com.apple.menuextra.bluetooth"
local deviceName = "Manav's AirPods Pro"
local retryInterval = 0.1
local maxAttempts = 20

local function normalizedName(value)
    return value and value:gsub("’", "'") or nil
end

local function findElement(element, predicate)
    if predicate(element) then return element end

    for _, child in ipairs(element:attributeValue("AXChildren") or {}) do
        local match = findElement(child, predicate)
        if match then return match end
    end
end

local function closePopover(appElement, menuItem)
    local isOpen = findElement(appElement, function(element)
        return element:attributeValue("AXIdentifier") == "bluetooth-header"
    end)

    if isOpen and menuItem:isValid() then
        menuItem:performAction("AXPress")
    end
end

local function dismissPopover(appElement, menuItem)
    hs.timer.doAfter(0.15, function()
        closePopover(appElement, menuItem)
    end)
end

local function connectDevice(appElement, menuItem, alerts)
    local device = findElement(appElement, function(element)
        return element:attributeValue("AXRole") == "AXCheckBox"
            and normalizedName(element:attributeValue("AXDescription")) == deviceName
    end)

    if not device then return false end

    if device:attributeValue("AXValue") == 1 then
        alerts.show("AirPods already connected")
    elseif device:performAction("AXPress") then
        alerts.show("Connecting AirPods…")
    else
        alerts.show("Could not connect AirPods")
    end

    dismissPopover(appElement, menuItem)
    return true
end

local function waitForDevice(appElement, menuItem, alerts, attempt)
    if connectDevice(appElement, menuItem, alerts) then return end

    if attempt >= maxAttempts then
        closePopover(appElement, menuItem)
        alerts.show(deviceName .. " not found")
        return
    end

    hs.timer.doAfter(retryInterval, function()
        waitForDevice(appElement, menuItem, alerts, attempt + 1)
    end)
end

local function connectAirPods(alerts)
    local app = hs.application.get(controlCenterBundleID)
    if not app then
        alerts.show("Control Centre is not available")
        return
    end

    local appElement = hs.axuielement.applicationElement(app)
    local menuItem = findElement(appElement, function(element)
        return element:attributeValue("AXIdentifier") == bluetoothMenuItemID
    end)

    if not menuItem then
        alerts.show("Show Bluetooth in the menu bar first")
        return
    end

    if connectDevice(appElement, menuItem, alerts) then return end

    if menuItem:performAction("AXPress") then
        waitForDevice(appElement, menuItem, alerts, 1)
    else
        alerts.show("Could not open Bluetooth")
    end
end

function M.setup(hyper, alertModule)
    hyper:bind({ "shift" }, "b", {
        group = "Utilities",
        description = "Connect AirPods",
    }, function()
        connectAirPods(alertModule)
    end)
end

return M
