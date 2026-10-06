-- fivex_marina — Harbor Authority (client)
local H = Harbor
local L = H.L

local onDuty = false
local boat = 0            -- work boat
local boatBlip = 0
local officeBlip = 0
local contract = nil      -- latest contract payload from the server
local ctx = nil           -- client-side runtime for the active contract (entities, blips, flags)
local tabletOpen = false
local tabletProp = 0
local busy = false
local profile = nil
local deathCancelled = false

---------------------------------------------------------------------------
-- NUI bridge
---------------------------------------------------------------------------

local function ui(action, data)
    data = data or {}
    data.action = action
    SendNUIMessage(data)
end

local function stopTabletAnim()
    tabletProp = H.deleteEntity(tabletProp)
    local ped = PlayerPedId()
    StopAnimTask(ped, Config.Anim.tablet.dict, Config.Anim.tablet.clip, 2.0)
end

local function closeTablet()
    if not tabletOpen then return end
    tabletOpen = false
    SetNuiFocus(false, false)
    ui('tablet', { open = false })
    stopTabletAnim()
end

local function startTabletAnim()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    if H.loadDict(Config.Anim.tablet.dict) then
        TaskPlayAnim(ped, Config.Anim.tablet.dict, Config.Anim.tablet.clip, 3.0, -3.0, -1, 49, 0.0, false, false, false)
    end
    tabletProp = H.attachProp('prop_cs_tablet', 60309, vector3(0.03, 0.002, -0.0), vector3(10.0, 160.0, 0.0))
end

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb({ ok = true })
end)

RegisterNUICallback('accept', function(data, cb)
    if type(data) == 'table' and type(data.id) == 'string' then
        TriggerServerEvent('fivex_marina:accept', data.id)
    end
    cb({ ok = true })
end)

RegisterNUICallback('cancelContract', function(_, cb)
    TriggerServerEvent('fivex_marina:cancel')
    cb({ ok = true })
end)

RegisterNUICallback('requestBoat', function(_, cb)
    TriggerServerEvent('fivex_marina:requestBoat')
    cb({ ok = true })
end)

RegisterNUICallback('closeSummary', function(_, cb)
    SetNuiFocus(false, false)
    cb({ ok = true })
end)

---------------------------------------------------------------------------
-- HUD: objective checklist built from the contract state
---------------------------------------------------------------------------

local function slipId(i)
    local s = Config.Slips[i or 1]
    return s and s.id or '?'
end

local function countTrue(t, n)
    local c = 0
    for i = 1, n do if t and t[i] then c = c + 1 end end
    return c
end

