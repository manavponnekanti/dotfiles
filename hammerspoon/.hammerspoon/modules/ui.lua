local M = {
    font = "Menlo",
    radius = 12,
    outerPadding = 16,
    gutter = 24,
    colors = {
        surface = { white = 0.055, alpha = 0.94 },
        primary = { white = 1, alpha = 0.96 },
        secondary = { white = 1, alpha = 0.9 },
        muted = { white = 1, alpha = 0.5 },
        section = { white = 1, alpha = 0.58 },
        divider = { white = 1, alpha = 0.14 },
        success = { red = 0.35, green = 0.84, blue = 0.55, alpha = 0.9 },
    },
    sizes = {
        title = 20,
        section = 11,
        body = 13,
    },
}

function M.hint(label)
    return "[" .. label .. "]"
end

return M
