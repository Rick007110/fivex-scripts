--[[
  fivex_gangwars — Flashpoint server
  Validates runs, kill counts, payday stub. Client never awards money.
]]

-- MySQL table (server/db.lua); the first start imports the old KVP data
FxDB.space('payday', 'fivex_gangwars_payday', 'int', { kvp = Config.PaydayKvpPrefix, key = 'license', value = 'earned' })

local Locale = Locales[Config.Locale] or Locales['en']

local function L(key, ...)
    local s = Locale[key] or key
    if select('#', ...) > 0 then
        return s:format(...)
    end
    return s
end

--- Active runs: [src] = { token, turfId, wave, cleared, kills, peds, started }
local Runs = {}

local function getLicense(src)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:sub(1, 8) == 'license:' then
            return id
        end
    end
    return nil
end

local function turfExists(id)
    for _, t in ipairs(Config.Turfs) do
        if t.id == id then return true end
    end
    return false
end

local function clearRun(src)
    Runs[src] = nil
end

local function computePayday(waves, kills)
    local amount = (waves * Config.PaydayPerWave) + (kills * Config.PaydayPerKill)
    if amount < 0 then amount = 0 end
    return amount
end

local function awardPayday(src, waves, kills)
    if not Config.PaydayEnabled then return end
    local amount = computePayday(waves, kills)
    if amount <= 0 then return end

    local license = getLicense(src)
    if license then
        local prev = tonumber(FxDB.get('payday', license)) or 0
        FxDB.set('payday', license, prev + amount)
    end

    TriggerClientEvent('fivex_gangwars:payday', src, amount)
end

---------------------------------------------------------------------------
-- Run lifecycle (client-initiated; server authoritative for score/pay)
---------------------------------------------------------------------------

local function maxPedsForWave(wave)
    local n = Config.BasePeds + (wave - 1) * Config.PedsPerWave
    if n > Config.MaxLiveHostiles then n = Config.MaxLiveHostiles end
    return n
end

