local M = {}

function M.setup()
    hs.window.animationDuration = 0

    hs.alert.defaultStyle.strokeWidth = 0
    hs.alert.defaultStyle.fillColor = { white = 0, alpha = 0.45 }
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
