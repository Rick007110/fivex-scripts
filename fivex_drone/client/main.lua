-- fivex_drone client. Your own drone is simulated here (Flight); its state goes to the server, which
-- relays it to players near the drone. Everyone renders drones as local props, interpolated between
-- snapshots, and hears them through the NUI motor synth (distance, pan, Doppler).

local qrot, clamp = FD.qrot, FD.clamp
local abs, sqrt, exp, rad, sin, cos, random = math.abs, math.sqrt, math.exp, math.rad, math.sin, math.cos, math.random

local own = nil      -- your drone (see deploy())
local remotes = {}   -- [serverId] = { snaps = {}, obj, px.. }
local modelHash = nil
local pending = false
local cutHeld = false -- throttle cut key mapping (works even when another script owns Ctrl / duck)
local INTERP = 120   -- ms remote render delay

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

RegisterNetEvent('fivex_drone:notify', function(msg)
    notify(msg)
end)

local function dbg(fmt, ...)
    if Config.Debug then print(('[fivex_drone] ' .. fmt):format(...)) end
end

local function nui(t, data)
    data = data or {}
    data.t = t
    SendNUIMessage(data)
end

---------------------------------------------------------------------------
-- Props
---------------------------------------------------------------------------

local function loadModel(m)
    local h = type(m) == 'number' and m or joaat(m)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(h) do
        if GetGameTimer() > deadline then return nil end
        Wait(0)
    end
    return h
end

local function makeProp(x, y, z)
    if not modelHash then return nil end
    local o = CreateObjectNoOffset(modelHash, x, y, z, false, false, false)
    SetEntityCollision(o, false, false)
    FreezeEntityPosition(o, true)
    SetEntityInvincible(o, true)
    SetEntityLodDist(o, Config.Drone.lodDistance)
    return o
end

local YAW_W, YAW_X, YAW_Y, YAW_Z = FD.qaxis(0, 0, 1, rad(Config.Drone.yawOffset))

local function place(o, px, py, pz, qw, qx, qy, qz)
    if not o or not DoesEntityExist(o) then return end
    local off = Config.Drone.offset
    local ox, oy, oz = qrot(qw, qx, qy, qz, off.x, off.y, off.z)
    local w, x, y, z = FD.qmul(qw, qx, qy, qz, YAW_W, YAW_X, YAW_Y, YAW_Z)
    local fx, fy, fz = qrot(w, x, y, z, 0, 1, 0)
    local rx, ry, rz = qrot(w, x, y, z, 1, 0, 0)
    local ux, uy, uz = qrot(w, x, y, z, 0, 0, 1)
    -- SetEntityCoords moves the entity in GTA's world (render / streaming culling); a bare matrix write
    -- can leave it registered where it spawned, so it stops drawing once it has flown away
    SetEntityCoordsNoOffset(o, px + ox, py + oy, pz + oz, false, false, false)
    SetEntityMatrix(o, fx, fy, fz, rx, ry, rz, ux, uy, uz, px + ox, py + oy, pz + oz)
end

local function led(x, y, z, kamikaze)
    if not Config.Led.enabled then return end
    local c = kamikaze and Config.Kamikaze.ledColor or Config.Led.color
    DrawLightWithRange(x, y, z, c[1], c[2], c[3], Config.Led.range, Config.Led.intensity)
end

-- kamikaze: your choice persists across drones; the server confirms every toggle (ACE)
local kamikaze = false
local setKamikaze -- defined in Network below (used by gamepad input before that)

local function deleteEntity(e)
    if e and DoesEntityExist(e) then
        SetEntityAsMissionEntity(e, true, true)
        DeleteEntity(e)
    end
end

---------------------------------------------------------------------------
-- Pilot
---------------------------------------------------------------------------

