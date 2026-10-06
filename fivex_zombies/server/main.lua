--[[
  fivex_zombies — server (authoritative apocalypse state + ped spawn)
  ACE: Config.AcePermission (default fivex_zombies), default-deny
]]

local apocalypseActive = false
local graceToken = 0

local function L(key, ...)
    local lang = Config.Locale or 'en'
    local pack = Locales and Locales[lang] or Locales and Locales['en'] or {}
    local str = pack[key] or key
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

local function hasAce(src)
    if src == 0 then return true end -- console
    return IsPlayerAceAllowed(src, Config.AcePermission)
end

local function announce(msg)
    local color = Config.ChatColor or { 200, 30, 30 }
    local prefix = Config.ChatPrefix or '[FiveX Zombies]'
    TriggerClientEvent('chat:addMessage', -1, {
        color = color,
        multiline = true,
        args = { prefix, msg },
    })
end

local function setActive(active)
    apocalypseActive = active and true or false
    -- outbreak start in cloud time, so every HUD shows the same elapsed clock
    GlobalState.fivex_zombies_since = apocalypseActive and os.time() or 0
    GlobalState.fivex_zombies_active = apocalypseActive
    TriggerClientEvent('fivex_zombies:setActive', -1, apocalypseActive)
end

local function startApocalypse(src)
    if apocalypseActive then
        if src and src > 0 then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 255, 180, 0 },
                args = { Config.ChatPrefix or '[FiveX Zombies]', L('already_active') },
            })
        end
        return
    end

    setActive(true)
    announce(L('start_announce'))
    if src and src > 0 then
        print(('[fivex_zombies] started by %s (%s)'):format(GetPlayerName(src) or '?', src))
    else
        print('[fivex_zombies] started from console')
    end

    -- Alarm + grace are client-driven from setActive(true); server also announces when infection begins
    graceToken = graceToken + 1
    local token = graceToken
    local grace = tonumber(Config.GraceSeconds) or 10
    SetTimeout(math.floor(grace * 1000), function()
        if token ~= graceToken or not apocalypseActive then return end
        announce(L('infection_begun'))
    end)
end

local function stopApocalypse(src)
    if not apocalypseActive then
        if src and src > 0 then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 255, 180, 0 },
                args = { Config.ChatPrefix or '[FiveX Zombies]', L('not_active') },
            })
        end
        return
    end

    graceToken = graceToken + 1
    setActive(false)
    announce(L('stop_announce'))
    if src and src > 0 then
        print(('[fivex_zombies] stopped by %s (%s)'):format(GetPlayerName(src) or '?', src))
    else
        print('[fivex_zombies] stopped from console')
    end
end

local function handleZombiesCommand(src, args)
    if not hasAce(src) then
        if src > 0 then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 255, 80, 80 },
                args = { Config.ChatPrefix or '[FiveX Zombies]', L('no_permission') },
            })
        end
        return
    end

    local sub = args[1] and string.lower(args[1]) or ''
    if sub == 'start' then
        startApocalypse(src)
    elseif sub == 'stop' then
        stopApocalypse(src)
    else
        local msg = L('usage')
        if src > 0 then
            TriggerClientEvent('chat:addMessage', src, {
                color = { 200, 200, 200 },
                args = { Config.ChatPrefix or '[FiveX Zombies]', msg },
            })
        else
            print('[fivex_zombies] ' .. msg)
        end
    end
end

RegisterCommand('zombies', function(source, args)
    handleZombiesCommand(source, args)
end, false)

RegisterCommand('apocalypse', function(source, args)
    handleZombiesCommand(source, args)
end, false)

-- Late joiners sync current state
AddEventHandler('playerJoining', function()
    -- state bag is enough; also push event shortly after spawn
end)

RegisterNetEvent('fivex_zombies:requestSync', function()
    local src = source
    TriggerClientEvent('fivex_zombies:setActive', src, apocalypseActive)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    GlobalState.fivex_zombies_active = false
    apocalypseActive = false
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if apocalypseActive then
        setActive(false)
    end
    GlobalState.fivex_zombies_active = false
end)

-- ============================================================
-- Server-side ped spawn (OneSync). Client CreatePed returns 0 here.
-- ============================================================
local serverPeds = {}          -- [ped] = { netId=, owner=, variant=, deleteAt=nil }
local function liveServerCount()
    local n = 0
    for ped, meta in pairs(serverPeds) do
        if DoesEntityExist(ped) then
            if not meta.deleteAt then
                n = n + 1
            end
        end
    end
    return n
end

