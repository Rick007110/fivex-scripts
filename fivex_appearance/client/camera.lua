--- Scripted orbit camera. Character stays visible left of the NUI dock.

Cam = {}

local cam
local running = false
local heading = 0.0
local pitch = 5.0
local zoom = 2.15
local lookZ = 0.12
local targetPitch = 5.0
local targetZoom = 2.15
local targetLookZ = 0.12
local preset = 'full'
local hoverPanel = false
local frozenPed = false

local PRESETS = {
    face  = { z = 0.68,  zoom = 0.62, pitch = 8.0 },
    torso = { z = 0.22,  zoom = 1.15, pitch = 4.0 },
    legs  = { z = -0.42, zoom = 1.25, pitch = -6.0 },
    full  = { z = 0.12,  zoom = 2.15, pitch = 5.0 },
}

local function cfg()
    return Config.Camera or {}
end

local function clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function smooth(cur, target, dt, speed)
    local t = 1.0 - math.exp(-(speed or 8.0) * dt)
    return cur + (target - cur) * t
end

local function snapToTargets()
    zoom = targetZoom
    pitch = targetPitch
    lookZ = targetLookZ
end

function Cam.IsOpen()
    return running
end

function Cam.SetHover(on)
    hoverPanel = on and true or false
end

--- @param name string
--- @param instant boolean|nil  snap with no ease (open / retarget)
function Cam.SetPreset(name, instant)
    local p = PRESETS[name]
    if not p then return end
    preset = name
    targetZoom = p.zoom
    targetPitch = p.pitch
    targetLookZ = p.z or 0.12
    if instant or not running then
        snapToTargets()
    end
end

function Cam.Drag(dx, dy)
    if not running then return end
    heading = heading + (tonumber(dx) or 0) * 0.18
    pitch = clamp(pitch + (tonumber(dy) or 0) * 0.12, cfg().MinPitch or -35.0, cfg().MaxPitch or 55.0)
    targetPitch = pitch
end

function Cam.Zoom(delta)
    if not running then return end
    local d = tonumber(delta) or 0
    zoom = clamp(zoom + (d * 0.0018), cfg().MinZoom or 0.45, cfg().MaxZoom or 3.2)
    targetZoom = zoom
end

local function hideHud()
    HideHudAndRadarThisFrame()
    HideHudComponentThisFrame(1)
    HideHudComponentThisFrame(2)
    HideHudComponentThisFrame(3)
    HideHudComponentThisFrame(4)
    HideHudComponentThisFrame(6)
    HideHudComponentThisFrame(7)
    HideHudComponentThisFrame(8)
    HideHudComponentThisFrame(9)
    HideHudComponentThisFrame(13)
    HideHudComponentThisFrame(14)
    HideHudComponentThisFrame(16)
    HideHudComponentThisFrame(17)
    HideHudComponentThisFrame(19)
    HideHudComponentThisFrame(20)
    HideHudComponentThisFrame(21)
    HideHudComponentThisFrame(22)
    DisplayRadar(false)
end

local function updateCam()
    if not cam then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local z = coords.z + lookZ
    local rad = math.rad(heading)
    local dist = zoom
    local pitchRad = math.rad(pitch)
    local cx = coords.x - math.sin(rad) * dist * math.cos(pitchRad)
    local cy = coords.y + math.cos(rad) * dist * math.cos(pitchRad)
    local cz = z + math.sin(pitchRad) * dist * 0.35
    SetCamCoord(cam, cx, cy, cz)
    PointCamAtCoord(cam, coords.x, coords.y, z)
    if cfg().Dof ~= false then
        SetCamUseShallowDofMode(cam, true)
        SetCamNearDof(cam, 0.35)
        SetCamFarDof(cam, math.max(2.2, dist + 1.4))
        SetCamDofStrength(cam, 0.35)
        pcall(SetUseHiDof)
    end
end

function Cam.FlipPed()
    if not running then return end
    local ped = PlayerPedId()
    SetEntityHeading(ped, (GetEntityHeading(ped) + 180.0) % 360.0)
end

function Cam.Retarget()
    if not running then return end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    frozenPed = true
    local pedHeading = GetEntityHeading(ped)
    -- Orbit 0 = in front of ped looking at face (GTA forward uses -sin).
    heading = pedHeading
    updateCam()
end

function Cam.Open()
    if running then
        Cam.Retarget()
        return
    end
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    frozenPed = true
    FreezeEntityPosition(ped, true)
    heading = GetEntityHeading(ped)
    Cam.SetPreset('full', true)
    hoverPanel = false

    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 450, true, true)
    updateCam()
    running = true
    DisplayRadar(false)

    CreateThread(function()
        while running do
            hideHud()
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 45, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 322, true) -- ESC handled via NUI
            DisableControlAction(0, 22, true) -- jump / Space (NUI flip)
            local ped = PlayerPedId()
            if frozenPed then
                FreezeEntityPosition(ped, true)
            end
            local dt = GetFrameTime()
            if dt <= 0.0 then dt = 0.016 end
            local speed = cfg().PresetLerp or 8.0
            zoom = smooth(zoom, targetZoom, dt, speed)
            pitch = smooth(pitch, targetPitch, dt, speed)
            lookZ = smooth(lookZ, targetLookZ, dt, speed)
            updateCam()
            Wait(0)
        end
    end)
end

function Cam.Close()
    running = false
    hoverPanel = false
    if cam then
        RenderScriptCams(false, true, 400, true, true)
        SetCamActive(cam, false)
        DestroyCam(cam, false)
        cam = nil
    end
    DisplayRadar(true)
    if frozenPed then
        frozenPed = false
        FreezeEntityPosition(PlayerPedId(), false)
    end
end
