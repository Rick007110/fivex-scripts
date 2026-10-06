-- fivex_drone server: one drone per player. The pilot's client simulates it; the server sanity-checks
-- every update and relays it only to players near the drone (viewers). Pickup and shots are checked
-- against server-side positions.

local drones = {}     -- [owner] = { x, y, z, data, t, viewers = { [pid] = true } }
local lastDeploy = {}
local shotBucket = {}

local function L(key, ...)
    local pack = Locales[Config.Locale] or Locales['en'] or {}
    local s = pack[key] or key
    if select('#', ...) > 0 then
        return s:format(...)
    end
    return s
end

local function notify(src, key, ...)
    TriggerClientEvent('fivex_drone:notify', src, L(key, ...))
end

local function dbg(fmt, ...)
    if Config.Debug then print(('[fivex_drone] ' .. fmt):format(...)) end
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function allowed(src)
    if not Config.Ace then return true end
    return IsPlayerAceAllowed(src, Config.Ace)
end

local function finite(n)
    return type(n) == 'number' and n == n and n > -1e6 and n < 1e6
end

local function remove(owner, reason)
    local d = drones[owner]
    if not d then return end
    for pid in pairs(d.viewers) do
        TriggerClientEvent('fivex_drone:gone', pid, owner)
    end
    drones[owner] = nil
    TriggerClientEvent('fivex_drone:removed', owner, reason)
    dbg('drone of %s removed (%s)', owner, tostring(reason))
end

local function deploy(src, skipCooldown)
    if drones[src] then return end
    if not allowed(src) then
        TriggerClientEvent('fivex_drone:deployed', src, false)
        return notify(src, 'no_permission')
    end
    local now = GetGameTimer()
    if not skipCooldown and lastDeploy[src] and now - lastDeploy[src] < Config.DeployCooldown then
        TriggerClientEvent('fivex_drone:deployed', src, false)
        return notify(src, 'cooldown')
    end
    local c = pedCoords(src)
    if not c then return TriggerClientEvent('fivex_drone:deployed', src, false) end
    lastDeploy[src] = now
    drones[src] = { x = c.x, y = c.y, z = c.z, data = nil, t = 0, viewers = {} }
    TriggerClientEvent('fivex_drone:deployed', src, true)
    dbg('%s deployed a drone', src)
end

RegisterNetEvent('fivex_drone:deploy', function()
    deploy(source)
end)

-- drone stuck out of reach: leave it behind (it disappears for everyone) and unpack a new one
RegisterNetEvent('fivex_drone:abandon', function()
    local src = source
    if not Config.Abandon or not drones[src] then return end
    local now = GetGameTimer()
    if lastDeploy[src] and now - lastDeploy[src] < Config.DeployCooldown then
        TriggerClientEvent('fivex_drone:deployed', src, false)
        return notify(src, 'cooldown')
    end
    remove(src, 'abandoned')
    deploy(src, true)
end)

RegisterNetEvent('fivex_drone:state', function(data)
    local src = source
    local d = drones[src]
    if not d or type(data) ~= 'table' or #data < 13 then return end
    for i = 1, 13 do
        if not finite(data[i]) then return end
    end
    local now = GetGameTimer()
    local dt = (now - d.t) / 1000
    if dt < 0.04 then return end -- faster than any sane send rate

    -- no teleporting drones: at most ~90 m/s between updates
    local dx, dy, dz = data[1] - d.x, data[2] - d.y, data[3] - d.z
    local moved = math.sqrt(dx * dx + dy * dy + dz * dz)
    if d.data and moved > 90 * math.min(dt, 2.0) + 10 then return end
    -- and never far beyond radio range of the pilot
    local c = pedCoords(src)
    if c and #(c - vector3(data[1], data[2], data[3])) > Config.Signal.range * 2 + 250 then return end

    d.x, d.y, d.z, d.data, d.t = data[1], data[2], data[3], data, now
    for pid in pairs(d.viewers) do
        TriggerClientEvent('fivex_drone:state', pid, src, data)
    end
end)

-- kamikaze toggle: server decides (ACE), client explodes the drone itself
local kamikazeOn = {}

local function kamikazeAllowed(src)
    local K = Config.Kamikaze
    if not K.enabled then return false end
    if not K.ace then return true end
    return IsPlayerAceAllowed(src, K.ace)
end

RegisterNetEvent('fivex_drone:kamikaze', function(on)
    local src = source
    if on and not kamikazeAllowed(src) then
        on = false
        notify(src, 'no_permission_kamikaze')
    end
    kamikazeOn[src] = on == true
    TriggerClientEvent('fivex_drone:kamikaze', src, kamikazeOn[src])
end)

RegisterNetEvent('fivex_drone:detonated', function()
    local src = source
    if not drones[src] or not kamikazeOn[src] then return end
    dbg('%s detonated their drone', src)
    remove(src, 'kamikaze_boom')
end)

RegisterNetEvent('fivex_drone:pickup', function()
    local src = source
    local d = drones[src]
    if not d then return end
    local c = pedCoords(src)
    if not c or #(c - vector3(d.x, d.y, d.z)) > Config.Pickup.distance + 2.0 then return end
    remove(src)
end)

RegisterNetEvent('fivex_drone:shot', function(owner)
    local src = source
    owner = tonumber(owner)
    if not Config.Shootable or not owner or owner == src then return end
    local d = drones[owner]
    if not d or not d.viewers[src] then return end
    local now = GetGameTimer()
    if shotBucket[src] and now - shotBucket[src] < 250 then return end
    shotBucket[src] = now
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or GetSelectedPedWeapon(ped) == `WEAPON_UNARMED` then return end
    if #(GetEntityCoords(ped) - vector3(d.x, d.y, d.z)) > Config.ShotRange + 20 then return end
    dbg('%s shot down the drone of %s', src, owner)
    TriggerClientEvent('fivex_drone:hit', owner, src)
end)

-- who can see which drone (1 Hz)
CreateThread(function()
    while true do
        Wait(1000)
        if next(drones) then
            local coords = {}
            for _, p in ipairs(GetPlayers()) do
                local pid = tonumber(p)
                coords[pid] = pedCoords(pid)
            end
            local range = Config.Net.streamDistance
            for owner, d in pairs(drones) do
                if d.data then
                    local dp = vector3(d.x, d.y, d.z)
                    for pid, c in pairs(coords) do
                        if pid ~= owner then
                            local near = c ~= nil and #(c - dp) <= range
                            if near and not d.viewers[pid] then
                                d.viewers[pid] = true
                                TriggerClientEvent('fivex_drone:state', pid, owner, d.data)
                            elseif not near and d.viewers[pid] then
                                d.viewers[pid] = nil
                                TriggerClientEvent('fivex_drone:gone', pid, owner)
                            end
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    remove(src)
    for _, d in pairs(drones) do d.viewers[src] = nil end
    lastDeploy[src], shotBucket[src], kamikazeOn[src] = nil, nil, nil
end)
