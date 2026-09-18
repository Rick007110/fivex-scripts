--[[
    fivex_rollover v1.0.3
    Client-authoritative tire-burst → rollover tip.
]]

local tyreState = {}
local cooldowns = {}
local WHEEL_INDICES = { 0, 1, 2, 3, 4, 5, 6, 7 }

local function dbg(fmt, ...)
    if Config.Debug then
        print(('[fivex_rollover] ' .. fmt):format(...))
    end
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function isClassAllowed(veh)
    return Config.ClassesAllowed[GetVehicleClass(veh)] == true
end

local function isPlayerVehicle(veh)
    local ped = PlayerPedId()
    if GetVehiclePedIsIn(ped, false) == veh then
        return true
    end
    local maxPass = GetVehicleMaxNumberOfPassengers(veh)
    for seat = -1, maxPass - 1 do
        local p = GetPedInVehicleSeat(veh, seat)
        if p ~= 0 and IsPedAPlayer(p) then
            return true
        end
    end
    return false
end

local function ensureNetworkControl(veh)
    if not Config.RequireNetworkControl then
        return true
    end
    if NetworkHasControlOfEntity(veh) then
        return true
    end
    if not NetworkGetEntityIsNetworked(veh) then
        return true
    end
    NetworkRequestControlOfEntity(veh)
    local deadline = GetGameTimer() + (Config.ControlRequestTimeoutMs or 400)
    while GetGameTimer() < deadline do
        if NetworkHasControlOfEntity(veh) then
            return true
        end
        NetworkRequestControlOfEntity(veh)
        Wait(0)
    end
    return NetworkHasControlOfEntity(veh)
end

local function wheelSideSign(wheel)
    if wheel == 0 or wheel == 2 or wheel == 4 or wheel == 6 then
        return -1.0
    end
    return 1.0
end

local function speedFactor(speed)
    local minS = Config.SpeedMin
    local fullS = Config.SpeedFull
    if speed < minS then
        return 0.0
    end
    if speed >= fullS then
        return 1.0
    end
    return (speed - minS) / (fullS - minS)
end

local function rollChance(factor)
    return lerp(Config.BaseChance, Config.ChanceAtFullSpeed, factor)
end

local function onCooldown(netId)
    if not netId or netId == 0 then
        return false
    end
    local untilT = cooldowns[netId]
    if not untilT then
        return false
    end
    if GetGameTimer() < untilT then
        return true
    end
    cooldowns[netId] = nil
    return false
end

local function setCooldown(netId)
    if not netId or netId == 0 then
        return
    end
    cooldowns[netId] = GetGameTimer() + (Config.CooldownMs or 8000)
end

--- FiveM returns four vector3s (forward, right, up, position) — not 12 floats.
local function entityAxes(veh)
    local forward, right, up = GetEntityMatrix(veh)
    if type(forward) == 'vector3' then
        return forward, right, up
    end
    -- Fallback if a build ever unpacks as floats
    local fX, fY, fZ, rX, rY, rZ, uX, uY, uZ = GetEntityMatrix(veh)
    if rY == nil and type(fX) == 'vector3' then
        return fX, fY, fZ
    end
    return vector3(fX or 0.0, fY or 0.0, fZ or 0.0),
        vector3(rX or 0.0, rY or 0.0, rZ or 0.0),
        vector3(uX or 0.0, uY or 0.0, uZ or 1.0)
end

local function dampExcessSpin(veh)
    local ms = Config.DampMs or 650
    local maxSpin = Config.MaxSpin or 2.2
    CreateThread(function()
        local ent = veh
        local untilT = GetGameTimer() + ms
        while GetGameTimer() < untilT do
            if not DoesEntityExist(ent) then
                return
            end
            if ensureNetworkControl(ent) then
                local av = GetEntityRotationVelocity(ent)
                if type(av) == 'vector3' then
                    local mag = math.sqrt(av.x * av.x + av.y * av.y + av.z * av.z)
                    if mag > maxSpin then
                        local s = maxSpin / mag
                        SetEntityAngularVelocity(ent, av.x * s * 0.85, av.y * s * 0.85, av.z * s * 0.85)
                    end
                end
            end
            Wait(40)
        end
    end)
end

