--[[
  fivex_gangwars — Flashpoint client
  Opt-in turf heat → waves of relationship-group NPCs
]]

local Locale = Locales[Config.Locale] or Locales['en']

local function L(key, ...)
    local s = Locale[key] or key
    if select('#', ...) > 0 then
        return s:format(...)
    end
    return s
end

-- State
local blips = {}
local optOut = false          -- /flashpoint session toggle
local armed = false           -- E pressed this visit
local armedTurfId = nil
local heat = 0.0
local runActive = false
local runToken = nil
local waveNumber = 0
local kills = 0
local hostiles = {}           -- [netId] = ped
local waveClearPending = false
local inCooldown = false
local hudVisible = false
local relationshipReady = false

local REL_HASH = nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function notify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, false)
end

local function helpText(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function dist2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function getTurfById(id)
    for _, t in ipairs(Config.Turfs) do
        if t.id == id then return t end
    end
    return nil
end

local function playerInsideTurf(turf)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return dist2d(coords, turf.center) <= turf.radius
end

local function nearestTurf()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local best, bestDist = nil, 1e9
    for _, t in ipairs(Config.Turfs) do
        local d = dist2d(coords, t.center)
        if d < bestDist then
            bestDist, best = d, t
        end
    end
    return best, bestDist
end

local function currentTurf()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    for _, t in ipairs(Config.Turfs) do
        if dist2d(coords, t.center) <= t.radius then
            return t
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Relationship group (hostile to PLAYER)
---------------------------------------------------------------------------

local function ensureRelationship()
    if relationshipReady then return end
    AddRelationshipGroup(Config.RelationshipGroup)
    REL_HASH = GetHashKey(Config.RelationshipGroup)
    local playerGroup = GetHashKey('PLAYER')
    SetRelationshipBetweenGroups(5, REL_HASH, playerGroup) -- Hate
    SetRelationshipBetweenGroups(5, playerGroup, REL_HASH)
    SetRelationshipBetweenGroups(0, REL_HASH, REL_HASH)    -- Companion among selves
    relationshipReady = true
end

---------------------------------------------------------------------------
-- Blips / markers
---------------------------------------------------------------------------

local function createBlips()
    for _, t in ipairs(Config.Turfs) do
        local b = AddBlipForCoord(t.center.x, t.center.y, t.center.z)
        SetBlipSprite(b, Config.BlipSprite)
        SetBlipColour(b, t.blipColor)
        SetBlipScale(b, Config.BlipScale)
        SetBlipAsShortRange(b, Config.BlipShortRange)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(t.label)
        EndTextCommandSetBlipName(b)
        blips[t.id] = b
    end
end

local function drawCenterMarker(turf)
    local c = turf.center
    DrawMarker(
        1, -- cylinder
        c.x, c.y, c.z - 1.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        1.6, 1.6, 0.6,
        91, 141, 239, 140,
        false, false, 2, false, nil, nil, false
    )
end

---------------------------------------------------------------------------
-- HUD NUI (no focus)
---------------------------------------------------------------------------

local function setHud(show, data)
    hudVisible = show
    SendNUIMessage({
        action = show and 'show' or 'hide',
        heat = data and data.heat or heat,
        wave = data and data.wave or waveNumber,
        kills = data and data.kills or kills,
        turf = data and data.turf or '',
        hint = L('leave_hint'),
    })
end

local function updateHud()
    if not hudVisible then return end
    local turf = armedTurfId and getTurfById(armedTurfId)
    SendNUIMessage({
        action = 'update',
        heat = heat,
        wave = waveNumber,
        kills = kills,
        turf = turf and turf.label or '',
        hint = L('leave_hint'),
    })
end

---------------------------------------------------------------------------
-- Hostile spawn / cleanup
---------------------------------------------------------------------------

local function cleanupHostiles()
    for netId, ped in pairs(hostiles) do
        if DoesEntityExist(ped) then
            SetEntityAsMissionEntity(ped, true, true)
            DeletePed(ped)
            DeleteEntity(ped)
        end
        hostiles[netId] = nil
    end
    hostiles = {}
end

--- Count only; the kill thread owns removal + reportKill for dead peds
local function countLiveHostiles()
    local n = 0
    for _, ped in pairs(hostiles) do
        if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) then
            n = n + 1
        end
    end
    return n
