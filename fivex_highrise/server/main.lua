local JC = 'fivex_jobcenter'
local warned = false
local assignments = {}
local vehNet = {}
local recent = {}
local buckets = {}
local vehCooldown = {}
local reissueAt = {}
local fellLock = {}

local function warnJc()
    if warned then return end
    warned = true
    print((Locales['en'] and Locales['en'].missing_jc) or '^1[fivex_highrise]^7 fivex_jobcenter is required and is not started. Resource will no-op.')
end

local function jcReady()
    if GetResourceState(JC) ~= 'started' then
        warnJc()
        return false
    end
    return true
end

local function jc(fn, ...)
    if not jcReady() then return nil end
    local exp = exports[JC]
    local ok, a, b = pcall(exp[fn], exp, ...)
    if not ok then return nil end
    return a, b
end

local function L(key, ...)
    local pack = Locales[Config.Locale] or Locales['en'] or {}
    local s = pack[key] or key
    if select('#', ...) > 0 then return s:format(...) end
    return s
end

local function notify(src, msg, typ)
    TriggerClientEvent('fivex_jobcenter:notify', src, msg, typ or 'info')
end

local function rateOk(src, key, maxN, windowMs)
    local now = GetGameTimer()
    local id = tostring(src) .. ':' .. key
    local b = buckets[id]
    if not b or (now - b.start) > windowMs then
        buckets[id] = { start = now, n = 1 }
        return true
    end
    if b.n >= maxN then return false end
    b.n = b.n + 1
    return true
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function dist(src, vec)
    local c = pedCoords(src)
    if not c then return 9999.0 end
    return #(c - vec)
end

local function hasDuty(src)
    return jc('HasJob', src, Config.JobId) and jc('IsDuty', src)
end

local function newId()
    return ('hr-%d-%d'):format(os.time(), math.random(10000, 99999))
end

-- Resolve a client-reported netId to a job vehicle this player actually created.
-- Waits briefly because the event can arrive before the entity's creation has synced.
local function ownedJobVehicle(src, netId, models)
    local ent = 0
    local deadline = GetGameTimer() + 3000
    repeat
        ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then break end
        Wait(100)
    until GetGameTimer() > deadline
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if GetEntityType(ent) ~= 2 then return nil end
    local m = GetEntityModel(ent) & 0xFFFFFFFF
    local okModel = false
    for i = 1, #models do
        if (models[i] & 0xFFFFFFFF) == m then okModel = true break end
    end
    if not okModel then return nil end
    local owner = NetworkGetFirstEntityOwner and NetworkGetFirstEntityOwner(ent) or NetworkGetEntityOwner(ent)
    if owner ~= src then return nil end
    return ent
end

local function findBuilding(id)
    for i = 1, #Config.Buildings do
        if Config.Buildings[i].id == id then return Config.Buildings[i], i end
    end
end

