local spawnedProps = {}
local spawnedPeds = {}
local NEARBY_CAP = 40

local function requestModel(hash, timeout)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then
        return false
    end
    RequestModel(hash)
    local t = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > t then
            return false
        end
        Wait(10)
    end
    return true
end

local function spawnPoint(dist)
    dist = dist or 2.5
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local rad = math.rad(h)
    local x = c.x - math.sin(rad) * dist
    local y = c.y + math.cos(rad) * dist
    return x, y, c.z, h
end

local function track(list, ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        list[#list + 1] = ent
        while #list > 80 do
            table.remove(list, 1)
        end
    end
end

local function deleteLast(list, label)
    for i = #list, 1, -1 do
        local ent = list[i]
        list[i] = nil
        if ent and DoesEntityExist(ent) then
            SetEntityAsMissionEntity(ent, true, true)
            DeleteEntity(ent)
            Notify(L('entity_deleted_last', label), 'success')
            return true
        end
    end
    Notify(L('entity_none_tracked', label), 'error')
    return false
end

local function inRadius(ent, origin, radius)
    if not ent or not DoesEntityExist(ent) then return false end
    return #(GetEntityCoords(ent) - origin) <= radius
end

local function catalogHashSet(catalog)
    local set = {}
    for i = 1, #catalog do
        set[joaat(catalog[i].model)] = true
    end
    return set
end

RegisterNetEvent('fivex_admin:spawnEntity', function(kind, payload)
    payload = payload or {}
    local model = payload.model
    if type(model) ~= 'string' then
        Notify(L('invalid_model'), 'error')
        return
    end
    model = string.lower(model)

    if kind == 'prop' then
        if not FindPropInCatalog(model) then
            Notify(L('invalid_model'), 'error')
            return
        end
        local hash = joaat(model)
        if not IsModelInCdimage(hash) or not IsModelValid(hash) then
            Notify(L('invalid_model'), 'error')
            return
        end
        if not requestModel(hash, 6000) then
            Notify(L('invalid_model'), 'error')
            return
        end
        local x, y, z, h = spawnPoint(2.2)
        local obj = CreateObject(hash, x, y, z, true, true, false)
        SetModelAsNoLongerNeeded(hash)
        if not obj or obj == 0 then
            Notify(L('invalid_model'), 'error')
            return
        end
        SetEntityHeading(obj, h)
        PlaceObjectOnGroundProperly(obj)
        SetEntityAsMissionEntity(obj, true, true)
        if payload.frozen then
            FreezeEntityPosition(obj, true)
        end
        track(spawnedProps, obj)
        Notify(L('entity_spawned', model), 'success')
        return
    end

    if kind == 'ped' then
        local def = FindPedInCatalog(model)
        if not def then
            Notify(L('invalid_model'), 'error')
            return
        end
        local hash = joaat(model)
        if not IsModelInCdimage(hash) or not IsModelValid(hash) then
            Notify(L('invalid_model'), 'error')
            return
        end
        if not requestModel(hash, 6000) then
            Notify(L('invalid_model'), 'error')
            return
        end
        local x, y, z, h = spawnPoint(2.6)
        local pedType = 4
        if def.category == 'Animals' then pedType = 28 end
        local ped = CreatePed(pedType, hash, x, y, z, h, true, false)
        SetModelAsNoLongerNeeded(hash)
        if not ped or ped == 0 then
            Notify(L('invalid_model'), 'error')
            return
        end
        SetEntityAsMissionEntity(ped, true, true)
        SetPedDefaultComponentVariation(ped)
        SetBlockingOfNonTemporaryEvents(ped, true)
        if payload.frozen then
            FreezeEntityPosition(ped, true)
        end
        track(spawnedPeds, ped)
        Notify(L('entity_spawned', model), 'success')
    end
end)

RegisterNetEvent('fivex_admin:deleteEntities', function(kind, mode, radius)
    radius = tonumber(radius) or Config.DeleteRadius or 8.0
    if kind == 'prop' then
        if mode == 'last' then
            deleteLast(spawnedProps, 'prop')
            return
        end
        local origin = GetEntityCoords(PlayerPedId())
        local allowed = catalogHashSet(PropCatalog)
        local n = 0
        local pool = GetGamePool('CObject')
        for i = 1, #pool do
            if n >= NEARBY_CAP then break end
            local obj = pool[i]
            if inRadius(obj, origin, radius) then
                local model = GetEntityModel(obj)
                local ours = false
                for k = 1, #spawnedProps do
                    if spawnedProps[k] == obj then ours = true break end
                end
                if ours or (allowed[model] and (IsEntityAMissionEntity(obj) or NetworkGetEntityIsNetworked(obj))) then
                    SetEntityAsMissionEntity(obj, true, true)
                    DeleteObject(obj)
                    n = n + 1
                end
            end
        end
        for i = #spawnedProps, 1, -1 do
            if not DoesEntityExist(spawnedProps[i]) then
                table.remove(spawnedProps, i)
            end
        end
        Notify(L('entity_deleted_nearby', n, 'props'), 'success')
        return
    end

    if kind == 'ped' then
        if mode == 'last' then
            deleteLast(spawnedPeds, 'ped')
            return
        end
        local origin = GetEntityCoords(PlayerPedId())
        local allowed = catalogHashSet(PedCatalog)
        local n = 0
        local pool = GetGamePool('CPed')
        for i = 1, #pool do
            if n >= NEARBY_CAP then break end
            local ped = pool[i]
            if ped and DoesEntityExist(ped) and not IsPedAPlayer(ped) and inRadius(ped, origin, radius) then
                local model = GetEntityModel(ped)
                local ours = false
                for k = 1, #spawnedPeds do
                    if spawnedPeds[k] == ped then ours = true break end
                end
                if ours or allowed[model] then
                    SetEntityAsMissionEntity(ped, true, true)
                    DeletePed(ped)
                    n = n + 1
                end
            end
        end
        for i = #spawnedPeds, 1, -1 do
            if not DoesEntityExist(spawnedPeds[i]) then
                table.remove(spawnedPeds, i)
            end
        end
        Notify(L('entity_deleted_nearby', n, 'peds'), 'success')
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for i = 1, #spawnedProps do
        local e = spawnedProps[i]
        if e and DoesEntityExist(e) then
            SetEntityAsMissionEntity(e, true, true)
            DeleteEntity(e)
        end
    end
    for i = 1, #spawnedPeds do
        local e = spawnedPeds[i]
        if e and DoesEntityExist(e) and not IsPedAPlayer(e) then
            SetEntityAsMissionEntity(e, true, true)
            DeleteEntity(e)
        end
    end
end)
