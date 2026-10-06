-- fivex_marina — client helpers shared by client/main.lua
Harbor = Harbor or {}
local H = Harbor

function H.L(key, ...)
    local pack = Locales[Config.Locale] or Locales['en'] or {}
    local s = pack[key] or key
    if select('#', ...) > 0 and type(s) == 'string' then return s:format(...) end
    return s
end

function H.notify(msg, typ)
    if GetResourceState('fivex_jobcenter') == 'started' then
        TriggerEvent('fivex_jobcenter:notify', msg, typ or 'info')
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(msg or '')
        EndTextCommandThefeedPostTicker(false, false)
    end
end

function H.help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

function H.subtitle(text, ms)
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandPrint(ms or 4000, true)
end

function H.sound(name, set)
    PlaySoundFrontend(-1, name, set, true)
end

function H.text3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.3, 0.3)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(230, 245, 255, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

-- Ground marker (z = standing height, drawn at the feet)
function H.marker(x, y, z, scaleMul)
    local m = Config.Marker
    local s = scaleMul or 1.0
    DrawMarker(m.type, x, y, z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        m.scale.x * s, m.scale.y * s, m.scale.z, m.color.r, m.color.g, m.color.b, m.color.a,
        false, false, 2, false, nil, nil, false)
end

-- Big floating ring for sea objectives (visible from a boat)
function H.seaMarker(x, y, z, r, g, b)
    DrawMarker(1, x, y, z - 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 9.0, 9.0, 3.0,
        r or 56, g or 189, b or 248, 90, false, false, 2, false, nil, nil, false)
    DrawMarker(0, x, y, z + 6.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 2.0,
        r or 56, g or 189, b or 248, 200, true, true, 2, false, nil, nil, false)
end

function H.requestModel(model, timeout)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return 0 end
    RequestModel(hash)
    local t = GetGameTimer() + (timeout or 6000)
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(hash) and hash or 0
end

function H.loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(0) end
    return HasAnimDictLoaded(dict)
end

local badFx = {}

--- Load a particle asset once; remembers assets that failed so callers never stall on them again
local function ptfxReady(asset)
    if badFx[asset] then return false end
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    local t = GetGameTimer() + 1000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < t do Wait(0) end
    if HasNamedPtfxAssetLoaded(asset) then return true end
    badFx[asset] = true
    return false
end

function H.fx(key, x, y, z, scaleMul)
    local f = Config.Fx[key]
    if not f then return end
    if not ptfxReady(f.asset) then return end
    UseParticleFxAssetNextCall(f.asset)
    StartParticleFxNonLoopedAtCoord(f.name, x, y, z, 0.0, 0.0, 0.0, (f.scale or 1.0) * (scaleMul or 1.0), false, false, false)
end

function H.fxLooped(key, x, y, z)
    local f = Config.Fx[key]
    if not f then return 0 end
    if not ptfxReady(f.asset) then return 0 end
    UseParticleFxAssetNextCall(f.asset)
    return StartParticleFxLoopedAtCoord(f.name, x, y, z, 0.0, 0.0, 0.0, f.scale or 1.0, false, false, false, false)
end

function H.progress(pct, label)
    if GetResourceState('fivex_jobcenter') ~= 'started' then return end
    pcall(function() exports['fivex_jobcenter']:SetProgress(pct, label) end)
end

--- Hold E for `ms`. Plays an anim/scenario while held. Returns true when completed.
--- opts: { label, dict, clip, scenario, flag, onTick(frac) }
function H.hold(ms, opts)
    opts = opts or {}
    local ped = PlayerPedId()
    local inVeh = IsPedInAnyVehicle(ped, false)
    if not inVeh then
        if opts.scenario then
            TaskStartScenarioInPlace(ped, opts.scenario, 0, true)
        elseif opts.dict and H.loadDict(opts.dict) then
            TaskPlayAnim(ped, opts.dict, opts.clip, 4.0, -4.0, -1, opts.flag or 1, 0.0, false, false, false)
        end
    end
    local start = GetGameTimer()
    local ok = true
    while true do
        local frac = (GetGameTimer() - start) / ms
        if frac >= 1.0 then break end
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 75, true)
        if not IsControlPressed(0, 38) and not IsDisabledControlPressed(0, 38) then
            ok = false
            break
        end
        H.progress(frac, opts.label or 'Working')
        if opts.onTick then opts.onTick(frac) end
        Wait(0)
    end
    H.progress(false)
    if not inVeh then
        if opts.scenario then
            ClearPedTasks(ped)
        else
            StopAnimTask(ped, opts.dict or '', opts.clip or '', 2.0)
        end
    end
    return ok
end

function H.attachProp(model, bone, off, rot)
    local hash = H.requestModel(model, 3000)
    if hash == 0 then return 0 end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, bone), off.x, off.y, off.z, rot.x, rot.y, rot.z,
        true, true, false, true, 1, true)
    return obj
