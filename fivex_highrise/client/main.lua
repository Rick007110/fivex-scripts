local JC = 'fivex_jobcenter'
local warned = false

local onDuty = false
local jobVeh = 0
local assignment = nil
local balance = 0
local workBlip = 0
local vehBlip = 0
local objBlip = 0
local lastJob = false
local fellLock = false
local busy = false
local roofReady = false
local localDone = {}

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
    if anim.scenario then
        TaskStartScenarioInPlace(ped, anim.scenario, 0, true)
    elseif anim.dict then
        RequestAnimDict(anim.dict)
        local t = GetGameTimer() + 2000
        while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < t do Wait(0) end
        if HasAnimDictLoaded(anim.dict) then
            TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, ms, 1, 0.0, false, false, false)
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
    ClearPedTasksImmediately(ped)
    return ok
end

local function teleport(dest, giveChute)
    if type(dest) ~= 'table' then return end
    local x, y, z, w = dest.x, dest.y, dest.z, dest.w
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    local t = GetGameTimer() + 1500
    while not IsScreenFadedOut() and GetGameTimer() < t do Wait(0) end
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, x, y, z, false, false, false, true)
    if w then SetEntityHeading(ped, w) end
    RequestCollisionAtCoord(x, y, z)
    local freezeUntil = GetGameTimer() + 800
    while GetGameTimer() < freezeUntil do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
    local deadline = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do
        RequestCollisionAtCoord(x, y, z)
        Wait(50)
    end
    if giveChute then
        GiveWeaponToPed(ped, joaat('GADGET_PARACHUTE'), 1, false, false)
    end
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(400)
end

local function clearObjBlip()
    if objBlip ~= 0 then RemoveBlip(objBlip) objBlip = 0 end
end

local function clearVehBlip()
    if vehBlip ~= 0 then RemoveBlip(vehBlip) vehBlip = 0 end
end

local function deleteVeh()
    clearVehBlip()
    if jobVeh ~= 0 and DoesEntityExist(jobVeh) then DeleteEntity(jobVeh) end
    jobVeh = 0
end

local function setRoute(coords, sprite, color, name)
    clearObjBlip()
    objBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(objBlip, sprite or 1)
    SetBlipColour(objBlip, color or 3)
    SetBlipScale(objBlip, 0.85)
    SetBlipRoute(objBlip, true)
    SetBlipRouteColour(objBlip, color or 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name or 'Objective')
    EndTextCommandSetBlipName(objBlip)
end

local function updateRoute()
    if not assignment then
        clearObjBlip()
        return
    end
    if assignment.step == 'drive' or assignment.step == 'lift' then
        setRoute(assignment.door, 566, 3, assignment.label .. ' lift')
    elseif assignment.step == 'down' then
        setRoute(assignment.roof, 566, 3, 'Lift down')
    else
        clearObjBlip()
    end
end

local function spawnJobVehicle(coords)
    deleteVeh()
    local hash = requestModel(Config.Vehicle.model, 7000)
    if hash == 0 then
        notify('Bison model failed to load.', 'error')
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
    TriggerServerEvent('fivex_highrise:vehicleSpawned', netId)
    vehBlip = AddBlipForEntity(veh)
    SetBlipSprite(vehBlip, 225)
    SetBlipColour(vehBlip, 3)
    SetBlipScale(vehBlip, 0.75)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Washer bison')
    EndTextCommandSetBlipName(vehBlip)
end

local function cleanup(full)
    fellLock = false
    roofReady = false
    busy = false
    localDone = {}
    assignment = nil
    clearObjBlip()
    if full then
        onDuty = false
        deleteVeh()
    end
end

local function stepLabel()
    if not assignment then return L('step_wait') end
    if assignment.step == 'drive' then return L('step_drive', assignment.label or '') end
    if assignment.step == 'scrub' then
        return L('step_scrub', tostring(assignment.done or 0), tostring(assignment.total or 0))
    end
    if assignment.step == 'down' then return L('step_down') end
    return L('step_wait')
end

RegisterNetEvent('fivex_jobcenter:clientJob', function(job, bal, duty)
    lastJob = job
    balance = tonumber(bal) or 0
    if job ~= Config.JobId or not duty then
        if onDuty or jobVeh ~= 0 then cleanup(true) end
    end
end)

RegisterNetEvent('fivex_highrise:duty', function(state)
    onDuty = state and true or false
    if not onDuty then cleanup(true) end
end)

RegisterNetEvent('fivex_highrise:spawnVehicle', function(coords)
    if type(coords) == 'table' then spawnJobVehicle(coords) end
end)

RegisterNetEvent('fivex_highrise:delVehicle', function()
    deleteVeh()
end)

