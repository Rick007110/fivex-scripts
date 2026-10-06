Spectating = false
SpectateTarget = nil

local saved = nil
-- Distance below the target the hidden staff ped is parked so OneSync keeps the target in scope.
local PARK_OFFSET = 15.0
local SCOPE_TIMEOUT = 5000

local function parkNear(ped, x, y, z)
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z - PARK_OFFSET, false, false, false)
end

local function hidePed(ped)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
end

local function restoreAppearance()
    local ped = PlayerPedId()
    NetworkSetInSpectatorMode(false, ped)
    if saved then
        if saved.coords then
            RequestCollisionAtCoord(saved.coords.x, saved.coords.y, saved.coords.z)
            SetEntityCoordsNoOffset(ped, saved.coords.x, saved.coords.y, saved.coords.z, false, false, false)
            SetEntityHeading(ped, saved.heading or 0.0)
        end
        SetEntityVisible(ped, saved.visible, false)
    else
        SetEntityVisible(ped, true, false)
    end
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, (SelfState.freeze or SelfState.remoteFreeze) and true or false)
    SetEntityInvincible(ped, SelfState.godmode or false)
    saved = nil
end

function StopSpectate(_dropped)
    if not Spectating then
        if saved then restoreAppearance() end
        return
    end
    Spectating = false
    SpectateTarget = nil
    restoreAppearance()
    Notify(L('spectate_off'), 'info')
end

function StartSpectate(serverId, coords)
    serverId = tonumber(serverId)
    if not serverId then return end
    if Spectating then
        StopSpectate(false)
    end
    local ped = PlayerPedId()
    saved = {
        coords = GetEntityCoords(ped),
        heading = GetEntityHeading(ped),
        visible = IsEntityVisible(ped),
    }
    -- Mark active early so a second start / stop during the scope wait is handled.
    Spectating = true
    SpectateTarget = serverId

    local player = GetPlayerFromServerId(serverId)
    if player == -1 and type(coords) == 'table' and tonumber(coords.x) and tonumber(coords.y) and tonumber(coords.z) then
        -- Target is outside our OneSync scope: move the hidden ped near it and wait for it to stream in.
        hidePed(ped)
        parkNear(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
        local deadline = GetGameTimer() + SCOPE_TIMEOUT
        while player == -1 and GetGameTimer() < deadline do
            Wait(100)
            if not Spectating or SpectateTarget ~= serverId then return end
            player = GetPlayerFromServerId(serverId)
        end
    end

    local targetPed = player ~= -1 and GetPlayerPed(player) or 0
    if player == -1 or not targetPed or targetPed == 0 then
        Spectating = false
        SpectateTarget = nil
        restoreAppearance()
        Notify(L('invalid_target'), 'error')
        return
    end

    hidePed(ped)
    local tc = GetEntityCoords(targetPed)
    parkNear(ped, tc.x, tc.y, tc.z)
    NetworkSetInSpectatorMode(true, targetPed)
    Notify(L('spectate_on'), 'success')

    CreateThread(function()
        while Spectating and SpectateTarget == serverId do
            Wait(250)
            if not Spectating or SpectateTarget ~= serverId then break end
            local p = GetPlayerFromServerId(serverId)
            if p == -1 then
                StopSpectate(true)
                Notify(L('spectate_dropped'), 'info')
                break
            end
            local tped = GetPlayerPed(p)
            if not tped or tped == 0 or not DoesEntityExist(tped) then
                StopSpectate(true)
                Notify(L('spectate_dropped'), 'info')
                break
            end
            -- Keep the hidden ped parked under the target so it stays in scope.
            local me = PlayerPedId()
            local c = GetEntityCoords(tped)
            SetEntityCoordsNoOffset(me, c.x, c.y, c.z - PARK_OFFSET, false, false, false)
            if not NetworkIsInSpectatorMode() then
                NetworkSetInSpectatorMode(true, tped)
            end
        end
    end)
end

RegisterNetEvent('fivex_admin:spectateStart', function(serverId, coords)
    StartSpectate(serverId, coords)
end)

RegisterNetEvent('fivex_admin:spectateStop', function()
    StopSpectate(false)
end)
