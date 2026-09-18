Spectating = false
SpectateTarget = nil

local saved = nil

local function restore()
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    if saved then
        SetEntityVisible(ped, saved.visible, false)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, SelfState.freeze or false)
        SetEntityInvincible(ped, SelfState.godmode or false)
        if saved.coords then
            RequestCollisionAtCoord(saved.coords.x, saved.coords.y, saved.coords.z)
            SetEntityCoordsNoOffset(ped, saved.coords.x, saved.coords.y, saved.coords.z, false, false, false)
            SetEntityHeading(ped, saved.heading or 0.0)
        end
    else
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, SelfState.freeze or false)
    end
    saved = nil
end

function StopSpectate()
    if not Spectating then
        restore()
        return
    end
    Spectating = false
    SpectateTarget = nil
    restore()
    Notify(L('spectate_off'), 'info')
end

function StartSpectate(serverId)
    serverId = tonumber(serverId)
    if not serverId then return end
    if Spectating then StopSpectate() end
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then
        Notify(L('invalid_target'), 'error')
        return
    end
    local targetPed = GetPlayerPed(player)
    if not targetPed or targetPed == 0 then
        Notify(L('invalid_target'), 'error')
        return
    end
    local ped = PlayerPedId()
    saved = {
        coords = GetEntityCoords(ped),
        heading = GetEntityHeading(ped),
        visible = IsEntityVisible(ped),
    }
    Spectating = true
    SpectateTarget = serverId
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    NetworkSetInSpectatorMode(true, targetPed)
    Notify(L('spectate_on'), 'success')

    CreateThread(function()
        while Spectating do
            Wait(250)
            local p = GetPlayerFromServerId(SpectateTarget)
            if p == -1 then
                StopSpectate()
                Notify(L('spectate_dropped'), 'info')
                break
            end
            local tped = GetPlayerPed(p)
            if not tped or tped == 0 or not DoesEntityExist(tped) then
                StopSpectate()
                Notify(L('spectate_dropped'), 'info')
                break
            end
            if not NetworkIsInSpectatorMode() then
                NetworkSetInSpectatorMode(true, tped)
            end
        end
    end)
end

RegisterNetEvent('fivex_admin:spectateStart', function(serverId)
    StartSpectate(serverId)
end)

RegisterNetEvent('fivex_admin:spectateStop', function()
    StopSpectate()
end)
