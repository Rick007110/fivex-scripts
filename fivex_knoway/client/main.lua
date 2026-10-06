local RESOURCE = GetCurrentResourceName()
local APP = Config.AppId

local ride = nil          -- latest ride from the server (public fields)
local ctl = nil           -- van controller; only the booker has one
local pendingAbort = nil  -- cancel that arrived before the van existed
local live = {}           -- { dist, eta } for HUD + app
local cursor = false
local hudShown = { show = false } -- last HUD state actually sent to the screen
local fromMap = false
local lastRefresh = 0

local function L(key, ...)
    local pack = Locales[Config.Locale] or Locales['en'] or {}
    local s = pack[key] or key
    if select('#', ...) > 0 then
        return s:format(...)
    end
    return s
end

local function notify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg or '')
    EndTextCommandThefeedPostTicker(false, false)
end

RegisterNetEvent('fivex_knoway:notify', function(msg)
    notify(msg)
end)

local function dbg(fmt, ...)
    if Config.Debug then print(('[fivex_knoway] ' .. fmt):format(...)) end
end

local function flexa(fn, ...)
    if GetResourceState('fivex_flexa') ~= 'started' then return nil end
    local ok, r = pcall(function(...)
        local exp = exports['fivex_flexa']
        return exp[fn](exp, ...)
    end, ...)
    return ok and r or nil
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function dist2(a, b)
    return #(vector2(a.x, a.y) - vector2(b.x, b.y))
end

local function fareFor(a, b)
    local km = dist2(a, b) * Config.Fare.roadFactor / 1000.0
    return math.max(Config.Fare.minimum, math.floor(Config.Fare.base + km * Config.Fare.perKm + 0.5)), km
end

local function streetAt(x, y, z)
    local s1, s2 = GetStreetNameAtCoord(x, y, z or 0.0)
    local a, b = GetStreetNameFromHashKey(s1), GetStreetNameFromHashKey(s2)
    if b ~= '' and b ~= a then return ('%s / %s'):format(a, b) end
    return a
end

local function zoneAt(x, y, z)
    return GetLabelText(GetNameOfZone(x, y, z or 0.0))
end

local function fmtDist(m)
    if not m then return '—' end
    if m >= 1000 then return ('%.1f km'):format(m / 1000) end
    return ('%d m'):format(math.floor(m / 10 + 0.5) * 10)
end

local function fmtEta(sec)
    if not sec then return '—' end
    if sec < 60 then return '< 1 min' end
    return ('%d min'):format(math.floor(sec / 60 + 0.5))
end

local function loadModel(name)
    local h = joaat(name)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local untilT = GetGameTimer() + 10000
    while not HasModelLoaded(h) and GetGameTimer() < untilT do Wait(50) end
    return HasModelLoaded(h) and h or nil
end

local function waypoint()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return nil end
    local c = GetBlipInfoIdCoord(blip)
    local z = GetHeightmapTopZForPosition(c.x, c.y)
    return vector3(c.x, c.y, z)
end

---------------------------------------------------------------------------
-- HUD (own NUI page) + phone app
---------------------------------------------------------------------------

local function setCursor(on)
    cursor = on and true or false
    SetNuiFocus(cursor, cursor)
    SetNuiFocusKeepInput(cursor)
    SendNUIMessage({ type = 'cursor', on = cursor })
end

local function hudState()
    if not ride then return { show = false } end
    local s = ride.state
    local h = { show = true, state = s, canGo = false, canCancel = false, progress = nil, keys = Config.Keys }
    if s == 'searching' or s == 'dispatched' then
        h.title, h.sub, h.canCancel = L('hud_finding'), L('hud_finding_sub'), true
    elseif s == 'enroute' then
        h.title = L('hud_enroute')
        h.sub = L('hud_enroute_sub', ('%s · %s'):format(fmtEta(live.eta), fmtDist(live.dist)), ride.plate or '')
        h.canCancel = true
    elseif s == 'arrived' then
        local inside = ctl and ctl.inside
        h.title = L('hud_arrived')
        h.sub = inside and L('hud_ready_sub') or L('hud_arrived_sub')
        h.canGo = inside and not (ctl and ctl.goPending)
        h.canCancel = true
    elseif s == 'riding' then
        h.title = L('hud_riding', ride.dest and ride.dest.label or '')
        h.sub = L('hud_riding_sub', ('%s · %s'):format(fmtDist(live.dist), fmtEta(live.eta)))
        h.canCancel = true
        if ctl and ctl.total and live.dist then
            h.progress = math.max(0.0, math.min(1.0, 1.0 - live.dist / ctl.total))
        end
    elseif s == 'dropoff' then
        h.title, h.sub, h.progress = L('hud_dropoff'), L('hud_dropoff_sub'), 1.0
    elseif s == 'leaving' or s == 'complete' then
        h.title, h.sub = L('hud_leaving'), ride.paid and ride.paid > 0 and ('$%s'):format(ride.paid - (ride.refund or 0)) or ''
    else
        h.show = false
    end
    return h
