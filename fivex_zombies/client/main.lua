--[[
  fivex_zombies — client (2.0.0)
  Reacts only to server state (setActive / GlobalState). Cannot force start.
  Threads: alarm | director (wanderers + hordes) | brain (AI of the zombies this client owns)
           | noise (own player) | infection | hud | street density
]]

local active = false
local graceUntil = 0
local alarmUntil = 0
local relationshipReady = false
local zombieGroupHash = 0
local densityPulseUntil = 0
local nextHordeAt = 0

--- converted ambient peds we restore/delete on stop
local converted = {}
local convertedCount = 0

--- spawned mission peds we delete on stop
local spawned = {}
local spawnedCount = 0
--- dead bodies: ped -> GameTimer when DeleteEntity is allowed
local corpses = {}
local spawnReqSeq = 0
local spawnResults = {}

--- AI of zombies this client owns: [ped] = { variant, state = 'idle'|'hunt', target, ... }
local brains = {}

--- player infection
local infectHits = 0
local lastHitAt = 0
local playerInfected = false

--- outbreak stats for the HUD
local kills = 0
local killed = {}

local DECOR_NAME = 'fivex_zombie'
local decorRegistered = false

local SENSES = Config.Senses or {}
local VARIANTS = Config.Variants or { walker = { weight = 1, health = 200 } }
local TASK_GOTO = `SCRIPT_TASK_GO_TO_ENTITY`
local TASK_COMBAT = `SCRIPT_TASK_COMBAT`
local TASK_WANDER = `SCRIPT_TASK_WANDER_STANDARD`
local MELEE_RANGE = 2.6

local function L(key, ...)
    local lang = Config.Locale or 'en'
    local pack = Locales and Locales[lang] or Locales and Locales['en'] or {}
    local str = pack[key] or key
    if select('#', ...) > 0 then
        return string.format(str, ...)
    end
    return str
end

local function dbg(...)
    if Config.Debug then
        print('[fivex_zombies]', ...)
    end
end

--- Always-on failure breadcrumbs (CreatePed / model)
local function dbgFail(...)
    print('[fivex_zombies]', ...)
end

local function rand(a, b)
    return a + math.random() * (b - a)
end

local function ensureDecor()
    if decorRegistered then return end
    DecorRegister(DECOR_NAME, 2) -- bool
    decorRegistered = true
end

local function isMarkedZombie(ped)
    if not DoesEntityExist(ped) then return false end
    if DecorExistOn(ped, DECOR_NAME) and DecorGetBool(ped, DECOR_NAME) then
        return true
    end
    local bag = Entity(ped).state
    if bag and bag.fivex_zombie then return true end
    return false
end

local function markZombie(ped)
    ensureDecor()
    DecorSetBool(ped, DECOR_NAME, true)
    pcall(function()
        local replicated = NetworkGetEntityIsNetworked(ped)
        Entity(ped).state:set('fivex_zombie', true, replicated and true or false)
    end)
end

local function variantOf(ped)
    local b = brains[ped]
    if b then return b.variant end
    local v = Entity(ped).state.fivex_zvar
    if type(v) == 'string' and VARIANTS[v] then return v end
    return 'walker'
end

local function isNight()
    local h = GetClockHours()
    local from, to = Config.NightHours and Config.NightHours[1] or 21, Config.NightHours and Config.NightHours[2] or 5
    if from > to then return h >= from or h <= to end
    return h >= from and h <= to
end