local function buildSteps(c)
    if not c then return {} end
    local k = c.kind
    if k == 'detail' then
        local done = countTrue(c.detail, #Config.DetailPoints)
        return { { text = L('step_detail', done), done = done >= 4, active = true } }
    elseif k == 'refuel' then
        return {
            { text = L('step_get_can'), done = c.hasCan, active = not c.hasCan },
            { text = L('step_pour', slipId(c.slip)), done = false, active = c.hasCan },
        }
    elseif k == 'recovery' then
        return {
            { text = c.points and L('step_find_runner') or L('step_locating'), done = c.boarded, active = not c.boarded },
            { text = L('step_repair'), done = c.repaired, active = c.boarded and not c.repaired },
            { text = L('step_return_runner', slipId(c.slip)), done = false, active = c.repaired },
        }
    elseif k == 'debris' then
        local n = c.needPoints
        local got = countTrue(c.collected, n)
        return {
            { text = c.points and L('step_debris', got, n) or L('step_locating'), done = got >= n, active = got < n },
            { text = L('step_unload'), done = false, active = got >= n },
        }
    elseif k == 'charter' then
        local n = c.needPoints
        local steps = { { text = L('step_pickup_pax'), done = c.picked, active = not c.picked } }
        steps[2] = { text = c.points and L('step_tour', math.min((c.wp or 0) + 1, n), n) or L('step_locating'),
            done = (c.wp or 0) >= n, active = c.picked and (c.wp or 0) < n }
        steps[3] = { text = L('step_return_pax'), done = false, active = (c.wp or 0) >= n }
        return steps
    elseif k == 'rescue' then
        return {
            { text = c.points and L('step_find_victim') or L('step_locating'), done = c.picked, active = not c.picked },
            { text = L('step_pull_victim'), done = c.picked, active = false },
            { text = L('step_deliver_victim'), done = false, active = c.picked },
        }
    end
    return {}
end

local function pushHud()
    if not onDuty then
        ui('hud', { show = false })
        return
    end
    -- endsIn / elapsed were measured when the contract arrived; age them to "now"
    local age = contract and (GetGameTimer() - (contract.recvAt or GetGameTimer())) or 0
    ui('hud', {
        show = true,
        profile = profile,
        contract = contract and {
            id = contract.id,
            kind = contract.kind,
            label = contract.label,
            pay = contract.pay,
            par = contract.par,
            endsIn = contract.endsIn - age,
            elapsed = contract.elapsed + age,
            areaLabel = contract.areaLabel,
            steps = buildSteps(contract),
            stars = ctx and ctx.stars or nil,
        } or false,
    })
end

---------------------------------------------------------------------------
-- Work boat
---------------------------------------------------------------------------

local function deleteBoat()
    boatBlip = H.removeBlip(boatBlip)
    boat = H.deleteEntity(boat)
end

RegisterNetEvent('fivex_marina:spawnBoat', function(d)
    if type(d) ~= 'table' then return end
    deleteBoat()
    local veh = H.spawnBoat(d.model, d.x, d.y, d.z, d.w, true, Config.BoatPlate)
    if veh == 0 then
        H.notify('Work boat failed to spawn.', 'error')
        return
    end
    SetBoatAnchor(veh, false)
    boat = veh
    boatBlip = AddBlipForEntity(veh)
    SetBlipSprite(boatBlip, 427)
    SetBlipColour(boatBlip, 3)
    SetBlipScale(boatBlip, 0.8)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Work boat')
    EndTextCommandSetBlipName(boatBlip)
    TriggerServerEvent('fivex_marina:boatSpawned', NetworkGetNetworkIdFromEntity(veh))
end)

RegisterNetEvent('fivex_marina:delBoat', function()
    deleteBoat()
end)

local function myBoat()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and GetVehicleClass(veh) == 14 and GetPedInVehicleSeat(veh, -1) == ped then
        return veh
    end
    return 0
end

local function freeSeat(veh)
    local n = GetVehicleMaxNumberOfPassengers(veh)
    for s = 0, n - 1 do
        if IsVehicleSeatFree(veh, s) then return s end
    end
    return nil
end

---------------------------------------------------------------------------
-- Contract runtime
---------------------------------------------------------------------------

--- linger: leave boats / peds in the world a few seconds so a finished job doesn't pop out of existence
local function clearCtx(linger)
    if not ctx then return end
    for _, b in pairs(ctx.blips) do H.removeBlip(b) end
    if linger then
        local ents = ctx.ents
        SetTimeout(10000, function()
            for _, e in pairs(ents) do H.deleteEntity(e) end
        end)
    else
        for _, e in pairs(ctx.ents) do H.deleteEntity(e) end
    end
    for _, fx in pairs(ctx.loops) do if fx ~= 0 then StopParticleFxLooped(fx, false) end end
    if ctx.can ~= 0 then H.deleteEntity(ctx.can) end
    H.progress(false)
    ui('gauge', { show = false })
    ctx = nil
end

local function newCtx(c)
    return {
        id = c.id, kind = c.kind,
        blips = {}, ents = {}, loops = {},
        can = 0, stars = c.kind == 'charter' and 5 or nil,
        sentPoints = false, spawned = {}, local_ = {}, retry = {},
    }
end

local function setBlip(key, x, y, z, sprite, color, label, route, scale)
    if ctx.blips[key] then H.removeBlip(ctx.blips[key]) end
    ctx.blips[key] = H.blip(x, y, z, sprite, color, label, route, scale)
end

local function dropBlip(key)
    if ctx and ctx.blips[key] then
        H.removeBlip(ctx.blips[key])
        ctx.blips[key] = nil
    end
end

local function routeTo(x, y, z, label, sprite, color)
    setBlip('route', x, y, z, sprite or 1, color or 3, label, true)
end

-- Locate sea objectives for a fresh contract (client-side water search, server validates)
local function locateSeaPoints(c)
    if ctx.sentPoints then return end
    ctx.sentPoints = true
    CreateThread(function()
        local spacing = c.kind == 'debris' and Config.DebrisSpacing or (c.kind == 'charter' and nil or 60.0)
        local pts = H.seaPoints(c.area, c.needPoints, spacing)
        if not pts then
            local a = Config.SeaAreas[c.area]
            pts = {}
            for i = 1, c.needPoints do
                pts[i] = vector3(a.center.x + (i - 1) * 25.0, a.center.y, 0.0)
            end
        end
        local out = {}
        for i = 1, #pts do out[i] = { x = pts[i].x, y = pts[i].y, z = pts[i].z } end
        if ctx and ctx.id == c.id then
            TriggerServerEvent('fivex_marina:seaPoints', c.id, out)
        end
    end)
end

-- When a far-away spot comes into streaming range, make sure it really is open water.
-- Nothing is spawned at a sea spot until it is verified ('ok'), so a moved spot never leaves
-- a duplicate runner / swimmer behind.
local VERIFY_RANGE = 220.0
local SPAWN_RANGE = 200.0

local function seaReady(i)
    return ctx and ctx.verified and ctx.verified[i] == 'ok'
end

local function verifySeaPoint(i, p)
    ctx.verified = ctx.verified or {}
    if ctx.verified[i] then return end
    local me = GetEntityCoords(PlayerPedId())
    if #(vector2(me.x, me.y) - vector2(p.x, p.y)) > VERIFY_RANGE then return end
    ctx.verified[i] = 'pending'
    local my, cid = ctx, ctx.id
    CreateThread(function()
        RequestCollisionAtCoord(p.x, p.y, p.z)
        Wait(500)
        if ctx ~= my then return end
        if H.isOpenWater(p.x, p.y, true) then my.verified[i] = 'ok' return end
        local np = H.findWater(p.x, p.y, Config.SeaSnapRadius, nil, 80)
        if ctx ~= my then return end
        if not np then my.verified[i] = 'ok' return end
        TriggerServerEvent('fivex_marina:movePoint', cid, i, { x = np.x, y = np.y, z = np.z })
        -- server refused the move: use the original spot rather than waiting forever
        SetTimeout(4000, function()
            if ctx == my and my.verified[i] == 'pending' then my.verified[i] = 'ok' end
        end)
    end)
end

local function mooredBoat(model, x, y, z, w)
    -- local (non-networked) prop boat: never shared with or deleted by another contract/player
    local veh = H.spawnBoat(model, x, y, z, w, false, 'CLIENT')
    if veh == 0 then return 0 end
    SetVehicleEngineOn(veh, false, true, true)
    SetVehicleDoorsLocked(veh, 2)
    if CanAnchorBoatHere(veh) then SetBoatAnchor(veh, true) end
    FreezeEntityPosition(veh, true)
    return veh
end

local function setupContract(c)
    local k = c.kind
    -- spawning waits on model loads: the contract can end meanwhile, so re-check before storing
    local function stillMine(ent)
        if ctx and ctx.id == c.id then return true end
        H.deleteEntity(ent)
        return false
    end
    if k == 'detail' then
        local b = Config.DetailBoat
        local veh = mooredBoat(Config.DetailBoatModel, b.x, b.y, b.z, b.w)
        if not stillMine(veh) then return end
        ctx.ents.detailBoat = veh
        if veh ~= 0 then SetVehicleDirtLevel(veh, 15.0) end
        ctx.cleanTarget = veh
        routeTo(Config.DetailCenter.x, Config.DetailCenter.y, Config.DetailCenter.z, 'Hull detail', 427, 3)
    elseif k == 'refuel' then
        local s = Config.Slips[c.slip].coords
        local veh = mooredBoat(c.boatModel or 'tropic', s.x, s.y, s.z, 0.0)
        if not stillMine(veh) then return end
        ctx.ents.client = veh
    elseif k == 'charter' then
        local d = Config.DockStand
        local ped = H.spawnPed(c.npcModel, d.x, d.y, d.z, 0.0)
        if not stillMine(ped) then return end
        if ped ~= 0 then
            TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_TOURIST_MAP', 0, true)
            ctx.ents.pax = ped
            local b = AddBlipForEntity(ped)
            SetBlipSprite(b, 280)
            SetBlipColour(b, 3)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('Passenger')
            EndTextCommandSetBlipName(b)
            ctx.blips.pax = b
        end
        ctx.lastSpeed = 0.0
        ctx.airSince = nil
        ctx.bumpCd = 0
    end
    if c.needPoints and c.needPoints > 0 and not c.points then
        H.notify(L('searching'), 'info')
        locateSeaPoints(c)
    end
end

local function updateRoute(c)
    if not ctx or ctx.id ~= c.id then return end
    local k = c.kind
    if k == 'refuel' then
        if not c.hasCan then
            routeTo(Config.FuelPump.x, Config.FuelPump.y, Config.FuelPump.z, 'Fuel pump', 361, 5)
        else
            local s = Config.Slips[c.slip].coords
            routeTo(s.x, s.y, s.z, 'Slip ' .. slipId(c.slip), 361, 5)
        end
    elseif k == 'recovery' and c.points then
        if not c.repaired then
            local p = c.points[1]
            routeTo(p.x, p.y, p.z, 'Drifting runner', 427, 1)
        else
            local s = Config.Slips[c.slip].coords
            routeTo(s.x, s.y, s.z, 'Slip ' .. slipId(c.slip), 427, 2)
        end
    elseif k == 'debris' and c.points then
        local all = true
        for i = 1, #c.points do
            if c.collected and c.collected[i] then
                dropBlip('d' .. i)
            else
                all = false
                if not ctx.blips['d' .. i] then
                    local p = c.points[i]
                    setBlip('d' .. i, p.x, p.y, p.z, 1, 5, 'Debris', false, 0.6)
                end
            end
        end
        if all then
            local d = Config.DockStand
            routeTo(d.x, d.y, d.z, 'Unload', 478, 3)
        else
            -- route to the first remaining piece
            for i = 1, #c.points do
                if not (c.collected and c.collected[i]) then
                    local p = c.points[i]
                    routeTo(p.x, p.y, p.z, 'Debris field', 1, 5)
                    break
                end
            end
        end
    elseif k == 'charter' then
        if not c.picked then
            local d = Config.DockStand
            routeTo(d.x, d.y, d.z, 'Passenger', 280, 3)
        elseif c.points and (c.wp or 0) < #c.points then
            local p = c.points[(c.wp or 0) + 1]
            routeTo(p.x, p.y, p.z, ('Stop %d'):format((c.wp or 0) + 1), 1, 3)
        else
            local d = Config.DockStand
            routeTo(d.x, d.y, d.z, 'Drop-off', 280, 2)
        end
    elseif k == 'rescue' and c.points then
        if not c.picked then
            local p = c.points[1]
            routeTo(p.x, p.y, p.z, 'MAYDAY', 280, 1)
        else
            local d = Config.DockStand
            routeTo(d.x, d.y, d.z, 'Medics', 61, 1)
        end
    end
end

RegisterNetEvent('fivex_marina:contract', function(c)
    if type(c) ~= 'table' then
        clearCtx(true)
        contract = nil
        pushHud()
        return
    end
    c.recvAt = GetGameTimer()  -- endsIn / elapsed are relative to this moment
    if not ctx or ctx.id ~= c.id then
        clearCtx()
        ctx = newCtx(c)
        contract = c
        ctx.pointsAt = GetGameTimer()
        setupContract(c)
        if not ctx or ctx.id ~= c.id then return end
    else
        -- points changed (moved after verification): respawn sea entities at the new spots
        if contract and contract.points and c.points then
            for i = 1, #c.points do
                local o, n = contract.points[i], c.points[i]
                if o and n and (o.x ~= n.x or o.y ~= n.y) then
                    if ctx.ents['sea' .. i] then ctx.ents['sea' .. i] = H.deleteEntity(ctx.ents['sea' .. i]) end
                    ctx.spawned[i] = nil
                    ctx.verified = ctx.verified or {}
                    ctx.verified[i] = nil
                    dropBlip('d' .. i)
                    if i == 1 and c.kind == 'recovery' and not c.boarded then
                        ctx.ents.runner = H.deleteEntity(ctx.ents.runner)
                        dropBlip('runner')
                    end
                    if i == 1 and c.kind == 'rescue' and not c.picked then
                        ctx.ents.victim = H.deleteEntity(ctx.ents.victim)
                        dropBlip('victim')
                        if ctx.loops.flare and ctx.loops.flare ~= 0 then StopParticleFxLooped(ctx.loops.flare, false) end
                        ctx.loops.flare = nil
                    end
                end
            end
        end
        -- sea spots never arrived (lost / rejected): search again
        if c.needPoints and c.needPoints > 0 and not c.points and GetGameTimer() - (ctx.pointsAt or 0) > 8000 then
            ctx.pointsAt = GetGameTimer()
            ctx.sentPoints = false
            locateSeaPoints(c)
        end
        contract = c
    end
    updateRoute(c)
    pushHud()
end)

-- Re-ask for sea spots if the server never accepted them (checked from the main loop)
local function retryPoints()
    local c = contract
    if not c or not ctx or ctx.id ~= c.id then return end
    if c.needPoints and c.needPoints > 0 and not c.points and GetGameTimer() - (ctx.pointsAt or 0) > 10000 then
        ctx.pointsAt = GetGameTimer()
        ctx.sentPoints = false
        locateSeaPoints(c)
    end
end

---------------------------------------------------------------------------
-- Per-kind interactions (called every frame while relevant)
---------------------------------------------------------------------------

local function planar(a, x, y)
    return #(vector2(a.x, a.y) - vector2(x, y))
end

local function tickDetail(c, p)
    local near = false
    for i = 1, #Config.DetailPoints do
        if not (c.detail and c.detail[i]) and not ctx.local_[i] then
            local pt = Config.DetailPoints[i]
            local d = planar(p, pt.x, pt.y)
            if d < 40.0 then
                near = true
                H.marker(pt.x, pt.y, pt.z, 0.8)
                H.text3D(pt.x, pt.y, pt.z + 0.6, ('Scrub %d'):format(i))
                if d < 1.6 and not busy then
                    H.help(L('prompt_scrub'))
                    if IsControlJustPressed(0, 38) then
                        busy = true
                        local veh = ctx.cleanTarget
                        local lastFx = 0
                        local ok = H.hold(Config.Anim.scrub.ms, {
                            label = 'Scrubbing', scenario = Config.Anim.scrub.scenario,
                            onTick = function()
                                if GetGameTimer() - lastFx > 450 and veh and veh ~= 0 and DoesEntityExist(veh) then
                                    lastFx = GetGameTimer()
                                    local vc = GetEntityCoords(veh)
                                    local mid = (vector3(pt.x, pt.y, vc.z) + vc) / 2.0
                                    H.fx('soap', mid.x, mid.y, vc.z + 0.6, 0.6)
                                end
                            end,
                        })
                        if ok and ctx and ctx.id == c.id then
                            ctx.local_[i] = true
                            if veh and veh ~= 0 and DoesEntityExist(veh) then
                                SetVehicleDirtLevel(veh, math.max(0.0, GetVehicleDirtLevel(veh) - 15.0 / #Config.DetailPoints))
                            end
                            H.sound('PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET')
                            TriggerServerEvent('fivex_marina:scrub', c.id, i)
                        end
                        busy = false
                    end
                end
            end
        end
    end
    return near
end

local function tickRefuel(c, p)
    if not c.hasCan then
        local pump = Config.FuelPump
        local d = #(p - pump)
        if d > 60.0 then return false end
        H.marker(pump.x, pump.y, pump.z)
        H.text3D(pump.x, pump.y, pump.z + 0.8, 'Fuel pump')
        if d < Config.InteractDistance and not busy then
            H.help(L('prompt_can'))
            if IsControlJustPressed(0, 38) then
                busy = true
                if H.hold(Config.Anim.grab.ms, { label = 'Filling can', dict = Config.Anim.grab.dict, clip = Config.Anim.grab.clip })
                    and ctx and ctx.id == c.id then
                    local can = H.attachProp('w_am_jerrycan', 57005, vector3(0.12, 0.0, -0.05), vector3(-80.0, 0.0, 90.0))
                    if ctx and ctx.id == c.id then ctx.can = can else H.deleteEntity(can) end
                    H.sound('PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET')
                    H.notify(L('can_ready', slipId(c.slip)), 'success')
                    TriggerServerEvent('fivex_marina:grabCan', c.id)
                end
                busy = false
            end
        end
        return true
    end
    local s = Config.Slips[c.slip].coords
    local d = planar(p, s.x, s.y)
    if d > 60.0 then return false end
    H.seaMarker(s.x, s.y, s.z + 1.0, 250, 204, 21)
    H.text3D(s.x, s.y, s.z + 2.2, 'Refuel')
    if d < 6.0 and not busy and not IsPedInAnyVehicle(PlayerPedId(), false) then
        H.help(L('prompt_pour'))
        if IsControlJustPressed(0, 38) then
            busy = true
            local ped = PlayerPedId()
            TaskTurnPedToFaceCoord(ped, s.x, s.y, s.z, 600)
            Wait(600)
            local anim = Config.Anim.pour
            if H.loadDict(anim.dict) then
                TaskPlayAnim(ped, anim.dict, anim.clip, 4.0, -4.0, -1, 49, 0.0, false, false, false)
            end
            local fill, last = 0.0, GetGameTimer()
            local P = Config.Pour
            ui('gauge', { show = true, value = 0, perfect = P.perfectMin, ok = P.okMin, spill = P.spillAt })
            while IsControlPressed(0, 38) or IsDisabledControlPressed(0, 38) do
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                local now = GetGameTimer()
                -- pours slightly faster the longer you hold: keeps the release honest
                fill = fill + (now - last) / 1000.0 * P.rate * (1.0 + fill * 0.35)
                last = now
                ui('gauge', { show = true, value = fill })
                if fill >= P.spillAt then break end
                Wait(0)
            end
            StopAnimTask(ped, anim.dict, anim.clip, 2.0)
            if fill >= P.spillAt then
                H.notify(L('spilled'), 'error')
                H.sound('ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET')
            end
            if fill > 0.05 then
                ui('gauge', { show = true, value = fill, done = true })
                TriggerServerEvent('fivex_marina:pour', c.id, fill)
                if ctx then ctx.can = H.deleteEntity(ctx.can) end
                SetTimeout(1800, function() ui('gauge', { show = false }) end)
            else
                ui('gauge', { show = false })
            end
            busy = false
        end
    end
    return true
end

local function runnerEnt()
    local r = ctx.ents.runner
    if r and r ~= 0 and DoesEntityExist(r) then return r end
    return 0
end

local function tickRecovery(c, p)
    if not c.points then return false end
    local pt = c.points[1]
    local ped = PlayerPedId()
    local runner = runnerEnt()
    if not ctx.spawned[1] then
        verifySeaPoint(1, pt)
        if planar(p, pt.x, pt.y) < SPAWN_RANGE and seaReady(1) then
            ctx.spawned[1] = true
            local my = ctx
            local veh = H.spawnBoat(c.runnerModel, pt.x, pt.y, pt.z + 0.3, math.random(0, 359) + 0.0, true, 'ADRIFT')
            if ctx ~= my then H.deleteEntity(veh) return false end
            if veh ~= 0 then
                SetVehicleEngineOn(veh, false, true, true)
                SetVehicleUndriveable(veh, true)
                SetVehicleEngineHealth(veh, 150.0)
                SetBoatAnchor(veh, false)
                ctx.ents.runner = veh
                ctx.ents['sea1'] = nil
                local b = AddBlipForEntity(veh)
                SetBlipSprite(b, 427)
                SetBlipColour(b, 1)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName('Drifting runner')
                EndTextCommandSetBlipName(b)
                ctx.blips.runner = b
                TriggerServerEvent('fivex_marina:runnerSpawned', c.id, NetworkGetNetworkIdFromEntity(veh))
            end
        end
        return planar(p, pt.x, pt.y) < 400.0
    end
    -- runner gone or wrecked: report it (repeat every few seconds until the server agrees)
    local wrecked = runner == 0 or IsEntityDead(runner) or GetVehicleBodyHealth(runner) <= 0.0
    if wrecked then
        if ctx.ents.runner and (not ctx.failAt or GetGameTimer() > ctx.failAt) then
            ctx.failAt = GetGameTimer() + 5000
            TriggerServerEvent('fivex_marina:fail', c.id, 'sunk')
        end
        if runner == 0 then return false end
    end
    local rc = GetEntityCoords(runner)
    local inRunner = GetVehiclePedIsIn(ped, false) == runner
    if not c.boarded then
        local d = #(p - rc)
        if d < 120.0 then
            H.text3D(rc.x, rc.y, rc.z + 2.0, 'Adrift')
        end
        if d < 8.0 and not busy then
            H.help(L('prompt_board'))
            if IsControlJustPressed(0, 38) then
                busy = true
                TaskWarpPedIntoVehicle(ped, runner, -1)
                -- wait until the server can see us in the seat before reporting
                local t = GetGameTimer() + 2000
                while GetVehiclePedIsIn(ped, false) ~= runner and GetGameTimer() < t do Wait(50) end
                Wait(500)
                H.notify(L('engine_dead'), 'error')
                TriggerServerEvent('fivex_marina:board', c.id)
                busy = false
            end
        end
        return d < 300.0
    end
    if not c.repaired then
        if inRunner and not busy then
            H.help(L('prompt_repair'))
            if IsControlJustPressed(0, 38) then
                busy = true
                local lastCrank = 0
                local ok = H.hold(Config.Anim.repair.ms, {
                    label = 'Bleeding fuel line',
                    onTick = function()
                        if GetGameTimer() - lastCrank > 900 then
                            lastCrank = GetGameTimer()
                            SetVehicleEngineOn(runner, true, true, true)
                            SetTimeout(250, function()
                                if DoesEntityExist(runner) and not (contract and contract.repaired) then
                                    SetVehicleEngineOn(runner, false, true, true)
                                end
                            end)
                        end
                    end,
                })
                if ok and ctx and ctx.id == c.id and DoesEntityExist(runner) then
                    SetVehicleUndriveable(runner, false)
                    SetVehicleEngineHealth(runner, 1000.0)
                    SetVehicleEngineOn(runner, true, true, false)
                    H.sound('CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET')
                    H.notify(L('engine_fixed', slipId(c.slip)), 'success')
                    TriggerServerEvent('fivex_marina:repair', c.id)
                end
                busy = false
            end
        end
        return true
    end
    local s = Config.Slips[c.slip].coords
    local d = #(vector3(p.x, p.y, s.z) - s)
    if d < 120.0 then
        H.seaMarker(s.x, s.y, s.z + 1.0, 74, 222, 128)
        H.text3D(s.x, s.y, s.z + 2.2, 'Slip ' .. slipId(c.slip))
    end
    if inRunner and d < Config.DockRadius and GetEntitySpeed(runner) < Config.DockSpeed and not busy then
        H.help(L('prompt_dock'))
        if IsControlJustPressed(0, 38) then
            busy = true
            TriggerServerEvent('fivex_marina:dock', c.id)
            SetTimeout(1000, function() busy = false end)
        end
    end
    return d < 150.0 or inRunner
end

local function tickDebris(c, p)
    if not c.points then return false end
    local near = false
    local allDone = true
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    local my = ctx
    for i = 1, #c.points do
        local pt = c.points[i]
        local acked = c.collected and c.collected[i]
        if not acked then
            allDone = false
            local d = planar(p, pt.x, pt.y)
            if ctx.local_[i] then
                -- scooped but the server hasn't confirmed yet: resend while still close
                if d < 20.0 and GetGameTimer() > (ctx.retry[i] or 0) then
                    ctx.retry[i] = GetGameTimer() + 2500
                    TriggerServerEvent('fivex_marina:collect', c.id, i)
                end
            else
                verifySeaPoint(i, pt)
                if d < 250.0 then
                    near = true
                    if not ctx.spawned[i] and seaReady(i) then
                        ctx.spawned[i] = true
                        local model = Config.DebrisModels[((i - 1) % #Config.DebrisModels) + 1]
                        local hash = H.requestModel(model, 3000)
                        if hash == 0 then hash = H.requestModel('prop_barrel_01a', 3000) end
                        if ctx ~= my then return false end
                        if hash ~= 0 then
                            local obj = CreateObject(hash, pt.x, pt.y, pt.z - 0.2, false, false, false)
                            SetModelAsNoLongerNeeded(hash)
                            SetEntityHeading(obj, math.random(0, 359) + 0.0)
                            FreezeEntityPosition(obj, true)
                            SetEntityCollision(obj, false, false)
                            ctx.ents['sea' .. i] = obj
                        end
                    end
                    if d < 60.0 then
                        DrawMarker(0, pt.x, pt.y, pt.z + 2.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.8,
                            250, 204, 21, 200, true, true, 2, false, nil, nil, false)
                    end
                    if d < Config.DebrisScoopRadius and veh ~= 0 and ctx.spawned[i] then
                        ctx.local_[i] = true
                        ctx.retry[i] = GetGameTimer() + 2500
                        ctx.ents['sea' .. i] = H.deleteEntity(ctx.ents['sea' .. i])
                        H.fx('splash', pt.x, pt.y, pt.z, 1.0)
                        H.sound('PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET')
                        dropBlip('d' .. i)
                        TriggerServerEvent('fivex_marina:collect', c.id, i)
                        local left = 0
                        for j = 1, #c.points do
                            if not ((c.collected and c.collected[j]) or ctx.local_[j]) then left = left + 1 end
                        end
                        if left == 0 then H.notify(L('all_debris'), 'success') end
                    end
                end
            end
        end
    end
    if allDone then
        local dock = Config.DockStand
        local d = #(p - dock)
        if d < 80.0 then
            near = true
            H.marker(dock.x, dock.y, dock.z, 1.4)
            H.text3D(dock.x, dock.y, dock.z + 0.8, 'Unload debris')
        end
        if d < 15.0 and not busy then
            H.help(L('prompt_unload'))
            if IsControlJustPressed(0, 38) then
                busy = true
                local a = Config.Anim.unload
                if H.hold(a.ms, { label = 'Unloading', dict = a.dict, clip = a.clip, flag = 49 }) and ctx == my then
                    TriggerServerEvent('fivex_marina:unload', c.id)
                end
                busy = false
            end
        end
    end
    return near
end

local function paxInBoat()
    local pax = ctx.ents.pax
    if not pax or pax == 0 or not DoesEntityExist(pax) then return false end
    return IsPedInAnyVehicle(pax, false)
end

local function tickCharter(c, p)
    local pax = ctx.ents.pax
    local paxOk = pax and pax ~= 0 and DoesEntityExist(pax)
    if paxOk and IsEntityDead(pax) and not ctx.failSent then
        ctx.failSent = true
        TriggerServerEvent('fivex_marina:paxBailed', c.id)
        return false
    end
    local veh = myBoat()
    local dock = Config.DockStand
    local dDock = #(p - dock)

    if not c.picked then
        if dDock < 80.0 then
            H.marker(dock.x, dock.y, dock.z, 1.6)
        end
        if veh ~= 0 and dDock < 20.0 and GetEntitySpeed(veh) < 2.0 and paxOk and not ctx.boarding then
            local seat = freeSeat(veh)
            if seat then
                ctx.boarding = GetGameTimer()
                ClearPedTasks(pax)
                TaskEnterVehicle(pax, veh, 8000, seat, 1.5, 1, 0)
                ctx.boardSeat = seat
            end
        elseif dDock < 30.0 and not ctx.boarding then
            H.help(L('prompt_pickup_pax'))
        end
        if paxOk and IsPedInAnyVehicle(pax, false) then
            -- aboard: tell the server (and keep telling it until it confirms)
            if ctx.boarding then
                ctx.boarding = nil
                H.notify(L('pax_boarded'), 'success')
                H.sound('CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET')
            end
            if GetGameTimer() > (ctx.boardRetry or 0) then
                ctx.boardRetry = GetGameTimer() + 2500
                TriggerServerEvent('fivex_marina:paxBoarded', c.id)
            end
        elseif ctx.boarding and paxOk then
            if GetGameTimer() - ctx.boarding > 7000 and veh ~= 0 then
                local seat = freeSeat(veh)
                if seat then TaskWarpPedIntoVehicle(pax, veh, seat) end
            end
        end
        return dDock < 120.0
    end

    -- passenger aboard: comfort tracking (bumps and airtime cost stars)
    if veh ~= 0 then
        local speed = GetEntitySpeed(veh)
        local now = GetGameTimer()
        if ctx.lastSpeed - speed > 6.0 and HasEntityCollidedWithAnything(veh) and now > ctx.bumpCd then
            ctx.bumpCd = now + 3000
            ctx.stars = math.max(1, ctx.stars - 1)
            local lines = L('pax_bump')
            H.subtitle(lines[math.random(1, #lines)], 3500)
            H.sound('ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET')
            pushHud()
        end
        if IsEntityInAir(veh) then
            ctx.airSince = ctx.airSince or now
            if now - ctx.airSince > 1200 and now > ctx.bumpCd then
                ctx.bumpCd = now + 3000
                ctx.stars = math.max(1, ctx.stars - 1)
                local lines = L('pax_bump')
                H.subtitle(lines[math.random(1, #lines)], 3500)
                pushHud()
            end
        else
            ctx.airSince = nil
        end
        ctx.lastSpeed = speed
    end
    if paxOk and not IsPedInAnyVehicle(pax, false) and #(GetEntityCoords(pax) - p) > 40.0 and not ctx.failSent then
        ctx.failSent = true
        TriggerServerEvent('fivex_marina:paxBailed', c.id)
        return false
    end

    if c.points and (c.wp or 0) < #c.points then
        local i = (c.wp or 0) + 1
        local pt = c.points[i]
        verifySeaPoint(i, pt)
        local d = planar(p, pt.x, pt.y)
        if d < 300.0 then
            H.seaMarker(pt.x, pt.y, pt.z + 1.0)
            H.text3D(pt.x, pt.y, pt.z + 4.0, ('Stop %d'):format(i))
        end
        if d < 30.0 then
            if ctx.lastWp ~= i then
                ctx.lastWp = i
                local lines = L('pax_lines')
                H.subtitle(lines[math.random(1, #lines)], 5000)
                H.sound('CHECKPOINT_NORMAL', 'HUD_MINI_GAME_SOUNDSET')
            end
            -- resend until the server moves us to the next stop
            if GetGameTimer() > (ctx.wpRetry or 0) then
                ctx.wpRetry = GetGameTimer() + 2500
                TriggerServerEvent('fivex_marina:waypoint', c.id, i)
            end
        end
        return true
    end

    if c.points and (c.wp or 0) >= #c.points then
        if dDock < 120.0 then H.marker(dock.x, dock.y, dock.z, 1.6) end
        if dDock < 20.0 and not busy then
            H.help(L('prompt_dropoff'))
            if IsControlJustPressed(0, 38) then
                busy = true
                local stars = ctx.stars or 3
                if paxOk then
                    ctx.ents.pax = nil
                    dropBlip('pax')
                    TaskLeaveVehicle(pax, GetVehiclePedIsIn(pax, false), 16)
                    Wait(400)
                    SetEntityCoords(pax, dock.x + 1.0, dock.y, dock.z, false, false, false, false)
                    TaskWanderStandard(pax, 10.0, 10)
                    SetPedAsNoLongerNeeded(pax)
                    SetTimeout(20000, function() H.deleteEntity(pax) end)
                end
                TriggerServerEvent('fivex_marina:dropoff', c.id, stars)
                busy = false
            end
        end
        return dDock < 150.0
    end
    return true
end

local function tickRescue(c, p)
    if not c.points then return false end
    local pt = c.points[1]
    local ped = PlayerPedId()
    if not c.picked then
        verifySeaPoint(1, pt)
        local d = planar(p, pt.x, pt.y)
        -- red flare smoke marks the spot
        if d < 600.0 and not ctx.loops.flare then
            ctx.loops.flare = H.fxLooped('flare', pt.x, pt.y, pt.z + 0.5)
        end
        if d < SPAWN_RANGE and not ctx.spawned[1] and seaReady(1) then
            ctx.spawned[1] = true
            local my = ctx
            local v = H.spawnPed(c.npcModel, pt.x, pt.y, pt.z, 0.0)
            if ctx ~= my then H.deleteEntity(v) return false end
            if v ~= 0 then
                SetEntityInvincible(v, true)
                SetPedDiesInWater(v, false)
                ctx.ents.victim = v
                ctx.ents['sea1'] = nil
                local b = AddBlipForEntity(v)
                SetBlipSprite(b, 280)
                SetBlipColour(b, 1)
                SetBlipFlashes(b, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName('Swimmer')
                EndTextCommandSetBlipName(b)
                ctx.blips.victim = b
            end
        end
        local v = ctx.ents.victim
        local myVeh = GetVehiclePedIsIn(ped, false)
        if v and v ~= 0 and DoesEntityExist(v) and myVeh ~= 0 and GetVehiclePedIsIn(v, false) == myVeh then
            -- already pulled aboard: keep reporting until the server confirms
            if GetGameTimer() > (ctx.pickRetry or 0) then
                ctx.pickRetry = GetGameTimer() + 2500
                TriggerServerEvent('fivex_marina:victimAboard', c.id)
            end
        elseif v and v ~= 0 and DoesEntityExist(v) then
            local vc = GetEntityCoords(v)
            if d < 120.0 then H.text3D(vc.x, vc.y, vc.z + 1.2, 'HELP!') end
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and #(p - vc) < 9.0 and GetEntitySpeed(veh) < 4.0 and not busy then
                H.help(L('prompt_victim'))
                if IsControlJustPressed(0, 38) then
                    busy = true
                    if H.hold(2500, { label = 'Pulling aboard' }) and ctx and ctx.id == c.id and DoesEntityExist(v) then
                        local seat = freeSeat(veh)
                        if seat then TaskWarpPedIntoVehicle(v, veh, seat) end
                        dropBlip('victim')
                        H.sound('CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET')
                        H.notify(L('victim_aboard'), 'success')
                        ctx.pickRetry = GetGameTimer() + 2500
                        TriggerServerEvent('fivex_marina:victimAboard', c.id)
                    end
                    busy = false
                end
            end
        end
        return d < 600.0
    end

    local dock = Config.DockStand
    local dDock = #(p - dock)
    if not ctx.ents.medic then
        local my = ctx
        ctx.ents.medic = 0
        local medic = H.spawnPed(Config.ParamedicModel, dock.x + 1.5, dock.y + 1.0, dock.z, 0.0)
        if ctx ~= my then H.deleteEntity(medic) return false end
        if medic ~= 0 then
            TaskStartScenarioInPlace(medic, 'CODE_HUMAN_MEDIC_TIME_OF_DEATH', 0, true)
            ctx.ents.medic = medic
        else
            ctx.ents.medic = 0
        end
    end
    if dDock < 120.0 then H.marker(dock.x, dock.y, dock.z, 1.6) end
    if dDock < 20.0 and not busy then
        H.help(L('prompt_handoff'))
        if IsControlJustPressed(0, 38) then
            busy = true
            local v = ctx.ents.victim
            local cid = c.id
            if v and v ~= 0 and DoesEntityExist(v) then
                TaskLeaveVehicle(v, GetVehiclePedIsIn(v, false), 16)
                Wait(400)
                SetEntityCoords(v, dock.x + 0.8, dock.y + 0.6, dock.z, false, false, false, false)
                TaskStartScenarioInPlace(v, 'WORLD_HUMAN_SIT_UPS', 0, true)
            end
            TriggerServerEvent('fivex_marina:handoff', cid)
            busy = false
        end
    end
    return dDock < 150.0
end

local TICK = {
    detail = tickDetail,
    refuel = tickRefuel,
    recovery = tickRecovery,
    debris = tickDebris,
    charter = tickCharter,
    rescue = tickRescue,
}

---------------------------------------------------------------------------
-- Server events
---------------------------------------------------------------------------

RegisterNetEvent('fivex_marina:duty', function(state)
    onDuty = state and true or false
    if not onDuty then
        closeTablet()
        clearCtx()
        contract = nil
        deleteBoat()
    end
    pushHud()
end)

RegisterNetEvent('fivex_marina:board', function(data)
    if type(data) ~= 'table' then return end
    profile = data.profile
    ui('board', { data = data })
    pushHud()
    if data.open and not tabletOpen then
        tabletOpen = true
        SetNuiFocus(true, true)
        ui('tablet', { open = true })
        startTabletAnim()
    end
end)

RegisterNetEvent('fivex_marina:completed', function(data)
    if type(data) ~= 'table' then return end
    profile = data.profile
    clearCtx(true)
    contract = nil
    H.sound(data.rankUp and 'MEDAL_UP' or 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET')
    if data.rankUp then
        SetTimeout(1600, function() H.sound('RANK_UP', 'HUD_AWARDS') end)
    end
    ui('completed', { data = data })
    pushHud()
end)

RegisterNetEvent('fivex_marina:failed', function(data)
    if type(data) ~= 'table' then return end
    clearCtx(true)
    contract = nil
    H.sound('LOSER', 'HUD_AWARDS')
    ui('failed', { data = data })
    pushHud()
end)

RegisterNetEvent('fivex_marina:summary', function(data)
    if type(data) ~= 'table' then return end
    profile = data.profile
    SetNuiFocus(true, true)
    ui('summary', { data = data })
end)

RegisterNetEvent('fivex_marina:putOnDock', function(coords)
    if type(coords) ~= 'table' then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16)
        Wait(400)
    end
    DoScreenFadeOut(250)
    Wait(300)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    Wait(200)
    DoScreenFadeIn(400)
    -- work boat left far away at sea: the harbor crew brings it back
    if boat == 0 or not DoesEntityExist(boat)
        or #(GetEntityCoords(boat) - vector3(Config.DinghySpawn.x, Config.DinghySpawn.y, Config.DinghySpawn.z)) > 150.0 then
        TriggerServerEvent('fivex_marina:returnBoat')
    end
end)

---------------------------------------------------------------------------
-- Tablet keybind
---------------------------------------------------------------------------

RegisterCommand(Config.TabletCommand, function()
    if not onDuty then return end
    if tabletOpen then
        closeTablet()
        return
    end
    TriggerServerEvent('fivex_marina:requestBoard')
end, false)
RegisterKeyMapping(Config.TabletCommand, 'Harbor Authority tablet', 'keyboard', Config.TabletKey)

---------------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------------

CreateThread(function()
    local c = Config.Duty
    officeBlip = H.blip(c.x, c.y, c.z, Config.Blip.sprite, Config.Blip.color, Config.Blip.label, false, Config.Blip.scale)
    SetBlipAsShortRange(officeBlip, true)
end)

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        local office = vector3(Config.Duty.x, Config.Duty.y, Config.Duty.z)
        local dOffice = #(p - office)

        if dOffice < 30.0 then
            sleep = 0
            H.marker(office.x, office.y, office.z)
            H.text3D(office.x, office.y, office.z + 0.9, onDuty and 'Harbor office' or 'Harbor Authority — clock in')
            if dOffice < Config.InteractDistance and not busy and not tabletOpen then
                if onDuty then
                    H.help(L('prompt_tablet') .. '~n~~INPUT_DETONATE~ Clock out')
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('fivex_marina:requestBoard')
                    elseif IsControlJustPressed(0, 47) then
                        TriggerServerEvent('fivex_marina:clockIn')
                    end
                else
                    H.help(L('prompt_in'))
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('fivex_marina:clockIn')
                    end
                end
            end
        end

        if onDuty then
            -- lost the work boat: request a new one at the dock
            if boat == 0 or not DoesEntityExist(boat) or IsEntityDead(boat) then
                local dock = Config.DockStand
                local d = #(p - dock)
                if d < 30.0 then
                    sleep = 0
                    H.marker(dock.x, dock.y, dock.z)
                    H.text3D(dock.x, dock.y, dock.z + 0.8, 'Work boat')
                    if d < Config.InteractDistance and not busy then
                        H.help(L('prompt_veh'))
                        if IsControlJustPressed(0, 38) then
                            TriggerServerEvent('fivex_marina:requestBoat')
                        end
                    end
                end
            end

            -- dying on the job ends the contract instead of leaving it hanging until the timer runs out
            if contract and IsEntityDead(ped) then
                if not deathCancelled then
                    deathCancelled = true
                    TriggerServerEvent('fivex_marina:cancel')
                end
            else
                deathCancelled = false
            end

            retryPoints()
            if contract and ctx and ctx.id == contract.id and not IsEntityDead(ped) then
                local fn = TICK[contract.kind]
                if fn and fn(contract, p) then sleep = 0 end
                if contract.kind == 'charter' or contract.kind == 'recovery' or contract.kind == 'rescue' then
                    sleep = math.min(sleep, 0)
                end
            end
        end
        Wait(sleep)
    end
end)

-- Respawn the HUD when the NUI reloads
RegisterNUICallback('ready', function(_, cb)
    pushHud()
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    closeTablet()
    clearCtx()
    deleteBoat()
    H.removeBlip(officeBlip)
end)
