local M = {}

local baseModifiers = { "ctrl", "alt", "shift" }

local function combinedModifiers(additionalModifiers)
    local modifiers = {}

    for _, modifier in ipairs(baseModifiers) do
        table.insert(modifiers, modifier)
    end

    for _, modifier in ipairs(additionalModifiers or {}) do
        table.insert(modifiers, modifier)
    end

    return modifiers
end

function M:bind(additionalModifiers, key, ...)
    return hs.hotkey.bind(combinedModifiers(additionalModifiers), key, ...)
end

return M