end

local function appState()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local places = {}
    for i, pl in ipairs(Config.Places) do
        local fare, km = fareFor(p, pl.coords)
        places[#places + 1] = { index = i, label = pl.label, area = pl.area, km = km, fare = fare, x = pl.coords.x, y = pl.coords.y }
    end
    table.sort(places, function(a, b) return a.km < b.km end)
    local wp = waypoint()
    local wpData = nil
    if wp then
        local fare, km = fareFor(p, wp)
        wpData = { x = wp.x, y = wp.y, z = wp.z, label = streetAt(wp.x, wp.y, wp.z), area = zoneAt(wp.x, wp.y, wp.z), km = km, fare = fare }
    end
    local bank = 0
    if GetResourceState('fivex_bank') == 'started' then
        pcall(function() bank = exports['fivex_bank']:GetBalance() or 0 end)
    end
    local data = {
        ride = ride,
        live = live,
        me = { x = p.x, y = p.y, street = streetAt(p.x, p.y, p.z), area = zoneAt(p.x, p.y, p.z) },
        waypoint = wpData,
        places = places,
        minTrip = Config.MinTripDistance,
        wallet = { bank = bank, cash = tonumber(LocalPlayer.state.fivex_pay) or 0 },
        fromMap = fromMap,
    }
    fromMap = false
    return data
end

local function refresh(force)
    local now = GetGameTimer()
    if not force and now - lastRefresh < 1000 then return end
    lastRefresh = now
    local h = hudState()
    hudShown = h
    SendNUIMessage({ type = 'hud', hud = h })
    -- no button left to click (cancelled, leaving, done, hidden) -> drop the mouse
    if cursor and not (h.show and (h.canCancel or h.canGo)) then setCursor(false) end
    flexa('SendAppMessage', APP, { type = 'ride', ride = ride, live = live })
end

local function registerApp()
    flexa('RegisterApp', {
        id = APP,
        label = 'KnoWay',
        page = 'html/app.html',
        iconUrl = 'html/logo.svg',
        color = '#0e1a18',
        blurb = 'Driverless rides across Los Santos. Book a KnoWay van to wherever you are going.',
        category = 'Travel',
        header = false,
        defaultInstalled = true,
    })
end

AddEventHandler('fivex_flexa:ready', registerApp)
CreateThread(function()
    Wait(1500)
    registerApp()
end)

---------------------------------------------------------------------------
-- Van controller (booker)
---------------------------------------------------------------------------

-- Could anyone see this spot / entity? Our own camera, or another player close by with line of sight.
local function otherPlayerNear(pos, r)
    local me = PlayerId()
    for _, id in ipairs(GetActivePlayers()) do
        if id ~= me and #(GetEntityCoords(GetPlayerPed(id)) - pos) < r then return true end
    end
    return false
end

local function seenByAnyone(veh)
    if IsEntityOnScreen(veh) then return true end
    local pos = GetEntityCoords(veh)
    local me = PlayerId()
    for _, id in ipairs(GetActivePlayers()) do
        local p = GetPlayerPed(id)
        if id ~= me and #(GetEntityCoords(p) - pos) < Config.Visibility.otherPlayerRange
            and HasEntityClearLosToEntity(p, veh, 17) then
            return true
        end
    end
    return false
end

-- any player (on foot) standing within r metres of the van
local function playerNear(veh, r)
    local pos = GetEntityCoords(veh)
    for _, id in ipairs(GetActivePlayers()) do
        local p = GetPlayerPed(id)
        if not IsPedInAnyVehicle(p, false) and #(GetEntityCoords(p) - pos) < r then return true end
    end
    return false
end

local function ridersInside(veh)
    if not DoesEntityExist(veh) then return false end
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local p = GetPedInVehicleSeat(veh, seat)
        if p ~= 0 and IsPedAPlayer(p) then return true end
    end
    return false
end

local SWITCHED_OFF_ROADS = 2097152 -- driving-style flag: may use roads the game closes to traffic

-- Plan like the GPS for the trip; only allow closed roads (pier road, lots) near the target, otherwise
-- the AI happily takes closed shortcuts the GPS line never shows.
local function drive(target, speed, style)
    ctl.style = style or ctl.style or Config.DriveStyle.ride
    local near = dist2(GetEntityCoords(ctl.veh), target) <= Config.ClosedRoadsWithin
    ctl.closedRoads = near
    local flags = near and ctl.style or (ctl.style & ~SWITCHED_OFF_ROADS)
    SetVehicleHandbrake(ctl.veh, false)
    TaskVehicleDriveToCoordLongrange(ctl.ped, ctl.veh, target.x, target.y, target.z, speed, flags, Config.ArriveDistance)
    SetPedKeepTask(ctl.ped, true)
end

-- Roll to a gentle stop over a few metres; handbrake only once it's standing still.
local function halt()
    if not DoesEntityExist(ctl.veh) then return end
    BringVehicleToHalt(ctl.veh, Config.Arrival.stopDistance, 1, false)
    local untilT = GetGameTimer() + 8000
    while GetEntitySpeed(ctl.veh) > 0.3 and GetGameTimer() < untilT do Wait(100) end
    ClearPedTasks(ctl.ped)
    SetVehicleHandbrake(ctl.veh, true)
end

-- Nearest road node of any kind, including roads the game switches off for traffic (pier road,
-- lots, side roads) - the driving styles use those too. Returns position or nil.
-- Nearest road node the default AI drives on: any road incl. parking-lot lanes, but not ones the game
-- switches off (pier walkway & co.), and on the same level (no bridge / highway overhead).
local function activeNode(x, y, z, maxDist)
    local here = vector2(x, y)
    for n = 1, 30 do
        local id = GetNthClosestVehicleNodeId(x, y, z, n, 1, 3.0, 2.5)
        if not id or id == 0 or not IsVehicleNodeIdValid(id) then break end
        local pos = GetVehicleNodePosition(id)
        if #(vector2(pos.x, pos.y) - here) > maxDist then break end
        if not GetVehicleNodeIsSwitchedOff(id) and math.abs(pos.z - z) <= Config.SameLevel then return pos end
    end
    return nil
end

local function roadNode(x, y, z)
    local ok, node, heading = GetClosestVehicleNodeWithHeading(x, y, z, 0, 3.0, 0)
    if ok and math.abs(node.z - z) <= Config.SameLevel * 2.0 then return node, heading end
    return nil
end

-- Last-resort unstick: move the van ~35 m further along the road towards the target.
local function hopAhead(pos, target)
    local dir = vector3(target.x - pos.x, target.y - pos.y, 0.0)
    local len = #dir
    if len < 1.0 then return false end
    local ahead = pos + dir / len * math.min(35.0, len * 0.5)
    local node, heading = roadNode(ahead.x, ahead.y, pos.z)
    if not node or #(node - pos) < 8.0 then return false end
    local riders = ridersInside(ctl.veh)
    if riders then DoScreenFadeOut(250) Wait(300) end
    SetEntityCoords(ctl.veh, node.x, node.y, node.z, false, false, false, false)
    -- face where we're going (a node's own heading can be the opposite lane's direction)
    SetEntityHeading(ctl.veh, GetHeadingFromVector_2d(target.x - node.x, target.y - node.y))
    SetVehicleOnGroundProperly(ctl.veh)
    if riders then Wait(200) DoScreenFadeIn(400) end
    return true
end

-- Drives to target; true on arrival, false if aborted or the van is gone.
local function driveTo(target, speed, allowJump, style, exact)
    drive(target, speed, style)
    local lastPos, lastMove = GetEntityCoords(ctl.veh), GetGameTimer()
    local refined = false
    local stuckCount = 0
    local lightSince, lightNudged = nil, false
    while ctl and not ctl.abort do
        Wait(500)
        if not DoesEntityExist(ctl.veh) or not DoesEntityExist(ctl.ped) then return false end
        local pos = GetEntityCoords(ctl.veh)
        local d = dist2(pos, target)
        live.dist = d
        live.eta = d * Config.Fare.roadFactor / speed
        refresh()
        if d <= Config.ArriveDistance then return true end

        -- close to the target now: re-plan once with closed roads allowed (pier road, lots)
        if not ctl.closedRoads and d <= Config.ClosedRoadsWithin then drive(target, speed) end

        -- ease off on the way in: normal driving, then a crawl for the last bit
        local A = Config.Arrival
        if d <= A.crawlWithin and speed > A.crawlSpeed then
            speed = A.crawlSpeed
            drive(target, speed, Config.DriveStyle.ride)
        elseif d <= A.slowWithin and speed > A.slowSpeed then
            speed = A.slowSpeed
            drive(target, speed, Config.DriveStyle.ride)
        end

        -- destinations off the road network (pier, plaza, park…): stop at the nearest real road instead
        -- Snap to the nearest road only near the end, and only to a road right by the destination;
        -- move the GPS marker with it so the route line shows where the van is really going.
        if not refined and not exact and d < Config.SnapRoad.within then
            refined = true
            local node = activeNode(target.x, target.y, target.z, Config.SnapRoad.maxOffset)
            if node and dist2(node, target) > 3.0 then
                target = node
                if ctl.destBlip and DoesBlipExist(ctl.destBlip) then SetBlipCoords(ctl.destBlip, node.x, node.y, node.z) end
                drive(target, speed)
            end
        end

        local now = GetGameTimer()
        local atLight = IsVehicleStoppedAtTrafficLights(ctl.veh)
        if atLight then lightSince = lightSince or now else lightSince, lightNudged = nil, false end
        local lightWait = lightSince and (now - lightSince) or 0

        if #(pos - lastPos) > 3.0 then
            lastPos, lastMove = pos, now
            stuckCount = 0
        elseif d <= Config.Arrival.crawlWithin and now - lastMove > 3000 and not atLight then
            return true -- stalled close in (kerb, bump, parked car): close enough, hand over
        elseif atLight and lightWait < Config.LightGrace.max * 1000 then
            -- a red phase is fine; but the AI sometimes keeps "waiting" after green
            if not lightNudged and lightWait > Config.LightGrace.nudge * 1000 then
                lightNudged = true
                drive(target, speed)
            end
            lastMove = now
        elseif now - lastMove > Config.StuckSeconds * 1000 then
            stuckCount = stuckCount + 1
            if stuckCount == 1 then
                -- back up a little, then try again (gets round most blocking cars / peds)
                TaskVehicleTempAction(ctl.ped, ctl.veh, 3, 1800)
                Wait(1800)
                drive(target, speed)
            elseif stuckCount == 2 then
                TaskVehicleTempAction(ctl.ped, ctl.veh, 3, 1800)
                Wait(1800)
                drive(target, speed, Config.DriveStyle.unstick)
            else
                -- still boxed in: hop ahead along the road (unseen when empty; screen fade with riders)
                local canHop = allowJump and not IsEntityOnScreen(ctl.veh) or ridersInside(ctl.veh) or stuckCount >= 4
                if canHop and hopAhead(pos, target) then stuckCount = 0 end
                drive(target, speed, style)
            end
            lastPos, lastMove = GetEntityCoords(ctl.veh), GetGameTimer()
        end
    end
    return false
end

local function openDoor()
    if DoesEntityExist(ctl.veh) then SetVehicleDoorOpen(ctl.veh, ctl.vdef.door or 3, false, false) end
end

local function shutDoor()
    if DoesEntityExist(ctl.veh) then SetVehicleDoorShut(ctl.veh, ctl.vdef.door or 3, false) end
end

local function exitPhase()
    openDoor()
    SetVehicleDoorsLocked(ctl.veh, 1)
    local untilT = GetGameTimer() + Config.ExitTimeout * 1000
    while ridersInside(ctl.veh) and GetGameTimer() < untilT do Wait(500) end
    if ridersInside(ctl.veh) then
        TriggerServerEvent('fivex_knoway:ejectRiders')
        untilT = GetGameTimer() + 6000
        while ridersInside(ctl.veh) and GetGameTimer() < untilT do Wait(250) end
    end
end

local function removeBlips()
    for _, k in ipairs({ 'blip', 'destBlip' }) do
        if ctl and ctl[k] and DoesBlipExist(ctl[k]) then RemoveBlip(ctl[k]) end
        if ctl then ctl[k] = nil end
    end
end

local function deleteVan()
    if not ctl then return end
    removeBlips()
    for _, e in ipairs({ ctl.ped, ctl.veh }) do
        if e and DoesEntityExist(e) then
            SetEntityAsMissionEntity(e, true, true)
            DeleteEntity(e)
        end
    end
end

-- afterRiders: people just got out -> pause and wait for them to clear before pulling away.
local function leaveAndDespawn(afterRiders)
    TriggerServerEvent('fivex_knoway:leaving')
    removeBlips()
    if ctl.veh and DoesEntityExist(ctl.veh) and DoesEntityExist(ctl.ped) then
        SetVehicleDoorsShut(ctl.veh, false) -- every door, not just the one we opened
        SetVehicleDoorsLocked(ctl.veh, 2)
        if afterRiders then
            Wait(Config.DepartDelay * 1000)
            local untilT = GetGameTimer() + 10000
            while playerNear(ctl.veh, Config.DepartClearance) and GetGameTimer() < untilT do Wait(250) end
            SetVehicleDoorsShut(ctl.veh, false)
        end
        dbg('leave: driving off')
        SetVehicleHandbrake(ctl.veh, false)
        TaskVehicleDriveWander(ctl.ped, ctl.veh, Config.Speed.ride, Config.DriveStyle.ride)
        Wait(Config.DespawnAfter * 1000)
        -- keep driving until nobody can see it, so it never pops out of existence on camera
        local untilT = GetGameTimer() + Config.Visibility.maxExtraDrive * 1000
        while DoesEntityExist(ctl.veh) and seenByAnyone(ctl.veh) and GetGameTimer() < untilT do Wait(500) end
    end
    deleteVan()
    ctl = nil
    live = {}
    TriggerServerEvent('fivex_knoway:finished')
end

-- Off the road graph (lots without nodes, driveways): creep straight towards the player, stop ~7 m away.
local function finalApproach(point, maxDistance)
    local F = Config.FinalApproach
    local untilT = GetGameTimer() + F.timeout * 1000
    local aimedAt = nil
    local stillSince, lastNudge = nil, 0
    while ctl and not ctl.abort and GetGameTimer() < untilT do
        if not DoesEntityExist(ctl.veh) or not DoesEntityExist(ctl.ped) then return end
        local now = GetGameTimer()
        local me = point or GetEntityCoords(PlayerPedId())
        local d = #(GetEntityCoords(ctl.veh) - me)
        if d <= F.stopAt or d > (maxDistance or F.maxDistance) then return end
        -- only re-aim when the player has actually walked off; constant re-tasking makes the AI hesitate
        if not aimedAt or #(me - aimedAt) > 4.0 then
            aimedAt = me
            SetVehicleHandbrake(ctl.veh, false)
            TaskVehicleDriveToCoord(ctl.ped, ctl.veh, me.x, me.y, me.z, F.speed, 0,
                GetEntityModel(ctl.veh), Config.DriveStyle.approach, F.stopAt, true)
        end
        if GetEntitySpeed(ctl.veh) < 0.5 then
            stillSince = stillSince or now
            local still = now - stillSince
            -- close enough (and, for a pickup, actually in view of the player - not behind a wall)
            if d <= F.goodEnough and still > 2000
                and (point or HasEntityClearLosToEntity(ctl.veh, PlayerPedId(), 17)) then return end
            if still > 2500 and now - lastNudge > 4000 then
                lastNudge = now -- stalled on a kerb / bump: small push forward instead of backing up
                SetVehicleForwardSpeed(ctl.veh, 3.0)
            end
        else
            stillSince = nil
        end
        live.dist = d
        live.eta = d / F.speed
        refresh()
        Wait(250)
    end
end

local function spawnVan(pickup)
    -- first road node in range that the player can't see; else one in range; else the farthest closer one
    local spawn, heading, inRange, inRangeH = nil, 0.0, nil, 0.0
    for n = 10, 260, 6 do
        local ok, pos, h = GetNthClosestVehicleNodeWithHeading(pickup.x, pickup.y, pickup.z, n, 0, 3.0, 2.5)
        if ok then
            local d = dist2(pos, pickup)
            if d >= Config.SpawnDistance.min and d <= Config.SpawnDistance.max then
                if not IsSphereVisible(pos.x, pos.y, pos.z + 1.0, 3.0)
                    and not otherPlayerNear(pos, Config.Visibility.otherPlayerSpawnRange) then
                    spawn, heading = pos, h
                    break
                end
                inRange, inRangeH = inRange or pos, inRange and inRangeH or h
            elseif d < Config.SpawnDistance.min and not inRange then
                spawn, heading = pos, h
            elseif d > Config.SpawnDistance.max then
                break
            end
        end
    end
    if inRange and (not spawn or dist2(spawn, pickup) < Config.SpawnDistance.min) then
        spawn, heading = inRange, inRangeH
    end
    local vdef = Config.Vehicles[(ride and ride.vehicle) or 1] or Config.Vehicles[1]
    local vh = loadModel(vdef.model) or loadModel(Config.Vehicles[1].model) -- custom model missing -> base van
    if vh ~= joaat(vdef.model) then vdef = Config.Vehicles[1] end
    local ph = loadModel(Config.DriverModel)
    if not spawn or not vh or not ph then return nil end

    local veh = CreateVehicle(vh, spawn.x, spawn.y, spawn.z, heading, true, false)
    SetModelAsNoLongerNeeded(vh)
    if not DoesEntityExist(veh) then return nil end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleModKit(veh, 0)
    for slot, index in pairs(vdef.mods or {}) do
        SetVehicleMod(veh, slot, index, false)
    end
    SetVehicleColours(veh, vdef.primary, vdef.secondary)
    SetVehicleNumberPlateText(veh, (ride and ride.plate) or Config.Plate)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDoorsLocked(veh, 2) -- locked until it reaches you
    SetVehicleCanBeUsedByFleeingPeds(veh, false)
    SetHornEnabled(veh, false) -- the AI honks in traffic otherwise

    local ped = CreatePedInsideVehicle(veh, 26, ph, -1, true, false)
    SetModelAsNoLongerNeeded(ph)
    if not DoesEntityExist(ped) then
        DeleteEntity(veh)
        return nil
    end
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeDraggedOut(ped, false)
    SetPedConfigFlag(ped, 32, false) -- no seatbelt fly-through
    SetPedFleeAttributes(ped, 0, false)
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 0.0)
    -- completely silent: no voice, pain, ambient chatter or insults
    DisablePedPainAudio(ped, true)
    StopPedSpeaking(ped, true)
    SetAmbientVoiceName(ped, 'NO_VOICE')
    StopCurrentPlayingAmbientSpeech(ped)
    StopCurrentPlayingSpeech(ped)

    -- keep the AI on the booker's machine; the tasks live where the entity is owned
    for _, e in ipairs({ veh, ped }) do
        local net = NetworkGetNetworkIdFromEntity(e)
        SetNetworkIdCanMigrate(net, false)
        SetNetworkIdExistsOnAllMachines(net, true)
    end
    return veh, ped, vdef
