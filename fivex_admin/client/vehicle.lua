local VEH_KVP = 'fivex_admin:savedVehicles'
local windowsDown = false
local doorState = {}

--- OneSync: only the owner can delete a networked entity. Request control (bounded wait).
function TakeEntityControl(ent, timeout)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return false end
    if not NetworkGetEntityIsNetworked(ent) or NetworkHasControlOfEntity(ent) then return true end
    local deadline = GetGameTimer() + (timeout or 1000)
    NetworkRequestControlOfEntity(ent)
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < deadline do
        Wait(0)
        if not DoesEntityExist(ent) then return false end
        NetworkRequestControlOfEntity(ent)
    end
    return NetworkHasControlOfEntity(ent)
end

function VehicleHasPlayerDriver(veh)
    local driver = GetPedInVehicleSeat(veh, -1)
    return driver ~= 0 and IsPedAPlayer(driver)
end

local function currentVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    return nil
end

local function closestVehicle(radius)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local veh = GetClosestVehicle(c.x, c.y, c.z, radius or 6.0, 0, 71)
    if veh ~= 0 and DoesEntityExist(veh) then return veh end
    return nil
end

local function requestModel(hash, timeout)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
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

local function spawnModel(model)
    local hash = joaat(model)
    if not requestModel(hash, 6000) then
        Notify(L('invalid_model'), 'error')
        return
    end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local old = GetVehiclePedIsIn(ped, false)
    if old ~= 0 then
        SetEntityAsMissionEntity(old, true, true)
        DeleteVehicle(old)
    end
    local veh = CreateVehicle(hash, c.x, c.y, c.z, h, true, false)
    if veh == 0 then
        SetModelAsNoLongerNeeded(hash)
        Notify(L('invalid_model'), 'error')
        return
    end
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehRadioStation(veh, 'OFF')
    SetModelAsNoLongerNeeded(hash)
    return veh
end

local function readSaved()
    local raw = GetResourceKvpString(VEH_KVP)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return {}
end

local function writeSaved(list)
    SetResourceKvp(VEH_KVP, json.encode(list))
end

function LoadSavedVehicles()
    return readSaved()
end

local function captureProps(veh)
    local extras = {}
    for i = 0, 14 do
        if DoesExtraExist(veh, i) then
            extras[tostring(i)] = IsVehicleExtraTurnedOn(veh, i)
        end
    end
    local c1, c2 = GetVehicleColours(veh)
    local pearlescent, wheel = GetVehicleExtraColours(veh)
    return {
        model = GetDisplayNameFromVehicleModel(GetEntityModel(veh)):lower(),
        hash = GetEntityModel(veh),
        plate = GetVehicleNumberPlateText(veh),
        livery = GetVehicleLivery(veh),
        tint = GetVehicleWindowTint(veh),
        extras = extras,
        colours = { c1, c2, pearlescent, wheel },
        xenon = IsToggleModOn(veh, 22),
        xenonColor = GetVehicleXenonLightsColor(veh),
    }
end

local function applyProps(veh, props)
    if not props then return end
    if props.plate then SetVehicleNumberPlateText(veh, props.plate) end
    if props.livery then SetVehicleLivery(veh, props.livery) end
    if props.tint then SetVehicleWindowTint(veh, props.tint) end
    if props.colours then
        SetVehicleColours(veh, props.colours[1] or 0, props.colours[2] or 0)
        SetVehicleExtraColours(veh, props.colours[3] or 0, props.colours[4] or 0)
    end
    if props.extras then
        for k, on in pairs(props.extras) do
            local idx = tonumber(k)
            if idx and DoesExtraExist(veh, idx) then
                SetVehicleExtra(veh, idx, on and 0 or 1)
            end
        end
    end
    if props.xenon then
        ToggleVehicleMod(veh, 22, true)
        if props.xenonColor then
            SetVehicleXenonLightsColor(veh, props.xenonColor)
        end
    end
end

local function toggleDoor(veh, index)
    doorState[index] = not doorState[index]
    if doorState[index] then
        SetVehicleDoorOpen(veh, index, false, false)
    else
        SetVehicleDoorShut(veh, index, false)
    end
end

