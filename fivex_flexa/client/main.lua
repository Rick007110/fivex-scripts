--[[
    fivex_flexa — the foldable.
    Flexa is sd-phone. Unfolding opens the same phone sideways to a double-width screen (sd-phone's
    foldable body): one device, so the open app, lock state, calls and data all carry straight over.
    sd-phone remembers which way it was left and comes back out that way.
]]

local PHONE = 'sd-phone'

local function dbg(fmt, ...)
    if Config.Debug then print(('[fivex_flexa] ' .. fmt):format(...)) end
end

-- export call that never throws (sd-phone may be restarting)
local function call(fn, ...)
    if GetResourceState(PHONE) ~= 'started' then return nil end
    local ok, r = pcall(function(...)
        local exp = exports[PHONE]
        return exp[fn](exp, ...)
    end, ...)
    if not ok then dbg('%s failed: %s', fn, tostring(r)) return nil end
    return r
end

local function isOpen() return call('isOpen') == true end
local function isFolded() return call('isFolded') ~= true end

local function toggle()
    if isOpen() then call('close') else call('open') end
end

-- the hinge: also the Unfold / Fold button on the phone's rail
local function toggleFold()
    if not isOpen() then return end
    local unfolded = call('setFolded', nil)
    dbg(unfolded and 'unfolded' or 'folded')
end

RegisterCommand(Config.OpenCommand, function() CreateThread(toggle) end, false)
RegisterKeyMapping(Config.OpenCommand, 'Open / close Flexa', 'keyboard', Config.OpenKey)
RegisterCommand(Config.FoldCommand, function() CreateThread(toggleFold) end, false)
RegisterKeyMapping(Config.FoldCommand, 'Fold / unfold Flexa (while open)', 'keyboard', Config.FoldKey)

-- ── Exports ──────────────────────────────────────────────
exports('IsOpen', isOpen)
exports('IsFolded', isFolded)
exports('ClosePhone', function() call('close') end)
exports('Open', function() if not isOpen() then CreateThread(function() call('open') end) end end)
exports('SetFolded', function(wantFolded)
    if isOpen() then call('setFolded', wantFolded == false) end
end)

-- ── App API (v2 compatibility) ───────────────────────────
-- Apps registered with exports.fivex_flexa:RegisterApp become sd-phone custom apps, so they
-- show up on both the phone and the tablet. Pages keep using html/sdk/flexa-app.js.
local apps = {} -- [id] = { resource, label }

local function resourceUrl(res, path)
    if type(path) ~= 'string' or path == '' then return nil end
    if path:find('^https?://') or path:find('^nui://') then return path end
    return ('https://cfx-nui-%s/%s'):format(res, (path:gsub('^/', '')))
end

local function ownApp(id)
    local a = type(id) == 'string' and apps[id] or nil
    return a ~= nil and a.resource == GetInvokingResource(), a
end

exports('RegisterApp', function(def)
    local res = GetInvokingResource()
    if not res or type(def) ~= 'table' or type(def.id) ~= 'string' or not def.id:match('^[%w_%-]+$') then return false end
    if apps[def.id] and apps[def.id].resource ~= res then return false end
    local ok, err = call('addCustomApp', {
        identifier = def.id,
        name = tostring(def.label or def.id):sub(1, 24),
        description = tostring(def.blurb or ''):sub(1, 200),
        developer = res,
        ui = resourceUrl(res, def.page or 'html/index.html'),
        icon = resourceUrl(res, def.iconUrl),
        defaultApp = def.defaultInstalled == true,
    })
    if ok == false or ok == nil then
        print(('[fivex_flexa] %s: could not register app "%s" with sd-phone: %s'):format(res, def.id, tostring(err)))
        return false
    end
    apps[def.id] = { resource = res, label = tostring(def.label or def.id) }
    return true
end)

exports('UnregisterApp', function(id)
    if not ownApp(id) then return false end
    apps[id] = nil
    call('removeCustomApp', id)
    return true
end)

exports('SendAppMessage', function(id, data)
    if not ownApp(id) then return false end
    return call('sendCustomAppMessage', id, { action = 'flexa:message', data = data }) == true
end)

exports('Notify', function(id, item)
    local mine, a = ownApp(id)
    if not mine or type(item) ~= 'table' then return false end
    call('showNotification', {
        app = a.label, appId = id,
        title = tostring(item.title or a.label):sub(1, 60),
        body = tostring(item.body or ''):sub(1, 140),
    })
    return true
end)

exports('OpenApp', function(id)
    if type(id) ~= 'string' then return false end
    CreateThread(function()
        -- reopened by an app (e.g. KnoWay after picking a spot on the map): go straight into it,
        -- not to the lock screen the player just left
        if not isOpen() then call('open', { unlocked = true }) end
        call('openApp', id)
    end)
    return true
end)

exports('IsAppInstalled', function(id) return apps[id] ~= nil end)

-- apps re-register when this fires (Flexa or sd-phone restarted)
local function announceReady()
    SetTimeout(500, function() TriggerEvent('fivex_flexa:ready') end)
end
AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() or res == PHONE then announceReady() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(apps) do call('removeCustomApp', id) end
end)

-- an app's own resource stopped: take its icon away (it re-registers when it starts again)
AddEventHandler('onClientResourceStop', function(res)
    for id, a in pairs(apps) do
        if a.resource == res then
            apps[id] = nil
            call('removeCustomApp', id)
        end
    end
end)