--- Dead = gone (ent 0 / deleted) or synced health / cause of death says so
local function isNetPedDead(netId)
    local ent = NetworkGetEntityFromNetworkId(netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return true end
    if GetEntityHealth(ent) <= 0 then return true end
    if GetPedCauseOfDeath and (GetPedCauseOfDeath(ent) or 0) ~= 0 then return true end
    return false
end

--- Same run still current (token unchanged after a Wait)
local function runStillValid(src, run)
    return Runs[src] == run
end

RegisterNetEvent('fivex_gangwars:startRun', function(token, turfId)
    local src = source
    if type(token) ~= 'string' or token == '' then return end
    if type(turfId) ~= 'string' or not turfExists(turfId) then return end

    Runs[src] = {
        token = token,
        turfId = turfId,
        wave = 1,
        cleared = 0,
        kills = 0,
        peds = {},
        seen = {},      -- netIds ever registered this run (no re-use)
        waveRegs = 0,   -- registrations accepted for the current wave
        pending = 0,    -- in-flight validation threads
        started = os.time(),
    }
end)

RegisterNetEvent('fivex_gangwars:registerPed', function(token, netId)
    local src = source
    local run = Runs[src]
    if not run or run.token ~= token then return end
    if type(netId) ~= 'number' then return end
    if run.seen[netId] then return end
    if run.waveRegs >= maxPedsForWave(run.wave) then return end
    run.seen[netId] = true
    run.waveRegs = run.waveRegs + 1

    -- Clone create can land after the net event; wait briefly for the entity
    run.pending = run.pending + 1
    CreateThread(function()
        local ent = 0
        local deadline = GetGameTimer() + 1500
        while GetGameTimer() < deadline do
            ent = NetworkGetEntityFromNetworkId(netId)
            if ent and ent ~= 0 and DoesEntityExist(ent) then break end
            ent = 0
            Wait(50)
        end
        run.pending = run.pending - 1
        if not runStillValid(src, run) then return end
        if ent == 0 or GetEntityType(ent) ~= 1 or NetworkGetEntityOwner(ent) ~= src then
            run.waveRegs = math.max(0, run.waveRegs - 1)
            return
        end
        run.peds[netId] = true
    end)
end)

RegisterNetEvent('fivex_gangwars:reportKill', function(token, netId)
    local src = source
    local run = Runs[src]
    if not run or run.token ~= token then return end
    if type(netId) ~= 'number' then return end
    if not run.seen[netId] then return end

    -- Wait for a pending registration and for death to sync to the server
    run.pending = run.pending + 1
    CreateThread(function()
        local deadline = GetGameTimer() + 2000
        while GetGameTimer() < deadline do
            if run.peds[netId] and isNetPedDead(netId) then break end
            Wait(100)
        end
        run.pending = run.pending - 1
        if not runStillValid(src, run) then return end
        if not run.peds[netId] or not isNetPedDead(netId) then return end
        run.peds[netId] = nil
        run.kills = run.kills + 1
    end)
end)

RegisterNetEvent('fivex_gangwars:waveClear', function(token, wave, _clientKills)
    local src = source
    local run = Runs[src]
    if not run or run.token ~= token then return end
    if type(wave) ~= 'number' or wave ~= run.cleared + 1 then return end

    -- Let in-flight register / kill validations settle first
    run.pending = run.pending + 1
    CreateThread(function()
        local deadline = GetGameTimer() + 3000
        while run.pending > 1 and GetGameTimer() < deadline do
            Wait(100)
        end
        run.pending = run.pending - 1
        if not runStillValid(src, run) then return end
        if wave ~= run.cleared + 1 then return end
        -- Drop peds that are dead/gone but whose kill report never arrived (no kill credit),
        -- so one lost event can't stall the run forever
        for netId in pairs(run.peds) do
            if isNetPedDead(netId) then run.peds[netId] = nil end
        end
        -- All registered peds of this wave must be dead
        if run.waveRegs == 0 or next(run.peds) ~= nil then return end
        run.cleared = wave
        run.wave = wave + 1
        run.peds = {}
        run.waveRegs = 0
    end)
end)

RegisterNetEvent('fivex_gangwars:endRun', function(token, _reason, _waves, _clientKills)
    local src = source
    local run = Runs[src]
    if not run or run.token ~= token then return end

    -- Settle any pending validations (e.g. final waveClear) before paying
    local deadline = GetGameTimer() + 4000
    while run.pending > 0 and GetGameTimer() < deadline do
        Wait(100)
    end
    if not runStillValid(src, run) then return end

    local cleared = run.cleared
    local kills = run.kills
    awardPayday(src, cleared, kills)
    clearRun(src)
end)

---------------------------------------------------------------------------
-- Debug ACE: fivex_gangwars (default deny)
---------------------------------------------------------------------------

RegisterNetEvent('fivex_gangwars:debug', function(action, turfId)
    local src = source
    if not IsPlayerAceAllowed(src, Config.AcePermission) then
        TriggerClientEvent('fivex_gangwars:debugResult', src, false, 'debug_denied')
        return
    end

    action = type(action) == 'string' and action:lower() or ''
    if action == 'start' then
        if type(turfId) ~= 'string' or turfId == '' then
            turfId = Config.Turfs[1] and Config.Turfs[1].id or nil
        end
        if not turfId or not turfExists(turfId) then
            TriggerClientEvent('fivex_gangwars:debugResult', src, false, 'no_turf')
            return
        end
        TriggerClientEvent('fivex_gangwars:debugResult', src, true, 'debug_started', turfId)
    elseif action == 'stop' then
        clearRun(src)
        TriggerClientEvent('fivex_gangwars:debugResult', src, true, 'debug_stopped')
    else
        TriggerClientEvent('fivex_gangwars:debugResult', src, false, 'debug_usage')
    end
end)

---------------------------------------------------------------------------
-- Cleanup on drop / stop
---------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    clearRun(source)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    Runs = {}
end)

exports('GetFlashpointEarnings', function(src)
    local license = getLicense(src)
    if not license then return 0 end
    return tonumber(FxDB.get('payday', license)) or 0
end)
