SelfState = {
    godmode = false,
    invis = false,
    superjump = false,
    fastrun = false,
    infstamina = false,
    infoxygen = false,
    wantedOff = false,
    freeze = false,
    remoteFreeze = false,
    infammo = false,
    noreload = false,
    norecoil = false,
    vehgod = false,
    drift = false,
    vehfreeze = false,
    names = false,
    blips = false,
    ids = false,
    dev = false,
}


local function flag(v)
    return v and true or false
end

function CollectToggleState()
    return {
        ['self.noclip'] = flag(NoclipActive),
        ['self.godmode'] = flag(SelfState.godmode),
        ['self.invisibility'] = flag(SelfState.invis),
        ['self.superjump'] = flag(SelfState.superjump),
        ['self.fastrun'] = flag(SelfState.fastrun),
        ['self.infstamina'] = flag(SelfState.infstamina),
        ['self.infoxygen'] = flag(SelfState.infoxygen),
        ['self.wanted.disable'] = flag(SelfState.wantedOff),
        ['self.freeze'] = flag(SelfState.freeze),
        ['self.overlay.names'] = flag(SelfState.names),
        ['self.overlay.blips'] = flag(SelfState.blips),
        ['self.overlay.ids'] = flag(SelfState.ids),
        ['veh.godmode'] = flag(SelfState.vehgod),
        ['veh.freeze'] = flag(SelfState.vehfreeze),
        ['veh.drift'] = flag(SelfState.drift),
        ['weap.infammo'] = flag(SelfState.infammo),
        ['weap.noreload'] = flag(SelfState.noreload),
        ['weap.norecoil'] = flag(SelfState.norecoil),
        ['world.freezeTime'] = flag(WorldState and WorldState.freeze),
        ['world.blackout'] = flag(WorldState and WorldState.blackout),
        ['dev.overlay'] = flag(SelfState.dev),
    }
end

function PushToggleState()
    SendNUIMessage({
        type = 'toggles',
        toggles = CollectToggleState(),
    })
end

local SELF_TOGGLES = {
    ['self.noclip'] = true,
    ['self.godmode'] = true,
    ['self.invisibility'] = true,
    ['self.superjump'] = true,
    ['self.fastrun'] = true,
    ['self.infstamina'] = true,
    ['self.infoxygen'] = true,
    ['self.wanted.disable'] = true,
    ['self.freeze'] = true,
    ['self.overlay.names'] = true,
    ['self.overlay.blips'] = true,
    ['self.overlay.ids'] = true,
    ['dev.overlay'] = true,
}

function RestoreSelfDefaults()
    local ped = PlayerPedId()
    local pid = PlayerId()
    SelfState.godmode = false
    SelfState.invis = false
    SelfState.superjump = false
    SelfState.fastrun = false
    SelfState.infstamina = false
    SelfState.infoxygen = false
    SelfState.wantedOff = false
    SelfState.freeze = false
    SelfState.infammo = false
    SelfState.noreload = false
    SelfState.norecoil = false
    SelfState.vehgod = false
    SelfState.drift = false
    SelfState.vehfreeze = false
    SetEntityInvincible(ped, false)
    SetPlayerInvincible(pid, false)
    SetEntityCanBeDamaged(ped, true)
    SetEntityProofs(ped, false, false, false, false, false, false, false, false)
    SetPedCanRagdoll(ped, true)
    SetPedDiesInWater(ped, true)
    ResetEntityAlpha(ped)
    SetEntityVisible(ped, true, false)
    SetLocalPlayerVisibleLocally(true)
    NetworkSetEntityInvisibleToNetwork(ped, false)
    SetRunSprintMultiplierForPlayer(pid, 1.0)
    SetSwimMultiplierForPlayer(pid, 1.0)
    SetMaxWantedLevel(5)
    SetPedInfiniteAmmo(ped, false, 0)
    SetPedInfiniteAmmoClip(ped, false)
    FreezeEntityPosition(ped, false)
end

local function applyGod(ped, pid, on)
    SetEntityInvincible(ped, on)
    SetPlayerInvincible(pid, on)
    SetEntityCanBeDamaged(ped, not on)
    SetEntityProofs(ped, on, on, on, on, on, on, on, on)
    SetPedCanRagdoll(ped, not on)
end

local function applyInvis(ped, on)
    SetEntityVisible(ped, not on, false)
    SetLocalPlayerVisibleLocally(true)
    NetworkSetEntityInvisibleToNetwork(ped, on)
    SetEntityAlpha(ped, on and 120 or 255, false)
    if not on then ResetEntityAlpha(ped) end
end