--- weighted pick from { name = weight }; stalkers only at night
local function pickVariant(weights)
    local night = isNight()
    local total, pool = 0, {}
    for name, w in pairs(weights) do
        local def = VARIANTS[name]
        if def and (not def.nightOnly or night) and (tonumber(w) or 0) > 0 then
            total = total + w
            pool[#pool + 1] = { name, total }
        end
    end
    if total <= 0 then return 'walker' end
    table.sort(pool, function(a, b) return a[2] < b[2] end)
    local r = math.random() * total
    for i = 1, #pool do
        if r <= pool[i][2] then return pool[i][1] end
    end
    return pool[#pool][1]
end

local function baseWeights()
    local w = {}
    for name, def in pairs(VARIANTS) do w[name] = def.weight or 0 end
    return w
end

local function ensureRelationship()
    if relationshipReady then return end
    local name = Config.RelationshipGroup or 'FIVEX_ZOMBIE'
    AddRelationshipGroup(name)
    zombieGroupHash = GetHashKey(name)

    SetRelationshipBetweenGroups(5, zombieGroupHash, GetHashKey('PLAYER'))
    SetRelationshipBetweenGroups(5, GetHashKey('PLAYER'), zombieGroupHash)
    SetRelationshipBetweenGroups(5, zombieGroupHash, GetHashKey('CIVMALE'))
    SetRelationshipBetweenGroups(5, GetHashKey('CIVMALE'), zombieGroupHash)
    SetRelationshipBetweenGroups(5, zombieGroupHash, GetHashKey('CIVFEMALE'))
    SetRelationshipBetweenGroups(5, GetHashKey('CIVFEMALE'), zombieGroupHash)
    SetRelationshipBetweenGroups(1, zombieGroupHash, zombieGroupHash)

    relationshipReady = true
end

--- Clear zombie↔CIV hostility so ambient recycle isn't stuck hostile after stop
local function clearCivHostility()
    if zombieGroupHash == 0 then return end
    SetRelationshipBetweenGroups(3, zombieGroupHash, GetHashKey('CIVMALE'))
    SetRelationshipBetweenGroups(3, GetHashKey('CIVMALE'), zombieGroupHash)
    SetRelationshipBetweenGroups(3, zombieGroupHash, GetHashKey('CIVFEMALE'))
    SetRelationshipBetweenGroups(3, GetHashKey('CIVFEMALE'), zombieGroupHash)
    SetRelationshipBetweenGroups(3, zombieGroupHash, GetHashKey('PLAYER'))
    SetRelationshipBetweenGroups(3, GetHashKey('PLAYER'), zombieGroupHash)
    relationshipReady = false
end

local function requestClipset(name)
    if not name or name == '' then return false end
    if HasAnimSetLoaded(name) then return true end
    RequestAnimSet(name)
    local timeout = GetGameTimer() + 2000
    while not HasAnimSetLoaded(name) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimSetLoaded(name)
end

local function applyClipset(ped, list)
    list = list or Config.ZombieClipsets or { 'move_m@injured' }
    for i = 1, #list do
        if requestClipset(list[i]) then
            SetPedMovementClipset(ped, list[i], 1.0)
            return list[i]
        end
    end
    return nil
end

local function ensureNetworkControl(ped, timeoutMs)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    if not NetworkGetEntityIsNetworked(ped) then return true end
    if NetworkHasControlOfEntity(ped) then return true end
    local deadline = GetGameTimer() + (timeoutMs or 400)
    NetworkRequestControlOfEntity(ped)
    while not NetworkHasControlOfEntity(ped) and GetGameTimer() < deadline do
        Wait(0)
        NetworkRequestControlOfEntity(ped)
    end
    return NetworkHasControlOfEntity(ped)
end

local function ownsPed(ped)
    if not NetworkGetEntityIsNetworked(ped) then return true end
    return NetworkGetEntityOwner(ped) == PlayerId()
end

--- Behaviour every owner re-applies (cheap; also after the ped migrates to us)
local function adoptZombie(ped, variant)
    ensureRelationship()
    SetPedRelationshipGroupHash(ped, zombieGroupHash)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)  -- BF_CanFightArmedPedsWhenNotArmed
    SetPedCombatAttributes(ped, 5, true)   -- BF_AlwaysFight
    SetPedCombatAttributes(ped, 0, false)  -- BF_CanUseCover off
    SetPedCombatAbility(ped, 2)
    SetPedCombatRange(ped, 0)
    SetPedCombatMovement(ped, 3)           -- suicidal: straight at you
    SetPedSuffersCriticalHits(ped, true)   -- headshots kill
    SetPedConfigFlag(ped, 281, true)       -- no writhe on the ground
    SetPedDiesWhenInjured(ped, true)
    SetPedCanRagdoll(ped, true)
    SetPedRagdollOnCollision(ped, false)
    -- DO NOT SetPedConfigFlag(ped, 224, true) — disables melee
    applyClipset(ped, (VARIANTS[variant] or {}).clipsets)
end

--- Full setup, once, by whoever creates the zombie: stats, look, weapons
local function setupZombie(ped, variant)
    markZombie(ped)
    local def = VARIANTS[variant] or VARIANTS.walker
    adoptZombie(ped, variant)

    local hp = math.floor(tonumber(def.health) or 200)
    SetEntityMaxHealth(ped, hp)
    SetEntityHealth(ped, hp)
    SetPedArmour(ped, math.floor(tonumber(def.armour) or 0))

    -- bloodied civilians: random outfit plus one or two damage packs
    SetPedRandomComponentVariation(ped, 0)
    local packs = Config.DamagePacks or {}
    if #packs > 0 then
        ApplyPedDamagePack(ped, packs[math.random(#packs)], 0.0, 1.0)
        if math.random() < 0.5 then
            ApplyPedDamagePack(ped, packs[math.random(#packs)], 0.0, 1.0)
        end
    end

    local knifeChance = tonumber(Config.GiveKnifeChance) or 0.0
    if knifeChance > 0.0 and math.random() < knifeChance then
        GiveWeaponToPed(ped, `WEAPON_KNIFE`, 1, false, true)
        SetCurrentPedWeapon(ped, `WEAPON_KNIFE`, true)
    else
        RemoveAllPedWeapons(ped, true)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    end
end

-- ============================================================
-- Brain: wander until a player is seen or heard, then hunt them
-- ============================================================

--- live players a zombie may go after (not dead, not turned)
local function huntablePlayers()
    local list = {}
    for _, pid in ipairs(GetActivePlayers()) do
        local pp = GetPlayerPed(pid)
        if pp ~= 0 and DoesEntityExist(pp) and not IsEntityDead(pp) then
            local sid = GetPlayerServerId(pid)
            local st = Player(sid).state
            if not (st and st.fivex_zturned) then
                list[#list + 1] = { ped = pp, sid = sid, coords = GetEntityCoords(pp), noise = st and st.fivex_znoise }
            end
        end
    end
    return list
end

--- the nearest player this zombie can see, hear or touch
local function sense(ped, pos, def, players, cloudNow)
    local sight = tonumber(def.sight) or tonumber(SENSES.sight) or 32.0
    local touch = tonumber(SENSES.touch) or 9.0
    local best, bestD = nil, 1e9
    for i = 1, #players do
        local p = players[i]
        local d = #(pos - p.coords)
        if d < bestD then
            local noticed = d < touch
            if not noticed and d < sight then
                -- facing it, or close enough to sense it from behind
                noticed = HasEntityClearLosToEntityInFront(ped, p.ped)
                    or (d < sight * 0.45 and HasEntityClearLosToEntity(ped, p.ped, 17))
            end
            if not noticed and type(p.noise) == 'table' then
                local r, t = tonumber(p.noise.r) or 0, tonumber(p.noise.t) or 0
                noticed = d < r and (cloudNow - t) <= 2
            end
            if noticed then
                best, bestD = p, d
            end
        end
    end
    return best, bestD
end

local function setTask(ped, b, name)
    b.task = name
    b.taskAt = GetGameTimer()
end

--- a task counts as running for a moment after it was given, so a slow status never makes us re-issue
local function taskRunning(ped, b, hash)
    local s = GetScriptTaskStatus(ped, hash)
    return s == 0 or s == 1 or GetGameTimer() - (b.taskAt or 0) < 2500
end

local function wander(ped, b)
    if b.task == 'wander' and taskRunning(ped, b, TASK_WANDER) then return end
    SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
    TaskWanderStandard(ped, 10.0, 10)
    setTask(ped, b, 'wander')
end

local function goTo(ped, b, target, speed)
    local name = 'goto' .. speed
    if b.task == name and taskRunning(ped, b, TASK_GOTO) then return end
    TaskGoToEntity(ped, target, -1, 1.2, speed, 1073741824.0, 0)
    setTask(ped, b, name)
end

local function fight(ped, b, target)
    if b.task == 'combat' and taskRunning(ped, b, TASK_COMBAT) then return end
    TaskCombatPed(ped, target, 0, 16)
    setTask(ped, b, 'combat')
end

local function leap(ped, b, def, target)
    local cfg = def.leap
    local from, to = GetEntityCoords(ped), GetEntityCoords(target)
    local dx, dy = to.x - from.x, to.y - from.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.1 then return end
    dx, dy = dx / len, dy / len
    -- a high arc that comes down on the target: flight time from the lift, push to cover the gap
    local lift = tonumber(cfg.lift) or 15.0
    local flight = 2.0 * lift / 9.81
    local push = math.max(tonumber(cfg.minPush) or 1.5, math.min(tonumber(cfg.maxPush) or 22.0, len / flight))
    b.task = 'leap'
    CreateThread(function()
        SetPedCanRagdoll(ped, false)
        -- collision proof = no fall damage from its own landing; bullets still hit mid-air
        SetEntityProofs(ped, false, false, false, true, false, false, false, false)
        SetEntityHeading(ped, GetHeadingFromVector_2d(dx, dy))
        TaskJump(ped, true, false, false)
        -- push only once it is off the ground, or friction eats the launch
        local deadline = GetGameTimer() + 450
        while DoesEntityExist(ped) and not IsEntityInAir(ped) and not IsPedJumping(ped) and GetGameTimer() < deadline do
            Wait(0)
        end
        -- hold the launch for a few frames: the ped's own jump would otherwise cap it
        for _ = 1, 6 do
            if not DoesEntityExist(ped) or IsEntityDead(ped) then break end
            SetEntityVelocity(ped, dx * push, dy * push, lift)
            Wait(0)
        end
        Wait(300)
        deadline = GetGameTimer() + math.floor(flight * 1000) + 2500
        while DoesEntityExist(ped) and IsEntityInAir(ped) and GetGameTimer() < deadline do
            Wait(50)
        end
        Wait(400)
        if DoesEntityExist(ped) then
            SetEntityProofs(ped, false, false, false, false, false, false, false, false)
            SetPedCanRagdoll(ped, true)
            b.task = nil
        end
    end)
end

local function startHunt(b, p)
    b.state = 'hunt'
    b.target = p.ped
    b.targetSid = p.sid
    b.lastSeen = GetGameTimer()
    b.task = nil
end

local function think(ped, b, players, cloudNow, again)
    local def = VARIANTS[b.variant] or VARIANTS.walker
    local pos = GetEntityCoords(ped)
    local now = GetGameTimer()
    if b.task == 'leap' then return end

    if b.state == 'hunt' then
        local tgt = b.target
        local valid = tgt and DoesEntityExist(tgt) and not IsEntityDead(tgt)
        if valid then
            local st = b.targetSid and Player(b.targetSid).state
            if st and st.fivex_zturned then valid = false end
        end
        if not valid then
            b.state, b.target = 'idle', nil
        else
            local d = #(pos - GetEntityCoords(tgt))
            if d < (tonumber(def.sight) or tonumber(SENSES.sight) or 32.0) * 1.6 and HasEntityClearLosToEntity(ped, tgt, 17) then
                b.lastSeen = now
            end
            if d > (tonumber(SENSES.loseDistance) or 140.0) or now - (b.lastSeen or now) > (tonumber(SENSES.loseAfterMs) or 15000) then
                b.state, b.target = 'idle', nil
            else
                -- a closer, louder player steals the chase
                local p, pd = sense(ped, pos, def, players, cloudNow)
                if p and p.ped ~= tgt and pd < d * 0.6 then startHunt(b, p) tgt = p.ped d = pd end

                if d <= MELEE_RANGE or (b.task == 'combat' and d < 6.0) then
                    -- (stays in the fight while the target backs off a step)
                    SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
                    fight(ped, b, tgt)
                elseif def.leap and d >= (def.leap.min or 5.0) and d <= (def.leap.max or 17.0)
                    and now >= (b.nextLeap or 0) and not IsPedRagdoll(ped) and not IsPedFalling(ped)
                    and HasEntityClearLosToEntity(ped, tgt, 17) then
                    b.nextLeap = now + (def.leap.cooldownMs or 5500)
                    leap(ped, b, def, tgt)
                elseif def.stealth and d > (tonumber(def.lunge) or 11.0) then
                    SetPedStealthMovement(ped, true, 'DEFAULT_ACTION')
                    goTo(ped, b, tgt, 1.0)
                else
                    SetPedStealthMovement(ped, false, 'DEFAULT_ACTION')
                    goTo(ped, b, tgt, (def.sprint or def.stealth) and 3.0 or 1.0)
                end
                return
            end
        end
    end

    local p = not again and sense(ped, pos, def, players, cloudNow)
    if p then
        startHunt(b, p)
        return think(ped, b, players, cloudNow, true)
    end
    wander(ped, b)
end

local function playerPedFromServerId(sid)
    local pid = GetPlayerFromServerId(tonumber(sid) or -1)
    if pid and pid ~= -1 then
        local pp = GetPlayerPed(pid)
        if pp ~= 0 and DoesEntityExist(pp) then return pp end
    end
    return nil
end

local function brainTick()
    local players = huntablePlayers()
    local cloudNow = GetCloudTimeAsInt()
    local seen = {}
    local pool = GetGamePool('CPed')
    for i = 1, #pool do
        local ped = pool[i]
        if not IsPedAPlayer(ped) and isMarkedZombie(ped) and not IsEntityDead(ped) and ownsPed(ped) then
            seen[ped] = true
            local b = brains[ped]
            if not b then
                b = { variant = variantOf(ped), state = 'idle' }
                brains[ped] = b
                adoptZombie(ped, b.variant)
                -- hordes are born hunting; the chase survives an ownership change
                local hunt = Entity(ped).state.fivex_zhunt
                local hp = hunt and playerPedFromServerId(hunt)
                if hp then startHunt(b, { ped = hp, sid = hunt }) end
            end
            think(ped, b, players, cloudNow)
        end
    end
    for ped in pairs(brains) do
        if not seen[ped] then brains[ped] = nil end
    end
end

-- ============================================================
-- Spawning
-- ============================================================

local function isAmbientConvertible(ped)
    if ped == 0 or not DoesEntityExist(ped) then return false end
    if IsPedAPlayer(ped) then return false end
    if IsEntityDead(ped) then return false end
    if isMarkedZombie(ped) then return false end
    if converted[ped] or spawned[ped] then return false end
    if not IsPedHuman(ped) then return false end
    if IsPedInAnyVehicle(ped, false) then return false end
    -- script peds (job clerks, shop staff, drivers) are mission entities: leave them be
    if IsEntityAMissionEntity(ped) then return false end
    -- each client turns the peds it owns, so nobody waits on network control
    if not ownsPed(ped) then return false end
    return true
end

--- alive zombies (anyone's) within radius of a point
local function zombiesNear(coords, radius)
    local n = 0
    local pool = GetGamePool('CPed')
    for i = 1, #pool do
        local ped = pool[i]
        if not IsPedAPlayer(ped) and not IsEntityDead(ped) and isMarkedZombie(ped)
            and #(GetEntityCoords(ped) - coords) <= radius then
            n = n + 1
        end
    end
    return n
end

local function aliveIn(map)
    local n = 0
    for ped in pairs(map) do
        if DoesEntityExist(ped) and not IsEntityDead(ped) then n = n + 1 end
    end
    return n
end

--- server-spawned zombies this client asked for (the server caps these too)
local function totalTracked()
    return aliveIn(spawned)
end

local function convertPed(ped)
    if not isAmbientConvertible(ped) then return false end
    local variant = pickVariant(baseWeights())
    pcall(function() Entity(ped).state:set('fivex_zvar', variant, NetworkGetEntityIsNetworked(ped)) end)
    setupZombie(ped, variant)
    converted[ped] = true
    convertedCount = convertedCount + 1
    return true
end

local function corpseLingerMs()
    return tonumber(Config.CorpseDespawnMs) or 60000
end

local function deleteSpawnedPed(ped)
    if not DoesEntityExist(ped) then return end
    local netId = 0
    if NetworkGetEntityIsNetworked(ped) then
        netId = NetworkGetNetworkIdFromEntity(ped) or 0
    end
    if netId ~= 0 and Config.SpawnUseServer then
        TriggerServerEvent('fivex_zombies:requestDespawn', netId)
    end
    ensureNetworkControl(ped, 300)
    SetEntityAsMissionEntity(ped, true, true)
    DeleteEntity(ped)
end

local function pruneMap(map, onRemove)
    local now = GetGameTimer()
    local linger = corpseLingerMs()
    local rem = {}
    for ped in pairs(map) do
        if not DoesEntityExist(ped) then
            rem[#rem + 1] = ped
        elseif IsEntityDead(ped) then
            if not corpses[ped] then
                corpses[ped] = now + linger
            elseif now >= corpses[ped] then
                rem[#rem + 1] = ped
            end
        else
            corpses[ped] = nil
        end
    end
    for i = 1, #rem do
        local ped = rem[i]
        if DoesEntityExist(ped) then onRemove(ped) end
        map[ped] = nil
        corpses[ped] = nil
    end
    return #rem
end

local function pruneTracked()
    convertedCount = math.max(0, convertedCount - pruneMap(converted, function(ped)
        if IsEntityDead(ped) then
            ensureNetworkControl(ped, 200)
            SetEntityAsMissionEntity(ped, true, true)
            DeleteEntity(ped)
        end
    end))
    spawnedCount = math.max(0, spawnedCount - pruneMap(spawned, deleteSpawnedPed))
    for ped in pairs(killed) do
        if not DoesEntityExist(ped) then killed[ped] = nil end
    end
end

local function scanAndConvert()
    if Config.ConvertAmbient ~= true then return end
    local playerPed = PlayerPedId()
    if playerPed == 0 then return end
    local pcoords = GetEntityCoords(playerPed)
    local radius = Config.ConvertRadius or 250.0
    local room = (tonumber(Config.MaxConverted) or 80) - aliveIn(converted)
    if room <= 0 then return end
    local pool = GetGamePool('CPed')
    for i = 1, #pool do
        local ped = pool[i]
        if isAmbientConvertible(ped) and #(GetEntityCoords(ped) - pcoords) <= radius and convertPed(ped) then
            room = room - 1
            if room <= 0 then break end
        end
    end
end

local function requestModel(hash)
    if type(hash) ~= 'number' then
        hash = joaat(hash)
    end
    if not IsModelInCdimage(hash) or not IsModelValid(hash) or not IsModelAPed(hash) then
        return false
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do
        Wait(0)
    end
    return HasModelLoaded(hash)
end

--- Local mission peds (SpawnUseServer = false only)
local function createPedAt(model, x, y, z, heading)
    if not requestModel(model) then return 0 end
    local zTries = { z + 1.0, z + 1.5, z }
    for i = 1, #zTries do
        RequestCollisionAtCoord(x, y, zTries[i])
        local ped = CreatePed(4, model, x, y, zTries[i], heading, false, true)
        if ped ~= 0 and DoesEntityExist(ped) then
            SetModelAsNoLongerNeeded(model)
            return ped
        end
        Wait(0)
    end
    SetModelAsNoLongerNeeded(model)
    return 0
end

local function isWaterish(tx, ty, gz)
    local ok, wh = GetWaterHeightNoWaves(tx, ty, gz + 5.0)
    if ok and type(wh) == 'number' and gz <= (wh + 0.75) then
        return true
    end
    return false
end

--- walkable ground at (x, y), or nil
local function groundAt(x, y, z)
    local found, safe = GetSafeCoordForPed(x, y, z, false, 16)
    if found and safe and safe.x and #(vector2(safe.x, safe.y) - vector2(x, y)) < 12.0 then
        if not isWaterish(safe.x, safe.y, safe.z) then
            return vector3(safe.x, safe.y, safe.z)
        end
    end
    local foundZ, gz = GetGroundZFor_3dCoord(x, y, z + 50.0, false)
    if foundZ and math.abs(gz - z) < 25.0 and not isWaterish(x, y, gz) then
        return vector3(x, y, gz + 0.05)
    end
    return nil
end

--- a spawn point in a ring around center; prefers points the camera can't see
local function findSpawnCoord(center, rMin, rMax, angle, spread)
    for attempt = 1, 24 do
        local a = angle and (angle + math.rad(rand(-spread, spread))) or (math.random() * math.pi * 2.0)
        local dist = rand(rMin, rMax)
        local pos = groundAt(center.x + math.cos(a) * dist, center.y + math.sin(a) * dist, center.z)
        if pos and (attempt > 16 or not IsSphereVisible(pos.x, pos.y, pos.z + 1.0, 1.0)) then
            return pos
        end
    end
    return nil
end

local function waitSpawnResult(reqId, timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or 3500)
    while GetGameTimer() < deadline do
        local res = spawnResults[reqId]
        if res ~= nil then
            spawnResults[reqId] = nil
            return res
        end
        Wait(0)
    end
    spawnResults[reqId] = nil
    return nil
end

local function entityFromNetId(netId, timeoutMs)
    local deadline = GetGameTimer() + (timeoutMs or 2500)
    while GetGameTimer() < deadline do
        local ped = NetworkGetEntityFromNetworkId(netId)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            return ped
        end
        Wait(0)
    end
    return 0
end

RegisterNetEvent('fivex_zombies:spawnResult', function(reqId, ok, netId)
    spawnResults[tonumber(reqId) or reqId] = {
        ok = ok and true or false,
        netId = tonumber(netId) or 0,
    }
end)

local function randomModel()
    local list = Config.SpawnModels or { `u_m_y_zombie_01` }
    return list[math.random(#list)]
end

--- one zombie at pos. hunt = born chasing this player (hordes)
local function spawnZombie(pos, variant, hunt)
    if totalTracked() >= (Config.MaxZombiesPerPlayer or 32) then return false end
    local model = randomModel()
    local heading = math.random(0, 359) + 0.0
    local ped = 0

    if Config.SpawnUseServer ~= false then
        spawnReqSeq = spawnReqSeq + 1
        local reqId = spawnReqSeq
        TriggerServerEvent('fivex_zombies:requestSpawn', reqId, model, pos.x, pos.y, pos.z, heading, variant, hunt and true or false)
        local res = waitSpawnResult(reqId, tonumber(Config.SpawnRequestTimeoutMs) or 3500)
        if not res or not res.ok or res.netId == 0 then
            dbg('server spawn refused', model)
            return false
        end
        ped = entityFromNetId(res.netId, 2500)
        if ped == 0 then
            dbgFail('server spawn resolve failed', 'model=', model, 'netId=', res.netId)
            TriggerServerEvent('fivex_zombies:requestDespawn', res.netId)
            return false
        end
        ensureNetworkControl(ped, 800)
        -- the server may have swapped the variant (alpha cap)
        variant = Entity(ped).state.fivex_zvar or variant
    else
        ped = createPedAt(model, pos.x, pos.y, pos.z, heading)
        if ped == 0 or not DoesEntityExist(ped) then
            dbgFail('CreatePed failed', 'model=', model, 'pos=', pos.x, pos.y, pos.z)
            return false
        end
        SetEntityAsMissionEntity(ped, true, true)
        pcall(function() Entity(ped).state:set('fivex_zvar', variant, false) end)
    end

    SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    ResetEntityAlpha(ped)
    setupZombie(ped, variant)

    if hunt then
        local b = { variant = variant, state = 'idle' }
        brains[ped] = b
        startHunt(b, { ped = PlayerPedId(), sid = GetPlayerServerId(PlayerId()) })
    end

    spawned[ped] = true
    spawnedCount = spawnedCount + 1
    corpses[ped] = nil
    return true
end

local function topUpWanderers()
    local playerPed = PlayerPedId()
    if playerPed == 0 or IsEntityDead(playerPed) then return end
    local pcoords = GetEntityCoords(playerPed)
    local want = tonumber(Config.Wanderers) or 14
    local have = zombiesNear(pcoords, tonumber(Config.WanderRadius) or 90.0)
    local need = math.min(want - have, tonumber(Config.SpawnBatch) or 4)
    if need <= 0 then return end
    local rMin, rMax = tonumber(Config.SpawnRadiusMin) or 38.0, tonumber(Config.SpawnRadiusMax) or 85.0
    local weights = baseWeights()
    for _ = 1, need do
        local pos = findSpawnCoord(pcoords, rMin, rMax)
        if pos then
            spawnZombie(pos, pickVariant(weights), false)
            Wait(40)
        end
    end
end

local COMPASS = { 'north', 'north-east', 'east', 'south-east', 'south', 'south-west', 'west', 'north-west' }

local function compassTo(from, to)
    local bearing = (math.deg(math.atan(to.x - from.x, to.y - from.y)) + 360.0) % 360.0
    return COMPASS[math.floor((bearing + 22.5) / 45.0) % 8 + 1]
end

local function spawnHorde()
    local cfg = Config.Hordes or {}
    local playerPed = PlayerPedId()
    if playerPed == 0 or IsEntityDead(playerPed) or IsPedInAnyVehicle(playerPed, false) then return false end
    local pcoords = GetEntityCoords(playerPed)

    -- behind the camera: the pack is heard before it is seen
    local camZ = GetGameplayCamRot(2).z
    local behind = math.rad(camZ + 90.0 + 180.0) -- GTA heading 0 = +y; cos/sin below start at +x
    local dist = cfg.distance or { 60.0, 85.0 }
    local centre = findSpawnCoord(pcoords, dist[1], dist[2], behind, 70.0)
    if not centre then return false end

    local size = cfg.size or { 7, 12 }
    local n = math.random(size[1], size[2])
    local room = (Config.MaxZombiesPerPlayer or 32) - totalTracked()
    n = math.min(n, room)
    if n < 3 then return false end

    local spread = tonumber(cfg.spread) or 5.0
    local made = 0
    for _ = 1, n do
        local a = math.random() * math.pi * 2.0
        local r = math.random() * spread
        local pos = groundAt(centre.x + math.cos(a) * r, centre.y + math.sin(a) * r, centre.z) or centre
        if spawnZombie(pos, pickVariant(Config.HordeVariants or { runner = 1 }), true) then
            made = made + 1
        end
    end
    if made > 0 and cfg.warn ~= false then
        SendNUIMessage({ action = 'horde', title = L('horde_title'), text = L('horde_text', compassTo(pcoords, centre)), size = made })
        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDS', true)
    end
    dbg('horde', made, 'at', centre)
    return made > 0
end

local function scheduleNextHorde(first)
    local cfg = Config.Hordes or {}
    if first then
        nextHordeAt = GetGameTimer() + (tonumber(cfg.firstAfterMs) or 20000)
    else
        local iv = cfg.intervalMs or { 45000, 80000 }
        nextHordeAt = GetGameTimer() + math.random(iv[1], iv[2])
    end
end

-- ============================================================
-- Cleanup
-- ============================================================

local function restorePed(ped)
    if not DoesEntityExist(ped) then return end
    ensureNetworkControl(ped, 300)
    ClearPedTasksImmediately(ped)
    ResetPedMovementClipset(ped, 0.25)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedKeepTask(ped, false)
    SetPedRelationshipGroupHash(ped, GetHashKey('CIVMALE'))
    if DecorExistOn(ped, DECOR_NAME) then
        DecorSetBool(ped, DECOR_NAME, false)
    end
    pcall(function()
        Entity(ped).state:set('fivex_zombie', false, false)
    end)
    SetPedAsNoLongerNeeded(ped)
end

local function cleanupConverted()
    local mode = Config.CleanupOnStop or 'delete'
    for ped in pairs(converted) do
        if DoesEntityExist(ped) then
            if mode == 'restore' then
                restorePed(ped)
            else
                ensureNetworkControl(ped, 300)
                SetEntityAsMissionEntity(ped, true, true)
                DeleteEntity(ped)
            end
        end
    end
    converted = {}
    convertedCount = 0
end

local function cleanupSpawned()
    for ped in pairs(spawned) do
        if DoesEntityExist(ped) then
            deleteSpawnedPed(ped)
        end
    end
    -- zombies that migrated to this client from someone else's spawn or conversion
    local pool = GetGamePool('CPed')
    for i = 1, #pool do
        local ped = pool[i]
        if not IsPedAPlayer(ped) and isMarkedZombie(ped) and ownsPed(ped) then
            if spawned[ped] == nil and converted[ped] == nil then
                SetEntityAsMissionEntity(ped, true, true)
                DeleteEntity(ped)
            end
        end
    end
    spawned = {}
    spawnedCount = 0
    corpses = {}
end

local function startDensityRestorePulse()
    local ms = tonumber(Config.DensityRestoreMs) or 45000
    densityPulseUntil = GetGameTimer() + math.floor(ms)
end

-- ============================================================
-- Player infection
-- ============================================================

local function setTurned(state)
    pcall(function() LocalPlayer.state:set('fivex_zturned', state and true or nil, true) end)
end

local function clearPlayerInfection()
    local ped = PlayerPedId()
    infectHits = 0
    lastHitAt = 0
    if playerInfected then
        playerInfected = false
        setTurned(false)
        if ped ~= 0 then
            ResetPedMovementClipset(ped, 0.25)
            ClearTimecycleModifier()
            StopGameplayCamShaking(true)
            AnimpostfxStopAll()
        end
    end
end

local function applyPlayerZombie()
    if playerInfected then return end
    playerInfected = true
    setTurned(true)
    local ped = PlayerPedId()
    applyClipset(ped, Config.ZombieClipsets)

    if Config.PlayerMeleeOnly then
        RemoveAllPedWeapons(ped, true)
    end

    AnimpostfxPlay(Config.InfectScreenEffect or 'DrugsMichaelAliensFight', 0, true)
    SetTimecycleModifier('damage')
    SetTimecycleModifierStrength(0.45)
    ShakeGameplayCam('DRUNK_SHAKE', 0.35)

    TriggerEvent('chat:addMessage', {
        color = Config.ChatColor or { 200, 30, 30 },
        args = { Config.ChatPrefix or '[FiveX Zombies]', L('turned') },
    })
end

local function killFromInfection()
    TriggerEvent('chat:addMessage', {
        color = Config.ChatColor or { 200, 30, 30 },
        args = { Config.ChatPrefix or '[FiveX Zombies]', L('infect_kill') },
    })
    SetEntityHealth(PlayerPedId(), 0)
    infectHits = 0
end

local function onInfectThreshold()
    local mode = Config.PlayerInfectMode or 'zombie'
    if mode == 'kill' then
        killFromInfection()
    elseif mode == 'zombie_or_kill' then
        if math.random() < 0.5 then applyPlayerZombie() else killFromInfection() end
    else
        applyPlayerZombie()
    end
end

local function registerHit(attacker)
    if playerInfected or not active then return end
    if GetGameTimer() < graceUntil then return end

    infectHits = infectHits + 1
    lastHitAt = GetGameTimer()

    -- an alpha's hit knocks you flat
    if attacker and DoesEntityExist(attacker) then
        local def = VARIANTS[variantOf(attacker)]
        if def and def.knockdown then
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) then
                SetPedToRagdoll(ped, 1600, 1600, 0, false, false, false)
            end
        end
    end

    if infectHits >= (Config.HitsToInfect or 5) then
        infectHits = 0
        onInfectThreshold()
    end
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or not active then return end
    local victim, attacker = args[1], args[2]
    local playerPed = PlayerPedId()

    -- a zombie you finished off
    if attacker == playerPed and victim ~= playerPed and not killed[victim] and DoesEntityExist(victim)
        and IsEntityAPed(victim) and isMarkedZombie(victim) and (args[6] == 1 or IsEntityDead(victim)) then
        killed[victim] = true
        kills = kills + 1
    end

    if victim ~= playerPed or playerInfected then return end
    if GetGameTimer() < graceUntil then return end
    if attacker == 0 or not DoesEntityExist(attacker) or not IsEntityAPed(attacker) then return end
    if isMarkedZombie(attacker) then
        registerHit(attacker)
        -- consume the damage record so pollZombieDamage doesn't count it again
        ClearEntityLastDamageEntity(playerPed)
    end
end)

local function pollZombieDamage()
    if not active or playerInfected then return end
    if GetGameTimer() < graceUntil then return end
    local playerPed = PlayerPedId()
    if not HasEntityBeenDamagedByAnyPed(playerPed) then return end
    local pool = GetGamePool('CPed')
    local pcoords = GetEntityCoords(playerPed)
    for i = 1, #pool do
        local ped = pool[i]
        if ped ~= playerPed and isMarkedZombie(ped) and #(GetEntityCoords(ped) - pcoords) < 4.0
            and HasEntityBeenDamagedByEntity(playerPed, ped, true) then
            registerHit(ped)
            ClearEntityLastDamageEntity(playerPed)
            break
        end
    end
end

local function decayHits()
    local decay = tonumber(Config.HitDecayMs) or 0
    if decay <= 0 or infectHits <= 0 or playerInfected then return end
    if lastHitAt > 0 and (GetGameTimer() - lastHitAt) >= decay then
        infectHits = infectHits - 1
        lastHitAt = GetGameTimer()
    end
end

-- ============================================================
-- NUI (never takes focus)
-- ============================================================

local function nuiFocusOff()
    SetNuiFocus(false, false)
end

local function startNuiAlarm()
    if not Config.UseNuiAlarm then return end
    SendNUIMessage({
        action = 'playAlarm',
        src = Config.AlarmNuiSrc or 'audio/alarm.ogg',
        volume = tonumber(Config.AlarmNuiVolume) or 0.55,
    })
end

local function stopNuiAlarm()
    SendNUIMessage({ action = 'stopAlarm' })
end

local function outbreakSince()
    return tonumber(GlobalState.fivex_zombies_since) or 0
end

local function showAnnounce(kind)
    nuiFocusOff()
    if kind == 'start' then
        SendNUIMessage({
            action = 'announce',
            kind = 'start',
            eyebrow = L('ui_start_eyebrow'),
            title = L('ui_start_title'),
            subtitle = L('ui_start_subtitle'),
            ticker = L('ui_start_ticker'),
            grace = tonumber(Config.GraceSeconds) or 10,
            durationMs = tonumber(Config.AnnounceDurationStartMs) or 9000,
        })
    else
        local since = outbreakSince()
        SendNUIMessage({
            action = 'announce',
            kind = 'stop',
            eyebrow = L('ui_stop_eyebrow'),
            title = L('ui_stop_title'),
            subtitle = L('ui_stop_subtitle'),
            ticker = L('ui_stop_ticker'),
            kills = kills,
            survived = since > 0 and math.max(0, GetCloudTimeAsInt() - since) or nil,
            durationMs = tonumber(Config.AnnounceDurationStopMs) or 9000,
        })
    end
end

local function stopAlarm()
    alarmUntil = 0
    stopNuiAlarm()
end

local function setApocalypseActive(state)
    state = state and true or false
    if state == active then
        return
    end

    active = state
    nuiFocusOff()

    if active then
        ensureDecor()
        ensureRelationship()
        local grace = tonumber(Config.GraceSeconds) or 10
        graceUntil = GetGameTimer() + math.floor(grace * 1000)
        infectHits = 0
        playerInfected = false
        kills = 0
        killed = {}
        densityPulseUntil = 0
        scheduleNextHorde(true)
        nextHordeAt = nextHordeAt + math.floor(grace * 1000)
        SetAiMeleeWeaponDamageModifier(tonumber(Config.ZombieDamageMult) or 1.0)
        showAnnounce('start')
        alarmUntil = GetGameTimer() + math.floor((tonumber(Config.AlarmSeconds) or 10) * 1000)
        startNuiAlarm()
        dbg('apocalypse ACTIVE, grace until', graceUntil)
    else
        stopAlarm()
        graceUntil = 0
        showAnnounce('stop')
        SendNUIMessage({ action = 'hud', show = false })
        cleanupSpawned()
        cleanupConverted()
        brains = {}
        killed = {}
        clearCivHostility()
        clearPlayerInfection()
        SetAiMeleeWeaponDamageModifier(1.0)
        pcall(function() LocalPlayer.state:set('fivex_znoise', nil, true) end)
        startDensityRestorePulse()
        dbg('apocalypse STOPPED; density pulse started')
    end
end

RegisterNetEvent('fivex_zombies:setActive', function(state)
    setApocalypseActive(state)
end)

CreateThread(function()
    Wait(1500)
    nuiFocusOff()
    TriggerServerEvent('fivex_zombies:requestSync')
    local bag = GlobalState.fivex_zombies_active
    if bag ~= nil then
        setApocalypseActive(bag and true or false)
    end
end)

AddStateBagChangeHandler('fivex_zombies_active', 'global', function(_, _, value)
    setApocalypseActive(value and true or false)
end)

-- ============================================================
-- Threads
-- ============================================================

--- Alarm frontend fallback (NUI alarm runs independently)
CreateThread(function()
    while true do
        if not active then
            Wait(Config.IdleWaitMs or 2000)
        elseif alarmUntil > 0 and GetGameTimer() < alarmUntil then
            if Config.UseFrontendAlarmFallback then
                PlaySoundFrontend(-1, Config.AlarmSoundName or 'ScreenFlash', Config.AlarmSoundSet or 'MissionFailedSounds', true)
            end
            Wait(Config.AlarmRepeatMs or 900)
        else
            if alarmUntil ~= 0 then
                alarmUntil = 0
                stopNuiAlarm()
            end
            Wait(500)
        end
    end
end)

--- Director: wanderers around you, hordes now and then, ambient conversion
CreateThread(function()
    local lastScan, lastSpawn = 0, 0
    while true do
        if not active then
            Wait(Config.IdleWaitMs or 2000)
        else
            local now = GetGameTimer()
            if now >= graceUntil then
                pruneTracked()
                if now - lastScan >= (Config.ScanIntervalMs or 1500) then
                    lastScan = now
                    scanAndConvert()
                end
                if Config.SpawnEnabled and now - lastSpawn >= (Config.SpawnIntervalMs or 1500) then
                    lastSpawn = now
                    topUpWanderers()
                end
                if Config.SpawnEnabled and (Config.Hordes or {}).enabled ~= false and now >= nextHordeAt then
                    -- no room or no ground: try again soon instead of waiting a full interval
                    if spawnHorde() then scheduleNextHorde(false) else nextHordeAt = now + 8000 end
                end
            end
            Wait(250)
        end
    end
end)

--- Brain: AI for every zombie this client owns
CreateThread(function()
    while true do
        if not active then
            Wait(Config.IdleWaitMs or 2000)
        else
            if GetGameTimer() >= graceUntil then brainTick() end
            Wait(400)
        end
    end
end)

--- Noise: tell zombies (whoever owns them) how loud this player is being
CreateThread(function()
    local lastR, lastSent = 0, 0
    while true do
        if not active or GetGameTimer() < graceUntil then
            lastR = 0
            Wait(1000)
        else
            local ped = PlayerPedId()
            local r = 0
            if IsPedShooting(ped) then
                r = IsPedCurrentWeaponSilenced(ped) and (SENSES.suppressed or 22.0) or (SENSES.gunshot or 95.0)
            elseif IsPedSprinting(ped) then
                r = SENSES.sprint or 22.0
            end
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then
                if IsHornActive(veh) then
                    r = math.max(r, SENSES.horn or 70.0)
                elseif GetEntitySpeed(veh) > 8.5 then
                    r = math.max(r, SENSES.vehicle or 35.0)
                end
            end
            local now = GetGameTimer()
            if r > 0 and (r > lastR or now - lastSent > 1000) then
                lastR, lastSent = r, now
                LocalPlayer.state:set('fivex_znoise', { r = r, t = GetCloudTimeAsInt() }, true)
            elseif now - lastSent > 1000 then
                lastR = 0
            end
            Wait(0)
        end
    end
end)

--- Infection / damage
CreateThread(function()
    while true do
        if not active then
            Wait(Config.IdleWaitMs or 2000)
        else
            pollZombieDamage()
            decayHits()

            if playerInfected then
                local ped = PlayerPedId()
                if IsEntityDead(ped) then
                    clearPlayerInfection()
                elseif Config.PlayerMeleeOnly then
                    local _, cur = GetCurrentPedWeapon(ped, true)
                    if cur and cur ~= `WEAPON_UNARMED` and cur ~= `WEAPON_KNIFE` and cur ~= `WEAPON_BAT` and cur ~= `WEAPON_NIGHTSTICK` then
                        RemoveAllPedWeapons(ped, true)
                        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
                    end
                end
            end

            Wait(Config.InfectionPollMs or 250)
        end
    end
end)

--- HUD: only sends when something changed
CreateThread(function()
    local last = ''
    while true do
        if not active or not Config.Hud then
            last = ''
            Wait(Config.IdleWaitMs or 2000)
        else
            local ped = PlayerPedId()
            local hidden = IsPauseMenuActive() or GetGameTimer() < graceUntil
            local nearby, hunting = 0, 0
            if not hidden then
                local pcoords = GetEntityCoords(ped)
                local radius = tonumber(Config.NearbyRadius) or 60.0
                local pool = GetGamePool('CPed')
                for i = 1, #pool do
                    local z = pool[i]
                    if not IsPedAPlayer(z) and not IsEntityDead(z) and isMarkedZombie(z)
                        and #(GetEntityCoords(z) - pcoords) <= radius then
                        nearby = nearby + 1
                        -- moving at you fast, or already swinging
                        if IsPedInMeleeCombat(z) or (GetEntitySpeed(z) > 2.2 and IsPedFacingPed(z, ped, 45.0)) then
                            hunting = hunting + 1
                        end
                    end
                end
            end
            local msg = {
                action = 'hud',
                show = not hidden,
                since = outbreakSince(),
                now = GetCloudTimeAsInt(),
                nearby = nearby,
                hunting = hunting,
                kills = kills,
                infect = infectHits,
                infectMax = Config.HitsToInfect or 5,
                turned = playerInfected,
                night = isNight(),
            }
            local key = table.concat({ tostring(msg.show), nearby, hunting, kills, infectHits, tostring(playerInfected), tostring(msg.night), msg.since }, '|')
            if key ~= last then
                last = key
                SendNUIMessage(msg)
            end
            Wait(500)
        end
    end
end)

--- Street density: empty while active, restore pulse after stop (every frame)
CreateThread(function()
    while true do
        local now = GetGameTimer()
        if active then
            local d = Config.StreetDensity or {}
            local peds, vehs = tonumber(d.peds) or 1.0, tonumber(d.vehicles) or 1.0
            SetPedDensityMultiplierThisFrame(peds)
            SetScenarioPedDensityMultiplierThisFrame(peds, peds)
            SetVehicleDensityMultiplierThisFrame(vehs)
            SetRandomVehicleDensityMultiplierThisFrame(vehs)
            SetParkedVehicleDensityMultiplierThisFrame(tonumber(d.parked) or vehs)
            Wait(0)
        elseif densityPulseUntil > 0 and now < densityPulseUntil then
            SetPedDensityMultiplierThisFrame(1.0)
            SetScenarioPedDensityMultiplierThisFrame(1.0, 1.0)
            SetVehicleDensityMultiplierThisFrame(1.0)
            SetRandomVehicleDensityMultiplierThisFrame(1.0)
            SetParkedVehicleDensityMultiplierThisFrame(1.0)
            SetCreateRandomCops(true)
            Wait(0)
        else
            if densityPulseUntil ~= 0 and now >= densityPulseUntil then
                densityPulseUntil = 0
            end
            Wait(500)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopAlarm()
    cleanupSpawned()
    cleanupConverted()
    clearCivHostility()
    clearPlayerInfection()
    SetAiMeleeWeaponDamageModifier(1.0)
    densityPulseUntil = 0
    active = false
    nuiFocusOff()
end)

AddEventHandler('baseevents:onPlayerDied', function()
    if playerInfected then clearPlayerInfection() end
end)

AddEventHandler('baseevents:onPlayerKilled', function()
    if playerInfected then clearPlayerInfection() end
end)
