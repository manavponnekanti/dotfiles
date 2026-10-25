local M = {}

local menuBarExtraBundleID = "com.apple.Passwords.MenuBarExtra"

-- The extra owns exactly one status item. Matching it by title broke in
-- macOS 26/27, which renamed it from "apple.passwords" to "Apple Passwords Key";
-- AXExtrasMenuBar reaches it without depending on that name.
local function statusItem()
    local app = hs.application.applicationsForBundleID(menuBarExtraBundleID)[1]
    if not app then return nil end

    local extras = hs.axuielement.applicationElement(app):attributeValue("AXExtrasMenuBar")
    return extras and (extras:attributeValue("AXChildren") or {})[1]
end

-- macOS 26/27 also ignores AXPress here: the action reports success and the
-- popover never opens. A real click does work, so synthesise one. The item
-- shifts sideways as other menu bar items come and go, so read its frame each
-- time rather than caching a position.
local function openPasswords(alerts)
    local item = statusItem()
    if not item then
        alerts.show("Enable Passwords in the menu bar")
        return
    end

    local frame = item:attributeValue("AXFrame")
    if not frame or frame.w == 0 or frame.h == 0 then
        alerts.show("Passwords menu bar item is hidden")
        return
    end

    local mouse = hs.mouse.absolutePosition()
    hs.eventtap.leftClick(hs.geometry.point(frame.x + frame.w / 2, frame.y + frame.h / 2), 0)

    -- Give the click time to land before putting the pointer back where it was.
    hs.timer.doAfter(0.2, function()
        hs.mouse.absolutePosition(mouse)
    end)
end

function M.setup(hyper, alerts)
    hyper:bind({}, "1", {
        group = "Utilities",
        description = "Open Passwords",
    }, function()
        openPasswords(alerts)
    end)
end

return M
