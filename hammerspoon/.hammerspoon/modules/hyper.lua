local M = {}

local caffeinateWatcher = nil

local function bindingID(modifiers, key)
    local normalizedModifiers = {}
    for _, modifier in ipairs(modifiers) do
        table.insert(normalizedModifiers, modifier:lower())
    end
    table.sort(normalizedModifiers)

    return table.concat(normalizedModifiers, "+") .. ":" .. key:lower()
end

function M.setup(cheatsheet)
    local modal = hs.hotkey.modal.new()
    local bindings = {}
    local hyper = {}

    cheatsheet:setBindings(bindings)

    function hyper:bind(modifiers, key, metadata, pressedFn, releasedFn, repeatFn)
        metadata = metadata or {}
        bindings[bindingID(modifiers, key)] = {
            description = metadata.description,
            group = metadata.group or "Other",
            key = key,
            modifiers = modifiers,
            order = metadata.order or 100,
        }

        local function wrappedPressedFn(...)
            cheatsheet:hide()
            if pressedFn then return pressedFn(...) end
        end

        return modal:bind(modifiers, key, wrappedPressedFn, releasedFn, repeatFn)
    end

    function hyper:unboundKeys(modifiers, keys)
        local unbound = {}
        for _, key in ipairs(keys) do
            if not bindings[bindingID(modifiers, key)] then
                table.insert(unbound, key)
            end
        end
        return unbound
    end

    local function pressF19()
        cheatsheet:hide()
        modal:enter()
    end

    local function releaseF19()
        cheatsheet:hide()
        modal:exit()
    end

    modal:bind({}, "tab", function()
        cheatsheet:show()
    end)

    for _, modifiers in ipairs({ {}, { "cmd" } }) do
        hs.hotkey.bind(modifiers, "f19", pressF19, releaseF19)
    end

    caffeinateWatcher = hs.caffeinate.watcher.new(function(event)
        if event == hs.caffeinate.watcher.systemDidWake
            or event == hs.caffeinate.watcher.screensDidUnlock then
            releaseF19()
        end
    end)
    caffeinateWatcher:start()

    return hyper
end

return M