end

local function runRide()
    local p = GetEntityCoords(PlayerPedId())
    -- road on the player's level (not the highway overhead)
    local node = activeNode(p.x, p.y, p.z, 60.0)
    local pickup = node or p
    -- pull up at the kerb next to the player rather than the middle of the road
    local okCall, okSide, side = pcall(GetPointOnRoadSide, p.x, p.y, p.z, -1)
    if okCall and okSide and side and math.abs(side.z - p.z) <= Config.SameLevel
        and #(vector2(side.x, side.y) - vector2(p.x, p.y)) < 30.0 then
        pickup = side
    end
    dbg('pickup point (%.0f, %.0f, %.0f), player (%.0f, %.0f, %.0f)', pickup.x, pickup.y, pickup.z, p.x, p.y, p.z)

    local veh, ped, vdef = spawnVan(pickup)
    if not veh then
        TriggerServerEvent('fivex_knoway:spawnFailed')
        return
    end
    ctl = { veh = veh, ped = ped, vdef = vdef }
    -- keep the driver mute for as long as it exists (some speech ignores StopPedSpeaking)
    CreateThread(function()
        while DoesEntityExist(ped) do
            if IsAnySpeechPlaying(ped) then
                StopCurrentPlayingAmbientSpeech(ped)
                StopCurrentPlayingSpeech(ped)
            end
            Wait(250)
        end
    end)
    TriggerServerEvent('fivex_knoway:spawned', NetworkGetNetworkIdFromEntity(veh), NetworkGetNetworkIdFromEntity(ped))
    ctl.blip = AddBlipForEntity(veh)
    SetBlipSprite(ctl.blip, 198)
    SetBlipColour(ctl.blip, 25)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('KnoWay')
    EndTextCommandSetBlipName(ctl.blip)
    if pendingAbort then ctl.abort, pendingAbort = pendingAbort, nil end

    -- 1. pick up
    dbg('pickup: driving to the road by the player (%.0f, %.0f)', pickup.x, pickup.y)
    local arrived = not ctl.abort and driveTo(pickup, Config.Speed.pickup, true, Config.DriveStyle.pickup)
    dbg('pickup: drive %s', arrived and 'arrived' or 'ended (cancelled / van gone)')
    if not ctl then return end
    if not arrived then
        if not DoesEntityExist(veh) then TriggerServerEvent('fivex_knoway:spawnFailed') deleteVan() ctl = nil return end
        dbg('pickup: cancelled on the way')
        return leaveAndDespawn(false)
    end
    finalApproach()
    if not ctl or ctl.abort then
        if ctl then return leaveAndDespawn(false) end
        return
    end
    halt()
    SetVehicleDoorsLocked(veh, 1)
    openDoor()
    live = {}
    TriggerServerEvent('fivex_knoway:arrived')
    flexa('Notify', APP, { title = 'KnoWay', body = 'Your ride is here — back right door is open.' })
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)

    -- 2. board, wait for Go
    local deadline = GetGameTimer() + Config.BoardTimeout * 1000
    while ctl and not ctl.abort and not ctl.go do
        Wait(250)
        local inside = IsPedInVehicle(PlayerPedId(), veh, false)
        if inside ~= ctl.inside then
            ctl.inside = inside
            refresh(true)
        end
        if not inside and GetGameTimer() > deadline then
            TriggerServerEvent('fivex_knoway:noShow')
            ctl.abort = 'leave'
        end
        if not DoesEntityExist(veh) then ctl.abort = 'leave' end
    end
    if not ctl then return end
    if ctl.abort then
        local hadRiders = ridersInside(veh)
        if hadRiders then exitPhase() end
        return leaveAndDespawn(hadRiders)
    end

    -- 3. ride
    shutDoor()
    local dest = vector3(ride.dest.x, ride.dest.y, ride.dest.z or GetHeightmapTopZForPosition(ride.dest.x, ride.dest.y))
    ctl.total = dist2(GetEntityCoords(veh), dest)
    ctl.destBlip = AddBlipForCoord(dest.x, dest.y, dest.z)
    SetBlipSprite(ctl.destBlip, 1)
    SetBlipColour(ctl.destBlip, 25)
    SetBlipRoute(ctl.destBlip, true)
    SetBlipRouteColour(ctl.destBlip, 25)
    local exact = ride.dest and ride.dest.exact == true
    local reached = not ctl.abort and driveTo(dest, Config.Speed.ride, false, Config.DriveStyle.ride, exact)
    if not ctl then return end
    if reached and not ctl.abort then
        finalApproach(dest, exact and Config.FinalApproach.maxDistance or Config.FinalApproach.dropoffMaxDistance)
    end
    if not ctl then return end
    halt()
    if reached then TriggerServerEvent('fivex_knoway:dropped') end
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    exitPhase()
    leaveAndDespawn(true)