end

local function pistolChanceForWave(wave)
    local c = Config.PistolChanceStart + (wave - 1) * Config.PistolChanceStep
    if c > Config.PistolChanceMax then c = Config.PistolChanceMax end
    return c
end

local function pedsForWave(wave)
    local n = Config.BasePeds + (wave - 1) * Config.PedsPerWave
    if n > Config.MaxLiveHostiles then n = Config.MaxLiveHostiles end
    return n
end

local function findSpawnCoord(turf, playerCoords, attempt)
    -- Ring offsets inside turf radius; fall back to GetSafeCoordForPed
    local angle = (attempt * 67.0 + GetGameTimer() * 0.01) % 360.0
    local rad = math.rad(angle)
    local ring = math.min(turf.radius * 0.65, 18.0 + (attempt % 4) * 4.0)
    local ox = math.cos(rad) * ring
    local oy = math.sin(rad) * ring
    local tx = playerCoords.x + ox
    local ty = playerCoords.y + oy
    -- Keep inside turf
    local fromCenter = dist2d(vector3(tx, ty, 0.0), turf.center)
    if fromCenter > turf.radius - 3.0 then
        local scale = (turf.radius - 5.0) / math.max(fromCenter, 0.1)
        tx = turf.center.x + (tx - turf.center.x) * scale
        ty = turf.center.y + (ty - turf.center.y) * scale
    end
    local found, safe = GetSafeCoordForPed(tx, ty, playerCoords.z, false, 16)
    if found then
        return safe
    end
    local gz = playerCoords.z
    local ok, z = GetGroundZFor_3dCoord(tx, ty, playerCoords.z + 50.0, false)
    if ok then gz = z end
    return vector3(tx, ty, gz)
end