local function applyRolloverImpulse(veh, wheel, speed, factor)
    if not ensureNetworkControl(veh) then
        dbg('no network control, skip impulse')
        return false
    end

    local side = wheelSideSign(wheel)
    local forward, right = entityAxes(veh)
    if not forward or not right then
        dbg('matrix missing')
        return false
    end

    -- Tip onto the blown SIDE (not a continuous barrel). Cap near SideLandDegrees.
    local land = Config.SideLandDegrees or 78.0
    local dip = (Config.PitchDip or 8.0) * factor
    local rot = GetEntityRotation(veh, 2)
    local targetRoll = side * land
    -- Move toward side-land, never add full revolutions
    local newRoll = rot.y + (targetRoll - rot.y) * (0.55 + 0.35 * factor)
    if side > 0.0 then
        if newRoll > land then newRoll = land end
        if newRoll < 25.0 then newRoll = 25.0 + 20.0 * factor end
    else
        if newRoll < -land then newRoll = -land end
        if newRoll > -25.0 then newRoll = -25.0 - 20.0 * factor end
    end
    SetEntityRotation(veh, rot.x - dip, newRoll, rot.z, 2, true)

    -- Short shove only — dampener kills barrel-roll spin.
    local kick = (Config.AngularKick or 1.6) * (0.75 + 0.4 * factor)
    SetEntityAngularVelocity(
        veh,
        forward.x * side * kick,
        forward.y * side * kick,
        forward.z * side * kick
    )

    local lift = (Config.LiftForce or 4.0) * factor
    local lateral = (Config.LateralForce or 1.2) * factor
    local off = Config.SideOffset or 0.7
    ApplyForceToEntity(
        veh,
        1,
        (-side) * lateral, 0.0, lift,
        (-side) * off, 0.0, 0.15,
        0,
        true, true, true, false, true
    )

    local vel = GetEntityVelocity(veh)
    if Config.PreserveSpeed ~= false then
        SetEntityVelocity(
            veh,
            vel.x + right.x * side * (0.25 * factor),
            vel.y + right.y * side * (0.25 * factor),
            math.max(vel.z, 0.0) + (0.2 * factor)
        )
    end

    dampExcessSpin(veh)

    dbg('side-land veh=%s wheel=%s speed=%.1f factor=%.2f roll=%.0f kick=%.1f',
        tostring(veh), tostring(wheel), speed, factor, newRoll, kick)
    return true
end

local function tryRollover(veh, wheel)
    if not DoesEntityExist(veh) then
        return
    end
    if not isClassAllowed(veh) then
        return
    end

    local playerVeh = isPlayerVehicle(veh)
    if playerVeh and not Config.PlayerVehicles then
        return
    end
    if (not playerVeh) and not Config.NpcVehicles then
        return
    end

    if Config.RespectBulletproof and playerVeh then
        if not GetVehicleTyresCanBurst(veh) then
            dbg('bulletproof tires, skip')
            return
        end
    end

    local netId = 0
    if NetworkGetEntityIsNetworked(veh) then
        netId = NetworkGetNetworkIdFromEntity(veh)
    end
    if onCooldown(netId) then
        dbg('cooldown active netId=%s', tostring(netId))
        return
    end

    local speed = GetEntitySpeed(veh)
    local factor = speedFactor(speed)
    if factor <= 0.0 then
        dbg('too slow %.1f m/s', speed)
        return
    end

    local chance = rollChance(factor)
    local roll = math.random()
    dbg('burst wheel=%s speed=%.1f chance=%.3f roll=%.3f',
        tostring(wheel), speed, chance, roll)
    if roll > chance then
        return
    end

    if applyRolloverImpulse(veh, wheel, speed, factor) then
        setCooldown(netId)
    end
end

local function trackVehicle(veh)
    if not DoesEntityExist(veh) or not IsEntityAVehicle(veh) then
        return
    end

    local prev = tyreState[veh]
    if not prev then
        prev = {}
        for i = 1, #WHEEL_INDICES do
            local w = WHEEL_INDICES[i]
            prev[w] = IsVehicleTyreBurst(veh, w, false)
        end
        tyreState[veh] = prev
        return
    end

    for i = 1, #WHEEL_INDICES do
        local w = WHEEL_INDICES[i]
        local burst = IsVehicleTyreBurst(veh, w, false)
        if burst and not prev[w] then
            tryRollover(veh, w)
        end
        prev[w] = burst
    end
end

local function cleanupStale()
    for veh in pairs(tyreState) do
        if not DoesEntityExist(veh) then
            tyreState[veh] = nil
        end
    end
    local now = GetGameTimer()
    for netId, untilT in pairs(cooldowns) do
        if now >= untilT then
            cooldowns[netId] = nil
        end
    end
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(500)
    end
    dbg('started v1.0.1')

    local cleanupTick = 0
    while true do
        if not Config.Enabled then
            Wait(1000)
        else
            local coords = GetEntityCoords(PlayerPedId())
            local vehicles = GetGamePool('CVehicle')
            local radius = Config.ScanRadius or 80.0
            local r2 = radius * radius

            for i = 1, #vehicles do
                local veh = vehicles[i]
                local vc = GetEntityCoords(veh)
                local dx = vc.x - coords.x
                local dy = vc.y - coords.y
                local dz = vc.z - coords.z
                if (dx * dx + dy * dy + dz * dz) <= r2 then
                    trackVehicle(veh)
                end
            end

            cleanupTick = cleanupTick + 1
            if cleanupTick >= 20 then
                cleanupTick = 0
                cleanupStale()
            end

            Wait(Config.ScanIntervalMs or 100)
        end
    end
end)

RegisterCommand('fivex_rollover_debug', function()
    Config.Debug = not Config.Debug
    print(('[fivex_rollover] Debug = %s'):format(tostring(Config.Debug)))
end, false)