local function countVariant(variant)
    local n = 0
    for ped, meta in pairs(serverPeds) do
        if meta.variant == variant and DoesEntityExist(ped) and not meta.deleteAt then
            n = n + 1
        end
    end
    return n
end

local function countOwnedBy(src)
    local n = 0
    for ped, meta in pairs(serverPeds) do
        if meta.owner == src and DoesEntityExist(ped) and not meta.deleteAt then
            n = n + 1
        end
    end
    return n
end

local function pruneServerPeds(forceAll)
    local now = GetGameTimer and GetGameTimer() or 0
    -- GetGameTimer exists on server in FiveM
    local rem = {}
    for ped, meta in pairs(serverPeds) do
        if forceAll or not DoesEntityExist(ped) then
            rem[#rem + 1] = ped
        elseif meta.deleteAt and GetGameTimer() >= meta.deleteAt then
            rem[#rem + 1] = ped
        end
    end
    for i = 1, #rem do
        local ped = rem[i]
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
        serverPeds[ped] = nil
    end
end

CreateThread(function()
    while true do
        Wait(2000)
        -- mark dead peds for delayed corpse despawn
        local linger = tonumber(Config.CorpseDespawnMs) or 60000
        for ped, meta in pairs(serverPeds) do
            if DoesEntityExist(ped) then
                local dead = false
                if IsPedDeadOrDying then
                    dead = IsPedDeadOrDying(ped, true)
                elseif IsEntityDead then
                    dead = IsEntityDead(ped)
                else
                    local health = GetEntityHealth(ped) or 0
                    dead = health <= 0
                end
                if dead and not meta.deleteAt then
                    meta.deleteAt = GetGameTimer() + linger
                end
            end
        end
        pruneServerPeds(false)
    end
end)

-- Recycle zombies nobody is near any more, so the caps go to where players are
CreateThread(function()
    while true do
        Wait(5000)
        if apocalypseActive and next(serverPeds) then
            local far = tonumber(Config.DespawnDistance) or 190.0
            local players = {}
            for _, id in ipairs(GetPlayers()) do
                local pp = GetPlayerPed(id)
                if pp and pp ~= 0 then players[#players + 1] = GetEntityCoords(pp) end
            end
            for ped, meta in pairs(serverPeds) do
                if DoesEntityExist(ped) and not meta.deleteAt then
                    local pos = GetEntityCoords(ped)
                    local near = false
                    for i = 1, #players do
                        if #(pos - players[i]) < far then near = true break end
                    end
                    if not near then meta.deleteAt = 0 end
                end
            end
            pruneServerPeds(false)
        end
    end
end)

local allowedSpawnModels = nil
local function rebuildAllowedSpawnModels()
    allowedSpawnModels = {}
    local list = Config.SpawnModels or {}
    for i = 1, #list do
        allowedSpawnModels[tonumber(list[i]) or list[i]] = true
    end
end

local spawnRate = {} -- src -> { windowStart=, count= }

local function rateLimitSpawn(src)
    local now = GetGameTimer()
    local windowMs = 1000
    local maxPerWindow = 24 -- a horde is up to 20 at once
    local st = spawnRate[src]
    if not st or (now - st.windowStart) > windowMs then
        spawnRate[src] = { windowStart = now, count = 1 }
        return true
    end
    st.count = st.count + 1
    return st.count <= maxPerWindow
end

RegisterNetEvent('fivex_zombies:requestSpawn', function(reqId, model, x, y, z, heading, variant, hunt)
    local src = source
    reqId = tonumber(reqId)
    variant = type(variant) == 'string' and Config.Variants and Config.Variants[variant] and variant or 'walker'
    model = tonumber(model)
    x, y, z, heading = tonumber(x), tonumber(y), tonumber(z), tonumber(heading)

    -- Return immediately; do CreatePed work on a thread so the net handler isn't blocked
    CreateThread(function()
        if not apocalypseActive or not reqId or not model or not x or not y or not z then
            if reqId then
                TriggerClientEvent('fivex_zombies:spawnResult', src, reqId, false, 0)
            end
            return
        end
        if not Config.SpawnEnabled then
            TriggerClientEvent('fivex_zombies:spawnResult', src, reqId, false, 0)
            return
        end

        if not allowedSpawnModels then rebuildAllowedSpawnModels() end
        if not allowedSpawnModels[model] then
            print(('[fivex_zombies] rejected non-allowlist model=%s from %s'):format(model, src))
            TriggerClientEvent('fivex_zombies:spawnResult', src, reqId, false, 0)
            return
        end

        if not rateLimitSpawn(src) then
            TriggerClientEvent('fivex_zombies:spawnResult', src, reqId, false, 0)
            return
        end

        heading = heading or 0.0
        pruneServerPeds(false)

        local vdef = Config.Variants[variant]
        if vdef and vdef.max and countVariant(variant) >= vdef.max then
            variant = 'runner'
        end

        local maxZ = tonumber(Config.MaxZombies) or 40
        local perPlayer = tonumber(Config.MaxZombiesPerPlayer) or 16
        if liveServerCount() >= maxZ or countOwnedBy(src) >= perPlayer then
            TriggerClientEvent('fivex_zombies:spawnResult', src, reqId, false, 0)
            return
        end

        local playerPed = GetPlayerPed(src)
        if not playerPed or playerPed == 0 then
            TriggerClientEvent('fivex_zombies:spawnResult', src, reqId, false, 0)
            return
        end
        local pcoords = GetEntityCoords(playerPed)
        local dist = #(vector3(x + 0.0, y + 0.0, z + 0.0) - vector3(pcoords.x, pcoords.y, pcoords.z))
        local hordeMax = Config.Hordes and Config.Hordes.distance and Config.Hordes.distance[2] or 0
        local rMax = math.max(tonumber(Config.SpawnRadiusMax) or 40.0, hordeMax) + 25.0
        if dist > rMax or dist < 2.0 then
            TriggerClientEvent('fivex_zombies:spawnResult', src, reqId, false, 0)
            return
        end

        local ped = CreatePed(4, model, x + 0.0, y + 0.0, z + 1.0, heading + 0.0, true, true)
        if not ped or ped == 0 then
            print(('[fivex_zombies] server CreatePed failed model=%s pos=%.2f %.2f %.2f'):format(model, x, y, z))
            TriggerClientEvent('fivex_zombies:spawnResult', src, reqId, false, 0)
            return
        end

        local deadline = GetGameTimer() + 2000
        while (not DoesEntityExist(ped) or NetworkGetNetworkIdFromEntity(ped) == 0) and GetGameTimer() < deadline do
            Wait(0)
        end

        if not DoesEntityExist(ped) then
            TriggerClientEvent('fivex_zombies:spawnResult', src, reqId, false, 0)
            return
        end

        local netId = NetworkGetNetworkIdFromEntity(ped)
        if not netId or netId == 0 then
            DeleteEntity(ped)
            TriggerClientEvent('fivex_zombies:spawnResult', src, reqId, false, 0)
            return
        end

        if SetEntityOrphanMode then
            SetEntityOrphanMode(ped, 2)
        end

        pcall(function()
            local st = Entity(ped).state
            st:set('fivex_zvar', variant, true)
            -- a horde is born hunting the player it was sent at; whoever owns it later keeps the chase
            if hunt then st:set('fivex_zhunt', src, true) end
            st:set('fivex_zombie', true, true)
        end)

        serverPeds[ped] = { netId = netId, owner = src, variant = variant, deleteAt = nil }
        TriggerClientEvent('fivex_zombies:spawnResult', src, reqId, true, netId)
    end)
end)

RegisterNetEvent('fivex_zombies:requestDespawn', function(netId)
    local src = source
    netId = tonumber(netId)
    if not netId then return end
    for ped, meta in pairs(serverPeds) do
        if meta.netId == netId then
            if meta.owner == src or IsPlayerAceAllowed(src, Config.AcePermission) then
                if DoesEntityExist(ped) then
                    DeleteEntity(ped)
                end
                serverPeds[ped] = nil
            end
            return
        end
    end
end)

local _stopApocalypse = stopApocalypse
stopApocalypse = function(src)
    pruneServerPeds(true)
    serverPeds = {}
    _stopApocalypse(src)
end

-- Dropped player: their KeepEntity zombies would otherwise linger and hold the global cap
AddEventHandler('playerDropped', function()
    local src = source
    spawnRate[src] = nil
    local rem = {}
    for ped, meta in pairs(serverPeds) do
        if meta.owner == src then
            rem[#rem + 1] = ped
        end
    end
    for i = 1, #rem do
        local ped = rem[i]
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
        serverPeds[ped] = nil
    end
end)

local _onStop = nil
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    pruneServerPeds(true)
    serverPeds = {}
end)

-- Export for other staff tools
exports('IsApocalypseActive', function()
    return apocalypseActive
end)

exports('StartApocalypse', function()
    startApocalypse(0)
end)

exports('StopApocalypse', function()
    stopApocalypse(0)
end)