end

---------------------------------------------------------------------------
-- Server events
---------------------------------------------------------------------------

RegisterNetEvent('fivex_knoway:state', function(r)
    ride = r
    if r and (r.state == 'complete' or r.state == 'cancelled') then
        live = {}
        refresh(true)
        local id = r.id
        SetTimeout(6000, function()
            if ride and ride.id == id and (ride.state == 'complete' or ride.state == 'cancelled') then
                hudShown = { show = false }
                SendNUIMessage({ type = 'hud', hud = hudShown })
                if cursor then setCursor(false) end
            end
        end)
        return
    end
    refresh(true)
end)

RegisterNetEvent('fivex_knoway:dispatch', function(r)
    ride = r
    if ctl then return end
    CreateThread(function()
        local ok, err = xpcall(runRide, debug.traceback)
        if not ok then
            print(('^1[fivex_knoway] ride failed: %s^7'):format(tostring(err)))
            deleteVan()
            ctl = nil
            live = {}
            TriggerServerEvent('fivex_knoway:failed') -- cancels the ride and refunds anything paid
        end
    end)
end)

RegisterNetEvent('fivex_knoway:goResult', function(ok)
    if not ctl then return end
    ctl.goPending = false
    if ok then ctl.go = true end
    refresh(true)
end)

