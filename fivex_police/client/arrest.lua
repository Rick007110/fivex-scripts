-- Use of force: cops try to arrest first. Non-lethal by default (tasers, surrender, cuffs); lethal
-- only when the suspect escalates (shoots, aims at / hurts a cop, keeps a gun drawn after a warning)
-- or reaches Config.Arrest.lethalWanted stars. Busted -> fine, weapons taken, released at Mission Row.

local A = Config.Arrest
local STUNGUN = joaat('WEAPON_STUNGUN')
local UNARMED = joaat('WEAPON_UNARMED')

local escalated = false     -- lethal until the wanted level clears
local drawnSince = nil      -- suspect holding a gun near cops
local surrendered = false
local surrenderAt = 0
local processing = false    -- busted sequence running
local armed = {}            -- [ped] = 'taser' | 'lethal'
local approachRetask = 0

local function subtitle(text, ms)
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandPrint(ms or 2500, true)
end

local function help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function loadDict(d)
    RequestAnimDict(d)
    local untilT = GetGameTimer() + 3000
    while not HasAnimDictLoaded(d) and GetGameTimer() < untilT do Wait(10) end
    return HasAnimDictLoaded(d)
end

local function escalate(why)
    if escalated then return end
    escalated = true
    Police.debug('lethal force: %s', why)
end

function Police.isLethal()
    return not A.enabled or escalated or Suspect.wanted >= A.lethalWanted
end

-- Cops (controlled by us) near the suspect, nearest first.
local function nearbyCops(radius)
    local me = GetEntityCoords(PlayerPedId())
    local list = {}
    for _, ped in ipairs(GetGamePool('CPed')) do
        if Police.isCop(ped) and NetworkHasControlOfEntity(ped) then
            local d = #(GetEntityCoords(ped) - me)
            if d < radius then list[#list + 1] = { ped = ped, d = d } end
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    return list
end

local function seesMe(ped)
    return HasEntityClearLosToEntity(ped, PlayerPedId(), 17)
end

---------------------------------------------------------------------------
-- Weapons: tasers while non-lethal, their own guns once lethal
---------------------------------------------------------------------------

-- Non-lethal: take every gun away so the AI physically can't fire bullets (it would otherwise pick
-- its pistol whenever the suspect is out of taser range). Lethal: hand guns back.
local function setTaser(ped)
    if armed[ped] == 'taser' then return end
    RemoveAllPedWeapons(ped, true)
    if A.taser then
        GiveWeaponToPed(ped, STUNGUN, 100, false, true)
        SetCurrentPedWeapon(ped, STUNGUN, true)
    end
    SetPedCanSwitchWeapon(ped, false)
    armed[ped] = 'taser'
end

local function setLethal(ped)
    if armed[ped] == 'lethal' then return end
    SetPedCanSwitchWeapon(ped, true)
    for i, name in ipairs(A.lethalWeapons) do
        local w = joaat(name)
        -- first weapon for everyone, the rest for some officers
        if i == 1 or math.random() < A.longGunChance then
            GiveWeaponToPed(ped, w, 250, false, i == 1)
        end
    end
    SetCurrentPedWeapon(ped, joaat(A.lethalWeapons[1]), true)
    armed[ped] = 'lethal'
end

---------------------------------------------------------------------------
-- Busted
---------------------------------------------------------------------------

local function endSurrender()
    surrendered = false
    SetPoliceIgnorePlayer(PlayerId(), false)
    ClearPedTasks(PlayerPedId())
end

local function busted(cop)
    if processing then return end
    processing = true
    local me = PlayerPedId()
    local stars = math.max(1, Suspect.wanted)
    SetPoliceIgnorePlayer(PlayerId(), true) -- nobody shoots during processing

    -- paired cuffing animation when we control the officer
    if cop and DoesEntityExist(cop) and NetworkHasControlOfEntity(cop) and loadDict('mp_arrest_paired') then
        ClearPedTasksImmediately(me)
        local behind = GetOffsetFromEntityInWorldCoords(me, 0.0, -0.9, 0.0)
        ClearPedTasksImmediately(cop)
        SetEntityCoords(cop, behind.x, behind.y, behind.z - 1.0, false, false, false, false)
        SetEntityHeading(cop, GetEntityHeading(me))
        TaskPlayAnim(cop, 'mp_arrest_paired', 'cop_p2_back_right', 8.0, -8.0, 3500, 33, 0.0, false, false, false)
        TaskPlayAnim(me, 'mp_arrest_paired', 'crook_p2_back_right', 8.0, -8.0, 3500, 33, 0.0, false, false, false)
        subtitle('~b~Police:~s~ You are under arrest.', 3000)
        Wait(3600)
    else
        subtitle('~b~Police:~s~ You are under arrest.', 2000)
        Wait(1500)
    end

    DoScreenFadeOut(800)
    while not IsScreenFadedOut() do Wait(0) end
    ClearPedTasksImmediately(me)
    if A.removeWeapons then RemoveAllPedWeapons(me, true) end
    ClearPlayerWantedLevel(PlayerId())
    SetPlayerWantedLevelNow(PlayerId(), false)
    local r = A.release
    RequestCollisionAtCoord(r.x, r.y, r.z)
    SetEntityCoords(me, r.x, r.y, r.z, false, false, false, false)
    SetEntityHeading(me, r.w)
    TriggerServerEvent('fivex_police:busted', stars)
    Wait(800)
    SetPoliceIgnorePlayer(PlayerId(), false)
    surrendered = false
    escalated = false
    drawnSince = nil
    DoScreenFadeIn(800)
    processing = false
end