local function pilotStart()
    local ped = PlayerPedId()
    local c = Config.Pilot
    if c.dict and c.anim then
        RequestAnimDict(c.dict)
        local deadline = GetGameTimer() + 3000
        while not HasAnimDictLoaded(c.dict) and GetGameTimer() < deadline do Wait(0) end
        TaskPlayAnim(ped, c.dict, c.anim, 3.0, 3.0, -1, c.flags, 0, false, false, false)
    end
    -- first prop in the list that exists in this game build
    local props = type(c.prop) == 'table' and c.prop or { c.prop }
    for _, name in ipairs(props) do
        local h = name and loadModel(name)
        if h then
            local p = GetEntityCoords(ped)
            local o = CreateObject(h, p.x, p.y, p.z, true, true, false)
            SetEntityCollision(o, false, false)
            AttachEntityToEntity(o, ped, GetPedBoneIndex(ped, c.bone), c.pos.x, c.pos.y, c.pos.z,
                c.rot.x, c.rot.y, c.rot.z, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(h)
            own.controller = o
            break
        end
    end
    own.pedHealth = GetEntityHealth(ped)
end

-- /fpvprop x y z rx ry rz — move the transmitter in your hands live while flying, then copy the
-- printed line into Config.Pilot (pos / rot)
RegisterCommand('fpvprop', function(_, args)
    local c = Config.Pilot
    if #args >= 6 then
        local n = {}
        for i = 1, 6 do n[i] = tonumber(args[i]) or 0.0 end
        c.pos, c.rot = vector3(n[1], n[2], n[3]), vector3(n[4], n[5], n[6])
    end
    if own and own.controller and DoesEntityExist(own.controller) then
        local ped = PlayerPedId()
        DetachEntity(own.controller, true, false)
        AttachEntityToEntity(own.controller, ped, GetPedBoneIndex(ped, c.bone), c.pos.x, c.pos.y, c.pos.z,
            c.rot.x, c.rot.y, c.rot.z, true, true, false, true, 1, true)
    end
    local line = ('pos = vector3(%.3f, %.3f, %.3f), rot = vector3(%.1f, %.1f, %.1f),'):format(
        c.pos.x, c.pos.y, c.pos.z, c.rot.x, c.rot.y, c.rot.z)
    print('[fivex_drone] ' .. line)
    notify(line)
end, false)

local function pilotStop()
    local ped = PlayerPedId()
    if Config.Pilot.dict then StopAnimTask(ped, Config.Pilot.dict, Config.Pilot.anim, 2.0) end
    deleteEntity(own and own.controller)
    if own then own.controller = nil end
end

local function pilotInterrupted()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedRagdoll(ped) or IsPedInAnyVehicle(ped, false) or IsPedSwimming(ped) then
        return true
    end
    local hp = GetEntityHealth(ped)
    if hp < (own.pedHealth or hp) then return true end
    own.pedHealth = hp
    return false
end

---------------------------------------------------------------------------
-- Goggles (FPV camera)
---------------------------------------------------------------------------

local function dronePos()
    local f = own.f
    return vector3(f.px, f.py, f.pz)
end

local function pilotDistance()
    return #(GetEntityCoords(PlayerPedId()) - dronePos())
end

local function exitFpv(reason)
    if not own or not own.fpv then return end
    own.fpv = false
    own.f.armed = false -- goggles off = failsafe
    if own.cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(own.cam, false)
        own.cam = nil
    end
    deleteEntity(own.camHelper)
    own.camHelper = nil
    ClearFocus()
    pilotStop()
    if own.obj then SetEntityVisible(own.obj, true, false) end
    own.parked = false
    nui('osd', { show = false })
    if reason then notify(L(reason)) end
    dbg('exit fpv (%s)', tostring(reason))
end

local function enterFpv(chime)
    if not own or own.fpv then return end
    own.fpv = true
    own.parked = false
    -- fresh sticks every time the goggles go on (keyboard throttle would otherwise stay where it was)
    own.thr, own.thrNow, own.sRoll, own.sPitch = 0.0, 0.0, 0.0, 0.0
    cutHeld = false
    own.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(own.cam, Config.Camera.fov)
    SetCamActive(own.cam, true)
    RenderScriptCams(true, false, 0, true, true)
    own.camHelper = makeProp(own.f.px, own.f.py, own.f.pz - 60.0)
    if own.camHelper then SetEntityVisible(own.camHelper, false, false) end
    if own.obj then SetEntityVisible(own.obj, false, false) end
    own.lostAt = nil
    pilotStart()
    nui('osd', { show = true })
    nui('sfx', { name = chime or 'connect' })
    local k = Config.Keys
    notify(L('deployed_help', k.arm, k.mode, k.tilt, k.exit))
end

-- camera orientation via a hidden helper prop: GTA turns the matrix into its own Euler angles,
-- so the camera always matches the drone exactly
local function updateCamera(dt)
    local f = own.f
    local tilt = rad(Config.Camera.tilts[own.tilt] or 0)
    local w, x, y, z = FD.qmul(f.qw, f.qx, f.qy, f.qz, FD.qaxis(1, 0, 0, tilt))
    local vib = rad(Config.Camera.vibration) * f.motor
    if vib > 0 then
        w, x, y, z = FD.qmul(w, x, y, z, FD.qaxis(1, 0, 0, (random() * 2 - 1) * vib))
        w, x, y, z = FD.qmul(w, x, y, z, FD.qaxis(0, 1, 0, (random() * 2 - 1) * vib))
    end
    local off = Config.Camera.offset
    local ox, oy, oz = qrot(f.qw, f.qx, f.qy, f.qz, off.x, off.y, off.z)
    local cx, cy, cz = f.px + ox, f.py + oy, f.pz + oz
    if own.camHelper and DoesEntityExist(own.camHelper) then
        local fx, fy, fz = qrot(w, x, y, z, 0, 1, 0)
        local rx, ry, rz = qrot(w, x, y, z, 1, 0, 0)
        local ux, uy, uz = qrot(w, x, y, z, 0, 0, 1)
        -- only its rotation matters: park it well below the drone so collision rays never touch it
        SetEntityMatrix(own.camHelper, fx, fy, fz, rx, ry, rz, ux, uy, uz, cx, cy, cz - 60.0)
        local r = GetEntityRotation(own.camHelper, 2)
        SetCamRot(own.cam, r.x, r.y, r.z, 2)
    end
    SetCamCoord(own.cam, cx, cy, cz)
    SetFocusPosAndVel(cx, cy, cz, 0.0, 0.0, 0.0)
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------

local function dz(v)
    local d = Config.Gamepad.deadzone
    if abs(v) < d then return 0.0 end
    return (v - (v > 0 and d or -d)) / (1 - d)
end

local function ctl(i) return GetDisabledControlNormal(0, i) end
local function pressed(i) return IsDisabledControlJustPressed(0, i) end

local function toggleArm()
    if not own or not own.fpv then return end
    local f = own.f
    if f.armed then
        f.armed = false
        nui('sfx', { name = 'disarm' })
        return
    end
    if f.broken or f.wet or f.battDead or own.lq <= 0.05 then return end
    local high
    if IsUsingKeyboard(2) then high = own.thrNow > 0.05 else high = (own.padY or 0) > 0.1 end
    if high then
        own.warnUntil = GetGameTimer() + 2000
        own.warn = L('osd_throttle')
        notify(L('arm_throttle'))
        return
    end
    f.armed = true
    own.crashAt = nil
    nui('sfx', { name = 'arm' })
end

local function toggleMode()
    if not own or not own.fpv then return end
    own.mode = own.mode == 'acro' and 'angle' or 'acro'
    nui('sfx', { name = 'click' })
end

local function cycleTilt()
    if not own or not own.fpv then return end
    own.tilt = own.tilt % #Config.Camera.tilts + 1
    nui('sfx', { name = 'click' })
end

local function readInput(dt)
    local inp = { mode = own.mode }
    if IsUsingKeyboard(2) then
        local K = Config.Keyboard
        own.thr = clamp(own.thr + (ctl(32) - ctl(33)) * K.throttleRate * dt, 0, 1) -- W / S
        if cutHeld or ctl(36) > 0.5 then own.thr = 0.0 end                       -- Ctrl: cut
        inp.thr = ctl(22) > 0.5 and 1.0 or own.thr                               -- Space: punch out

        local my = ctl(2)
        if not K.invertMouseY then my = -my end
        local rc = exp(-dt * K.mouseRecenter)
        own.sRoll = clamp((own.sRoll + ctl(1) * K.mouseSensitivity * 0.1) * rc, -1, 1)
        own.sPitch = clamp((own.sPitch + my * K.mouseSensitivity * 0.1) * rc, -1, 1)
        local ar = (ctl(175) - ctl(174)) -- arrows right / left
        local ap = (ctl(172) - ctl(173)) -- arrows up / down
        inp.roll = clamp(own.sRoll + ar, -1, 1)
        inp.pitch = clamp(own.sPitch + ap, -1, 1)
        inp.yaw = ctl(35) - ctl(34) -- D / A
    else
        -- Mode 2: left stick Y throttle (centre = hover), left X yaw, right stick pitch / roll
        local y = -dz(ctl(219))
        local c = Config.Gamepad.centreThrottle
        local thr = y >= 0 and (c + (1 - c) * y) or (c * (1 + y))
        if not own.f.armed then own.padLock = true end
        if own.padLock then
            if own.f.armed and y > 0.1 then own.padLock = false else thr = 0.0 end
        end
        own.padY = y
        inp.thr = clamp(thr, 0, 1)
        own.thr = inp.thr
        inp.yaw = dz(ctl(218))
        inp.roll = dz(ctl(220))
        inp.pitch = -dz(ctl(221))
        if pressed(227) then toggleArm() end  -- RB
        if pressed(226) then toggleMode() end -- LB
        if pressed(232) then cycleTilt() end  -- D-pad up
        if pressed(233) then setKamikaze(not kamikaze) end -- D-pad down
        if pressed(225) then exitFpv() end    -- B
    end
    own.thrNow = inp.thr
    return inp
end

local function blockControls()
    DisableAllControlActions(0)
    EnableControlAction(0, 245, true) -- chat
    EnableControlAction(0, 249, true) -- push to talk
    EnableControlAction(0, 199, true) -- pause
    EnableControlAction(0, 200, true) -- pause (esc)
    HideHudAndRadarThisFrame()
end

---------------------------------------------------------------------------
-- Network
---------------------------------------------------------------------------

local function sendState()
    local f = own.f
    local flags = (f.armed and 1 or 0) | ((f.broken or f.wet) and 2 or 0) | (own.beeper and 4 or 0)
        | (kamikaze and 8 or 0)
    TriggerServerEvent('fivex_drone:state', {
        f.px, f.py, f.pz, f.qw, f.qx, f.qy, f.qz, f.vx, f.vy, f.vz, f.motor, flags, f.activity,
    })
    own.sentAt = GetGameTimer()
end

-- owner-only map blip (blips are client-side, nobody else sees it)
local function updateBlip()
    local B = Config.Blip
    if not B.enabled then return end
    local f = own.f
    if not own.blip or not DoesBlipExist(own.blip) then
        own.blip = AddBlipForCoord(f.px, f.py, f.pz)
        SetBlipSprite(own.blip, B.sprite)
        SetBlipColour(own.blip, B.colour)
        SetBlipScale(own.blip, B.scale)
        SetBlipAsShortRange(own.blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(L('blip'))
        EndTextCommandSetBlipName(own.blip)
    else
        SetBlipCoords(own.blip, f.px, f.py, f.pz)
    end
end

local function removeBlip()
    if own and own.blip and DoesBlipExist(own.blip) then RemoveBlip(own.blip) end
    if own then own.blip = nil end
end

local function removeOwn()
    if not own then return end
    exitFpv()
    removeBlip()
    deleteEntity(own.obj)
    own = nil
    nui('voices', { list = {} })
end

RegisterNetEvent('fivex_drone:removed', function(reason)
    if not own then return end
    notify(L(reason or 'picked_up'))
    if own.detonated then
        -- let the goggles show static for a moment after the blast
        local gone = own
        SetTimeout(1000, function() if own == gone then removeOwn() end end)
        return
    end
    removeOwn()
end)

-- kamikaze: blow up where the drone is (owned by the pilot, synced to everyone), drone is used up
local function detonate()
    if not own or own.detonated then return end
    own.detonated = true
    local f, K = own.f, Config.Kamikaze
    AddOwnedExplosion(PlayerPedId(), f.px, f.py, f.pz, K.explosion, K.damage, true, false, K.shake)
    f.broken, f.armed = true, false
    f.vx, f.vy, f.vz, f.motor = 0.0, 0.0, 0.0, 0.0
    own.parked = true
    if own.obj then SetEntityVisible(own.obj, false, false) end
    nui('sfx', { name = 'crash' })
    TriggerServerEvent('fivex_drone:detonated')
    dbg('detonated at %.1f %.1f %.1f', f.px, f.py, f.pz)
end

function setKamikaze(on)
    if not Config.Kamikaze.enabled then return end
    TriggerServerEvent('fivex_drone:kamikaze', on)
end

RegisterNetEvent('fivex_drone:kamikaze', function(on)
    kamikaze = on == true
    notify(L(kamikaze and 'kamikaze_on' or 'kamikaze_off'))
    nui('sfx', { name = kamikaze and 'arm' or 'disarm' })
end)

RegisterNetEvent('fivex_drone:hit', function()
    if not own then return end
    if kamikaze then return detonate() end
    local f = own.f
    f.broken, f.armed = true, false
    f.wx, f.wy, f.wz = (random() * 2 - 1) * 25, (random() * 2 - 1) * 25, (random() * 2 - 1) * 10
    f.vz = f.vz + 2.0
    own.parked = false
    nui('sfx', { name = 'crash' })
    notify(L('shot_down'))
end)

RegisterNetEvent('fivex_drone:state', function(id, d)
    if type(d) ~= 'table' or #d < 13 then return end
    local r = remotes[id]
    if not r then
        r = { snaps = {} }
        remotes[id] = r
        dbg('remote drone %s in range', id)
    end
    local s = r.snaps
    s[#s + 1] = { t = GetGameTimer(), d = d }
    if #s > 5 then table.remove(s, 1) end
end)

RegisterNetEvent('fivex_drone:gone', function(id)
    local r = remotes[id]
    if not r then return end
    deleteEntity(r.obj)
    remotes[id] = nil
end)

---------------------------------------------------------------------------
-- Deploy / reconnect / pick up
---------------------------------------------------------------------------

RegisterNetEvent('fivex_drone:deployed', function(ok)
    pending = false
    if not ok or own then return end
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local fwd = GetEntityForwardVector(ped)
    local x, y = p.x + fwd.x * 1.3, p.y + fwd.y * 1.3
    local found, gz = GetGroundZFor_3dCoord(x, y, p.z + 1.0, false)
    local z = (found and gz or (p.z - 1.0)) + Config.Drone.radius
    own = {
        f = Flight.new(x, y, z, h),
        obj = makeProp(x, y, z),
        home = vector3(p.x, p.y, p.z), homeZ = z,
        mode = Config.DefaultMode, tilt = Config.Camera.defaultTilt,
        thr = 0.0, thrNow = 0.0, sRoll = 0.0, sPitch = 0.0,
        lq = 1.0, blocked = false, flightTime = 0.0,
        parked = false, restT = 0.0, sentAt = 0, beeper = false,
    }
    sendState()
    enterFpv('esc')
    dbg('deployed at %.1f %.1f %.1f', x, y, z)
end)

-- can't fly the old drone (wrecked / out of range): second /fpv within Config.Abandon s replaces it
local function cannotReconnect(msg)
    local now = GetGameTimer()
    if Config.Abandon and own.abandonAt and now < own.abandonAt then
        own.abandonAt = nil
        if pending then return end
        if IsPedInAnyVehicle(PlayerPedId(), false) then return notify(L('not_on_foot')) end
        pending = true
        TriggerServerEvent('fivex_drone:abandon')
        SetTimeout(5000, function() pending = false end)
        return
    end
    if Config.Abandon then
        own.abandonAt = now + Config.Abandon * 1000
        msg = msg .. ' ' .. L('abandon_hint', Config.Command, Config.Abandon)
    end
    notify(msg)
end

local function useCommand()
    if own then
        if own.fpv then return exitFpv() end
        if own.f.broken or own.f.wet then return cannotReconnect(L('destroyed')) end
        local d = pilotDistance()
        if d > Config.Signal.range then return cannotReconnect(L('too_far', math.floor(d))) end
        if pilotInterrupted() then return notify(L('cannot_now')) end
        return enterFpv()
    end
    if pending then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return notify(L('not_on_foot')) end
    if IsEntityDead(ped) or IsPedSwimming(ped) or IsPedRagdoll(ped) or IsPedFalling(ped) then
        return notify(L('cannot_now'))
    end
    if not modelHash then return notify(L('model_failed')) end
    pending = true
    TriggerServerEvent('fivex_drone:deploy')
    SetTimeout(5000, function() pending = false end)
end

RegisterCommand(Config.Command, useCommand, false)
RegisterCommand('fivex_drone_arm', toggleArm, false)
RegisterCommand('fivex_drone_mode', toggleMode, false)
RegisterCommand('fivex_drone_tilt', cycleTilt, false)
RegisterCommand('fivex_drone_exit', function() exitFpv() end, false)
RegisterCommand('+fivex_drone_cut', function() cutHeld = true end, false)
RegisterCommand('-fivex_drone_cut', function() cutHeld = false end, false)
RegisterKeyMapping('+fivex_drone_cut', L('key_cut'), 'keyboard', Config.Keys.cut)
RegisterKeyMapping('fivex_drone_arm', L('key_arm'), 'keyboard', Config.Keys.arm)
RegisterKeyMapping('fivex_drone_mode', L('key_mode'), 'keyboard', Config.Keys.mode)
RegisterKeyMapping('fivex_drone_tilt', L('key_tilt'), 'keyboard', Config.Keys.tilt)
RegisterKeyMapping('fivex_drone_exit', L('key_exit'), 'keyboard', Config.Keys.exit)

-- /kamikaze (toggle) · /kamikaze on · /kamikaze off — also bound to a key (default K)
if Config.Kamikaze.enabled then
    local K = Config.Kamikaze
    RegisterCommand(K.command, function(_, args)
        local a = args[1] and args[1]:lower()
        if a == 'on' then setKamikaze(true)
        elseif a == 'off' then setKamikaze(false)
        else setKamikaze(not kamikaze) end
    end, false)
    RegisterKeyMapping(K.command, L('key_kamikaze'), 'keyboard', K.key)
    TriggerEvent('chat:addSuggestion', '/' .. K.command, 'FPV drone: kamikaze mode — explode instead of crashing', {
        { name = 'on|off', help = 'leave empty to toggle' },
    })
end
TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'FPV drone: deploy, fly, take the goggles off')

---------------------------------------------------------------------------
-- Own drone simulation
---------------------------------------------------------------------------

local IDLE_INPUT = { thr = 0.0, roll = 0.0, pitch = 0.0, yaw = 0.0, mode = 'acro' }

local function simulate(dt)
    local f = own.f
    local inp = own.fpv and readInput(dt) or IDLE_INPUT
    if own.lq <= 0.0 then f.armed = false end -- failsafe

    -- wind with gusts
    local t = GetGameTimer() / 1000
    local ws = GetWindSpeed() * Config.Physics.wind * (1 + 0.35 * sin(t * 0.7) + 0.2 * sin(t * 1.9 + 1.3))
    local wd = GetWindDirection()
    f.windX, f.windY = wd.x * ws, wd.y * ws

    if not own.fpv then RequestCollisionAtCoord(f.px, f.py, f.pz) end

    local ox, oy, oz = f.px, f.py, f.pz
    local n = clamp(math.ceil(dt / (1 / 240)), 1, 8)
    for _ = 1, n do Flight.step(f, inp, dt / n) end
    local kind, impact = Flight.collide(f, ox, oy, oz, own.obj)
    Flight.ground(f, inp, dt, own.obj)

    if kind then
        dbg('%s at %.1f m/s', kind, impact)
        if kind ~= 'bump' and kamikaze then
            detonate()
        elseif kind == 'bump' then
            nui('sfx', { name = 'bump', v = clamp(impact / 8, 0.2, 1) })
        else
            nui('sfx', { name = 'crash' })
            own.crashAt = GetGameTimer()
        end
    end
    if f.armed then own.flightTime = own.flightTime + dt end

    -- parked: lying still, nobody flying → stop simulating, switch the lost-drone beeper on
    if not own.fpv and f.contact and Flight.speed(f) < 0.05 and not f.armed then
        own.restT = own.restT + dt
        if own.restT > 1.5 and not own.parked then
            own.parked = true
            own.beeper = Config.Beeper
            f.motor = 0.0
            sendState()
        end
    else
        own.restT = 0.0
        own.beeper = false
    end
end

---------------------------------------------------------------------------
-- Signal (4 Hz): distance + line of sight between pilot and drone
---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(250)
        if own then
            local S = Config.Signal
            local ped = PlayerPedId()
            local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
            local f = own.f
            local d = #(head - vector3(f.px, f.py, f.pz))
            -- stop short of the drone so the ray never ends inside its own model
            local k = math.max(d - 0.6, 0) / math.max(d, 0.01)
            local ex, ey, ez = head.x + (f.px - head.x) * k, head.y + (f.py - head.y) * k, head.z + (f.pz - head.z) * k
            own.blocked = d > 2.0 and Flight.ray(head.x, head.y, head.z, ex, ey, ez, ped) ~= nil
            local eff = own.blocked and d * S.obstructedFactor or d
            local start = S.range * S.noiseStart
            local target = clamp(1 - (eff - start) / (S.range - start), 0, 1)
            own.lq = own.lq + (target - own.lq) * 0.5
            if target <= 0 then own.lq = 0.0 end
            own.dist = d
        end
    end
end)

---------------------------------------------------------------------------
-- OSD + audio (20 Hz to NUI)
---------------------------------------------------------------------------

local function warning()
    local f, now = own.f, GetGameTimer()
    if f.broken or f.wet then return L('osd_novideo') end
    if own.lq <= 0.15 then return L('osd_rxloss') end
    if own.warnUntil and now < own.warnUntil then return own.warn end
    if Config.Battery.enabled then
        if f.battDead or f.vcell < Config.Battery.criticalCell then return L('osd_critbat') end
        if f.armed and f.vcell < Config.Battery.warnCell then return L('osd_lowbat') end
    end
    if f.turtle then return L('osd_turtle') end
    if own.crashAt and now - own.crashAt < 2500 then return L('osd_crash') end
    if not f.armed then return L('osd_disarmed') end
    return ''
end

local function osdFrame()
    local f = own.f
    local fx, fy, fz = qrot(f.qw, f.qx, f.qy, f.qz, 0, 1, 0)
    local rx, ry, rz = qrot(f.qw, f.qx, f.qy, f.qz, 1, 0, 0)
    local _, _, uz = qrot(f.qw, f.qx, f.qy, f.qz, 0, 0, 1)
    local noise = 1 - own.lq
    if f.broken or f.wet then noise = 1 end
    local hx, hy = f.px - own.home.x, f.py - own.home.y
    return {
        volt = f.vcell * Config.Battery.cells,
        cell = f.vcell,
        mah = f.mah,
        time = own.flightTime,
        lq = own.lq * 100,
        thr = f.armed and own.thrNow * 100 or 0,
        spd = Flight.speed(f) * 3.6,
        alt = f.pz - own.homeZ,
        home = sqrt(hx * hx + hy * hy),
        mode = own.mode == 'acro' and 'ACRO' or 'ANGL',
        tilt = Config.Camera.tilts[own.tilt],
        armed = f.armed,
        warn = warning(),
        pitch = math.deg(math.asin(clamp(fz, -1, 1))),
        roll = math.deg(math.atan(-rz, uz)),
        noise = noise,
        low = f.vcell < Config.Battery.warnCell,
        kami = kamikaze and L('osd_kamikaze') or '',
        batt = Config.Battery.enabled,
    }
end

-- one voice per audible drone: gain by distance, pan by camera, Doppler by closing speed
local function voice(id, px, py, pz, vx, vy, vz, motor, activity, beeper, cam, right)
    local dx, dy, dz = px - cam.x, py - cam.y, pz - cam.z
    local d = sqrt(dx * dx + dy * dy + dz * dz)
    local S = Config.Sound
    if d > S.maxDistance then return nil end
    local nx, ny, nz = dx / math.max(d, 0.01), dy / math.max(d, 0.01), dz / math.max(d, 0.01)
    local closing = -(vx * nx + vy * ny + vz * nz)
    return {
        id = id,
        g = 1 / (1 + (d / S.refDistance) ^ S.rolloff),
        p = clamp(nx * right.x + ny * right.y, -1, 1) * 0.85,
        dop = clamp(343 / (343 - clamp(closing, -80, 80)), 0.7, 1.4),
        d = d,
        m = motor,
        a = activity or 0,
        b = beeper,
    }
end

CreateThread(function()
    while true do
        Wait(50)
        local list = {}
        local cam = GetFinalRenderedCamCoord()
        local cr = GetFinalRenderedCamRot(2)
        local right = vector3(cos(rad(cr.z)), sin(rad(cr.z)), 0.0)
        if own then
            local f = own.f
            if own.fpv then
                list[#list + 1] = { id = 'self', g = Config.Sound.onboard, p = 0, dop = 1, d = 0, m = f.motor, a = f.activity, b = false }
            else
                list[#list + 1] = voice('self', f.px, f.py, f.pz, f.vx, f.vy, f.vz, f.motor, f.activity, own.beeper, cam, right)
            end
            if own.fpv then nui('osd', { show = true, data = osdFrame() }) end
        end
        for id, r in pairs(remotes) do
            if r.px then
                list[#list + 1] = voice(tostring(id), r.px, r.py, r.pz, r.vx, r.vy, r.vz, r.motor, r.activity, r.beeper, cam, right)
            end
        end
        local S = Config.Sound
        nui('voices', { list = list, volume = S.volume, rpm = { S.idleRpm, S.maxRpm, S.blades } })
    end
end)

---------------------------------------------------------------------------
-- Remote drones: interpolate between snapshots
---------------------------------------------------------------------------

local function renderRemote(r, now)
    local s = r.snaps
    if #s == 0 then return end
    local t = now - INTERP
    local last = s[#s]
    local d = {}
    if t >= last.t or #s == 1 then
        -- past the newest snapshot: short extrapolation along its velocity
        local ahead = clamp((t - last.t) / 1000, 0, 0.25)
        for i = 1, 13 do d[i] = last.d[i] end
        d[1], d[2], d[3] = d[1] + d[8] * ahead, d[2] + d[9] * ahead, d[3] + d[10] * ahead
    else
        local a, b = s[1], s[2]
        for i = #s - 1, 1, -1 do
            if s[i].t <= t then a, b = s[i], s[i + 1]; break end
        end
        local k = clamp((t - a.t) / math.max(b.t - a.t, 1), 0, 1)
        local da, db = a.d, b.d
        for i = 1, 3 do d[i] = da[i] + (db[i] - da[i]) * k end
        d[4], d[5], d[6], d[7] = FD.qslerp(da[4], da[5], da[6], da[7], db[4], db[5], db[6], db[7], k)
        for i = 8, 13 do d[i] = (i == 12) and db[i] or (da[i] + (db[i] - da[i]) * k) end
    end

    if not r.obj then r.obj = makeProp(d[1], d[2], d[3]) end
    place(r.obj, d[1], d[2], d[3], d[4], d[5], d[6], d[7])
    r.px, r.py, r.pz, r.vx, r.vy, r.vz = d[1], d[2], d[3], d[8], d[9], d[10]
    r.motor, r.activity = d[11], d[13]
    local flags = math.floor(d[12])
    r.armed, r.broken, r.beeper, r.kamikaze = flags & 1 ~= 0, flags & 2 ~= 0, flags & 4 ~= 0, flags & 8 ~= 0
    if r.armed then led(d[1], d[2], d[3] + 0.05, r.kamikaze) end
end

-- shooting other people's drones
local function checkShots(now)
    if not Config.Shootable or not next(remotes) then return end
    local ped = PlayerPedId()
    if not IsPedShooting(ped) then return end
    local cp = GetFinalRenderedCamCoord()
    local cr = GetFinalRenderedCamRot(2)
    local px, pz = rad(cr.x), rad(cr.z)
    local dir = vector3(-sin(pz) * cos(px), cos(pz) * cos(px), sin(px))
    for id, r in pairs(remotes) do
        if r.px and not r.broken and (r.shotCd or 0) < now then
            local rel = vector3(r.px, r.py, r.pz) - cp
            local t = rel.x * dir.x + rel.y * dir.y + rel.z * dir.z
            if t > 0 and t < Config.ShotRange and #(rel - dir * t) < Config.HitRadius then
                local stop = cp + dir * math.max(t - 0.5, 0)
                if not Flight.ray(cp.x, cp.y, cp.z, stop.x, stop.y, stop.z, ped) then
                    r.shotCd = now + 300
                    TriggerServerEvent('fivex_drone:shot', id)
                end
            end
        end
    end
end

local function help(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

---------------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------------

CreateThread(function()
    modelHash = loadModel(Config.Drone.model)
    if not modelHash then print(('^1[fivex_drone] model %s failed to load^7'):format(Config.Drone.model)) end
    while true do
        if not own and not next(remotes) then
            Wait(300)
        else
            Wait(0)
            local now = GetGameTimer()
            local dt = clamp(GetFrameTime(), 0.001, 0.05)

            if own then
                local f = own.f
                if own.fpv then
                    blockControls()
                    if pilotInterrupted() then exitFpv('interrupted') end
                end
                if not own.parked then simulate(dt) end
                place(own.obj, f.px, f.py, f.pz, f.qw, f.qx, f.qy, f.qz)
                if not own.parked or not own.blip then updateBlip() end

                if own.fpv then
                    updateCamera(dt)
                    -- video gone (destroyed / link lost): show static briefly, then goggles off
                    if f.broken or f.wet or own.lq <= 0 then
                        own.lostAt = own.lostAt or now
                        if now - own.lostAt > 2000 then
                            exitFpv((f.broken or f.wet) and 'destroyed' or 'signal_lost')
                        end
                    else
                        own.lostAt = nil
                    end
                else
                    if f.armed then led(f.px, f.py, f.pz + 0.05, kamikaze) end
                    local d = pilotDistance()
                    -- owner-only marker over a drone lying still nearby (easy to spot in grass)
                    local M = Config.Marker
                    if M.enabled and own.parked and d < M.distance then
                        local c = M.color
                        DrawMarker(0, f.px, f.py, f.pz + 0.6, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.25, 0.25,
                            c[1], c[2], c[3], c[4], true, true, 2, false, nil, nil, false)
                    end
                    if d < Config.Pickup.distance then
                        help(L('help_pickup', Config.Command))
                        if IsControlJustPressed(0, 38) then TriggerServerEvent('fivex_drone:pickup') end
                    end
                end

                if not own.parked and now - own.sentAt >= 1000 / Config.Net.sendRate then sendState() end
            end

            for _, r in pairs(remotes) do renderRemote(r, now) end
            if not (own and own.fpv) then checkShots(now) end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if own then
        if own.fpv then
            RenderScriptCams(false, false, 0, true, true)
            if own.cam then DestroyCam(own.cam, false) end
            ClearFocus()
            pilotStop()
        end
        deleteEntity(own.camHelper)
        deleteEntity(own.obj)
        removeBlip()
    end
    for _, r in pairs(remotes) do deleteEntity(r.obj) end
end)
