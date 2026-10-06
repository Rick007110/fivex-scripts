-- Spawn selector. Takes over spawnmanager's auto-spawn callback: on join you pick where to spawn
-- (last location or a configured place, with a camera preview); after dying you respawn at the
-- nearest hospital. The map resources' random spawnpoints are never used.

local selecting = false
local chosen = false     -- picked a spawn this session
local respawning = false
local cam = nil
local choices = {}
local lastLoc = nil
local lastReceived = false

local FREEMODE = { [joaat('mp_m_freemode_01')] = true, [joaat('mp_f_freemode_01')] = true }

local function streetOf(x, y, z)
    local s = GetStreetNameFromHashKey((GetStreetNameAtCoord(x, y, z)))
    local zone = GetLabelText(GetNameOfZone(x, y, z))
    if s ~= '' and zone ~= '' and zone ~= 'NULL' then return ('%s, %s'):format(s, zone) end
    return s ~= '' and s or zone
end

local function buildChoices()
    choices = {}
    if lastLoc then
        choices[#choices + 1] = {
            id = 'last', label = 'Last location', icon = 'history',
            area = streetOf(lastLoc.x, lastLoc.y, lastLoc.z),
            coords = vector4(lastLoc.x, lastLoc.y, lastLoc.z, tonumber(lastLoc.h) or 0.0),
        }
    end
    for _, l in ipairs(Config.Locations) do choices[#choices + 1] = l end
end

---------------------------------------------------------------------------
-- Preview camera
---------------------------------------------------------------------------

-- Behind and above the spot; raised until nothing (buildings, trees, bridges) blocks the view.
local function camPos(c)
    local h = math.rad(c.w)
    local fx, fy = -math.sin(h), math.cos(h) -- GTA heading -> forward vector
    local bx, by = c.x - fx * Config.Camera.distance, c.y - fy * Config.Camera.distance
    local target = vector3(c.x, c.y, c.z + 1.0)
    local height = Config.Camera.height
    while height < Config.Camera.maxHeight do
        local probe = StartExpensiveSynchronousShapeTestLosProbe(target.x, target.y, target.z, bx, by, c.z + height, 1 | 16 | 256, 0, 4)
        local _, hit = GetShapeTestResult(probe)
        if hit == 0 then break end
        height = height + Config.Camera.step
    end
    return vector3(bx, by, c.z + height)
end

-- Story-mode "switch" look, done with scripted cameras so we control speed and destination:
-- rise straight up, glide across high above the map, drop to the aerial shot of the new spot.
local camToken = 0
local oldCams = {}

local function newCam(pos, rot, pointAt)
    local c = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, Config.Camera.fov, false, 0)
    if pointAt then PointCamAtCoord(c, pointAt.x, pointAt.y, pointAt.z) end
    return c
end

local function blendTo(nextCam, ms)
    if cam and DoesCamExist(cam) then
        SetCamActiveWithInterp(nextCam, cam, ms, 1, 1)
        oldCams[#oldCams + 1] = cam
    else
        SetCamActive(nextCam, true)
        RenderScriptCams(true, false, 0, true, true)
    end
    cam = nextCam
end

local function cleanupOldCams()
    for i = #oldCams, 1, -1 do
        if DoesCamExist(oldCams[i]) and oldCams[i] ~= cam then DestroyCam(oldCams[i], false) end
        oldCams[i] = nil
    end
end

local DOWN = vector3(-89.5, 0.0, 0.0) -- looking straight down

local function whoosh(name)
    PlaySoundFrontend(-1, name, 'PLAYER_SWITCH_CUSTOM_SOUNDSET', true)
end

-- Fly the camera to choices[index]. `intro` = first shot: drop in from the sky above it.
local function preview(index, intro)
    local choice = choices[index]
    if not choice then return end
    camToken = camToken + 1
    local token = camToken
    local c = choice.coords
    local T = Config.Transition
    local target = vector3(c.x, c.y, c.z + 1.0)

    CreateThread(function()
        local function alive() return token == camToken end
        local high = vector3(c.x, c.y, c.z + T.altitude)

        if intro or not cam or not DoesCamExist(cam) then
            SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
            blendTo(newCam(high, DOWN), 0)
        else
            -- 1. straight up from wherever the camera is now
            local from = GetCamCoord(cam)
            whoosh('Short_Transition_Out')
            blendTo(newCam(vector3(from.x, from.y, math.max(from.z, c.z) + T.altitude), DOWN), T.up)
            Wait(T.up)
            if not alive() then return end
            -- 2. glide across, high above the map; start streaming the destination
            SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
            RequestCollisionAtCoord(c.x, c.y, c.z)
            local d = #(vector2(from.x, from.y) - vector2(c.x, c.y))
            local across = math.floor(math.min(T.acrossMax, T.across + d * T.acrossPerKm / 1000.0))
            blendTo(newCam(high, DOWN), across)
            Wait(across)
            if not alive() then return end
        end
        -- 3. drop down to the aerial shot (camPos raises itself if something blocks the view)
        RequestCollisionAtCoord(c.x, c.y, c.z)
        local p = camPos(c)
        whoosh('Short_Transition_In')
        blendTo(newCam(p, vector3(0.0, 0.0, 0.0), target), intro and T.intro or T.down)
        Wait(intro and T.intro or T.down)
        if alive() then cleanupOldCams() end
    end)
end

local function destroyCam(blendMs)
    camToken = camToken + 1
    RenderScriptCams(false, (blendMs or 0) > 0, blendMs or 0, true, true)
    if cam and DoesCamExist(cam) then DestroyCam(cam, false) end
    cam = nil
    cleanupOldCams()
    ClearFocus()
end

---------------------------------------------------------------------------
-- Spawning
---------------------------------------------------------------------------

-- Snap z to the ground once collision is loaded (configured / saved z can be a bit off).
local function groundZ(c)
    local untilT = GetGameTimer() + 3000
    while GetGameTimer() < untilT do
        RequestCollisionAtCoord(c.x, c.y, c.z)
        for _, probe in ipairs({ c.z + 2.0, c.z + 50.0 }) do
            local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, probe, false)
            if ok and math.abs(gz - c.z) < 40.0 then return gz + 0.05 end
        end
        Wait(0)
    end
    return c.z
