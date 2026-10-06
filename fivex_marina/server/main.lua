-- fivex_marina — Harbor Authority (server)
-- Server-authoritative: contracts, career progress and every payout are decided here.
-- Clients only report what they did; each step is checked against position, state and time.

local JC = 'fivex_jobcenter'
local warned = false

local KVP_PROFILE = 'fivex_marina_v2:'
local KVP_BOARD = 'fivex_marina_v2_board'

-- MySQL tables (server/db.lua); the first start imports the old KVP data
FxDB.space('profile', 'fivex_marina_profile', 'text', { kvp = KVP_PROFILE, key = 'license', value = 'profile' })
FxDB.space('board',   'fivex_marina_board',   'text', { kvp = KVP_BOARD, key = 'id', value = 'leaderboard' })

local Players = {}   -- src -> { lic, profile, streak, shift, offers, offersAt, contract }
local vehNet = {}    -- src -> work boat netId
local runnerNet = {} -- src -> recovery runner netId
local vehCooldown = {}
local buckets = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function warnJc()
    if warned then return end
    warned = true
    print((Locales['en'] and Locales['en'].missing_jc) or '^1[fivex_marina]^7 fivex_jobcenter is required and is not started.')
end

local function jcReady()
    if GetResourceState(JC) ~= 'started' then
        warnJc()
        return false
    end
    return true
end

local function jc(fn, ...)
    if not jcReady() then return nil end
    local exp = exports[JC]
    local ok, a, b = pcall(exp[fn], exp, ...)
    if not ok then return nil end
    return a, b
end

local function L(key, ...)
    local pack = Locales[Config.Locale] or Locales['en'] or {}
    local s = pack[key] or key
    if select('#', ...) > 0 then return s:format(...) end
    return s
end

local function notify(src, msg, typ)
    TriggerClientEvent('fivex_jobcenter:notify', src, msg, typ or 'info')
end

local function rateOk(src, key, maxN, windowMs)
    local now = GetGameTimer()
    local id = tostring(src) .. ':' .. key
    local b = buckets[id]
    if not b or (now - b.start) > windowMs then
        buckets[id] = { start = now, n = 1 }
        return true
    end
    if b.n >= maxN then return false end
    b.n = b.n + 1
    return true
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function dist(src, vec)
    local c = pedCoords(src)
    if not c then return 9999.0 end
    return #(c - vec)
end

local function dist2d(src, x, y)
    local c = pedCoords(src)
    if not c then return 9999.0 end
    return #(vector2(c.x, c.y) - vector2(x, y))
end

local function v3(t) return vector3(t.x + 0.0, t.y + 0.0, (t.z or 0.0) + 0.0) end

local function hasDuty(src)
    return jc('HasJob', src, Config.JobId) and jc('IsDuty', src)
end

local function newId()
    return ('har-%d-%d'):format(os.time(), math.random(10000, 99999))
end

local function hashSet(names)
    local set = {}
    for i = 1, #names do set[joaat(names[i]) & 0xFFFFFFFF] = true end
    return set
end

local BOAT_MODELS = (function()
    local names = { Config.BoatFallback }
    for i = 1, #Config.Ranks do names[#names + 1] = Config.Ranks[i].boat end
    return hashSet(names)
end)()
-- the client falls back to Config.BoatFallback when a runner model fails to load
local RUNNER_MODELS = (function()
    local names = { Config.BoatFallback }
    for i = 1, #Config.RunnerModels do names[#names + 1] = Config.RunnerModels[i] end
    return hashSet(names)
end)()

-- Resolve a client-reported netId to a vehicle this player actually created, of an allowed model.
-- Waits briefly because the event can arrive before the entity's creation has synced.
local function ownedVehicle(src, netId, modelSet)
    local ent = 0
    local deadline = GetGameTimer() + 3000
    repeat
        ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) then break end
        Wait(100)
    until GetGameTimer() > deadline
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    if GetEntityType(ent) ~= 2 then return nil end
    if not modelSet[GetEntityModel(ent) & 0xFFFFFFFF] then return nil end
    local owner = NetworkGetFirstEntityOwner and NetworkGetFirstEntityOwner(ent) or NetworkGetEntityOwner(ent)
    if owner ~= src then return nil end
    return ent
end

local function deleteNet(netId)
    if not netId then return end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
end