RegisterNetEvent('fivex_knoway:cancelled', function(mode)
    if ctl then ctl.abort = mode else pendingAbort = mode end
end)

RegisterNetEvent('fivex_knoway:exitVehicle', function(netVeh)
    if not NetworkDoesEntityExistWithNetworkId(netVeh) then return end
    local veh = NetToVeh(netVeh)
    local ped = PlayerPedId()
    if IsPedInVehicle(ped, veh, false) then TaskLeaveVehicle(ped, veh, 0) end
end)

RegisterNetEvent('fivex_knoway:reset', function()
    deleteVan()
    ctl, ride, live, pendingAbort = nil, nil, {}, nil
    refresh(true)
end)

---------------------------------------------------------------------------
-- Controls (keys, HUD buttons, phone app)
---------------------------------------------------------------------------

local function requestGo()
    if not ctl or not ride or ride.state ~= 'arrived' or ctl.goPending then return end
    if not IsPedInVehicle(PlayerPedId(), ctl.veh, false) then
        notify(L('not_inside'))
        return
    end
    ctl.goPending = true
    TriggerServerEvent('fivex_knoway:go')
    refresh(true)
end

local function requestCancel()
    if not ride then return end
    local s = ride.state
    if s == 'searching' or s == 'dispatched' or s == 'enroute' or s == 'arrived' or s == 'riding' then
        if cursor then setCursor(false) end
        TriggerServerEvent('fivex_knoway:cancel')
    end