end

local function hideLocalPed(on)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, on)
    SetEntityVisible(ped, not on, false)
    SetEntityInvincible(ped, on)
    SetPlayerControl(PlayerId(), not on, 0)
end

local function spawnAt(c, withModel, done)
    local fired = false
    local function attempt()
        local spawn = { x = c.x, y = c.y, z = c.z, heading = c.w, skipFade = true }
        if withModel and not FREEMODE[GetEntityModel(PlayerPedId())] then spawn.model = Config.DefaultModel end
        exports.spawnmanager:spawnPlayer(spawn, function()
            fired = true
            if done then done() end
        end)
    end
    attempt()
    -- spawnmanager ignores calls while another spawn is in progress: retry once it's free
    CreateThread(function()
        for _ = 1, 3 do
            Wait(6000)
            if fired then return end
            attempt()
        end
    end)
end

local function finishSpawn()
    selecting = false
    chosen = true
    DisplayRadar(true)
    TriggerServerEvent('fivex_spawn:spawned')
end

-- Finish like a story-mode switch: from the aerial shot, dive down to just behind the player and
-- blend into the normal gameplay camera.
local function diveTo(c, z)
    local T = Config.Transition
    camToken = camToken + 1
    hideLocalPed(false)
    spawnAt(vector4(c.x, c.y, z, c.w), true, function()
        local ped = PlayerPedId()
        SetGameplayCamRelativeHeading(0.0)
        SetGameplayCamRelativePitch(-5.0, 1.0)
        local behind = GetOffsetFromEntityInWorldCoords(ped, 0.0, -4.5, 1.4)
        local head = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, 0.7)
        whoosh('Short_Transition_In')
        blendTo(newCam(behind, vector3(0.0, 0.0, 0.0), head), T.land)
        Wait(T.land)
        destroyCam(T.handoff)
        finishSpawn()
    end)
end

local function doSpawn(choice)
    if not choice then return end
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
    local c = choice.coords
    SetFocusPosAndVel(c.x, c.y, c.z, 0.0, 0.0, 0.0)
    local z = groundZ(c)
    if Config.Transition.enabled and cam then
        diveTo(c, z)
        return
    end
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    destroyCam()
    hideLocalPed(false)
    spawnAt(vector4(c.x, c.y, z, c.w), true, finishSpawn)
end

local function openSelector()
    if selecting or chosen then return end
    selecting = true
    CreateThread(function()
        DoScreenFadeOut(0)
        hideLocalPed(true)
        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()

        lastReceived = false
        TriggerServerEvent('fivex_spawn:requestLast')
        local untilT = GetGameTimer() + 4000
        while not lastReceived and GetGameTimer() < untilT do Wait(50) end

        buildChoices()
        preview(1, true)
        Wait(400)
        local list = {}
        for i, ch in ipairs(choices) do
            list[i] = { id = ch.id, label = ch.label, area = ch.area, icon = ch.icon }
        end
        SendNUIMessage({ type = 'open', choices = list, name = GetPlayerName(PlayerId()) })
        SetNuiFocus(true, true)
        DoScreenFadeIn(700)
    end)
end

local function respawnAtHospital()
    if respawning then return end
    respawning = true
    local p = GetEntityCoords(PlayerPedId())
    local best, bestD = Config.Hospitals[1], math.huge
    for _, h in ipairs(Config.Hospitals) do
        local d = #(p - vector3(h.x, h.y, h.z))
        if d < bestD then best, bestD = h, d end
    end
    DoScreenFadeOut(800)
    while not IsScreenFadedOut() do Wait(0) end
    spawnAt(best, false, function() respawning = false end)
end

-- spawnmanager calls this whenever it would auto-spawn (join, forced respawn, death)
local function onAutoSpawn()
    if not chosen then
        openSelector()
    elseif IsEntityDead(PlayerPedId()) then
        CreateThread(respawnAtHospital)
    end
    -- alive + already spawned (e.g. a map change forcing a respawn): stay where you are
end

local function hook()
    exports.spawnmanager:setAutoSpawnCallback(onAutoSpawn)
end

hook()
AddEventHandler('onClientResourceStart', function(res)
    if res == 'spawnmanager' then hook() end
end)

-- In case spawnmanager already spawned us at a random point before this resource loaded.
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(200) end
    Wait(1500)
    if not chosen and not selecting then openSelector() end
end)

-- hide HUD / radar while choosing
CreateThread(function()
    while true do
        if selecting then
            HideHudAndRadarThisFrame()
            DisplayRadar(false)
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('fivex_spawn:last', function(last)
    lastLoc = type(last) == 'table' and last or nil
    lastReceived = true
end)

RegisterNUICallback('preview', function(data, cb)
    preview(tonumber(data and data.index))
    cb({ ok = true })
end)

RegisterNUICallback('spawn', function(data, cb)
    cb({ ok = true })
    local choice = choices[tonumber(data and data.index) or 0]
    if selecting and choice then CreateThread(function() doSpawn(choice) end) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if selecting then
        SetNuiFocus(false, false)
        destroyCam()
        hideLocalPed(false)
        DoScreenFadeIn(0)
    end
end)
