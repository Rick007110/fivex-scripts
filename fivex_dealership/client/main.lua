local RESOURCE = GetCurrentResourceName()

local blips = {}
local menuOpen = false
local menuKind = nil
local cbWait = {}
local nuiSeq = 0
local openPendingUntil = 0
local storePendingUntil = 0

local cam = nil
local previewVeh = 0
local previewToken = 0

local function L(key, ...)
    local pack = Locales[Config.Locale] or Locales['en'] or {}
    local s = pack[key] or key
    if select('#', ...) > 0 then
        return s:format(...)
    end
    return s
end

local function nui(msg)
    SendNUIMessage(msg)
end

local function setFocus(on)
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(false)
end

local function notify(message, ntype)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message or '')
    EndTextCommandThefeedPostTicker(false, false)
    nui({ type = 'toast', message = message, level = ntype or 'info' })
end

RegisterNetEvent('fivex_dealership:notify', function(message, ntype)
    notify(message, ntype)
end)

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

local function drawMarker(m, c)
    DrawMarker(m.type, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        m.scale.x, m.scale.y, m.scale.z, m.color.r, m.color.g, m.color.b, m.color.a,
        false, false, 2, false, nil, nil, false)
end

local function addBlip(coords, b)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, b.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, b.scale)
    SetBlipColour(blip, b.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(b.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function ensureBlips()
    if #blips > 0 then return end
    blips[#blips + 1] = addBlip(Config.Showroom.desk, Config.Showroom.blip)
    for _, g in ipairs(Config.Garages) do
        blips[#blips + 1] = addBlip(g.coords, Config.GarageBlip)
    end
end

---------------------------------------------------------------------------
-- Showroom interior (vanilla leaves PDM on its closed placeholder)
---------------------------------------------------------------------------

local interiorWarned = false

-- Returns true once the interior is loaded (or loading is disabled).
local function loadShowroomInterior()
    local s = Config.Showroom
    if not s.loadInterior then return true end
    for _, ipl in ipairs(s.ipl.remove) do
        if IsIplActive(ipl) then RemoveIpl(ipl) end
    end
    for _, ipl in ipairs(s.ipl.request) do
        if not IsIplActive(ipl) then RequestIpl(ipl) end
    end
    local p = s.preview
    local interior = 0
    local untilT = GetGameTimer() + 10000
    while interior == 0 and GetGameTimer() < untilT do
        interior = GetInteriorAtCoords(p.x, p.y, p.z)
        if interior == 0 then Wait(250) end
    end
    if interior == 0 then
        if not interiorWarned then
            interiorWarned = true
            print('[fivex_dealership] showroom interior not found yet — retrying (check Config.Showroom.ipl)')
        end
        return false
    end
    PinInteriorInMemory(interior)
    untilT = GetGameTimer() + 5000
    while not IsInteriorReady(interior) and GetGameTimer() < untilT do
        Wait(50)
    end
    for _, set in ipairs(s.entitySets.off) do
        if IsInteriorEntitySetActive(interior, set) then DeactivateInteriorEntitySet(interior, set) end
    end
    for _, set in ipairs(s.entitySets.on) do
        if not IsInteriorEntitySetActive(interior, set) then ActivateInteriorEntitySet(interior, set) end
    end
    RefreshInterior(interior)
    return true
end

---------------------------------------------------------------------------
-- Showroom preview (local entity + camera; nobody else sees it)
---------------------------------------------------------------------------

local function deletePreview()
    if previewVeh ~= 0 and DoesEntityExist(previewVeh) then
        DeleteEntity(previewVeh)
    end
    previewVeh = 0
end

local function startCam()
    if cam then return end
    local c = Config.Showroom.camera
    local p = Config.Showroom.preview
    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x, c.y, c.z, 0.0, 0.0, 0.0, 50.0, false, 0)
    PointCamAtCoord(cam, p.x, p.y, p.z + 0.2)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function stopCam()
    if not cam then return end
    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(cam, false)
    cam = nil
end

local function modelStats(hash)
    local speed = GetVehicleModelEstimatedMaxSpeed(hash) -- m/s
    local display = Config.SpeedUnit == 'mph' and speed * 2.236936 or speed * 3.6
    local function bar(v, max) return math.max(0.0, math.min(1.0, (v or 0.0) / max)) end
    return {
        speed = math.floor(display + 0.5),
        unit = Config.SpeedUnit == 'mph' and 'mph' or 'km/h',
        seats = GetVehicleModelNumberOfSeats(hash),
        bars = {
            speed = bar(speed, 60.0),
            accel = bar(GetVehicleModelAcceleration(hash), 0.45),
            braking = bar(GetVehicleModelMaxBraking(hash), 1.5),
            traction = bar(GetVehicleModelMaxTraction(hash), 3.2),
        },
    }
end

local function showPreview(model, colorId)
    previewToken = previewToken + 1
    local token = previewToken
    deletePreview()
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return nil end
    RequestModel(hash)
    local untilT = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < untilT do
        Wait(10)
    end
    -- a newer selection (or closing the menu) wins
    if token ~= previewToken or menuKind ~= 'showroom' or not HasModelLoaded(hash) then
        SetModelAsNoLongerNeeded(hash)
        return nil
    end
    local p = Config.Showroom.preview
    local veh = CreateVehicle(hash, p.x, p.y, p.z, p.w, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(veh) then return nil end
    SetVehicleOnGroundProperly(veh)
    FreezeEntityPosition(veh, true)
    SetEntityInvincible(veh, true)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleNumberPlateText(veh, 'FIVEX')
    SetVehicleColours(veh, colorId or 0, colorId or 0)
    previewVeh = veh
    return modelStats(hash)
end

local manualUntil = 0

-- Showroom frame loop: hide HUD, slow turntable (paused for a moment after a drag).
CreateThread(function()
    while true do
        if menuKind == 'showroom' then
            HideHudAndRadarThisFrame()
            if previewVeh ~= 0 and DoesEntityExist(previewVeh) and GetGameTimer() >= manualUntil then
                SetEntityHeading(previewVeh, (GetEntityHeading(previewVeh) + 0.2) % 360.0)
            end
            Wait(0)
        else
            Wait(250)
        end
    end
end)

---------------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------------

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    menuKind = nil
    previewToken = previewToken + 1
    deletePreview()
    stopCam()
    setFocus(false)
    nui({ type = 'close' })
    TriggerServerEvent('fivex_dealership:close')
end

local function open(kind)
    if menuOpen then return end
    -- one request in flight at a time; cleared by openResult or after 2 s
    local now = GetGameTimer()
    if now < openPendingUntil then return end
    openPendingUntil = now + 2000
    TriggerServerEvent('fivex_dealership:open', kind)
end

RegisterNetEvent('fivex_dealership:openResult', function(payload)
    if type(payload) ~= 'table' then return end
    openPendingUntil = 0
    menuOpen = true
    menuKind = payload.kind
    if menuKind == 'showroom' then startCam() end
    setFocus(true)
    payload.type = 'open'
    payload.catalog = Config.Catalog
    payload.categories = Config.Categories
    payload.colors = Config.Colors
    nui(payload)
end)

RegisterNetEvent('fivex_dealership:actionResult', function(ok, _msg, state, cbId)
    if cbId and cbWait[cbId] then
        cbWait[cbId]({ ok = ok and true or false })
        cbWait[cbId] = nil
    end
    if type(state) == 'table' then
        state.type = 'state'
        nui(state)
    elseif menuOpen and not ok then
        closeMenu() -- session ended server-side (walked away)
    end
end)

-- Server spawned one of our cars: close the menu, apply saved condition, put us in it.
RegisterNetEvent('fivex_dealership:spawned', function(netId, cond)
    closeMenu()
    local untilT = GetGameTimer() + 5000
    while not NetworkDoesEntityExistWithNetworkId(netId) and GetGameTimer() < untilT do
        Wait(50)
    end
    if not NetworkDoesEntityExistWithNetworkId(netId) then return end
    local veh = NetToVeh(netId)
    NetworkRequestControlOfEntity(veh)
    untilT = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < untilT do
        Wait(50)
        NetworkRequestControlOfEntity(veh)
    end
    SetVehicleOnGroundProperly(veh)
    if type(cond) == 'table' then
        SetVehicleEngineHealth(veh, (tonumber(cond.engine) or 1000.0) + 0.0)
        SetVehicleBodyHealth(veh, (tonumber(cond.body) or 1000.0) + 0.0)
        SetVehicleDirtLevel(veh, (tonumber(cond.dirt) or 0.0) + 0.0)
    end
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
end)

-- Sends event(..., cbId) and resolves the NUI callback on actionResult or after 6 s.
local function serverAction(cb, event, ...)
    nuiSeq = nuiSeq + 1
    local id = nuiSeq
    cbWait[id] = cb
    local args = table.pack(...)
    args[args.n + 1] = id
    TriggerServerEvent(event, table.unpack(args, 1, args.n + 1))
    SetTimeout(6000, function()
        if cbWait[id] then
            cbWait[id]({ ok = false })
            cbWait[id] = nil
        end
    end)
end

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('preview', function(data, cb)
    data = data or {}
    if menuKind ~= 'showroom' or type(data.model) ~= 'string' then
        cb({ ok = false })
        return
    end
    local stats = showPreview(data.model, tonumber(data.color) or 0)
    cb({ ok = stats ~= nil, stats = stats })
end)

RegisterNUICallback('rotate', function(data, cb)
    local d = tonumber(data and data.delta) or 0.0
    if previewVeh ~= 0 and DoesEntityExist(previewVeh) then
        d = math.max(-45.0, math.min(45.0, d))
        SetEntityHeading(previewVeh, (GetEntityHeading(previewVeh) + d) % 360.0)
        manualUntil = GetGameTimer() + 2500
    end
    cb({ ok = true })
end)

RegisterNUICallback('color', function(data, cb)
    local id = tonumber(data and data.color)
    if id and previewVeh ~= 0 and DoesEntityExist(previewVeh) then
        SetVehicleColours(previewVeh, id, id)
    end
    cb({ ok = true })
end)

RegisterNUICallback('buy', function(data, cb)
    data = data or {}
    serverAction(cb, 'fivex_dealership:buy', tostring(data.model or ''), tonumber(data.color), tostring(data.method or ''))
end)

RegisterNUICallback('sell', function(data, cb)
    serverAction(cb, 'fivex_dealership:sell', tostring(data and data.plate or ''))
end)

RegisterNUICallback('takeout', function(data, cb)
    serverAction(cb, 'fivex_dealership:takeout', tostring(data and data.plate or ''))
end)

RegisterNUICallback('recover', function(data, cb)
    serverAction(cb, 'fivex_dealership:recover', tostring(data and data.plate or ''))
end)

---------------------------------------------------------------------------
-- World
---------------------------------------------------------------------------

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/givecar', 'Staff: give a player a vehicle', {
        { name = 'id', help = 'server id' },
        { name = 'model', help = 'catalog model, e.g. sultan' },
    })
    TriggerEvent('chat:addSuggestion', '/takecar', 'Staff: remove an owned vehicle', {
        { name = 'plate', help = 'plate text' },
    })
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(200) end
    Wait(1000)
    ensureBlips()
    while not loadShowroomInterior() do
        Wait(5000)
    end
end)

-- Markers and prompts. Always yields every iteration.
CreateThread(function()
    local s = Config.Showroom
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        local veh = GetVehiclePedIsIn(ped, false)
        local driving = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped

        if not menuOpen then
            -- showroom desk (on foot)
            local d = #(p - s.desk)
            if veh == 0 and d < Config.DrawDistance then
                sleep = 0
                drawMarker(Config.Marker, s.desk)
                drawText3D(s.desk.x, s.desk.y, s.desk.z + 0.35, s.label)
                if d < Config.InteractDistance then
                    help(L('prompt_showroom'))
                    if IsControlJustPressed(0, 38) then open('showroom') end
                end
            end

            for _, g in ipairs(Config.Garages) do
                local gd = #(p - g.coords)
                if veh == 0 and gd < Config.DrawDistance then
                    sleep = 0
                    drawMarker(Config.Marker, g.coords)
                    drawText3D(g.coords.x, g.coords.y, g.coords.z + 0.35, g.label)
                    if gd < Config.InteractDistance then
                        help(L('prompt_garage'))
                        if IsControlJustPressed(0, 38) then open('garage') end
                    end
                elseif driving and gd < Config.StoreDistance + Config.DrawDistance
                    and Entity(veh).state.fivex_plate then
                    sleep = 0
                    drawMarker(Config.StoreMarker, g.coords)
                    if gd < Config.StoreDistance then
                        help(L('prompt_store'))
                        local now = GetGameTimer()
                        if IsControlJustPressed(0, 38) and now >= storePendingUntil then
                            storePendingUntil = now + 1500
                            TriggerServerEvent('fivex_dealership:store', VehToNet(veh))
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == RESOURCE then
        ensureBlips()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    closeMenu()
    deletePreview()
    stopCam()
    for i, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        blips[i] = nil
    end
end)
