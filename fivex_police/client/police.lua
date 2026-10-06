-- Regular AI police: tuned stats and a perimeter instead of a rush when the suspect is barricaded
-- in a building or actively shooting.

local tuned = {}  -- [ped] = true once stats are applied
local holding = {} -- [ped] = vector3 of the spot they hold

local function applyDispatch()
    local D = Config.Dispatch
    -- service ids: 2 police heli · 4 SWAT van · 8 roadblock · 12 SWAT heli
    EnableDispatchService(2, D.policeHelicopter)
    EnableDispatchService(8, D.roadblocks)
    if D.disableGameSwat then
        EnableDispatchService(4, false)
        EnableDispatchService(12, false)
    end
end

local function tune(ped)
    local C = Config.Cops
    SetPedAccuracy(ped, C.accuracy)
    if GetPedArmour(ped) < C.armour then SetPedArmour(ped, C.armour) end
    SetPedCombatAbility(ped, C.combatAbility)
    SetPedCombatRange(ped, C.combatRange)
    SetPedSeeingRange(ped, C.seeingRange)
    SetPedHearingRange(ped, C.hearingRange)
    SetPedCombatAttributes(ped, 0, true)   -- use cover
    SetPedCombatAttributes(ped, 1, true)   -- use vehicles
    SetPedCombatAttributes(ped, 2, C.driveBy == true) -- drive-bys
    SetPedCombatAttributes(ped, 3, true)   -- can leave vehicle (get out to fight)
    SetPedCombatAttributes(ped, 21, true)  -- chase on foot
    SetPedCombatAttributes(ped, 46, true)  -- always fight (don't flee)
    SetPedFleeAttributes(ped, 0, false)
    SetPedSuffersCriticalHits(ped, true)
    if IsPedInAnyVehicle(ped, false) and GetPedInVehicleSeat(GetVehiclePedIsIn(ped, false), -1) == ped then
        SetDriverAbility(ped, C.driverAbility)
        SetDriverAggressiveness(ped, C.driverAggression)
    end
end

-- Hold a spot at least minDistance from the suspect, in cover, still shooting back.
local function hold(ped, suspectPos)
    if holding[ped] then return end
    local pos = GetEntityCoords(ped)
    if #(pos - suspectPos) < Config.Perimeter.minDistance then return end -- already in the fight up close
    holding[ped] = pos
    SetPedCombatMovement(ped, 1) -- defensive
    SetPedSphereDefensiveArea(ped, pos.x, pos.y, pos.z, Config.Perimeter.holdRadius, false, false)
    SetPedCombatAttributes(ped, 0, true)
end

-- Patrol cars: sirens on; while the suspect drives they stay in and chase; when the suspect is on
-- foot they drive up and only get out within dismountDistance (or once it's lethal).
local chasing = {}
local function pursue(ped, me)
    local P = Config.Pursuit
    local veh = GetVehiclePedIsIn(ped, false)
    local suspect = PlayerPedId()
    local suspectDriving = IsPedInAnyVehicle(suspect, false)
    local driver = GetPedInVehicleSeat(veh, -1) == ped
    if driver and P.sirens then
        SetVehicleSiren(veh, true)
        SetVehicleHasMutedSirens(veh, false)
    end
    local d = #(GetEntityCoords(ped) - me)
    local lethal = Police.isLethal and Police.isLethal()
    local mayLeave = (not suspectDriving and d < P.dismountDistance) or (lethal and d < P.dismountDistance * 1.5)
    SetPedCombatAttributes(ped, 3, mayLeave)
    if driver and suspectDriving then
        if not chasing[ped] then
            chasing[ped] = true
            TaskVehicleChase(ped, suspect)
            SetTaskVehicleChaseIdealPursuitDistance(ped, P.followDistance)
            SetTaskVehicleChaseBehaviorFlag(ped, 1, true) -- aggressive pursuit
        end
    else
        chasing[ped] = nil
    end
end

local function release(ped)
    if not holding[ped] then return end
    holding[ped] = nil
    if DoesEntityExist(ped) then
        RemovePedDefensiveArea(ped, false)
        SetPedCombatMovement(ped, 2) -- advance again
    end
end

CreateThread(function()
    applyDispatch()
    while true do
        if Suspect.wanted > 0 then
            applyDispatch() -- the game resets some services on wanted-level changes
            local me = GetEntityCoords(PlayerPedId())
            local standoff = Config.Perimeter.enabled and Police.isStandoff() and Suspect.alive
            for _, ped in ipairs(GetGamePool('CPed')) do
                if Police.isCop(ped) and not Entity(ped).state.fivexSwat
                    and NetworkHasControlOfEntity(ped)
                    and #(GetEntityCoords(ped) - me) < Config.Cops.scanRadius then
                    if not tuned[ped] then
                        tuned[ped] = true
                        tune(ped)
                    end
                    if IsPedInAnyVehicle(ped, false) then
                        pursue(ped, me)
                    elseif standoff then
                        hold(ped, me)
                    else
                        release(ped)
                    end
                end
            end
            Wait(750)
        else
            if next(holding) then
                for ped in pairs(holding) do release(ped) end
            end
            Wait(1500)
        end
        -- forget peds that no longer exist
        for ped in pairs(tuned) do if not DoesEntityExist(ped) then tuned[ped] = nil holding[ped] = nil end end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for ped in pairs(holding) do release(ped) end
    EnableDispatchService(4, true)
    EnableDispatchService(12, true)
end)
