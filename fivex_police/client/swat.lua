-- Scripted SWAT / NOOSE squads. When the local player is wanted (Config.Swat.minWanted+) and is
-- barricaded in a building or actively shooting, a riot van brings a squad that moves as a group:
-- the point man bounds toward the suspect along the navmesh with weapon up, the rest follow in
-- formation; they hold and cover between bounds, engage from cover on contact, and regroup to keep
-- clearing when they lose sight. Runs on the suspect's client (entities owned there, no migration).

local S = Config.Swat
local squads = {}
local nextId = 0
local cooldownUntil = 0
local standoffSince = nil
local FULL_AUTO = joaat('FIRING_PATTERN_FULL_AUTO')

local function log(squad, fmt, ...)
    Police.debug('squad %d: ' .. fmt, squad.id, ...)
end

local function alivePeds(squad)
    local out = {}
    for _, m in ipairs(squad.members) do
        if DoesEntityExist(m.ped) and not IsPedDeadOrDying(m.ped, true) then out[#out + 1] = m end
    end
    return out
end

local function lockNet(entity)
    local net = NetworkGetNetworkIdFromEntity(entity)
    SetNetworkIdCanMigrate(net, false)
    SetNetworkIdExistsOnAllMachines(net, true)
end

---------------------------------------------------------------------------
-- Spawning
---------------------------------------------------------------------------

local function otherPlayerNear(pos, r)
    local me = PlayerId()
    for _, id in ipairs(GetActivePlayers()) do
        if id ~= me and #(GetEntityCoords(GetPlayerPed(id)) - pos) < r then return true end
    end
    return false
end

local function spawnPoint(around)
    local fallback, fallbackH
    for n = 20, 300, 8 do
        local ok, pos, h = GetNthClosestVehicleNodeWithHeading(around.x, around.y, around.z, n, 0, 3.0, 2.5)
        if ok then
            local d = #(vector2(pos.x, pos.y) - vector2(around.x, around.y))
            if d >= S.spawnDistance.min and d <= S.spawnDistance.max then
                if not IsSphereVisible(pos.x, pos.y, pos.z + 1.0, 4.0) and not otherPlayerNear(pos, 100.0) then
                    return pos, h
                end
                fallback, fallbackH = fallback or pos, fallbackH or h
            elseif d > S.spawnDistance.max then
                break
            end
        end
    end
    return fallback, fallbackH
end

-- Road node near the suspect where the van stops: around stagingDistance away, not right on top.
local function stagingPoint(around)
    local best, bestScore
    for n = 1, 40 do
        local ok, pos = GetNthClosestVehicleNode(around.x, around.y, around.z, n, 0, 3.0, 0)
        if ok then
            local d = #(pos - around)
            if d > 120.0 then break end
            local score = math.abs(d - S.stagingDistance)
            if d >= 15.0 and (not bestScore or score < bestScore) then best, bestScore = pos, score end
        end
    end
    return best or around
end

local function equip(ped, slot)
    local kit = S.loadout[((slot - 1) % #S.loadout) + 1]
    local w = joaat(kit.weapon)
    GiveWeaponToPed(ped, w, 999, false, true)
    for _, comp in ipairs(kit.components or {}) do GiveWeaponComponentToPed(ped, w, joaat(comp)) end
    SetCurrentPedWeapon(ped, w, true)
    SetPedArmour(ped, S.armour)
    SetEntityMaxHealth(ped, S.health)
    SetEntityHealth(ped, S.health)
    SetPedAccuracy(ped, S.accuracy)
    SetPedCombatAbility(ped, 2)
    SetPedCombatRange(ped, 1)
    SetPedCombatMovement(ped, 2)            -- advance
    SetPedCombatAttributes(ped, 0, true)    -- use cover
    SetPedCombatAttributes(ped, 2, Config.Cops.driveBy == true) -- drive-bys
    SetPedCombatAttributes(ped, 3, true)    -- get out of the van to fight
    SetPedCombatAttributes(ped, 5, true)    -- fight armed peds
    SetPedCombatAttributes(ped, 46, true)   -- always fight
    SetPedFleeAttributes(ped, 0, false)
    SetPedDropsWeaponsWhenDead(ped, false)
    SetPedSeeingRange(ped, 90.0)
    SetPedHearingRange(ped, 80.0)
    SetPedRelationshipGroupHash(ped, joaat('COP'))
    SetPedKeepTask(ped, true)
    SetPedCanSwitchWeapon(ped, true)
    SetPedSuffersCriticalHits(ped, true)
    Entity(ped).state:set('fivexSwat', true, true) -- police.lua leaves these alone
end

local function spawnSquad()
    local me = GetEntityCoords(PlayerPedId())
    local pos, heading = spawnPoint(me)
    local vh, ph = Police.loadModel(S.vehicle), Police.loadModel(S.ped)
    if not pos or not vh or not ph then return nil end

    local veh = CreateVehicle(vh, pos.x, pos.y, pos.z, heading, true, false)
    SetModelAsNoLongerNeeded(vh)
    if not DoesEntityExist(veh) then return nil end
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleSiren(veh, true)
    lockNet(veh)

    nextId = nextId + 1
    local squad = { id = nextId, veh = veh, members = {}, state = 'driving', bornAt = Police.now(), lastSeen = 0 }
    local seats = { -1, 0, 1, 2, 3, 4, 5, 6 }
    for i = 1, S.size do
        local ped = CreatePedInsideVehicle(veh, 6, ph, seats[i], true, false)
        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            equip(ped, i)
            lockNet(ped)
            squad.members[#squad.members + 1] = { ped = ped, engaged = false }
        end
    end
    SetModelAsNoLongerNeeded(ph)
    if #squad.members == 0 then
        DeleteEntity(veh)
        return nil
    end
    squad.staging = stagingPoint(me)
    local driver = squad.members[1].ped
    SetDriverAbility(driver, 1.0)
    SetDriverAggressiveness(driver, 0.6)
    TaskVehicleDriveToCoordLongrange(driver, veh, squad.staging.x, squad.staging.y, squad.staging.z, S.driveSpeed, 1074528293, 8.0)
    squads[#squads + 1] = squad
    log(squad, 'dispatched with %d officers', #squad.members)
    return squad
end

---------------------------------------------------------------------------
-- Squad behaviour
---------------------------------------------------------------------------

local function formUp(squad)
    local alive = alivePeds(squad)
    if #alive == 0 then return end
    if squad.group then RemoveGroup(squad.group) end
    local grp = CreateGroup(0)
    squad.group = grp
    squad.leader = alive[1].ped
    SetPedAsGroupLeader(squad.leader, grp)
    for i = 2, #alive do
        SetPedAsGroupMember(alive[i].ped, grp)
        SetPedNeverLeavesGroup(alive[i].ped, true)
    end
    SetGroupFormation(grp, 0)
    SetGroupFormationSpacing(grp, 1.6, -1.0, -1.0)
end

local function deploy(squad)
    squad.state = 'deploy'
    BringVehicleToHalt(squad.veh, 4.0, 1, false)
    SetVehicleSiren(squad.veh, true)
    for _, m in ipairs(alivePeds(squad)) do TaskLeaveVehicle(m.ped, squad.veh, 256) end
    squad.deployAt = Police.now() + 3000
    log(squad, 'deploying')
end

-- Point man walks toward the suspect for one bound (weapon up), then the stack holds.
local function bound(squad, target)
    local leader = squad.leader
    ClearPedTasks(leader)
    TaskGoToCoordWhileAimingAtCoord(leader, target.x, target.y, target.z, target.x, target.y, target.z + 0.8,
        S.advanceSpeed, false, 1.5, 4.0, true, 0, false, FULL_AUTO)
    -- followers drop their hold tasks so the group formation takes over again
    for _, m in ipairs(alivePeds(squad)) do
        if m.ped ~= leader and not m.engaged then ClearPedTasks(m.ped) end
    end
    local walk = S.advanceSpeed >= 2.0 and 3.5 or 1.4 -- m/s
    squad.holdAt = Police.now() + math.floor(S.advanceStep / walk * 1000)
    squad.phase = 'move'
end

local function hold(squad, target)
    local alive = alivePeds(squad)
    local leaderPos = GetEntityCoords(squad.leader)
    for i, m in ipairs(alive) do
        if not m.engaged then
            ClearPedTasks(m.ped)
            if i == 1 then
                TaskAimGunAtCoord(m.ped, target.x, target.y, target.z + 0.8, math.floor(S.holdSeconds * 1000), false, false)
            else
                -- cover different angles around the stack
                local a = (i - 1) / math.max(1, #alive - 1) * math.pi * 2.0
                TaskAimGunAtCoord(m.ped, leaderPos.x + math.cos(a) * 10.0, leaderPos.y + math.sin(a) * 10.0, leaderPos.z + 0.8,
                    math.floor(S.holdSeconds * 1000), false, false)
            end
        end
    end
    squad.nextBound = Police.now() + math.floor(S.holdSeconds * 1000)
    squad.phase = 'hold'
end

local function withdraw(squad, why)
    if squad.state == 'withdraw' then return end
    squad.state = 'withdraw'
    squad.withdrawAt = Police.now()
    log(squad, 'withdrawing (%s)', why)
    for _, m in ipairs(alivePeds(squad)) do
        ClearPedTasks(m.ped)
        if DoesEntityExist(squad.veh) then
            TaskGoToEntity(m.ped, squad.veh, -1, 3.0, 1.0, 0, 0)
        else
            TaskWanderStandard(m.ped, 10.0, 10)
        end
    end
end

local function deleteSquad(squad)
    for _, m in ipairs(squad.members) do
        if DoesEntityExist(m.ped) then
            SetEntityAsMissionEntity(m.ped, true, true)
            DeleteEntity(m.ped)
        end
    end
    if squad.veh and DoesEntityExist(squad.veh) then
        SetEntityAsMissionEntity(squad.veh, true, true)
        DeleteEntity(squad.veh)
    end
    if squad.group then RemoveGroup(squad.group) end
    squad.dead = true
end

local function tickSquad(squad)
    local now = Police.now()
    local player = PlayerPedId()
    local target = GetEntityCoords(player)
    local alive = alivePeds(squad)

    if squad.state ~= 'withdraw' then
        if #alive == 0 then
            withdraw(squad, 'squad down')
        elseif not Suspect.alive or Suspect.wanted == 0 then
            squad.calmSince = squad.calmSince or now
            if now - squad.calmSince > S.withdrawAfter * 1000 then withdraw(squad, 'suspect gone') end
        else
            squad.calmSince = nil
        end
        if now - squad.bornAt > S.maxLifetime * 1000 then withdraw(squad, 'lifetime') end
    end

    if squad.state == 'driving' then
        local veh = squad.veh
        if not DoesEntityExist(veh) or #(GetEntityCoords(veh) - squad.staging) < 12.0
            or (GetEntitySpeed(veh) < 0.5 and now - squad.bornAt > 30000) then
            deploy(squad)
        end
    elseif squad.state == 'deploy' then
        if now >= squad.deployAt then
            formUp(squad)
            squad.state = 'advance'
            squad.nextBound = now
            squad.phase = 'hold'
            log(squad, 'advancing')
        end
    elseif squad.state == 'advance' then
        -- point man down -> next officer takes point
        if not squad.leader or not DoesEntityExist(squad.leader) or IsPedDeadOrDying(squad.leader, true) then
            formUp(squad)
            if not squad.leader then return end
        end
        -- contact: anyone with line of sight in range engages from cover
        local anySight = false
        for _, m in ipairs(alive) do
            local sees = #(GetEntityCoords(m.ped) - target) < S.engageRange and HasEntityClearLosToEntity(m.ped, player, 17)
            if sees then
                anySight = true
                if not m.engaged then
                    m.engaged = true
                    ClearPedTasks(m.ped)
                    TaskCombatPed(m.ped, player, 0, 16)
                end
            end
        end
        if anySight then
            squad.lastSeen = now
        elseif squad.lastSeen > 0 and now - squad.lastSeen > S.lostSightRegroup * 1000 then
            -- lost them: regroup on the point man and keep clearing
            squad.lastSeen = 0
            for _, m in ipairs(alive) do m.engaged = false end
            formUp(squad)
            squad.nextBound = now
            squad.phase = 'hold'
            log(squad, 'regrouping')
        end
        -- bounding while nobody is fighting
        local leaderEngaged = false
        for _, m in ipairs(alive) do if m.ped == squad.leader and m.engaged then leaderEngaged = true end end
        if not leaderEngaged then
            if squad.phase == 'hold' and now >= (squad.nextBound or 0) then
                bound(squad, target)
            elseif squad.phase == 'move' and now >= (squad.holdAt or 0) then
                hold(squad, target)
            end
        end
    elseif squad.state == 'withdraw' then
        -- vanish once nobody can see them (or after a while regardless, when off our screen)
        local visible = false
        for _, m in ipairs(squad.members) do
            if DoesEntityExist(m.ped) and Police.seenByAnyone(m.ped) then visible = true break end
        end
        if squad.veh and DoesEntityExist(squad.veh) and Police.seenByAnyone(squad.veh) then visible = true end
        if not visible or (now - squad.withdrawAt > 120000 and not IsEntityOnScreen(squad.leader or 0)) then
            log(squad, 'removed')
            deleteSquad(squad)
            cooldownUntil = now + S.cooldown * 1000
        end
    end
end

---------------------------------------------------------------------------
-- Dispatcher
---------------------------------------------------------------------------

local function activeCount()
    local n = 0
    for _, sq in ipairs(squads) do if not sq.dead and sq.state ~= 'withdraw' then n = n + 1 end end
    return n
end

CreateThread(function()
    while true do
        local now = Police.now()
        -- squads only at Config.Swat.minWanted+ stars (GTA's own NOOSE level is 4)
        if S.enabled and Suspect.wanted >= S.minWanted and Suspect.alive then
            if Police.isStandoff() then
                standoffSince = standoffSince or now
            else
                standoffSince = nil
            end
            local want = S.squadsByWanted[math.min(5, Suspect.wanted)] or 0
            local ready = standoffSince and now - standoffSince >= S.triggerSeconds * 1000
            if ready and activeCount() < want and now >= cooldownUntil then
                spawnSquad()
                cooldownUntil = now + 15000 -- spacing between multiple squads
            end
        else
            standoffSince = nil
        end

        for i = #squads, 1, -1 do
            local sq = squads[i]
            if sq.dead then table.remove(squads, i) else tickSquad(sq) end
        end
        Wait(#squads > 0 and 300 or 1000)
    end
end)

---------------------------------------------------------------------------
-- /swat_test (ACE-gated on the server): wanted 4 + a squad right away
---------------------------------------------------------------------------

RegisterCommand('swat_test', function()
    TriggerServerEvent('fivex_police:requestTest')
end, false)

RegisterNetEvent('fivex_police:testAllowed', function()
    SetMaxWantedLevel(5)
    SetPlayerWantedLevel(PlayerId(), math.max(4, GetPlayerWantedLevel(PlayerId())), false)
    SetPlayerWantedLevelNow(PlayerId(), false)
    CreateThread(function()
        Wait(500)
        local sq = spawnSquad() -- one squad now; no lasting override of the normal rules
        if sq then cooldownUntil = Police.now() + 15000 end
    end)
    TriggerEvent('chat:addMessage', { args = { 'Police', 'SWAT test: 4 stars, a squad is on the way. Lose the stars to end it.' } })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, sq in ipairs(squads) do deleteSquad(sq) end
end)
