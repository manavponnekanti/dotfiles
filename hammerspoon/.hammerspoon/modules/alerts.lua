local M = {}

local lastTransientAlert = nil

local function closeTransientAlert()
    if lastTransientAlert then
        hs.alert.closeSpecific(lastTransientAlert, 0)
        lastTransientAlert = nil
    end
end

function M.show(message, ...)
    closeTransientAlert()
    lastTransientAlert = hs.alert.show(message, ...)
    return lastTransientAlert
end

function M.showPersistent(message)
    -- Persistent alerts are used for modes that remain active until another key.
    return hs.alert.show(message, "indefinite")
end

function M.close(id, seconds)
    if id == lastTransientAlert then
        lastTransientAlert = nil
    end
    hs.alert.closeSpecific(id, seconds)
end

function M.setup()
    hs.window.animationDuration = 0

    hs.alert.defaultStyle.strokeWidth = 0
    hs.alert.defaultStyle.fillColor = { white = 0, alpha = 0.75 }
    hs.alert.defaultStyle.strokeColor = { white = 1, alpha = 0 }
    hs.alert.defaultStyle.textColor = { white = 1, alpha = 0.9 }
    hs.alert.defaultStyle.textSize = 20
    hs.alert.defaultStyle.radius = 14
    hs.alert.defaultStyle.padding = 12
    hs.alert.defaultStyle.atScreenEdge = 2
    hs.alert.defaultStyle.fadeInDuration = 0.08
    hs.alert.defaultStyle.fadeOutDuration = 0.12

end

return M