end

RegisterCommand('knoway_go', requestGo, false)
-- Keys only do something while the HUD is on screen and offers that button.
RegisterCommand('knoway_cancel', function()
    if hudShown.show and hudShown.canCancel then requestCancel() end
end, false)
RegisterCommand('knoway_cursor', function()
    if cursor then return setCursor(false) end
    if hudShown.show and (hudShown.canCancel or hudShown.canGo or hudShown.state == 'arrived') then setCursor(true) end
end, false)
-- /knoway_van: spawn the van exactly as KnoWay uses it (grille, livery, paint, plate) and get in.
local myVan = nil
RegisterCommand('knoway_van', function(_, args)
    TriggerServerEvent('fivex_knoway:requestVan', args[1])
end, false)

RegisterNetEvent('fivex_knoway:spawnVan', function(which)
    local vdef = Config.Vehicles[1]
    for _, v in ipairs(Config.Vehicles) do
        if which and v.model == tostring(which):lower() then vdef = v end
    end
    local hash = loadModel(vdef.model)
    if not hash then return notify('KnoWay: vehicle model not available on this game build') end
    if myVan and DoesEntityExist(myVan) then
        SetEntityAsMissionEntity(myVan, true, true)
        DeleteEntity(myVan)
    end
    local ped = PlayerPedId()
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.0)
    local veh = CreateVehicle(hash, pos.x, pos.y, pos.z, GetEntityHeading(ped) + 90.0, true, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(veh) then return end
    SetVehicleOnGroundProperly(veh)
    SetVehicleModKit(veh, 0)
    for slot, index in pairs(vdef.mods or {}) do SetVehicleMod(veh, slot, index, false) end
    SetVehicleColours(veh, vdef.primary, vdef.secondary)
    SetVehicleNumberPlateText(veh, Config.Plate)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    TaskWarpPedIntoVehicle(ped, veh, -1)
    myVan = veh
end)

