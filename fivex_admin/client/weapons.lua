local function giveWeapon(name)
    local hash = joaat(name)
    if not IsWeaponValid(hash) then
        Notify(L('invalid_weapon'), 'error')
        return
    end
    local ped = PlayerPedId()
    GiveWeaponToPed(ped, hash, 250, false, true)
    SetPedAmmo(ped, hash, 250)
end

RegisterNetEvent('fivex_admin:applyWeapon', function(actionId, payload)
    payload = payload or {}
    local ped = PlayerPedId()

    if actionId == 'weap.give' then
        if type(payload.weapon) ~= 'string' or not FindWeaponInCatalog(payload.weapon) then
            Notify(L('invalid_weapon'), 'error')
            return
        end
        if not IsWeaponValid(joaat(payload.weapon)) then
            Notify(L('invalid_weapon'), 'error')
            return
        end
        giveWeapon(payload.weapon)
    elseif actionId == 'weap.giveAll' then
        for i = 1, #WeaponCatalog do
            local name = WeaponCatalog[i].name
            local hash = joaat(name)
            if IsWeaponValid(hash) then
                GiveWeaponToPed(ped, hash, 250, false, false)
            end
        end
    elseif actionId == 'weap.removeAll' then
        RemoveAllPedWeapons(ped, true)
    elseif actionId == 'weap.refill' then
        local _, weap = GetCurrentPedWeapon(ped, true)
        if weap and weap ~= `WEAPON_UNARMED` then
            SetPedAmmo(ped, weap, 250)
            SetAmmoInClip(ped, weap, GetMaxAmmoInClip(ped, weap, true))
        else
            for i = 1, #WeaponCatalog do
                local hash = joaat(WeaponCatalog[i].name)
                if HasPedGotWeapon(ped, hash, false) then
                    SetPedAmmo(ped, hash, 250)
                end
            end
        end
    elseif actionId == 'weap.infammo' then
        SelfState.infammo = not SelfState.infammo
        SetPedInfiniteAmmo(ped, SelfState.infammo, 0)
        SetPedInfiniteAmmoClip(ped, SelfState.infammo)
        PushToggleState()
    elseif actionId == 'weap.noreload' then
        SelfState.noreload = not SelfState.noreload
        SetPedInfiniteAmmoClip(ped, SelfState.noreload)
        PushToggleState()
    elseif actionId == 'weap.norecoil' then
        SelfState.norecoil = not SelfState.norecoil
        PushToggleState()
    elseif actionId == 'weap.maxclip' then
        local _, weap = GetCurrentPedWeapon(ped, true)
        if weap and weap ~= `WEAPON_UNARMED` then
            local maxClip = GetMaxAmmoInClip(ped, weap, true)
            SetAmmoInClip(ped, weap, maxClip)
        end
    end
end)