RegisterNetEvent('fivex_highrise:assignment', function(data)
    if type(data) ~= 'table' then
        assignment = nil
        localDone = {}
        fellLock = false
        roofReady = false
        clearObjBlip()
        return
    end
    local keepRoof = roofReady and (data.step == 'scrub' or data.step == 'down')
    if data.step == 'drive' or data.step == 'lift' then
        fellLock = false
        roofReady = false
    elseif not keepRoof then
        roofReady = false
    end
    assignment = data
    localDone = {}
    if type(data.doneFlags) == 'table' then
        for i, v in pairs(data.doneFlags) do
            localDone[tonumber(i) or i] = v and true or false
        end
    end
    updateRoute()
end)

RegisterNetEvent('fivex_highrise:teleport', function(dest, chute)
    roofReady = false
    teleport(dest, chute and true or false)
    if assignment and dest and assignment.roof and dest.z and math.abs((dest.z or 0) - (assignment.roof.z or 0)) < 4.0 then
        roofReady = true
        TriggerServerEvent('fivex_highrise:roofReady', assignment.id)
    else
        roofReady = false
    end
end)

RegisterNetEvent('fivex_jobcenter:clientCancel', function()
    if onDuty then
        localDone = {}
    end
end)

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
                drawText3D(dutyPos.x, dutyPos.y, dutyPos.z + 1.0, onDuty and 'Clock out' or 'High-rise duty')
                if dDuty < Config.InteractDistance and not busy then
                    help(onDuty and L('prompt_out') or L('prompt_in'))
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('fivex_highrise:clockIn')
                    end
                end
            end

            if onDuty and dGar < 30.0 and (jobVeh == 0 or not DoesEntityExist(jobVeh)) then
                sleep = 0
                marker(garPos.x, garPos.y, garPos.z)
                drawText3D(garPos.x, garPos.y, garPos.z + 1.0, 'Washer bison')
                if dGar < Config.InteractDistance then
                    help(L('prompt_veh'))
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('fivex_highrise:respawnVehicle')
                    end
                end
            end

            if onDuty and assignment and not busy then
                if assignment.step == 'drive' or assignment.step == 'lift' then
                    local door = assignment.door
                    local dp = vector3(door.x, door.y, door.z)
                    local d = #(p - dp)
                    if d < 30.0 then
                        sleep = 0
                        marker(dp.x, dp.y, dp.z)
                        drawText3D(dp.x, dp.y, dp.z + 1.0, 'Service lift')
                        if d < 2.0 then
                            help(L('prompt_lift'))
                            if IsControlJustPressed(0, 38) then
                                busy = true
                                TriggerServerEvent('fivex_highrise:liftUp', assignment.id)
                                SetTimeout(1200, function() busy = false end)
                            end
                        end
                    end
                elseif assignment.step == 'scrub' or assignment.step == 'down' then
                    local windows = assignment.windows or {}
                    for i = 1, #windows do
                        if not localDone[i] then
                            local w = windows[i]
                            local wp = vector3(w.x, w.y, w.z)
                            local d = #(p - wp)
                            if d < 30.0 then
                                sleep = 0
                                marker(wp.x, wp.y, wp.z)
                                drawText3D(wp.x, wp.y, wp.z + 0.55, ('Bay %s'):format(i))
                                if d < 2.0 then
                                    help(L('prompt_scrub'))
                                    if IsControlJustPressed(0, 38) then
                                        busy = true
                                        if playHold(Config.Anim.scrub.ms, Config.Anim.scrub) then
                                            localDone[i] = true
                                            TriggerServerEvent('fivex_highrise:scrub', assignment.id, i)
                                        end
                                        busy = false
                                    end
                                end
                            end
                        end
                    end
                    if assignment.step == 'down' then
                        local r = assignment.roof
                        local rp = vector3(r.x, r.y, r.z)
                        local d = #(p - rp)
                        if d < 30.0 then
                            sleep = 0
                            marker(rp.x, rp.y, rp.z)
                            drawText3D(rp.x, rp.y, rp.z + 1.0, 'Lift down')
                            if d < 2.2 then
                                help(L('prompt_down'))
                                if IsControlJustPressed(0, 38) then
                                    busy = true
                                    TriggerServerEvent('fivex_highrise:complete', assignment.id)
                                    SetTimeout(1500, function() busy = false end)
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

CreateThread(function()
    while true do
        if onDuty then
            drawHud(L('overlay', stepLabel(), tostring(balance)))
            if roofReady and assignment and (assignment.step == 'scrub' or assignment.step == 'down') and not fellLock then
                local z = GetEntityCoords(PlayerPedId()).z
                local roofZ = assignment.roof and assignment.roof.z or z
                if z < (roofZ - Config.FallGrace) then
                    fellLock = true
                    TriggerServerEvent('fivex_highrise:fell', assignment.id)
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

lastJob = lastJob
