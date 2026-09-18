--[[
  fivex_gangwars — Flashpoint server
  Validates runs, kill counts, payday stub. Client never awards money.
]]

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
        local key = Config.PaydayKvpPrefix .. license
        local prev = tonumber(GetResourceKvpString(key)) or 0
        SetResourceKvp(key, tostring(prev + amount))
    end

    TriggerClientEvent('fivex_gangwars:payday', src, amount)
end

---------------------------------------------------------------------------
-- Run lifecycle (client-initiated; server authoritative for score/pay)
---------------------------------------------------------------------------

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
        started = os.time(),
    }
end)

RegisterNetEvent('fivex_gangwars:registerPed', function(token, netId)
    local src = source
    local run = Runs[src]
    if not run or run.token ~= token then return end
    if type(netId) ~= 'number' then return end

    local live = 0
    for _ in pairs(run.peds) do live = live + 1 end
    if live >= Config.MaxLiveHostiles then return end

    run.peds[netId] = true
end)

RegisterNetEvent('fivex_gangwars:reportKill', function(token, netId)
    local src = source
    local run = Runs[src]
    if not run or run.token ~= token then return end
    if type(netId) ~= 'number' then return end
    if not run.peds[netId] then return end

    run.peds[netId] = nil
    run.kills = run.kills + 1
end)

RegisterNetEvent('fivex_gangwars:waveClear', function(token, wave, _clientKills)
    local src = source
    local run = Runs[src]
    if not run or run.token ~= token then return end
    if type(wave) ~= 'number' or wave < 1 then return end

    -- Advance cleared count; ignore duplicate / out-of-order
    if wave > run.cleared then
        run.cleared = wave
        run.wave = wave + 1
        run.peds = {} -- fresh wave registrations expected next
    end
end)

RegisterNetEvent('fivex_gangwars:endRun', function(token, _reason, _waves, _clientKills)
    local src = source
    local run = Runs[src]
    if not run or run.token ~= token then return end

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
    return tonumber(GetResourceKvpString(Config.PaydayKvpPrefix .. license)) or 0
end)