-- Entry assist: on some custom models GTA's own F-key entry ignores doors whose entry points sit close
-- together (knowayest's rear doors). If F doesn't start an entry, pick the nearest free door ourselves.
local DOOR_SEAT = { [0] = -1, [1] = 0, [2] = 1, [3] = 2 }
local assistModels = {}
for _, name in ipairs(Config.EntryAssistModels or {}) do assistModels[joaat(name)] = true end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if next(assistModels) and not IsPedInAnyVehicle(ped, false) and IsControlJustPressed(0, 23) then
            local p = GetEntityCoords(ped)
            local veh = GetClosestVehicle(p.x, p.y, p.z, 6.0, 0, 70)
            if veh ~= 0 and assistModels[GetEntityModel(veh)] and GetVehicleDoorLockStatus(veh) < 2 then
                Wait(250) -- give GTA's own entry a moment first
                if GetVehiclePedIsTryingToEnter(ped) == 0 and not IsPedInAnyVehicle(ped, false) then
                    local bestSeat, bestD = nil, 2.5
                    for door = 0, 3 do
                        local seat = DOOR_SEAT[door]
                        local ok, entry = pcall(GetEntryPositionOfDoor, veh, door)
                        if ok and entry and IsVehicleSeatFree(veh, seat) then
                            local d = #(entry - GetEntityCoords(ped))
                            if d < bestD then bestSeat, bestD = seat, d end
                        end
                    end
                    if bestSeat then TaskEnterVehicle(ped, veh, 6000, bestSeat, 1.0, 1, 0) end
                end
            end
        end
        Wait(0)
    end
end)

