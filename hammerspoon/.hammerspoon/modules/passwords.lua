local M = {}

local menuBarExtraBundleID = "com.apple.Passwords.MenuBarExtra"
local menuBarItemTitle = "apple.passwords"

local function openMenuBarWindow(alerts)
    local app = hs.application.get(menuBarExtraBundleID)
    if not app then
        alerts.show("Enable Passwords in the menu bar")
        return
    end

    local appElement = hs.axuielement.applicationElement(app)
    for _, menuBar in ipairs(appElement:attributeValue("AXChildren") or {}) do
        for _, item in ipairs(menuBar:attributeValue("AXChildren") or {}) do
            if item:attributeValue("AXTitle") == menuBarItemTitle then
                local pressed = item:performAction("AXPress")
                if not pressed then
                    alerts.show("Could not open Passwords")
                end
                return
            end
        end
    end

    alerts.show("Passwords menu bar item not found")
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