local function pickBuilding(src)
    local pool = Config.Buildings
    local last = recent[src]
    local choices = {}
    for i = 1, #pool do
        if pool[i].id ~= last then choices[#choices + 1] = i end
    end
    if #choices == 0 then
        for i = 1, #pool do choices[i] = i end
    end
    local idx = choices[math.random(1, #choices)]
    recent[src] = pool[idx].id
    return pool[idx]
end

local function payload(a)
    if not a then return false end
    local done = 0
    local n = a.total
    for i = 1, n do
        if a.done[i] then done = done + 1 end
    end
    return {
        id = a.id,
        building = a.building,
        label = a.label,
        step = a.step,
        total = n,
        done = done,
        door = a.door,
        roof = a.roof,
        groundReturn = a.groundReturn,
        windows = a.windows,
        doneFlags = a.done,
    }
end

local function sendAssign(src)
    TriggerClientEvent('fivex_highrise:assignment', src, payload(assignments[src]))
end

local function issue(src)
    if not hasDuty(src) then return end
    local b = pickBuilding(src)
    local flags = {}
    for i = 1, #b.windows do flags[i] = false end
    assignments[src] = {
        id = newId(),
        building = b.id,
        label = b.label,
        step = 'drive',
        door = { x = b.groundDoor.x, y = b.groundDoor.y, z = b.groundDoor.z },
        roof = { x = b.roof.x, y = b.roof.y, z = b.roof.z, w = b.roof.w },
        groundReturn = { x = b.groundReturn.x, y = b.groundReturn.y, z = b.groundReturn.z, w = b.groundReturn.w },
        windows = b.windows,
        done = flags,
        total = #b.windows,
        lifted = false,
        airborne = false,
    }
    fellLock[src] = false
    sendAssign(src)
end

local function clearAssign(src)
    assignments[src] = nil
    sendAssign(src)
end

local function deleteVeh(src)
    local netId = vehNet[src]
    vehNet[src] = nil
    if netId then
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    TriggerClientEvent('fivex_highrise:delVehicle', src)
end

local function clockOut(src, silent)
    jc('SetDuty', src, false)
    deleteVeh(src)
    clearAssign(src)
    reissueAt[src] = nil
    fellLock[src] = nil
    if not silent then notify(src, L('off_duty'), 'info') end
    TriggerClientEvent('fivex_highrise:duty', src, false)
end

RegisterNetEvent('fivex_highrise:clockIn', function()
    local src = source
    if not jcReady() then return end
    if not rateOk(src, 'clock', 6, 10000) then return end
    if not jc('HasJob', src, Config.JobId) then
        notify(src, L('need_job'), 'error')
        return
    end
    if jc('IsDuty', src) then
        clockOut(src)
        return
    end
    if dist(src, vector3(Config.Duty.x, Config.Duty.y, Config.Duty.z)) > Config.DutyRadius then return end
    if not jc('SetDuty', src, true) then return end
    notify(src, L('on_duty'), 'success')
    TriggerClientEvent('fivex_highrise:duty', src, true)
    TriggerClientEvent('fivex_highrise:spawnVehicle', src, {
        x = Config.Garage.x, y = Config.Garage.y, z = Config.Garage.z, w = Config.Garage.w,
    })
    issue(src)
end)

RegisterNetEvent('fivex_highrise:vehicleSpawned', function(netId)
    local src = source
    if not hasDuty(src) then return end
    netId = tonumber(netId)
    if not netId then return end
    local ent = ownedJobVehicle(src, netId, { Config.Vehicle.model })
    if not ent then return end
    local now = GetGameTimer()
    if vehCooldown[src] and now < vehCooldown[src] and vehNet[src] then
        notify(src, L('cooldown'), 'error')
        return
    end
    if vehNet[src] and vehNet[src] ~= netId then
        local old = NetworkGetEntityFromNetworkId(vehNet[src])
        if old and old ~= 0 and DoesEntityExist(old) then DeleteEntity(old) end
    end
    vehNet[src] = netId
    vehCooldown[src] = now + Config.VehicleCooldown
end)

RegisterNetEvent('fivex_highrise:respawnVehicle', function()
    local src = source
    if not hasDuty(src) then return end
    if dist(src, vector3(Config.Garage.x, Config.Garage.y, Config.Garage.z)) > 8.0 then return end
    local now = GetGameTimer()
    if vehCooldown[src] and now < vehCooldown[src] then
        notify(src, L('cooldown'), 'error')
        return
    end
    local existing = vehNet[src]
    if existing then
        local ent = NetworkGetEntityFromNetworkId(existing)
        if ent and ent ~= 0 and DoesEntityExist(ent) then return end
    end
    TriggerClientEvent('fivex_highrise:spawnVehicle', src, {
        x = Config.Garage.x, y = Config.Garage.y, z = Config.Garage.z, w = Config.Garage.w,
    })
end)

RegisterNetEvent('fivex_highrise:liftUp', function(assignId)
    local src = source
    if not hasDuty(src) then return end
    if not rateOk(src, 'step', 8, 10000) then return end
    local a = assignments[src]
    if not a or a.id ~= assignId then return end
    if dist(src, vector3(a.door.x, a.door.y, a.door.z)) > Config.DoorRadius then return end
    a.lifted = true
    a.liftedAt = GetGameTimer()
    a.airborne = false
    a.step = 'scrub'
    sendAssign(src)
    TriggerClientEvent('fivex_highrise:teleport', src, a.roof, Config.GiveParachute)
end)

RegisterNetEvent('fivex_highrise:roofReady', function(assignId)
    local src = source
    if not hasDuty(src) then return end
    local a = assignments[src]
    if not a or a.id ~= assignId then return end
    if not a.lifted then return end
    if dist(src, vector3(a.roof.x, a.roof.y, a.roof.z)) > 20.0 then return end
    a.airborne = true
end)

RegisterNetEvent('fivex_highrise:scrub', function(assignId, index)
    local src = source
    if not hasDuty(src) then return end
    if not rateOk(src, 'step', 12, 10000) then return end
    local a = assignments[src]
    if not a or a.id ~= assignId then return end
    if not a.lifted then return end
    index = tonumber(index)
    if not index or not a.windows[index] then return end
    if a.done[index] then return end
    local w = a.windows[index]
    if dist(src, vector3(w.x, w.y, w.z)) > Config.WindowRadius then return end
    a.done[index] = true
    local all = true
    for i = 1, a.total do
        if not a.done[i] then all = false break end
    end
    if all then a.step = 'down' end
    sendAssign(src)
end)

RegisterNetEvent('fivex_highrise:complete', function(assignId)
    local src = source
    if not hasDuty(src) then return end
    if not rateOk(src, 'step', 8, 10000) then return end
    local a = assignments[src]
    if not a or a.id ~= assignId then return end
    for i = 1, a.total do
        if not a.done[i] then return end
    end
    if dist(src, vector3(a.roof.x, a.roof.y, a.roof.z)) > 25.0 then return end
    local scrubMs = (Config.Anim.scrub and Config.Anim.scrub.ms) or 3000
    local minMs = math.max(Config.MinTaskMs or 8000, a.total * scrubMs * (Config.MinScrubFactor or 0.75))
    if not a.liftedAt or GetGameTimer() - a.liftedAt < minMs then return end
    local pay = Config.PayPerBuilding
    jc('AddPay', src, pay, 'highrise ' .. a.building)
    notify(src, L('paid'), 'success')
    TriggerClientEvent('fivex_highrise:teleport', src, a.groundReturn, false)
    clearAssign(src)
    reissueAt[src] = GetGameTimer() + Config.NextDelay
end)

RegisterNetEvent('fivex_highrise:fell', function(assignId)
    local src = source
    if not hasDuty(src) then return end
    if fellLock[src] then return end
    local a = assignments[src]
    if not a or a.id ~= assignId then return end
    if not a.lifted or not a.airborne then return end
    local c = pedCoords(src)
    if not c then return end
    if c.z >= (a.roof.z - Config.FallGrace) then return end
    fellLock[src] = true
    notify(src, L('failed'), 'error')
    TriggerClientEvent('fivex_highrise:teleport', src, {
        x = Config.Duty.x, y = Config.Duty.y, z = Config.Duty.z, w = Config.Duty.w,
    }, false)
    clearAssign(src)
    reissueAt[src] = GetGameTimer() + Config.NextDelay
end)

AddEventHandler('fivex_jobcenter:internalCancel', function(src)
    src = tonumber(src)
    if not src or not assignments[src] then return end
    clearAssign(src)
    notify(src, L('cancelled'), 'info')
    reissueAt[src] = GetGameTimer() + Config.NextDelay
end)

AddEventHandler('fivex_jobcenter:jobChanged', function(src, oldJob)
    src = tonumber(src)
    if oldJob == Config.JobId or assignments[src] or vehNet[src] then
        deleteVeh(src)
        clearAssign(src)
        reissueAt[src] = nil
        TriggerClientEvent('fivex_highrise:duty', src, false)
    end
end)

AddEventHandler('fivex_jobcenter:dutyChanged', function(src, jobId, duty)
    src = tonumber(src)
    if jobId == Config.JobId and not duty then
        deleteVeh(src)
        clearAssign(src)
        TriggerClientEvent('fivex_highrise:duty', src, false)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    deleteVeh(src)
    assignments[src] = nil
    recent[src] = nil
    reissueAt[src] = nil
    fellLock[src] = nil
    vehCooldown[src] = nil
end)

CreateThread(function()
    Wait(500)
    jcReady()
end)

CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for src, t in pairs(reissueAt) do
            if t and now >= t then
                reissueAt[src] = nil
                if hasDuty(src) and not assignments[src] then
                    issue(src)
                end
            end
        end
    end
end)

findBuilding = findBuilding