-- Stand where a drop-off should be and paste the printed line into Config.Places.
RegisterCommand('knoway_coords', function()
    local p = GetEntityCoords(PlayerPedId())
    local line = ("{ label = '%s', area = '%s', coords = vector3(%.2f, %.2f, %.2f) },")
        :format(streetAt(p.x, p.y, p.z), zoneAt(p.x, p.y, p.z), p.x, p.y, p.z)
    print('[fivex_knoway] ' .. line)
    notify('KnoWay: place line printed in F8')
end, false)

RegisterKeyMapping('knoway_go', 'KnoWay: start ride (Go)', 'keyboard', Config.Keys.go)
RegisterKeyMapping('knoway_cancel', 'KnoWay: cancel ride', 'keyboard', Config.Keys.cancel)
RegisterKeyMapping('knoway_cursor', 'KnoWay: mouse for ride buttons', 'keyboard', Config.Keys.cursor)

-- HUD buttons
RegisterNUICallback('hudGo', function(_, cb) requestGo() cb({ ok = true }) end)
RegisterNUICallback('hudCancel', function(_, cb) requestCancel() cb({ ok = true }) end)
RegisterNUICallback('hudCursorOff', function(_, cb) setCursor(false) cb({ ok = true }) end)

-- Phone app (html/app.html inside Flexa)
RegisterNUICallback('state', function(_, cb)
    cb(appState())
end)

RegisterNUICallback('book', function(data, cb)
    data = data or {}
    if ride and ride.state ~= 'complete' and ride.state ~= 'cancelled' then
        cb({ ok = false, error = 'busy' })
        return
    end
    if data.kind == 'place' then
        TriggerServerEvent('fivex_knoway:request', { kind = 'place', index = tonumber(data.index) })
    elseif data.kind == 'waypoint' then
        local wp = waypoint()
        if not wp then
            cb({ ok = false, error = 'no_waypoint' })
            return
        end
        TriggerServerEvent('fivex_knoway:request', {
            kind = 'waypoint', x = wp.x, y = wp.y, z = wp.z,
            label = streetAt(wp.x, wp.y, wp.z), area = zoneAt(wp.x, wp.y, wp.z),
        })
    else
        cb({ ok = false, error = 'bad_dest' })
        return
    end
    cb({ ok = true })
end)

RegisterNUICallback('cancel', function(_, cb)
    requestCancel()
    cb({ ok = true })
end)

RegisterNUICallback('dismiss', function(_, cb)
    if ride and (ride.state == 'complete' or ride.state == 'cancelled') then
        ride = nil
        refresh(true)
    end
    cb({ ok = true })
end)

-- Close the phone, open the pause map; when the player leaves it with a waypoint set, reopen KnoWay.
RegisterNUICallback('pickOnMap', function(_, cb)
    cb({ ok = true })
    CreateThread(function()
        flexa('ClosePhone')
        Wait(250)
        ActivateFrontendMenu(joaat('FE_MENU_VERSION_MP_PAUSE'), false, -1)
        local untilT = GetGameTimer() + 3000
        while not IsPauseMenuActive() and GetGameTimer() < untilT do Wait(50) end
        while IsPauseMenuActive() do Wait(100) end
        Wait(300)
        if waypoint() then
            fromMap = true
            flexa('OpenApp', APP)
        end
    end)
end)

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

-- keep the HUD's numbers ticking while the phone is closed
CreateThread(function()
    while true do
        Wait(1000)
        if ride and ride.state ~= 'complete' and ride.state ~= 'cancelled' then refresh() end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    if cursor then SetNuiFocus(false, false) end
    deleteVan()
end)
