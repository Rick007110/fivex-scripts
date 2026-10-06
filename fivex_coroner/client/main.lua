local JC = 'fivex_jobcenter'
local warned = false

local onDuty = false
local jobVeh = 0
local bodyPed = 0
local carrying = false
local assignment = nil
local balance = 0
local workBlip = 0
local vehBlip = 0
local objBlip = 0
local lastJob = false
local failLock = false

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

local function L(key, ...)
    local pack = Locales[Config.Locale] or Locales['en'] or {}
    local s = pack[key] or key
    if select('#', ...) > 0 then return s:format(...) end
    return s
end

local function notify(msg, typ)
    if jcReady() then
        TriggerEvent('fivex_jobcenter:notify', msg, typ or 'info')
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg or '')
        EndTextCommandThefeedPostTicker(false, false)
    end
end

local function help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function drawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.28, 0.28)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(230, 237, 243, 220)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function marker(x, y, z)
    local m = Config.Marker
    DrawMarker(m.type, x, y, z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        m.scale.x, m.scale.y, m.scale.z, m.color.r, m.color.g, m.color.b, m.color.a,
        false, false, 2, false, nil, nil, false)
end

local function drawHud(line)
    DrawRect(0.5, 0.042, 0.34, 0.046, 14, 17, 22, 200)
    SetTextFont(4)
    SetTextScale(0.34, 0.34)
    SetTextCentre(true)
    SetTextColour(230, 237, 243, 240)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(line)
    EndTextCommandDisplayText(0.5, 0.028)
end

local function requestModel(hash, timeout)
    if type(hash) == 'string' then hash = joaat(hash) end
    if not IsModelValid(hash) and not IsModelInCdimage(hash) then return 0 end
    RequestModel(hash)
    local t = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash) and hash or 0
end

local function playHold(ms, anim)
    local ped = PlayerPedId()
    local dict, clip = anim.dict, anim.clip
    if dict then
        RequestAnimDict(dict)
        local t = GetGameTimer() + 2000
        while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
        if HasAnimDictLoaded(dict) then
            TaskPlayAnim(ped, dict, clip, 8.0, -8.0, ms, 1, 0.0, false, false, false)
        end
    end
    local start = GetGameTimer()
    local finish = start + ms
    local ok = true
    while GetGameTimer() < finish do
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 23, true)
        DisableControlAction(0, 75, true)
        DisableControlAction(0, 38, true)
        if not IsDisabledControlPressed(0, 38) and not IsControlPressed(0, 38) then
            ok = false
            break
        end
        if GetResourceState('fivex_jobcenter') == 'started' then
            pcall(function()
                exports['fivex_jobcenter']:SetProgress((GetGameTimer() - start) / ms, 'Working')
            end)
        end
        Wait(0)
    end
    if GetResourceState('fivex_jobcenter') == 'started' then
        pcall(function()
            exports['fivex_jobcenter']:SetProgress(false)
        end)
    end
    ClearPedTasks(ped)
    if dict then RemoveAnimDict(dict) end
    return ok
end

local function setBlip(handle, coords, sprite, color, name, route)
    if handle ~= 0 and DoesBlipExist(handle) then RemoveBlip(handle) end
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, sprite)
    SetBlipColour(b, color or 3)
    SetBlipScale(b, 0.85)
    SetBlipAsShortRange(b, not route)
    if route then SetBlipRoute(b, true) SetBlipRouteColour(b, color or 3) end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name or 'Objective')
    EndTextCommandSetBlipName(b)
    return b
end

local function clearObjBlip()
    if objBlip ~= 0 then RemoveBlip(objBlip) objBlip = 0 end
end

local function clearVehBlip()
    if vehBlip ~= 0 then RemoveBlip(vehBlip) vehBlip = 0 end
end

local function deleteBody()
    if bodyPed ~= 0 and DoesEntityExist(bodyPed) then
        DeleteEntity(bodyPed)
    end
    bodyPed = 0
end

local function deleteVeh()
    clearVehBlip()
    if jobVeh ~= 0 and DoesEntityExist(jobVeh) then
        DeleteEntity(jobVeh)
    end
    jobVeh = 0
end

