local M = {}

local menuBarExtraBundleID = "com.apple.Passwords.MenuBarExtra"

-- The extra owns exactly one status item. Matching it by title broke in
-- macOS 26/27, which renamed it from "apple.passwords" to "Apple Passwords Key";
-- AXExtrasMenuBar reaches it without depending on that name.
local function openMenuBarWindow(alerts)
    local app = hs.application.applicationsForBundleID(menuBarExtraBundleID)[1]
    if not app then
        alerts.show("Enable Passwords in the menu bar")
        return
    end

    local extras = hs.axuielement.applicationElement(app):attributeValue("AXExtrasMenuBar")
    local item = extras and (extras:attributeValue("AXChildren") or {})[1]
    if not item then
        alerts.show("Passwords menu bar item not found")
        return
    end

    if not item:performAction("AXPress") then
        alerts.show("Could not open Passwords")
    end
end

function M.setup(hyper, alerts)
    hyper:bind({}, "1", {
        group = "Utilities",
        description = "Open Passwords",
    }, function()
        openMenuBarWindow(alerts)
    end)
end

return M