end

function H.deleteEntity(ent)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        SetEntityAsMissionEntity(ent, true, true)
        DeleteEntity(ent)
    end
    return 0
end

function H.blip(x, y, z, sprite, color, label, route, scale)
    local b = AddBlipForCoord(x, y, z)
    SetBlipSprite(b, sprite or 1)
    SetBlipColour(b, color or 3)
    SetBlipScale(b, scale or 0.85)
    if route then
        SetBlipRoute(b, true)
        SetBlipRouteColour(b, color or 3)
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Harbor')
    EndTextCommandSetBlipName(b)
    return b
end

function H.removeBlip(b)
    if b and b ~= 0 and DoesBlipExist(b) then RemoveBlip(b) end
    return 0
end

function H.spawnBoat(model, x, y, z, w, networked, plate)
    local hash = H.requestModel(model)
    if hash == 0 and Config.BoatFallback then hash = H.requestModel(Config.BoatFallback) end
    if hash == 0 then return 0 end
    local veh = CreateVehicle(hash, x, y, z, w or 0.0, networked ~= false, true)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(veh) then return 0 end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleNumberPlateText(veh, plate or Config.BoatPlate)
    SetVehicleDirtLevel(veh, 0.0)
    if networked ~= false then
        SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(veh), true)
    end
    return veh
end

function H.spawnPed(model, x, y, z, w)
    local hash = H.requestModel(model)
    if hash == 0 then return 0 end
    local ped = CreatePed(4, hash, x, y, z, w or 0.0, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return 0 end
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedKeepTask(ped, true)
    return ped
end

---------------------------------------------------------------------------
-- Open-water finder
---------------------------------------------------------------------------

local function waterAt(x, y)
    local ok, h = GetWaterHeightNoWaves(x, y, 40.0)
    if ok then return h end
    return nil
end

--- Open water: water here and in a ring around it, and (when the seabed is streamed in) deep enough.
--- strict = the area is streamed in, so missing ground means "very deep" rather than "unknown".
function H.isOpenWater(x, y, strict)
    local h = waterAt(x, y)
    if not h then return nil end
    for i = 0, 5 do
        local a = i * math.pi / 3
        if not waterAt(x + math.cos(a) * 18.0, y + math.sin(a) * 18.0) then return nil end
    end
    local found, gz = GetGroundZFor_3dCoord(x, y, h + 40.0, false)
    if found and gz > h - Config.SeaMinDepth then return nil end
    if strict then
        -- nothing solid between the sky and the surface (piers, rocks, hulls)
        local ray = StartShapeTestLosProbe(x, y, h + 30.0, x, y, h + 0.3, 1 | 16, 0, 7)
        local res, hit
        local t = GetGameTimer() + 500
        repeat
            res, hit = GetShapeTestResult(ray)
            if res ~= 1 then break end
            Wait(0)
        until GetGameTimer() > t
        if res == 2 and (hit == 1 or hit == true) then return nil end
    end
    return h
end

--- Random open-water point inside a circle. Returns vector3 or nil.
function H.findWater(cx, cy, radius, minFrom, tries)
    for _ = 1, tries or 60 do
        local a = math.random() * math.pi * 2.0
        local r = math.sqrt(math.random()) * radius
        local x, y = cx + math.cos(a) * r, cy + math.sin(a) * r
        local farEnough = true
        if minFrom then
            for i = 1, #minFrom do
                if #(vector2(x, y) - vector2(minFrom[i].x, minFrom[i].y)) < minFrom[i].d then
                    farEnough = false
                    break
                end
            end
        end
        if farEnough then
            local h = H.isOpenWater(x, y, false)
            if h then return vector3(x, y, h) end
        end
        Wait(0)
    end
    return nil
end

--- Points for a sea contract: n spots in the area.
--- spacing = cluster them within that radius of the first spot (debris);
--- nil = spread them across the whole area (sightseeing stops).
function H.seaPoints(areaKey, n, spacing)
    local area = Config.SeaAreas[areaKey]
    if not area then return nil end
    local duty = { x = Config.Duty.x, y = Config.Duty.y, d = Config.SeaMinDistance + 10.0 }
    local pts = {}
    local anchor = H.findWater(area.center.x, area.center.y, area.radius, { duty }, 80)
    if not anchor then return nil end
    pts[1] = anchor
    for i = 2, n do
        local avoid = { duty }
        local gap = spacing and spacing * 0.35 or area.radius * 0.5
        for j = 1, #pts do avoid[#avoid + 1] = { x = pts[j].x, y = pts[j].y, d = gap } end
        local p
        if spacing then
            p = H.findWater(anchor.x, anchor.y, spacing, avoid, 60)
        end
        p = p or H.findWater(area.center.x, area.center.y, area.radius, avoid, 80)
        if not p then return nil end
        pts[i] = p
    end
    return pts
end