local function spawnHostile(turf, wave)
    ensureRelationship()
    local models = turf.models
    local model = models[math.random(1, #models)]
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end
    if not HasModelLoaded(model) then return nil end

    local playerPed = PlayerPedId()
    local pcoords = GetEntityCoords(playerPed)
    local spawn = findSpawnCoord(turf, pcoords, math.random(1, 12))

    local ped = CreatePed(4, model, spawn.x, spawn.y, spawn.z, math.random(0, 359) + 0.0, true, true)
    SetModelAsNoLongerNeeded(model)
    if not DoesEntityExist(ped) then return nil end

    SetEntityAsMissionEntity(ped, true, true)
    SetPedRelationshipGroupHash(ped, REL_HASH)
    SetPedAsEnemy(ped, true)
    SetCanAttackFriendly(ped, false, false)
    SetPedCombatAttributes(ped, 46, true)  -- always fight
    SetPedCombatAttributes(ped, 5, true)   -- can fight armed peds when not armed
    SetPedCombatAbility(ped, 2)
    SetPedCombatMovement(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedFleeAttributes(ped, 0, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)

    local usePistol = math.random() < pistolChanceForWave(wave)
    if usePistol then
        GiveWeaponToPed(ped, `WEAPON_PISTOL`, 60, false, true)
        SetCurrentPedWeapon(ped, `WEAPON_PISTOL`, true)
    else
        GiveWeaponToPed(ped, `WEAPON_UNARMED`, 1, false, true)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    end

    TaskCombatPed(ped, playerPed, 0, 16)

    local netId = NetworkGetNetworkIdFromEntity(ped)
    -- Keep ownership so cleanupHostiles can delete and server owner check holds
    SetNetworkIdCanMigrate(netId, false)
    hostiles[netId] = ped

    TriggerServerEvent('fivex_gangwars:registerPed', runToken, netId)
    return ped
end

local endRun -- forward decl (spawnWave ends empty waves)

local function spawnWave(wave)
    local turf = getTurfById(armedTurfId)
    if not turf then return end
    local token = runToken
    -- Block wave-clear detection while peds are still loading / spawning
    waveClearPending = true
    local want = pedsForWave(wave)
    local live = countLiveHostiles()
    local toSpawn = math.min(want - live, Config.MaxLiveHostiles - live)
    if toSpawn < 1 then toSpawn = want end
    toSpawn = math.min(toSpawn, Config.MaxLiveHostiles)

    local made = 0
    for i = 1, toSpawn do
        if not runActive or runToken ~= token then return end
        if countLiveHostiles() >= Config.MaxLiveHostiles then break end
        if spawnHostile(turf, wave) then
            made = made + 1
        end
        Wait(150)
    end
    if not runActive or runToken ~= token then return end
    waveClearPending = false
    if made == 0 then
        -- Nothing spawned (model / CreatePed failure): never auto-clear an empty wave
        endRun('stop')
        return
    end
    notify(L('wave_start', wave))
end

---------------------------------------------------------------------------
-- Run lifecycle
---------------------------------------------------------------------------

endRun = function(reason)
    if not runActive and not armed then
        heat = 0.0
        return
    end
    local token = runToken
    local waves = waveNumber
    local k = kills
    runActive = false
    armed = false
    armedTurfId = nil
    heat = 0.0
    waveNumber = 0
    kills = 0
    waveClearPending = false
    inCooldown = false
    runToken = nil
    cleanupHostiles()
    setHud(false)
    if reason == 'leave' then
        notify(L('run_ended_leave'))
    elseif reason == 'death' then
        notify(L('run_ended_death'))
    else
        notify(L('run_ended_stop'))
    end
    notify(L('score', waves, k))
    if token then
        TriggerServerEvent('fivex_gangwars:endRun', token, reason, waves, k)
    end
end

local function startWaveFromHeat()
    if runActive or inCooldown then return end
    runActive = true
    waveNumber = 1
    kills = 0
    heat = 100.0
    runToken = ('%s-%s-%s'):format(GetPlayerServerId(PlayerId()), armedTurfId, GetGameTimer())
    TriggerServerEvent('fivex_gangwars:startRun', runToken, armedTurfId)
    setHud(true, { heat = heat, wave = waveNumber, kills = kills, turf = getTurfById(armedTurfId).label })
    spawnWave(waveNumber)
end

local function onWaveCleared()
    if not runActive or waveClearPending then return end
    waveClearPending = true
    notify(L('wave_clear', waveNumber))
    TriggerServerEvent('fivex_gangwars:waveClear', runToken, waveNumber, kills)

    if Config.MaxWaves > 0 and waveNumber >= Config.MaxWaves then
        endRun('maxwaves')
        return
    end

    inCooldown = true
    local myToken = runToken
    CreateThread(function()
        Wait(Config.WaveCooldownMs)
        -- Stale thread from an earlier run: leave the new run's state alone
        if not runActive or runToken ~= myToken then return end
        inCooldown = false
        waveClearPending = false
        waveNumber = waveNumber + 1
        heat = 100.0
        updateHud()
        spawnWave(waveNumber)
    end)
end

---------------------------------------------------------------------------
-- Arm (E at center)
---------------------------------------------------------------------------

local function tryArm(turf)
    if optOut or armed or runActive then return end
    armed = true
    armedTurfId = turf.id
    heat = 0.0
    ensureRelationship()
    notify(L('armed'))
    setHud(true, { heat = 0, wave = 0, kills = 0, turf = turf.label })
end

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------

RegisterCommand('flashpoint', function()
    optOut = not optOut
    if optOut then
        notify(L('optout_on'))
        if armed or runActive then
            endRun('optout')
        end
    else
        notify(L('optout_off'))
    end
end, false)

RegisterCommand(Config.DebugCommand, function(_, args)
    TriggerServerEvent('fivex_gangwars:debug', args[1], args[2])
end, false)

RegisterNetEvent('fivex_gangwars:debugResult', function(ok, msgKey, extra)
    if not ok then
        notify(L(msgKey))
        return
    end
    if msgKey == 'debug_started' then
        local turf = getTurfById(extra)
        if not turf then
            notify(L('no_turf'))
            return
        end
        if runActive then endRun('stop') end
        armed = true
        armedTurfId = turf.id
        heat = 100.0
        notify(L('debug_started', turf.label))
        startWaveFromHeat()
    elseif msgKey == 'debug_stopped' then
        endRun('stop')
        notify(L('debug_stopped'))
    else
        notify(L(msgKey))
    end
end)

RegisterNetEvent('fivex_gangwars:payday', function(amount)
    if Config.PaydayNotify then
        notify(L('payday', amount))
    end
end)

---------------------------------------------------------------------------
-- Kill tracking thread (only while run active)
---------------------------------------------------------------------------

CreateThread(function()
    while true do
        if runActive then
            local died = {}
            for netId, ped in pairs(hostiles) do
                if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
                    died[#died + 1] = netId
                end
            end
            for _, netId in ipairs(died) do
                hostiles[netId] = nil
                kills = kills + 1
                TriggerServerEvent('fivex_gangwars:reportKill', runToken, netId)
                updateHud()
            end
            if not inCooldown and not waveClearPending and countLiveHostiles() == 0 and waveNumber > 0 then
                onWaveCleared()
            end
            -- Top up if somehow under desired mid-wave (despawn edge)
            Wait(200)
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------------------
-- Main turf / heat loop
---------------------------------------------------------------------------

CreateThread(function()
    createBlips()
    ensureRelationship()

    while true do
        local sleep = Config.TurfCheckIdleMs
        local ped = PlayerPedId()
        local turf = currentTurf()

        if optOut then
            -- still draw blips only; no prompts
            Wait(sleep)
        elseif runActive or armed then
            sleep = Config.TurfCheckActiveMs
            local activeTurf = getTurfById(armedTurfId)
            if not activeTurf then
                endRun('stop')
            else
                local inside = playerInsideTurf(activeTurf)
                -- marker drawn per-frame by the active marker thread below

                if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then
                    endRun('death')
                elseif not inside then
                    if runActive then
                        endRun('leave')
                    else
                        -- armed but left before wave: decay heat
                        heat = math.max(0.0, heat - Config.HeatDecayOutside * (sleep / 1000.0))
                        if heat <= 0.0 then
                            armed = false
                            armedTurfId = nil
                            setHud(false)
                        else
                            updateHud()
                        end
                    end
                else
                    -- inside & armed/running: build heat until wave
                    if not runActive then
                        local dt = sleep / 1000.0
                        local rate = Config.HeatPerSecondInside
                        local speed = GetEntitySpeed(ped)
                        if speed > 1.0 then
                            rate = rate + Config.HeatMovingBonus
                        end
                        if IsPedArmed(ped, 4) or IsPedArmed(ped, 1) then
                            rate = rate + Config.HeatArmedWeaponBonus
                        end
                        heat = math.min(100.0, heat + rate * dt)
                        updateHud()
                        if heat >= 100.0 then
                            startWaveFromHeat()
                        end
                    else
                        heat = 100.0
                        updateHud()
                    end
                end
            end
            Wait(sleep)
        else
            -- idle: check proximity for arm prompt
            if turf then
                sleep = 200
                local coords = GetEntityCoords(ped)
                local dCenter = dist2d(coords, turf.center)
                if dCenter <= Config.MarkerDrawDistance then
                    drawCenterMarker(turf)
                    sleep = 0
                end
                if dCenter <= Config.ArmInteractDistance then
                    helpText(L('press_e_arm'))
                    if IsControlJustReleased(0, Config.ArmKey) then
                        tryArm(turf)
                    end
                    sleep = 0
                elseif dist2d(coords, turf.center) <= Config.PromptDistance then
                    -- far inside turf but not at marker: soft hint via marker only
                end
            else
                local near, d = nearestTurf()
                if near and d < Config.MarkerDrawDistance + near.radius then
                    sleep = 400
                end
            end
            Wait(sleep)
        end
    end
end)

---------------------------------------------------------------------------
-- Active turf marker (DrawMarker must run every frame)
---------------------------------------------------------------------------

CreateThread(function()
    while true do
        local turf = (armed or runActive) and not optOut and armedTurfId and getTurfById(armedTurfId)
        if turf then
            drawCenterMarker(turf)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------------------
-- Resource stop cleanup
---------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    cleanupHostiles()
    for _, b in pairs(blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    blips = {}
    setHud(false)
end)