local function vehicleOfPed(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return 0 end
    return GetVehiclePedIsIn(ped, false)
end

---------------------------------------------------------------------------
-- Career profile + leaderboard (KVP, keyed by license)
---------------------------------------------------------------------------

local function licenseOf(src)
    return GetPlayerIdentifierByType(src, 'license')
end

local function loadProfile(lic)
    local p
    if lic then
        local ok, dec = pcall(json.decode, FxDB.get('profile', lic) or '')
        if ok and type(dec) == 'table' then p = dec end
    end
    p = p or {}
    return {
        xp = math.max(0, math.floor(tonumber(p.xp) or 0)),
        jobs = math.max(0, math.floor(tonumber(p.jobs) or 0)),
        earned = math.max(0, math.floor(tonumber(p.earned) or 0)),
        best = math.max(0, math.floor(tonumber(p.best) or 0)),
    }
end

local function saveProfile(st)
    if not st.lic then return end
    FxDB.set('profile', st.lic, json.encode(st.profile))
end

local function rankOf(xp)
    local idx = 1
    for i = 1, #Config.Ranks do
        if xp >= Config.Ranks[i].xp then idx = i end
    end
    return idx, Config.Ranks[idx]
end

local function loadBoard()
    local ok, dec = pcall(json.decode, FxDB.get('board', 'main') or '')
    if ok and type(dec) == 'table' then return dec end
    return {}
end

local function updateBoard(st, name)
    if not st.lic then return end
    local board = loadBoard()
    local found = false
    for i = 1, #board do
        if board[i].lic == st.lic then
            board[i].name, board[i].earned, board[i].jobs, board[i].xp = name, st.profile.earned, st.profile.jobs, st.profile.xp
            found = true
            break
        end
    end
    if not found then
        board[#board + 1] = { lic = st.lic, name = name, earned = st.profile.earned, jobs = st.profile.jobs, xp = st.profile.xp }
    end
    table.sort(board, function(a, b) return (a.earned or 0) > (b.earned or 0) end)
    while #board > Config.LeaderboardSize do table.remove(board) end
    FxDB.set('board', 'main', json.encode(board))
end

-- License stays server-side; clients only see names and numbers
local function boardPayload(st)
    local out = {}
    local board = loadBoard()
    for i = 1, #board do
        local e = board[i]
        local _, r = rankOf(tonumber(e.xp) or 0)
        out[#out + 1] = {
            name = tostring(e.name or '?'):sub(1, 32),
            earned = tonumber(e.earned) or 0,
            jobs = tonumber(e.jobs) or 0,
            rank = r.name,
            me = st and st.lic ~= nil and e.lic == st.lic or false,
        }
    end
    return out
end

---------------------------------------------------------------------------
-- Player state
---------------------------------------------------------------------------

local function getState(src)
    local st = Players[src]
    if st then return st end
    -- before the stored profiles are loaded, hand out a throwaway state that is never saved
    local loaded = FxDB.await()
    local lic = loaded and licenseOf(src) or nil
    st = {
        lic = lic,
        profile = loadProfile(lic),
        streak = 0,
        shift = nil,
        offers = {},
        offersAt = 0,
        contract = nil,
    }
    if loaded then Players[src] = st end
    return st
end

local function profilePayload(st)
    local idx, r = rankOf(st.profile.xp)
    local nxt = Config.Ranks[idx + 1]
    return {
        rank = idx,
        rankName = r.name,
        xp = st.profile.xp,
        rankXp = r.xp,
        nextXp = nxt and nxt.xp or nil,
        nextName = nxt and nxt.name or nil,
        payMult = r.pay,
        streak = st.streak,
        streakBonus = math.min(st.streak * Config.StreakStep, Config.StreakMax),
        jobs = st.profile.jobs,
        earned = st.profile.earned,
        best = st.profile.best,
        boat = r.boat,
        boatLabel = r.boatLabel,
        ranks = (function()
            local list = {}
            for i = 1, #Config.Ranks do
                local rr = Config.Ranks[i]
                list[i] = { name = rr.name, xp = rr.xp, pay = rr.pay, boatLabel = rr.boatLabel }
            end
            return list
        end)(),
    }
end

local function shiftPayload(st)
    local s = st.shift
    if not s then return nil end
    return {
        minutes = math.floor((os.time() - s.start) / 60),
        earned = s.earned, jobs = s.jobs, fails = s.fails, xp = s.xp, bestStreak = s.bestStreak,
    }
end

---------------------------------------------------------------------------
-- Offers (the contract board)
---------------------------------------------------------------------------

local function makeOffer(st, kind)
    local def = Config.Contracts[kind]
    local idx, r = rankOf(st.profile.xp)
    local variance = 1.0 + (math.random() * 2.0 - 1.0) * Config.PayVariance
    local o = {
        id = newId() .. kind,
        kind = kind,
        label = def.label,
        blurb = def.blurb,
        icon = def.icon,
        rank = def.rank,
        rankName = Config.Ranks[def.rank] and Config.Ranks[def.rank].name or '?',
        locked = idx < def.rank,
        xp = def.xp,
        par = def.par,
        limit = def.limit,
        pay = math.floor(def.pay * variance * r.pay + 0.5),
    }
    if def.sea then
        o.area = def.areas[math.random(1, #def.areas)]
        o.areaLabel = Config.SeaAreas[o.area].label
    elseif kind == 'refuel' then
        o.slip = math.random(1, #Config.Slips)
        o.areaLabel = 'Slip ' .. Config.Slips[o.slip].id
    else
        o.areaLabel = 'Detail slip'
    end
    return o
end

local function ensureOffers(st, force)
    local now = GetGameTimer()
    if not force and #st.offers > 0 and now - st.offersAt < Config.OfferRefreshMs then return end
    st.offers = {}
    for i = 1, #Config.ContractOrder do
        st.offers[i] = makeOffer(st, Config.ContractOrder[i])
    end
    st.offersAt = now
end

local function refreshOffer(st, kind)
    for i = 1, #st.offers do
        if st.offers[i].kind == kind then
            st.offers[i] = makeOffer(st, kind)
        end
    end
end

local function pushBoard(src, open)
    local st = getState(src)
    ensureOffers(st, false)
    TriggerClientEvent('fivex_marina:board', src, {
        open = open and true or false,
        offers = st.offers,
        profile = profilePayload(st),
        leaderboard = boardPayload(st),
        shift = shiftPayload(st),
        refreshIn = math.max(0, Config.OfferRefreshMs - (GetGameTimer() - st.offersAt)),
        active = st.contract and st.contract.kind or nil,
    })
end

---------------------------------------------------------------------------
-- Contracts
---------------------------------------------------------------------------

local function pointsNeeded(kind)
    if kind == 'debris' then return Config.DebrisCount end
    if kind == 'charter' then return Config.CharterStops end
    if kind == 'recovery' or kind == 'rescue' then return 1 end
    return 0
end

local function contractPayload(a)
    if not a then return false end
    local now = GetGameTimer()
    return {
        id = a.id,
        kind = a.kind,
        label = a.label,
        pay = a.pay,
        xp = a.xp,
        par = a.par,
        endsIn = math.max(0, a.deadline - now),
        elapsed = now - a.issuedAt,
        area = a.area,
        areaLabel = a.areaLabel,
        needPoints = pointsNeeded(a.kind),
        points = a.points,
        detail = a.detail,
        slip = a.slip,
        hasCan = a.hasCan,
        boarded = a.boarded,
        repaired = a.repaired,
        collected = a.collected,
        picked = a.picked,
        wp = a.wp,
        reached = a.reached,
        runnerModel = a.runnerModel,
        npcModel = a.npcModel,
        boatModel = a.boatModel,
    }
end

local function sendContract(src)
    local st = Players[src]
    TriggerClientEvent('fivex_marina:contract', src, contractPayload(st and st.contract))
end

local function cleanupContract(src)
    deleteNet(runnerNet[src])
    runnerNet[src] = nil
end

-- Minimum believable time for the travel a contract needs (anti-teleport)
local function tooFast(a, travel)
    local def = Config.Contracts[a.kind]
    local floor = math.max(Config.MinTaskMs, ((def and def.minSecs) or 0) * 1000)
    local minMs = math.max(floor, (travel or 0.0) / Config.MaxTravelSpeed * 1000.0)
    return GetGameTimer() - a.issuedAt < minMs
end

local function routeLength(a)
    local dock = Config.DockStand
    local pts = a.points or {}
    if a.kind == 'recovery' and pts[1] then
        local slip = Config.Slips[a.slip].coords
        return #(v3(pts[1]) - vector3(Config.DinghySpawn.x, Config.DinghySpawn.y, 0.0)) + #(v3(pts[1]) - slip)
    elseif a.kind == 'charter' and #pts > 0 then
        local len, prev = 0.0, dock
        for i = 1, #pts do
            len = len + #(v3(pts[i]) - prev)
            prev = v3(pts[i])
        end
        return len + #(prev - dock)
    elseif (a.kind == 'debris' or a.kind == 'rescue') and pts[1] then
        return #(v3(pts[1]) - dock) * 2.0
    end
    return 0.0
end

local function fail(src, reasonKey)
    local st = Players[src]
    if not st or not st.contract then return end
    local a = st.contract
    st.contract = nil
    st.streak = 0
    if st.shift then st.shift.fails = st.shift.fails + 1 end
    cleanupContract(src)
    refreshOffer(st, a.kind)
    sendContract(src)
    TriggerClientEvent('fivex_marina:failed', src, { label = a.label, reason = L(reasonKey) })
    if reasonKey == 'fail_cancelled' then
        notify(src, L('cancelled'), 'error')
    else
        notify(src, L('failed', L(reasonKey)), 'error')
    end
end

local function complete(src, quality, qualityLabel)
    local st = Players[src]
    if not st or not st.contract then return end
    local a = st.contract
    st.contract = nil
    cleanupContract(src)

    local now = GetGameTimer()
    local elapsed = (now - a.issuedAt) / 1000.0
    local express = elapsed <= a.par
    local streakBonus = math.min(st.streak * Config.StreakStep, Config.StreakMax)
    quality = math.max(0.3, math.min(1.5, tonumber(quality) or 1.0))

    local pay = a.pay * quality * (1.0 + streakBonus + (express and Config.ExpressBonus or 0.0))
    pay = math.max(1, math.min(4999, math.floor(pay + 0.5)))
    local paid = jc('AddPay', src, pay, 'harbor ' .. a.kind) ~= nil
    if not paid then
        notify(src, L('rate_limited'), 'error')
    end
    local earned = paid and pay or 0

    local oldRank = rankOf(st.profile.xp)
    local xpGain = math.floor(a.xp * (express and 1.25 or 1.0) * math.min(quality, 1.2) + 0.5)
    st.profile.xp = st.profile.xp + xpGain
    st.profile.jobs = st.profile.jobs + 1
    st.profile.earned = st.profile.earned + earned
    st.streak = st.streak + 1
    if st.streak > st.profile.best then st.profile.best = st.streak end
    if st.shift then
        st.shift.earned = st.shift.earned + earned
        st.shift.jobs = st.shift.jobs + 1
        st.shift.xp = st.shift.xp + xpGain
        if st.streak > st.shift.bestStreak then st.shift.bestStreak = st.streak end
    end
    saveProfile(st)
    updateBoard(st, GetPlayerName(src) or ('Player ' .. src))
    refreshOffer(st, a.kind)

    local newRank, r = rankOf(st.profile.xp)
    if newRank ~= oldRank then
        -- new rank may unlock contracts and change pay: re-roll the board
        ensureOffers(st, true)
    end

    sendContract(src)
    TriggerClientEvent('fivex_marina:completed', src, {
        label = a.label,
        kind = a.kind,
        base = a.pay,
        pay = earned,
        quality = quality,
        qualityLabel = qualityLabel,
        streakBonus = streakBonus,
        express = express,
        elapsed = math.floor(elapsed),
        par = a.par,
        xpGain = xpGain,
        profile = profilePayload(st),
        rankUp = newRank ~= oldRank and { name = r.name, boatLabel = r.boatLabel, pay = r.pay } or nil,
    })
end

local function active(src, cid, kind)
    if not hasDuty(src) then return nil end
    local st = Players[src]
    local a = st and st.contract
    if not a or a.id ~= cid then return nil end
    if kind and a.kind ~= kind then return nil end
    return a, st
end

---------------------------------------------------------------------------
-- Duty + work boat
---------------------------------------------------------------------------

local function boatFor(st)
    local _, r = rankOf(st.profile.xp)
    return r.boat
end

local function spawnWorkBoat(src)
    local st = getState(src)
    TriggerClientEvent('fivex_marina:spawnBoat', src, {
        x = Config.DinghySpawn.x, y = Config.DinghySpawn.y, z = Config.DinghySpawn.z, w = Config.DinghySpawn.w,
        model = boatFor(st),
    })
end

local function deleteBoat(src)
    deleteNet(vehNet[src])
    vehNet[src] = nil
    TriggerClientEvent('fivex_marina:delBoat', src)
end

local function clockOut(src, silent)
    local st = Players[src]
    if st and st.contract then fail(src, 'fail_cancelled') end
    -- take the summary before SetDuty: its dutyChanged event clears the shift
    local summary = st and shiftPayload(st)
    jc('SetDuty', src, false)
    deleteBoat(src)
    if st then
        st.shift = nil
        st.streak = 0
        if summary and not silent then
            summary.profile = profilePayload(st)
            TriggerClientEvent('fivex_marina:summary', src, summary)
        end
    end
    if not silent then notify(src, L('off_duty'), 'info') end
    TriggerClientEvent('fivex_marina:duty', src, false)
end

RegisterNetEvent('fivex_marina:clockIn', function()
    local src = source
    if not jcReady() then return end
    if not rateOk(src, 'clock', 6, 10000) then return end
    if not jc('HasJob', src, Config.JobId) then
        notify(src, L('need_job'), 'error')
        return
    end
    if dist(src, vector3(Config.Duty.x, Config.Duty.y, Config.Duty.z)) > Config.DutyRadius + 2.0 then return end
    -- on duty with an active shift = clock out. (Jobcenter duty without a marina shift, e.g. after a
    -- marina restart, just starts a fresh shift instead of clocking out on the first press.)
    if jc('IsDuty', src) and Players[src] and Players[src].shift then
        clockOut(src)
        return
    end
    if not jc('SetDuty', src, true) then return end
    local st = getState(src)
    if not st.lic then notify(src, L('no_license'), 'error') end
    st.shift = { start = os.time(), earned = 0, jobs = 0, fails = 0, xp = 0, bestStreak = 0 }
    st.streak = 0
    notify(src, L('on_duty', Config.TabletKey), 'success')
    TriggerClientEvent('fivex_marina:duty', src, true)
    spawnWorkBoat(src)
    pushBoard(src, true)
end)

RegisterNetEvent('fivex_marina:boatSpawned', function(netId)
    local src = source
    if not hasDuty(src) then return end
    netId = tonumber(netId)
    if not netId then return end
    if not ownedVehicle(src, netId, BOAT_MODELS) then return end
    if vehNet[src] and vehNet[src] ~= netId then deleteNet(vehNet[src]) end
    vehNet[src] = netId
end)

RegisterNetEvent('fivex_marina:requestBoat', function()
    local src = source
    if not hasDuty(src) then return end
    local spawn = vector3(Config.DinghySpawn.x, Config.DinghySpawn.y, Config.DinghySpawn.z)
    if dist(src, spawn) > 15.0 and dist(src, Config.DockStand) > 15.0
        and dist(src, vector3(Config.Duty.x, Config.Duty.y, Config.Duty.z)) > 8.0 then
        return
    end
    local now = GetGameTimer()
    if vehCooldown[src] and now < vehCooldown[src] then
        notify(src, L('cooldown'), 'error')
        return
    end
    vehCooldown[src] = now + Config.VehicleCooldown
    spawnWorkBoat(src)
end)

-- After a recovery the work boat is usually left out at sea: bring it home (no cooldown),
-- but only when the player is back at the dock and the boat really is far away / gone.
RegisterNetEvent('fivex_marina:returnBoat', function()
    local src = source
    if not hasDuty(src) then return end
    if not rateOk(src, 'return', 3, 30000) then return end
    if dist(src, Config.DockStand) > 25.0 then return end
    local spawn = vector3(Config.DinghySpawn.x, Config.DinghySpawn.y, Config.DinghySpawn.z)
    local netId = vehNet[src]
    if netId then
        local ent = NetworkGetEntityFromNetworkId(netId)
        if ent and ent ~= 0 and DoesEntityExist(ent) and #(GetEntityCoords(ent) - spawn) < 150.0 then return end
    end
    deleteBoat(src)
    spawnWorkBoat(src)
    notify(src, L('boat_returned'), 'info')
end)

---------------------------------------------------------------------------
-- Board + accepting contracts
---------------------------------------------------------------------------

RegisterNetEvent('fivex_marina:requestBoard', function()
    local src = source
    if not hasDuty(src) then return end
    if not rateOk(src, 'board', 10, 10000) then return end
    pushBoard(src, true)
end)

RegisterNetEvent('fivex_marina:accept', function(offerId)
    local src = source
    if not hasDuty(src) then return end
    if not rateOk(src, 'accept', 6, 10000) then return end
    local st = getState(src)
    if st.contract then
        notify(src, L('busy'), 'error')
        return
    end
    local offer
    for i = 1, #st.offers do
        if st.offers[i].id == offerId then offer = st.offers[i] break end
    end
    if not offer then
        pushBoard(src, true)
        return
    end
    local idx = rankOf(st.profile.xp)
    if idx < offer.rank then
        notify(src, L('locked', offer.rankName), 'error')
        return
    end

    local def = Config.Contracts[offer.kind]
    local now = GetGameTimer()
    local a = {
        id = newId(),
        kind = offer.kind,
        label = offer.label,
        pay = offer.pay,
        xp = offer.xp,
        par = offer.par,
        issuedAt = now,
        deadline = now + def.limit * 1000,
        area = offer.area,
        areaLabel = offer.areaLabel,
    }
    if a.kind == 'detail' then
        a.detail = { false, false, false, false }
    elseif a.kind == 'refuel' then
        a.slip = offer.slip
        a.hasCan = false
        a.boatModel = Config.RefuelBoatModels[math.random(1, #Config.RefuelBoatModels)]
    elseif a.kind == 'recovery' then
        a.slip = math.random(1, #Config.Slips)
        a.boarded = false
        a.repaired = false
        a.runnerModel = Config.RunnerModels[math.random(1, #Config.RunnerModels)]
    elseif a.kind == 'debris' then
        a.collected = {}
    elseif a.kind == 'charter' then
        a.picked = false
        a.wp = 0
        a.npcModel = Config.CharterPassengers[math.random(1, #Config.CharterPassengers)]
    elseif a.kind == 'rescue' then
        a.reached = false
        a.picked = false
        a.npcModel = Config.RescueVictims[math.random(1, #Config.RescueVictims)]
    end
    st.contract = a
    sendContract(src)
    notify(src, L('accepted', a.label), 'success')
end)

---------------------------------------------------------------------------
-- Sea objective locations (picked by the client inside the area, validated here)
---------------------------------------------------------------------------

local function validSeaPoint(a, p, slack)
    if type(p) ~= 'table' then return nil end
    local x, y, z = tonumber(p.x), tonumber(p.y), tonumber(p.z)
    if not x or not y or not z then return nil end
    local area = Config.SeaAreas[a.area]
    if not area then return nil end
    if #(vector2(x, y) - area.center) > area.radius + (slack or 0.0) then return nil end
    if #(vector2(x, y) - vector2(Config.Duty.x, Config.Duty.y)) < Config.SeaMinDistance then return nil end
    if #(vector2(x, y) - vector2(Config.DockStand.x, Config.DockStand.y)) < Config.SeaMinDistance then return nil end
    if z < -5.0 or z > 10.0 then return nil end
    return { x = x, y = y, z = z }
end

RegisterNetEvent('fivex_marina:seaPoints', function(cid, pts)
    local src = source
    local a = active(src, cid)
    if not a or a.points then return end
    local need = pointsNeeded(a.kind)
    if need == 0 or type(pts) ~= 'table' or #pts ~= need then return end
    local clean = {}
    for i = 1, need do
        local p = validSeaPoint(a, pts[i], Config.DebrisSpacing)
        if not p then return end
        clean[i] = p
    end
    a.points = clean
    sendContract(src)
end)

-- A spot that looked like water from afar turned out to be shallow / land: move it
RegisterNetEvent('fivex_marina:movePoint', function(cid, i, p)
    local src = source
    local a = active(src, cid)
    if not a or not a.points then return end
    i = tonumber(i)
    if not i or not a.points[i] then return end
    if not rateOk(src, 'move', 12, 10000) then return end
    if a.collected and a.collected[i] then return end
    -- each spot may be corrected once, and only a short way: the client can't walk it to the dock
    a.moved = a.moved or {}
    if a.moved[i] then return end
    local clean = validSeaPoint(a, p, Config.DebrisSpacing + Config.SeaSnapRadius)
    if not clean then return end
    if #(v3(clean) - v3(a.points[i])) > Config.SeaSnapRadius + 5.0 then return end
    a.moved[i] = true
    a.points[i] = clean
    sendContract(src)
end)

---------------------------------------------------------------------------
-- Hull detail
---------------------------------------------------------------------------

RegisterNetEvent('fivex_marina:scrub', function(cid, index)
    local src = source
    if not rateOk(src, 'step', 12, 10000) then return end
    local a = active(src, cid, 'detail')
    if not a then return end
    index = tonumber(index)
    if not index or not Config.DetailPoints[index] or a.detail[index] then return end
    if dist(src, Config.DetailPoints[index]) > 3.5 then return end
    -- each scrub is a timed hold: reports can't come faster than that
    local now = GetGameTimer()
    if a.lastStep and now - a.lastStep < Config.Anim.scrub.ms - 300 then return end
    a.lastStep = now
    local all = true
    for i = 1, #Config.DetailPoints do
        if i ~= index and not a.detail[i] then all = false break end
    end
    if all and tooFast(a, 0.0) then return end
    a.detail[index] = true
    if all then
        complete(src, 1.0, 'Showroom shine')
    else
        sendContract(src)
    end
end)

---------------------------------------------------------------------------
-- Slip refuel
---------------------------------------------------------------------------

RegisterNetEvent('fivex_marina:grabCan', function(cid)
    local src = source
    if not rateOk(src, 'step', 12, 10000) then return end
    local a = active(src, cid, 'refuel')
    if not a or a.hasCan then return end
    if dist(src, Config.FuelPump) > 6.0 then return end
    a.hasCan = true
    sendContract(src)
end)

RegisterNetEvent('fivex_marina:pour', function(cid, fill)
    local src = source
    if not rateOk(src, 'step', 12, 10000) then return end
    local a = active(src, cid, 'refuel')
    if not a or not a.hasCan then return end
    local slip = Config.Slips[a.slip].coords
    if dist2d(src, slip.x, slip.y) > 12.0 then return end
    if tooFast(a, 0.0) then return end
    fill = tonumber(fill) or 0.0
    local P = Config.Pour
    if fill >= P.spillAt then
        complete(src, 0.6, 'Spilled fuel')
    elseif fill >= P.perfectMin then
        complete(src, 1.15, 'Perfect fill')
    elseif fill >= P.okMin then
        complete(src, 1.0, 'Topped off')
    else
        complete(src, 0.7, 'Half empty')
    end
end)

---------------------------------------------------------------------------
-- Adrift recovery
---------------------------------------------------------------------------

RegisterNetEvent('fivex_marina:runnerSpawned', function(cid, netId)
    local src = source
    local a = active(src, cid, 'recovery')
    if not a or runnerNet[src] then return end
    netId = tonumber(netId)
    if not netId then return end
    if not ownedVehicle(src, netId, RUNNER_MODELS) then return end
    if not Players[src] or Players[src].contract ~= a then
        deleteNet(netId)
        return
    end
    runnerNet[src] = netId
end)

local function runnerEntity(src)
    local netId = runnerNet[src]
    if not netId then return 0 end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
    return 0
end

RegisterNetEvent('fivex_marina:board', function(cid)
    local src = source
    local a = active(src, cid, 'recovery')
    if not a or a.boarded then return end
    local ent = runnerEntity(src)
    if ent == 0 or vehicleOfPed(src) ~= ent then return end
    a.boarded = true
    sendContract(src)
end)

RegisterNetEvent('fivex_marina:repair', function(cid)
    local src = source
    local a = active(src, cid, 'recovery')
    if not a or not a.boarded or a.repaired then return end
    local ent = runnerEntity(src)
    if ent == 0 or vehicleOfPed(src) ~= ent then return end
    a.repaired = true
    sendContract(src)
end)

RegisterNetEvent('fivex_marina:dock', function(cid)
    local src = source
    if not rateOk(src, 'step', 12, 10000) then return end
    local a = active(src, cid, 'recovery')
    if not a or not a.repaired then return end
    local ent = runnerEntity(src)
    if ent == 0 or vehicleOfPed(src) ~= ent then return end
    local slip = Config.Slips[a.slip].coords
    if dist(src, slip) > Config.DockRadius + 3.0 then return end
    if GetEntitySpeed(ent) > Config.DockSpeed + 1.0 then return end
    if tooFast(a, routeLength(a)) then return end
    -- body condition decides the bonus: a scratch-free runner earns the full rate
    local body = GetVehicleBodyHealth and GetVehicleBodyHealth(ent) or 1000.0
    local q = 0.6 + 0.5 * math.max(0.0, math.min(1.0, (body or 1000.0) / 1000.0))
    TriggerClientEvent('fivex_marina:putOnDock', src, { x = Config.DockStand.x, y = Config.DockStand.y, z = Config.DockStand.z })
    complete(src, q, q >= 1.05 and 'Not a scratch' or (q >= 0.9 and 'Minor scrapes' or 'Banged up'))
end)

---------------------------------------------------------------------------
-- Debris sweep
---------------------------------------------------------------------------

RegisterNetEvent('fivex_marina:collect', function(cid, i)
    local src = source
    if not rateOk(src, 'collect', 20, 10000) then return end
    local a = active(src, cid, 'debris')
    if not a or not a.points then return end
    i = tonumber(i)
    if not i or not a.points[i] or a.collected[i] then return end
    if dist2d(src, a.points[i].x, a.points[i].y) > 25.0 then return end
    a.collected[i] = true
    sendContract(src)
end)

RegisterNetEvent('fivex_marina:unload', function(cid)
    local src = source
    if not rateOk(src, 'step', 12, 10000) then return end
    local a = active(src, cid, 'debris')
    if not a or not a.points then return end
    for i = 1, #a.points do
        if not a.collected[i] then return end
    end
    if dist(src, Config.DockStand) > 20.0
        and dist(src, vector3(Config.DinghySpawn.x, Config.DinghySpawn.y, Config.DinghySpawn.z)) > 20.0 then
        return
    end
    if tooFast(a, routeLength(a)) then return end
    complete(src, 1.0, 'Lane clear')
end)

---------------------------------------------------------------------------
-- Harbor charter
---------------------------------------------------------------------------

RegisterNetEvent('fivex_marina:paxBoarded', function(cid)
    local src = source
    local a = active(src, cid, 'charter')
    if not a or a.picked then return end
    if dist(src, Config.DockStand) > 40.0 then return end
    a.picked = true
    sendContract(src)
end)

RegisterNetEvent('fivex_marina:waypoint', function(cid, i)
    local src = source
    if not rateOk(src, 'step', 12, 10000) then return end
    local a = active(src, cid, 'charter')
    if not a or not a.picked or not a.points then return end
    i = tonumber(i)
    if not i or i ~= a.wp + 1 or not a.points[i] then return end
    if dist2d(src, a.points[i].x, a.points[i].y) > 45.0 then return end
    a.wp = i
    sendContract(src)
end)

RegisterNetEvent('fivex_marina:dropoff', function(cid, stars)
    local src = source
    if not rateOk(src, 'step', 12, 10000) then return end
    local a = active(src, cid, 'charter')
    if not a or not a.points or a.wp < #a.points then return end
    if dist(src, Config.DockStand) > 40.0 then return end
    if tooFast(a, routeLength(a)) then return end
    stars = math.max(1, math.min(5, math.floor(tonumber(stars) or 3)))
    local q = ({ 0.7, 0.85, 1.0, 1.12, 1.25 })[stars]
    complete(src, q, ('%d-star ride'):format(stars))
end)

RegisterNetEvent('fivex_marina:paxBailed', function(cid)
    local src = source
    local a = active(src, cid, 'charter')
    if not a then return end
    fail(src, 'fail_passenger')
end)

---------------------------------------------------------------------------
-- Mayday rescue
---------------------------------------------------------------------------

RegisterNetEvent('fivex_marina:victimAboard', function(cid)
    local src = source
    local a = active(src, cid, 'rescue')
    if not a or not a.points or a.picked then return end
    if dist2d(src, a.points[1].x, a.points[1].y) > 45.0 then return end
    if vehicleOfPed(src) == 0 then return end
    a.reached = true
    a.picked = true
    sendContract(src)
end)

RegisterNetEvent('fivex_marina:handoff', function(cid)
    local src = source
    if not rateOk(src, 'step', 12, 10000) then return end
    local a = active(src, cid, 'rescue')
    if not a or not a.picked then return end
    if dist(src, Config.DockStand) > 40.0 then return end
    if tooFast(a, routeLength(a)) then return end
    -- the faster they're back, the better the bonus
    local secs = (GetGameTimer() - a.issuedAt) / 1000.0
    local q = secs <= a.par and 1.2 or 1.0
    complete(src, q, q > 1.0 and 'Golden hour' or 'Stable condition')
end)

---------------------------------------------------------------------------
-- Failure reports + cancel
---------------------------------------------------------------------------

RegisterNetEvent('fivex_marina:fail', function(cid, reason)
    local src = source
    local a = active(src, cid)
    if not a then return end
    if reason == 'sunk' and a.kind == 'recovery' then
        local ent = runnerEntity(src)
        local wrecked = ent == 0 or GetEntityHealth(ent) <= 0 or GetVehicleBodyHealth(ent) <= 0.0
            or GetEntityCoords(ent).z < -2.0
        if not wrecked then return end
        fail(src, 'fail_sunk')
    elseif reason == 'victim' and a.kind == 'rescue' then
        fail(src, 'fail_victim')
    end
end)

RegisterNetEvent('fivex_marina:cancel', function()
    local src = source
    if not hasDuty(src) then return end
    fail(src, 'fail_cancelled')
end)

AddEventHandler('fivex_jobcenter:internalCancel', function(src)
    src = tonumber(src)
    if not src or not Players[src] or not Players[src].contract then return end
    fail(src, 'fail_cancelled')
end)

AddEventHandler('fivex_jobcenter:jobChanged', function(src, oldJob)
    src = tonumber(src)
    if not src then return end
    if oldJob == Config.JobId or vehNet[src] or (Players[src] and Players[src].contract) then
        clockOut(src, true)
    end
end)

AddEventHandler('fivex_jobcenter:dutyChanged', function(src, jobId, duty)
    src = tonumber(src)
    if src and jobId == Config.JobId and not duty and (vehNet[src] or (Players[src] and Players[src].shift)) then
        local st = Players[src]
        if st and st.contract then fail(src, 'fail_cancelled') end
        deleteBoat(src)
        if st then st.shift = nil end
        TriggerClientEvent('fivex_marina:duty', src, false)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    deleteNet(vehNet[src])
    deleteNet(runnerNet[src])
    vehNet[src] = nil
    runnerNet[src] = nil
    vehCooldown[src] = nil
    Players[src] = nil
    local prefix = tostring(src) .. ':'
    for k in pairs(buckets) do
        if k:sub(1, #prefix) == prefix then buckets[k] = nil end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(vehNet) do deleteNet(vehNet[src]) end
    for src in pairs(runnerNet) do deleteNet(runnerNet[src]) end
end)

-- Contract deadlines
CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for src, st in pairs(Players) do
            if st.contract and now > st.contract.deadline then
                fail(src, 'fail_timeout')
            end
        end
    end
end)

CreateThread(function()
    Wait(500)
    jcReady()
end)