local function spawnBody()
    deleteBody()
    if not assignment or assignment.bagged then return end
    local hash = requestModel(assignment.pedModel, 5000)
    if hash == 0 then return end
    local x, y, z = assignment.x, assignment.y, assignment.z
    local found, gz = GetGroundZFor_3dCoord(x, y, z + 1.5, false)
    if found then z = gz end
    local ped = CreatePed(4, hash, x, y, z, 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return end
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetEntityInvincible(ped, true)
    SetEntityHealth(ped, 0)
    FreezeEntityPosition(ped, true)
    SetPedToRagdoll(ped, 12000, 12000, 0, false, false, false)
    bodyPed = ped
end

local function updateObjectiveBlip()
    clearObjBlip()
    if not assignment then return end
    if assignment.step == 'recover' then
        objBlip = setBlip(0, vector3(assignment.x, assignment.y, assignment.z), 310, 1, 'Remains', true)
    elseif assignment.step == 'load' then
        -- vehicle is the target; keep van blip
    elseif assignment.step == 'deliver' then
        objBlip = setBlip(0, Config.Delivery, 478, 2, 'Morgue bay', true)
    end
end

local function spawnJobVehicle(coords)
    deleteVeh()
    local hash = requestModel(Config.Vehicle.model, 7000)
    if hash == 0 then
        notify('Van model failed to load.', 'error')
        return
    end
    local veh = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w or 0.0, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(veh) then return end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleNumberPlateText(veh, Config.Vehicle.plate)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    jobVeh = veh
    local netId = NetworkGetNetworkIdFromEntity(veh)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetNetworkIdCanMigrate(netId, true)
    TriggerServerEvent('fivex_coroner:vehicleSpawned', netId)
    vehBlip = AddBlipForEntity(veh)
    SetBlipSprite(vehBlip, 225)
    SetBlipColour(vehBlip, 40)
    SetBlipScale(vehBlip, 0.75)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Coroner van')
    EndTextCommandSetBlipName(vehBlip)
end

local function cleanup(full)
    carrying = false
    failLock = false
    deleteBody()
    clearObjBlip()
    assignment = nil
    if full then
        onDuty = false
        deleteVeh()
    end
end

local function trimPlate(s)
    return (tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', ''))
end

local function resolveJobVeh()
    if jobVeh ~= 0 and DoesEntityExist(jobVeh) then
        return jobVeh
    end
    jobVeh = 0
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local model = Config.Vehicle.model
    local needle = trimPlate(Config.Vehicle.plate or 'CORONER'):upper()
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and GetEntityModel(veh) == model then
            local plate = trimPlate(GetVehicleNumberPlateText(veh)):upper()
            if plate:find(needle, 1, true) then
                local d = #(pcoords - GetEntityCoords(veh))
                if d <= 20.0 then
                    jobVeh = veh
                    return jobVeh
                end
            end
        end
    end
    return 0
end

local function rearBoot(veh)
    if veh == 0 or not DoesEntityExist(veh) then return nil end
    -- Rumpo 'boot' bone is chassis/center (or missing); always use rear offset.
    return GetOffsetFromEntityInWorldCoords(veh, 0.0, -3.65, 0.35)
end

local function stepLabel()
    if not assignment then return L('step_wait') end
    if assignment.step == 'recover' then return L('step_recover') end
    if assignment.step == 'load' then return L('step_load') end
    if assignment.step == 'deliver' then return L('step_deliver') end
    return L('step_wait')
end

RegisterNetEvent('fivex_jobcenter:clientJob', function(job, bal, duty)
    lastJob = job
    balance = tonumber(bal) or 0
    if job ~= Config.JobId or not duty then
        if onDuty or jobVeh ~= 0 or bodyPed ~= 0 then
            cleanup(true)
        end
    end
end)

RegisterNetEvent('fivex_coroner:duty', function(state)
    onDuty = state and true or false
    if not onDuty then cleanup(true) end
end)

RegisterNetEvent('fivex_coroner:spawnVehicle', function(coords)
    if type(coords) ~= 'table' then return end
    spawnJobVehicle(coords)
end)

RegisterNetEvent('fivex_coroner:delVehicle', function()
    deleteVeh()
end)

RegisterNetEvent('fivex_coroner:assignment', function(data)
    deleteBody()
    carrying = false
    failLock = false
    if type(data) ~= 'table' then
        assignment = nil
        clearObjBlip()
        return
    end
    assignment = data
    if data.step == 'recover' and not data.bagged then
        spawnBody()
    end
    if data.step == 'load' then carrying = true end
    updateObjectiveBlip()
end)

RegisterNetEvent('fivex_coroner:delivered', function()
    carrying = false
    deleteBody()
    clearObjBlip()
end)

RegisterNetEvent('fivex_jobcenter:clientCancel', function()
    if onDuty then
        carrying = false
        deleteBody()
    end
end)

-- Workplace blip
CreateThread(function()
    local c = Config.Duty
    workBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(workBlip, Config.Blip.sprite)
    SetBlipColour(workBlip, Config.Blip.color)
    SetBlipScale(workBlip, Config.Blip.scale)
    SetBlipAsShortRange(workBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Blip.label)
    EndTextCommandSetBlipName(workBlip)
    Wait(800)
    jcReady()
end)

-- Main interact loop
CreateThread(function()
    while true do
        local sleep = 500
        if not jcReady() then
            Wait(2000)
        else
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)
            local dutyPos = vector3(Config.Duty.x, Config.Duty.y, Config.Duty.z)
            local garPos = vector3(Config.Garage.x, Config.Garage.y, Config.Garage.z)
            local dDuty = #(p - dutyPos)
            local dGar = #(p - garPos)

            if dDuty < 30.0 then
                sleep = 0
                marker(dutyPos.x, dutyPos.y, dutyPos.z)
                drawText3D(dutyPos.x, dutyPos.y, dutyPos.z + 1.0, onDuty and 'Clock out' or 'Coroner duty')
                if dDuty < Config.InteractDistance then
                    help(onDuty and L('prompt_out') or L('prompt_in'))
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('fivex_coroner:clockIn')
                    end
                end
            end

            if onDuty and dGar < 30.0 then
                sleep = 0
                if jobVeh == 0 or not DoesEntityExist(jobVeh) then
                    resolveJobVeh()
                end
                if jobVeh == 0 or not DoesEntityExist(jobVeh) then
                    marker(garPos.x, garPos.y, garPos.z)
                    drawText3D(garPos.x, garPos.y, garPos.z + 1.0, 'Coroner van')
                    if dGar < Config.InteractDistance then
                        help(L('prompt_veh'))
                        if IsControlJustPressed(0, 38) then
                            TriggerServerEvent('fivex_coroner:respawnVehicle')
                        end
                    end
                end
            end

            if onDuty and assignment then
                if assignment.step == 'recover' and not assignment.bagged then
                    local bp = vector3(assignment.x, assignment.y, assignment.z)
                    local d = #(p - bp)
                    if d < 30.0 then
                        sleep = 0
                        marker(bp.x, bp.y, bp.z)
                        drawText3D(bp.x, bp.y, bp.z + 0.6, 'Deceased')
                        if d < 2.0 then
                            help(L('prompt_bag'))
                            if IsControlJustPressed(0, 38) then
                                if playHold(Config.Anim.bag.ms, Config.Anim.bag) then
                                    deleteBody()
                                    carrying = true
                                    TriggerServerEvent('fivex_coroner:bag', assignment.id)
                                end
                            end
                        end
                    end
                elseif assignment.step == 'load' or carrying then
                    local veh = resolveJobVeh()
                    if veh ~= 0 and DoesEntityExist(veh) then
                        local boot = rearBoot(veh)
                        if boot then
                            local dBoot = #(p - boot)
                            local dVan = #(p - GetEntityCoords(veh))
                            local inVan = IsPedInVehicle(ped, veh, false)
                            local onFoot = IsPedOnFoot(ped) and not inVan
                            if dVan < Config.LoadRadius or dBoot < 30.0 then
                                sleep = 0
                            end
                            if dBoot < 30.0 then
                                marker(boot.x, boot.y, boot.z)
                                drawText3D(boot.x, boot.y, boot.z + 0.5, 'Load remains')
                            end
                            if inVan then
                                help(L('prompt_getout'))
                            elseif onFoot and dVan < Config.LoadRadius then
                                DisableControlAction(0, 38, true)
                                DisableControlAction(0, 23, true)
                                DisableControlAction(0, 75, true)
                                if dBoot < (Config.LoadInteract or 4.0) then
                                    SetVehicleDoorOpen(veh, 2, false, false)
                                    SetVehicleDoorOpen(veh, 3, false, false)
                                    help(L('prompt_load'))
                                    if IsDisabledControlJustPressed(0, 38) then
                                        if playHold(Config.Anim.load.ms, Config.Anim.load) then
                                            carrying = false
                                            TriggerServerEvent('fivex_coroner:load', assignment.id)
                                        end
                                    end
                                end
                            end
                        end
                    end
                elseif assignment.step == 'deliver' then
                    local bay = Config.Delivery
                    local d = #(p - bay)
                    if d < 30.0 then
                        sleep = 0
                        marker(bay.x, bay.y, bay.z)
                        drawText3D(bay.x, bay.y, bay.z + 1.0, 'Unload bay')
                        if d < 2.2 then
                            help(L('prompt_deliver'))
                            if IsControlJustPressed(0, 38) then
                                if playHold(Config.Anim.deliver.ms, Config.Anim.deliver) then
                                    TriggerServerEvent('fivex_coroner:deliver', assignment.id)
                                end
                            end
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end
end)

-- HUD + fail watch
CreateThread(function()
    while true do
        if onDuty then
            drawHud(L('overlay', stepLabel(), tostring(balance)))
            local ped = PlayerPedId()
            if assignment and not failLock then
                if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
                    failLock = true
                    TriggerServerEvent('fivex_coroner:fail', assignment.id, 'dead')
                else
                    if jobVeh ~= 0 and not DoesEntityExist(jobVeh) then
                        resolveJobVeh()
                    end
                    if jobVeh ~= 0 and (not DoesEntityExist(jobVeh) or IsEntityDead(jobVeh)) then
                        failLock = true
                        jobVeh = 0
                        TriggerServerEvent('fivex_coroner:fail', assignment.id, 'van')
                    end
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    cleanup(true)
    if workBlip ~= 0 then RemoveBlip(workBlip) end
end)
