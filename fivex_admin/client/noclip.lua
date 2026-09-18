NoclipActive = false

local speed = nil
local entity = nil

local function rotToDir(rot)
    local z = math.rad(rot.z)
    local x = math.rad(rot.x)
    local num = math.abs(math.cos(x))
    return vector3(-math.sin(z) * num, math.cos(z) * num, math.sin(x))
end

local function restore(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    SetEntityCollision(ent, true, true)
    FreezeEntityPosition(ent, false)
    SetEntityInvincible(ent, SelfState.godmode or false)
    SetEntityAlpha(ent, 255, false)
    ResetEntityAlpha(ent)
end

local function attach(ent)
    entity = ent
    SetEntityCollision(ent, false, false)
    FreezeEntityPosition(ent, true)
    SetEntityAlpha(ent, 180, false)
end

function StopNoclip()
    NoclipActive = false
    restore(entity)
    entity = nil
end

function StartNoclip()
    if NoclipActive then return end
    NoclipActive = true
    speed = Config.Noclip.BaseSpeed
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    attach((veh ~= 0) and veh or ped)

    CreateThread(function()
        while NoclipActive do
            Wait(0)
            ped = PlayerPedId()
            veh = GetVehiclePedIsIn(ped, false)
            local ent = (veh ~= 0) and veh or ped
            if ent ~= entity then
                restore(entity)
                attach(ent)
            end

            local camRot = GetGameplayCamRot(2)
            local fwd = rotToDir(camRot)
            local right = vector3(-fwd.y, fwd.x, 0.0)

            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)
            DisableControlAction(0, 266, true)
            DisableControlAction(0, 267, true)
            DisableControlAction(0, 268, true)
            DisableControlAction(0, 269, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 20, true)
            DisableControlAction(0, 75, true)
            DisableControlAction(0, 23, true)

            if IsDisabledControlJustPressed(0, 15) or IsControlJustPressed(0, 15) or IsControlJustPressed(0, 241) then
                speed = math.min(Config.Noclip.MaxSpeed, speed + Config.Noclip.SpeedStep)
            elseif IsDisabledControlJustPressed(0, 14) or IsControlJustPressed(0, 14) or IsControlJustPressed(0, 242) then
                speed = math.max(Config.Noclip.MinSpeed, speed - Config.Noclip.SpeedStep)
            end

            local mul = speed
            if IsControlPressed(0, 21) then
                mul = mul * Config.Noclip.FastMult
            elseif IsControlPressed(0, 36) then
                mul = mul * Config.Noclip.SlowMult
            end

            local move = vector3(0.0, 0.0, 0.0)
            if IsControlPressed(0, 32) or IsDisabledControlPressed(0, 32) then
                move = move + fwd
            end
            if IsControlPressed(0, 33) or IsDisabledControlPressed(0, 33) then
                move = move - fwd
            end
            if IsControlPressed(0, 34) or IsDisabledControlPressed(0, 34) then
                move = move - right
            end
            if IsControlPressed(0, 35) or IsDisabledControlPressed(0, 35) then
                move = move + right
            end
            if IsControlPressed(0, 22) then
                move = move + vector3(0.0, 0.0, 1.0)
            end
            if IsControlPressed(0, 44) or IsDisabledControlPressed(0, 44) then
                move = move - vector3(0.0, 0.0, 1.0)
            end

            local mag = #move
            local pos = GetEntityCoords(ent, true)
            if mag > 0.001 then
                move = (move / mag) * mul
                SetEntityCoordsNoOffset(ent, pos.x + move.x, pos.y + move.y, pos.z + move.z, true, true, true)
            else
                SetEntityCoordsNoOffset(ent, pos.x, pos.y, pos.z, true, true, true)
            end
            SetEntityHeading(ent, camRot.z)
            SetEntityVelocity(ent, 0.0, 0.0, 0.0)
            SetEntityRotation(ent, 0.0, 0.0, camRot.z, 2, true)
        end
        restore(entity)
        entity = nil
    end)
end

function ToggleNoclip()
    if NoclipActive then
        StopNoclip()
        Notify(L('noclip_off'), 'info')
    else
        StartNoclip()
        Notify(L('noclip_on'), 'success')
    end
    if PushToggleState then
        PushToggleState()
    end
end