RegisterNetEvent('fivex_police:fined', function(amount, wanted)
    local msg = amount > 0 and ('~r~Busted.~s~ Fined ~g~$%s~s~ for a %d-star offence.'):format(amount, wanted)
        or ('~r~Busted.~s~ You could not pay the fine.')
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end)

---------------------------------------------------------------------------
-- Surrender (hands up)
---------------------------------------------------------------------------

local function surrender()
    if surrendered or processing or Suspect.wanted == 0 or Police.isLethal() and Police.recentlyShooting() then return end
    local me = PlayerPedId()
    if IsPedInAnyVehicle(me, false) then return subtitle('Get out of the vehicle first.') end
    surrendered = true
    surrenderAt = GetGameTimer()
    SetCurrentPedWeapon(me, UNARMED, true)
    SetPoliceIgnorePlayer(PlayerId(), true) -- cops hold fire while you comply
    if loadDict('random@arrests@busted') then
        TaskPlayAnim(me, 'random@arrests@busted', 'idle_a', 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end
    subtitle('~b~Police:~s~ Stay where you are! Hands where we can see them!', 3000)
end

RegisterCommand('police_surrender', function()
    if surrendered then return end -- once you surrender you're processed
    surrender()
end, false)
RegisterKeyMapping('police_surrender', 'Surrender to police (hands up)', 'keyboard', Config.SurrenderKey)

---------------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------------

CreateThread(function()
    while true do
        if not A.enabled or Suspect.wanted == 0 then
            if escalated or surrendered or next(armed) then
                escalated, drawnSince = false, nil
                if surrendered then endSurrender() end
                for ped in pairs(armed) do
                    if DoesEntityExist(ped) then SetPedCanSwitchWeapon(ped, true) end
                end
                armed = {}
            end
            Wait(1000)
        elseif processing then
            Wait(250)
        else
            local me = PlayerPedId()
            local pid = PlayerId()
            local cops = nearbyCops(Config.Cops.scanRadius)

            -- escalation triggers
            if Police.recentlyShooting() then escalate('suspect fired') end
            if IsPlayerFreeAiming(pid) then
                local ok, ent = GetEntityPlayerIsFreeAimingAt(pid)
                if ok and Police.isCop(ent) then escalate('aimed at an officer') end
            end
            for _, c in ipairs(cops) do
                if HasEntityBeenDamagedByEntity(c.ped, me, true) then
                    -- bumping / ramming with a car is not an assault with a weapon
                    local byCar = HasPedBeenDamagedByWeapon(c.ped, joaat('WEAPON_RUN_OVER_BY_CAR'), 0)
                        or HasPedBeenDamagedByWeapon(c.ped, joaat('WEAPON_RAMMED_BY_CAR'), 0)
                    if not byCar then escalate('hurt an officer') end
                    ClearEntityLastDamageEntity(c.ped)
                    ClearPedLastWeaponDamage(c.ped)
                end
            end
            local nearSeen = false
            for _, c in ipairs(cops) do
                if c.d < A.warnDistance and seesMe(c.ped) then nearSeen = true break end
            end
            local holdingGun = IsPedArmed(me, 4 | 2) and GetSelectedPedWeapon(me) ~= UNARMED
            if holdingGun and nearSeen and not escalated then
                drawnSince = drawnSince or GetGameTimer()
                subtitle('~b~Police:~s~ Drop your weapon! Drop it now!', 1000)
                if GetGameTimer() - drawnSince > A.drawGrace * 1000 then escalate('kept a weapon drawn') end
            else
                drawnSince = nil
            end

            local lethal = Police.isLethal()
            for _, c in ipairs(cops) do
                if not Entity(c.ped).state.fivexSwat then
                    if lethal then setLethal(c.ped) elseif A.taser then setTaser(c.ped) end
                end
            end

            if surrendered then
                DisableControlAction(0, 30, true) -- move
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 21, true) -- sprint
                DisableControlAction(0, 22, true) -- jump
                DisableControlAction(0, 24, true) -- attack
                DisableControlAction(0, 25, true) -- aim
                local nearest = cops[1]
                if nearest and nearest.d <= A.cuffDistance then
                    busted(nearest.ped)
                elseif nearest then
                    if GetGameTimer() >= approachRetask then -- (re)send the nearest officer to cuff you
                        approachRetask = GetGameTimer() + 3000
                        ClearPedTasks(nearest.ped)
                        TaskGoToEntity(nearest.ped, me, -1, A.cuffDistance - 0.4, 1.4, 0, 0)
                    end
                    if GetGameTimer() - surrenderAt > A.surrenderTimeout * 1000 then busted(nil) end
                elseif GetGameTimer() - surrenderAt > A.surrenderTimeout * 1000 then
                    busted(nil)
                end
                Wait(0)
            else
                -- tased / knocked down near an officer while it's still an arrest
                if not lethal then
                    local down = IsPedBeingStunned(me, 0) or IsPedRagdoll(me)
                    local nearest = cops[1]
                    if down and nearest and nearest.d < A.stunArrestDistance then busted(nearest.ped) end
                end
                -- offer surrender when cops are close and it isn't a firefight
                if nearSeen and not Police.recentlyShooting() and not IsPedInAnyVehicle(me, false) then
                    help(('Press ~b~%s~s~ to surrender'):format(Config.SurrenderKey))
                end
                Wait(lethal and 300 or 100)
            end
        end
        for ped in pairs(armed) do if not DoesEntityExist(ped) then armed[ped] = nil end end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetPoliceIgnorePlayer(PlayerId(), false)
    for ped in pairs(armed) do
        if DoesEntityExist(ped) then SetPedCanSwitchWeapon(ped, true) end
    end
end)