RegisterNetEvent('fivex_admin:applyVehicle', function(actionId, payload)
    payload = payload or {}
    local ped = PlayerPedId()

    if actionId == 'veh.spawn' then
        if type(payload.model) ~= 'string' or not FindVehicleInCatalog(payload.model) then
            Notify(L('invalid_model'), 'error')
            return
        end
        local hash = joaat(payload.model)
        if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
            Notify(L('invalid_model'), 'error')
            return
        end
        spawnModel(payload.model)
        return
    end

    if actionId == 'veh.saved.spawn' then
        local list = readSaved()
        for i = 1, #list do
            if list[i].id == payload.id then
                local veh = spawnModel(list[i].model)
                if veh then applyProps(veh, list[i].props) end
                return
            end
        end
        return
    end

    if actionId == 'veh.saved.delete' then
        local list = readSaved()
        for i = 1, #list do
            if list[i].id == payload.id then
                table.remove(list, i)
                writeSaved(list)
                Notify(L('deleted'), 'success')
                if MenuOpen then
                    SendNUIMessage({ type = 'savedVehicles', vehicles = list })
                end
                return
            end
        end
        return
    end

    if actionId == 'veh.enter' then
        local veh = closestVehicle(7.0)
        if not veh then
            Notify(L('no_vehicle_near'), 'error')
            return
        end
        TaskWarpPedIntoVehicle(ped, veh, -1)
        return
    end

    if actionId == 'veh.deleteNearby' then
        local c = GetEntityCoords(ped)
        local radius = tonumber(payload.radius) or Config.DeleteRadius
        local pool = GetGamePool('CVehicle')
        local n = 0
        local mine = GetVehiclePedIsIn(ped, false)
        for i = 1, #pool do
            local veh = pool[i]
            if veh ~= mine and DoesEntityExist(veh) and #(GetEntityCoords(veh) - c) <= radius
                and not VehicleHasPlayerDriver(veh) and TakeEntityControl(veh) then
                SetEntityAsMissionEntity(veh, true, true)
                DeleteVehicle(veh)
                if not DoesEntityExist(veh) then
                    n = n + 1
                end
            end
        end
        Notify(('Deleted %s nearby vehicles'):format(n), 'success')
        return
    end

    local veh = currentVehicle()
    if actionId == 'veh.save' then
        if not veh then Notify(L('no_vehicle'), 'error') return end
        local list = readSaved()
        local hash = GetEntityModel(veh)
        local modelName = GetDisplayNameFromVehicleModel(hash):lower()
        for i = 1, #VehicleCatalog do
            if joaat(VehicleCatalog[i].model) == hash then
                modelName = VehicleCatalog[i].model
                break
            end
        end
        list[#list + 1] = {
            id = tostring(GetGameTimer()) .. '-' .. tostring(math.random(1000, 9999)),
            name = payload.name or 'Saved',
            model = modelName,
            props = captureProps(veh),
        }
        writeSaved(list)
        Notify(L('saved'), 'success')
        if MenuOpen then
            SendNUIMessage({ type = 'savedVehicles', vehicles = list })
        end
        return
    end

    if not veh then
        Notify(L('no_vehicle'), 'error')
        if actionId == 'veh.godmode' or actionId == 'veh.freeze' or actionId == 'veh.drift' then
            PushToggleState()
        end
        return
    end

    if actionId == 'veh.repair' then
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleUndriveable(veh, false)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleDirtLevel(veh, 0.0)
    elseif actionId == 'veh.wash' then
        SetVehicleDirtLevel(veh, 0.0)
        WashDecalsFromVehicle(veh, 1.0)
    elseif actionId == 'veh.flip' then
        local c = GetEntityCoords(veh)
        local h = GetEntityHeading(veh)
        SetEntityCoords(veh, c.x, c.y, c.z + 0.5, false, false, false, false)
        SetEntityRotation(veh, 0.0, 0.0, h, 2, true)
        SetVehicleOnGroundProperly(veh)
    elseif actionId == 'veh.engine' then
        local on = payload.on and true or false
        SetVehicleEngineOn(veh, on, true, true)
    elseif actionId == 'veh.delete' then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    elseif actionId == 'veh.godmode' then
        SelfState.vehgod = not SelfState.vehgod
        SetEntityInvincible(veh, SelfState.vehgod)
        SetVehicleCanBeVisiblyDamaged(veh, not SelfState.vehgod)
        SetVehicleTyresCanBurst(veh, not SelfState.vehgod)
        PushToggleState()
    elseif actionId == 'veh.freeze' then
        SelfState.vehfreeze = not SelfState.vehfreeze
        FreezeEntityPosition(veh, SelfState.vehfreeze)
        PushToggleState()
    elseif actionId == 'veh.boost' then
        local speed = GetEntitySpeed(veh)
        SetVehicleForwardSpeed(veh, math.max(speed, 0.0) + 22.0)
    elseif actionId == 'veh.drift' then
        SelfState.drift = not SelfState.drift
        SetVehicleReduceGrip(veh, SelfState.drift)
        PushToggleState()
    elseif actionId == 'veh.door' then
        toggleDoor(veh, tonumber(payload.index) or 0)
    elseif actionId == 'veh.windows' then
        windowsDown = not windowsDown
        for i = 0, 7 do
            if windowsDown then
                RollDownWindow(veh, i)
            else
                RollUpWindow(veh, i)
            end
        end
    elseif actionId == 'veh.extras' then
        local extra = tonumber(payload.extra)
        if extra and DoesExtraExist(veh, extra) then
            local on = IsVehicleExtraTurnedOn(veh, extra)
            SetVehicleExtra(veh, extra, on and 1 or 0)
        end
    elseif actionId == 'veh.livery' then
        SetVehicleLivery(veh, tonumber(payload.livery) or 0)
    elseif actionId == 'veh.xenon' then
        ToggleVehicleMod(veh, 22, true)
        SetVehicleXenonLightsColor(veh, tonumber(payload.color) or 0)
    elseif actionId == 'veh.tint' then
        SetVehicleWindowTint(veh, tonumber(payload.tint) or 0)
    elseif actionId == 'veh.plate' then
        SetVehicleNumberPlateText(veh, payload.plate or 'FIVEX')
    end
end)