RegisterNetEvent('fivex_admin:applySelf', function(actionId, payload)
    payload = payload or {}
    local ped = PlayerPedId()
    local pid = PlayerId()

    if actionId == 'self.noclip' then
        ToggleNoclip()
    elseif actionId == 'self.godmode' then
        SelfState.godmode = not SelfState.godmode
        applyGod(ped, pid, SelfState.godmode)
        Notify(SelfState.godmode and L('godmode_on') or L('godmode_off'), 'info')
    elseif actionId == 'self.invisibility' then
        SelfState.invis = not SelfState.invis
        applyInvis(ped, SelfState.invis)
    elseif actionId == 'self.superjump' then
        SelfState.superjump = not SelfState.superjump
    elseif actionId == 'self.fastrun' then
        SelfState.fastrun = not SelfState.fastrun
        SetRunSprintMultiplierForPlayer(pid, SelfState.fastrun and 1.49 or 1.0)
    elseif actionId == 'self.infstamina' then
        SelfState.infstamina = not SelfState.infstamina
    elseif actionId == 'self.infoxygen' then
        SelfState.infoxygen = not SelfState.infoxygen
        SetPedDiesInWater(ped, not SelfState.infoxygen)
    elseif actionId == 'self.heal' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
    elseif actionId == 'self.armor' then
        SetPedArmour(ped, 100)
    elseif actionId == 'self.revive' then
        ReviveLocalPed()
    elseif actionId == 'self.wanted' then
        local lvl = tonumber(payload.level) or 0
        if lvl < 0 then lvl = 0 end
        if lvl > 5 then lvl = 5 end
        SelfState.wantedOff = false
        SetMaxWantedLevel(5)
        SetPlayerWantedLevel(pid, lvl, false)
        SetPlayerWantedLevelNow(pid, false)
    elseif actionId == 'self.wanted.disable' then
        SelfState.wantedOff = not SelfState.wantedOff
        if SelfState.wantedOff then
            ClearPlayerWantedLevel(pid)
            SetMaxWantedLevel(0)
        else
            SetMaxWantedLevel(5)
        end
    elseif actionId == 'self.ragdoll' then
        SetPedToRagdoll(ped, 4000, 4000, 0, false, false, false)
    elseif actionId == 'self.freeze' then
        SelfState.freeze = not SelfState.freeze
        FreezeEntityPosition(ped, SelfState.freeze or SelfState.remoteFreeze)
    elseif actionId == 'self.overlay.names' then
        SelfState.names = not SelfState.names
        RefreshOverlays()
    elseif actionId == 'self.overlay.blips' then
        SelfState.blips = not SelfState.blips
        RefreshOverlays()
    elseif actionId == 'self.overlay.ids' then
        SelfState.ids = not SelfState.ids
        RefreshOverlays()
    elseif actionId == 'self.copy.vector3' then
        local c = GetEntityCoords(ped)
        SendNUIMessage({ type = 'clipboard', text = ('vector3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z) })
        Notify(L('copied'), 'success')
    elseif actionId == 'self.copy.vector4' then
        local c = GetEntityCoords(ped)
        local h = GetEntityHeading(ped)
        SendNUIMessage({ type = 'clipboard', text = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(c.x, c.y, c.z, h) })
        Notify(L('copied'), 'success')
    elseif actionId == 'self.copy.heading' then
        SendNUIMessage({ type = 'clipboard', text = ('%.2f'):format(GetEntityHeading(ped)) })
        Notify(L('copied'), 'success')
    elseif actionId == 'self.clear.blood' then
        ClearPedBloodDamage(ped)
        ResetPedVisibleDamage(ped)
        ClearPedLastWeaponDamage(ped)
    elseif actionId == 'self.clear.wetness' then
        ClearPedWetness(ped)
        ClearPedEnvDirt(ped)
    elseif actionId == 'dev.overlay' then
        SelfState.dev = not SelfState.dev
        RefreshOverlays()
    elseif actionId == 'dev.copyVehHash' then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then
            Notify(L('no_vehicle'), 'error')
            return
        end
        local model = GetEntityModel(veh)
        SendNUIMessage({ type = 'clipboard', text = ('%s (%d)'):format(GetDisplayNameFromVehicleModel(model), model) })
        Notify(L('copied'), 'success')
    elseif actionId == 'dev.copyWeapHash' then
        local _, weap = GetCurrentPedWeapon(ped, true)
        SendNUIMessage({ type = 'clipboard', text = tostring(weap) })
        Notify(L('copied'), 'success')
    end

    if SELF_TOGGLES[actionId] or actionId == 'self.wanted' then
        PushToggleState()
    end
end)

CreateThread(function()
    while true do
        local busy = SelfState.godmode or SelfState.superjump or SelfState.infstamina
            or SelfState.infoxygen or SelfState.wantedOff or SelfState.norecoil
            or SelfState.invis or SelfState.vehgod or SelfState.infammo or SelfState.noreload
        if not busy then
            Wait(400)
        else
            Wait(0)
            local ped = PlayerPedId()
            local pid = PlayerId()
            if SelfState.godmode then
                applyGod(ped, pid, true)
            end
            if SelfState.invis then
                applyInvis(ped, true)
            end
            if SelfState.superjump then
                SetSuperJumpThisFrame(pid)
            end
            if SelfState.infstamina then
                RestorePlayerStamina(pid, 1.0)
            end
            if SelfState.infoxygen then
                ResetPlayerStamina(pid)
                SetPedDiesInWater(ped, false)
            end
            if SelfState.wantedOff then
                ClearPlayerWantedLevel(pid)
                SetMaxWantedLevel(0)
            end
            if SelfState.vehgod then
                local veh = GetVehiclePedIsIn(ped, false)
                if veh ~= 0 then
                    SetEntityInvincible(veh, true)
                    SetVehicleCanBeVisiblyDamaged(veh, false)
                    SetVehicleTyresCanBurst(veh, false)
                    SetVehicleEngineCanDegrade(veh, false)
                    SetVehicleExplodesOnHighExplosionDamage(veh, false)
                end
            end
            if SelfState.infammo then
                SetPedInfiniteAmmoClip(ped, true)
                local _, weap = GetCurrentPedWeapon(ped, true)
                if weap and weap ~= `WEAPON_UNARMED` then
                    SetPedInfiniteAmmo(ped, true, weap)
                    local ok, ammo = GetMaxAmmo(ped, weap)
                    if ok and type(ammo) == 'number' then SetPedAmmo(ped, weap, ammo) else SetPedAmmo(ped, weap, 250) end
                end
            end
            if SelfState.noreload then
                local _, weap = GetCurrentPedWeapon(ped, true)
                if weap and weap ~= `WEAPON_UNARMED` then
                    SetPedInfiniteAmmoClip(ped, true)
                    local clip = GetMaxAmmoInClip(ped, weap, true)
                    SetAmmoInClip(ped, weap, clip)
                end
            end
            if SelfState.norecoil then
                StopGameplayCamShaking(true)
                SetGameplayCamShakeAmplitude(0.0)
            end
        end
    end
end)

RegisterNetEvent('fivex_admin:applyTeleport', function(kind, payload)
    payload = payload or {}
    if kind == 'waypoint' then
        local blip = GetFirstBlipInfoId(8)
        if not DoesBlipExist(blip) then
            Notify(L('no_waypoint'), 'error')
            return
        end
        local c = GetBlipInfoIdCoord(blip)
        local x, y = c.x, c.y
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local ent = (veh ~= 0) and veh or ped
        -- Probe downwards from high altitude, letting collision stream in at each step.
        FreezeEntityPosition(ent, true)
        local z, found = 0.0, false
        for h = 1000.0, 0.0, -25.0 do
            SetEntityCoordsNoOffset(ent, x, y, h, false, false, false)
            RequestCollisionAtCoord(x, y, h)
            Wait(0)
            local ok, gz = GetGroundZFor_3dCoord(x, y, h, false)
            if ok then
                z = gz
                found = true
                break
            end
        end
        SetEntityCoordsNoOffset(ent, x, y, (found and z or 200.0) + 1.0, false, false, false)
        local keepFrozen
        if NoclipActive then
            keepFrozen = true
        elseif ent == ped then
            keepFrozen = SelfState.freeze or SelfState.remoteFreeze
        else
            keepFrozen = SelfState.vehfreeze
        end
        FreezeEntityPosition(ent, keepFrozen and true or false)
    elseif kind == 'coords' then
        TeleportTo(payload.x, payload.y, payload.z, payload.w)
    elseif kind == 'save' then
        SaveCurrentLocation(payload.name)
        Notify(L('saved'), 'success')
        if MenuOpen then
            SendNUIMessage({ type = 'savedLocations', locations = LoadSavedLocations() })
        end
    elseif kind == 'saved' then
        local loc = FindSavedLocation(payload.id)
        if loc then
            TeleportTo(loc.x, loc.y, loc.z, loc.w)
        end
    elseif kind == 'savedDelete' then
        DeleteSavedLocation(payload.id)
        Notify(L('deleted'), 'success')
        if MenuOpen then
            SendNUIMessage({ type = 'savedLocations', locations = LoadSavedLocations() })
        end
    end
end)

local LOC_KVP = 'fivex_admin:savedLocations'

local function readLocs()
    local raw = GetResourceKvpString(LOC_KVP)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return {}
end

local function writeLocs(list)
    SetResourceKvp(LOC_KVP, json.encode(list))
end

function LoadSavedLocations()
    return readLocs()
end

function SaveCurrentLocation(name)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local list = readLocs()
    list[#list + 1] = {
        id = tostring(GetGameTimer()) .. '-' .. tostring(math.random(1000, 9999)),
        name = name or 'Saved',
        x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped),
    }
    writeLocs(list)
end

function FindSavedLocation(id)
    local list = readLocs()
    for i = 1, #list do
        if list[i].id == id then return list[i] end
    end
    return nil
end

function DeleteSavedLocation(id)
    local list = readLocs()
    for i = 1, #list do
        if list[i].id == id then
            table.remove(list, i)
            writeLocs(list)
            return
        end
    end
end
