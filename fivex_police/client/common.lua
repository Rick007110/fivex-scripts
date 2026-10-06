-- Shared client state for fivex_police: what the local (possibly wanted) player is doing.
-- AI police near a player run on that player's machine, so each client handles its own suspect.

Police = Police or {}

Suspect = {
    wanted = 0,
    inBuilding = false,
    buildingSince = nil,   -- GetGameTimer() when they went inside
    lastShot = 0,          -- GetGameTimer() of the last shot fired
    alive = true,
}

function Police.debug(fmt, ...)
    if Config.Debug then print(('[fivex_police] ' .. fmt):format(...)) end
end

function Police.now() return GetGameTimer() end

function Police.recentlyShooting()
    return Police.now() - Suspect.lastShot < Config.Perimeter.shootingMemory * 1000
end

-- "Barricaded or active shooter": the situations where cops should hold and SWAT should go in.
function Police.isStandoff()
    return Suspect.inBuilding or Police.recentlyShooting()
end

function Police.isCop(ped)
    if ped == 0 or not DoesEntityExist(ped) or IsPedAPlayer(ped) or IsPedDeadOrDying(ped, true) then return false end
    local t = GetPedType(ped)
    return t == 6 or t == 27 -- cop / swat
end

function Police.loadModel(name)
    local h = type(name) == 'number' and name or joaat(name)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local untilT = Police.now() + 8000
    while not HasModelLoaded(h) and Police.now() < untilT do Wait(25) end
    return HasModelLoaded(h) and h or nil
end

function Police.seenByAnyone(entity, range)
    if IsEntityOnScreen(entity) then return true end
    local pos = GetEntityCoords(entity)
    local me = PlayerId()
    for _, id in ipairs(GetActivePlayers()) do
        local p = GetPlayerPed(id)
        if id ~= me and #(GetEntityCoords(p) - pos) < (range or 150.0) and HasEntityClearLosToEntity(p, entity, 17) then
            return true
        end
    end
    return false
end

-- Track the local player: wanted level, inside a building (interior), shots fired.
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pid = PlayerId()
        Suspect.wanted = GetPlayerWantedLevel(pid)
        Suspect.alive = not IsEntityDead(ped)
        if IsPedShooting(ped) then Suspect.lastShot = Police.now() end
        local inside = GetInteriorFromEntity(ped) ~= 0
        if inside and not Suspect.inBuilding then Suspect.buildingSince = Police.now() end
        if not inside then Suspect.buildingSince = nil end
        Suspect.inBuilding = inside
        Wait(Suspect.wanted > 0 and 0 or 250)
    end
end)
