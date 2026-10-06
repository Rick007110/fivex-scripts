local JC = 'fivex_jobcenter'
local warned = false
local assignments = {} -- [src] = table
local vehNet = {}      -- [src] = netId
local recent = {}      -- [src] = { idx, idx, idx }
local buckets = {}
local vehCooldown = {} -- [src] = gameTimer
local reissueAt = {}

local function warnJc()
    if warned then return end
    warned = true
    print((Locales['en'] and Locales['en'].missing_jc) or '^1[fivex_coroner]^7 fivex_jobcenter is required and is not started. Resource will no-op.')
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
    return ('cor-%d-%d'):format(os.time(), math.random(10000, 99999))
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

local function pickCall(src)
    local pool = Config.Calls
    local used = recent[src] or {}
    local choices = {}
    for i = 1, #pool do
        local skip = false
        for u = 1, #used do
            if used[u] == i then skip = true break end
        end
        if not skip then choices[#choices + 1] = i end
    end
    if #choices == 0 then
        for i = 1, #pool do choices[i] = i end
    end
    local idx = choices[math.random(1, #choices)]
    used[#used + 1] = idx
    while #used > 3 do table.remove(used, 1) end
    recent[src] = used
    local pos = pool[idx]
    local models = Config.PedModels
    return pos, models[math.random(1, #models)]
end

local function sendAssign(src)
    local a = assignments[src]
    if not a then
        TriggerClientEvent('fivex_coroner:assignment', src, false)
        return
    end
    TriggerClientEvent('fivex_coroner:assignment', src, {
        id = a.id,
        x = a.x, y = a.y, z = a.z,
        pedModel = a.pedModel,
        step = a.step,
        cargo = a.cargo or 0,
        bagged = a.bagged and true or false,
    })
end

local function issue(src)
    if not hasDuty(src) then return end
    local pos, model = pickCall(src)
    assignments[src] = {
        id = newId(),
        x = pos.x, y = pos.y, z = pos.z,
        pedModel = model,
        step = 'recover',
        cargo = 0,
        bagged = false,
        loaded = false,
        issuedAt = GetGameTimer(),
    }
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
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    TriggerClientEvent('fivex_coroner:delVehicle', src)
end

local function clockOut(src, silent)
    jc('SetDuty', src, false)
    deleteVeh(src)
    clearAssign(src)
    reissueAt[src] = nil
    if not silent then notify(src, L('off_duty'), 'info') end
    TriggerClientEvent('fivex_coroner:duty', src, false)
end

local function failAssign(src, msg)
    local a = assignments[src]
    if not a then return end
    clearAssign(src)
    notify(src, msg or L('failed'), 'error')
    reissueAt[src] = GetGameTimer() + Config.NextDelay
end

RegisterNetEvent('fivex_coroner:clockIn', function()
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
    if dist(src, vector3(Config.Duty.x, Config.Duty.y, Config.Duty.z)) > Config.DutyRadius then
        return
    end
    if not jc('SetDuty', src, true) then return end
    notify(src, L('on_duty'), 'success')
    TriggerClientEvent('fivex_coroner:duty', src, true)
    TriggerClientEvent('fivex_coroner:spawnVehicle', src, {
        x = Config.Garage.x, y = Config.Garage.y, z = Config.Garage.z, w = Config.Garage.w,
    })
    issue(src)
end)

RegisterNetEvent('fivex_coroner:clockOut', function()
    local src = source
    if not jcReady() then return end
    if dist(src, vector3(Config.Duty.x, Config.Duty.y, Config.Duty.z)) > Config.DutyRadius + 6.0 then
        return
    end
    clockOut(src)
end)

RegisterNetEvent('fivex_coroner:vehicleSpawned', function(netId)
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

RegisterNetEvent('fivex_coroner:respawnVehicle', function()
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
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            notify(src, L('cooldown'), 'error')
            return
        end
    end
    TriggerClientEvent('fivex_coroner:spawnVehicle', src, {
        x = Config.Garage.x, y = Config.Garage.y, z = Config.Garage.z, w = Config.Garage.w,
    })
end)

RegisterNetEvent('fivex_coroner:bag', function(assignId)
    local src = source
    if not hasDuty(src) then return end
    if not rateOk(src, 'step', 8, 10000) then return end
    local a = assignments[src]
    if not a or a.id ~= assignId then return end
    if a.bagged then return end
    if dist(src, vector3(a.x, a.y, a.z)) > Config.PickupRadius then return end
    a.bagged = true
    a.step = 'load'
    sendAssign(src)
    notify(src, L('bagged'), 'success')
end)

RegisterNetEvent('fivex_coroner:load', function(assignId)
    local src = source
    if not hasDuty(src) then return end
    if not rateOk(src, 'step', 8, 10000) then return end
    local a = assignments[src]
    if not a or a.id ~= assignId then return end
    if not a.bagged or a.loaded then return end
    local netId = vehNet[src]
    if not netId then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) then
        notify(src, L('van_lost'), 'error')
        return
    end
    local vcoords = GetEntityCoords(veh)
    local pcoords = pedCoords(src)
    if not pcoords or #(pcoords - vcoords) > Config.LoadRadius + 4.0 then return end
    a.loaded = true
    a.cargo = 1
    a.step = 'deliver'
    sendAssign(src)
    notify(src, L('loaded'), 'success')
end)

RegisterNetEvent('fivex_coroner:deliver', function(assignId)
    local src = source
    if not hasDuty(src) then return end
    if not rateOk(src, 'step', 8, 10000) then return end
    local a = assignments[src]
    if not a or a.id ~= assignId then return end
    if not a.loaded or (a.cargo or 0) < 1 then return end
    if dist(src, Config.Delivery) > Config.DeliverRadius then return end
    local travel = #(vector3(a.x, a.y, a.z) - Config.Delivery)
    local minMs = math.max(Config.MinTaskMs or 8000, travel / (Config.MaxTravelSpeed or 60.0) * 1000.0)
    if GetGameTimer() - (a.issuedAt or 0) < minMs then return end
    local pay = Config.PayPerBody
    local bal = jc('AddPay', src, pay, 'coroner body')
    clearAssign(src)
    if bal then
        notify(src, L('paid'), 'success')
    end
    reissueAt[src] = GetGameTimer() + Config.NextDelay
    TriggerClientEvent('fivex_coroner:delivered', src)
end)

RegisterNetEvent('fivex_coroner:fail', function(assignId, reason)
    local src = source
    if not hasDuty(src) then return end
    local a = assignments[src]
    if not a or a.id ~= assignId then return end
    reason = tostring(reason or '')
    if reason == 'dead' then
        local ped = GetPlayerPed(src)
        if GetEntityHealth(ped) > 100 then return end
    elseif reason == 'van' then
        local netId = vehNet[src]
        if netId then
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent and ent ~= 0 and DoesEntityExist(ent) and not IsEntityDead(ent) then
                return
            end
        end
        vehNet[src] = nil
    else
        return
    end
    failAssign(src, L('failed'))
end)

AddEventHandler('fivex_jobcenter:internalCancel', function(src)
    src = tonumber(src)
    if not src or not assignments[src] then return end
    failAssign(src, L('cancelled'))
end)

AddEventHandler('fivex_jobcenter:jobChanged', function(src, oldJob, _new)
    src = tonumber(src)
    if oldJob == Config.JobId or (assignments[src] or vehNet[src]) then
        deleteVeh(src)
        clearAssign(src)
        reissueAt[src] = nil
        TriggerClientEvent('fivex_coroner:duty', src, false)
    end
end)

AddEventHandler('fivex_jobcenter:dutyChanged', function(src, jobId, duty)
    src = tonumber(src)
    if jobId == Config.JobId and not duty then
        deleteVeh(src)
        clearAssign(src)
        TriggerClientEvent('fivex_coroner:duty', src, false)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    deleteVeh(src)
    assignments[src] = nil
    recent[src] = nil
    reissueAt[src] = nil
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
                local ped = GetPlayerPed(src)
                if ped and ped ~= 0 and GetEntityHealth(ped) <= 100 then
                    -- still dead: hold the next call until they respawn
                    -- (updating an existing key is safe during pairs; re-adding a cleared one is not)
                    reissueAt[src] = now + 3000
                else
                    reissueAt[src] = nil
                    if hasDuty(src) and not assignments[src] then
                        issue(src)
                    end
                end
            end
        end
    end
end)
