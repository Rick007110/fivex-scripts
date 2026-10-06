-- Only gatekeeps /swat_test; all AI runs on the wanted player's client.

RegisterNetEvent('fivex_police:requestTest', function()
    local src = source
    if IsPlayerAceAllowed(src, 'fivex_police') or IsPlayerAceAllowed(src, Config.TestAce) then
        TriggerClientEvent('fivex_police:testAllowed', src)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { 'Police', ('You need %s.'):format(Config.TestAce) } })
    end
end)

-- Busted: fine per star, bank first then cash, whatever the suspect can cover.
local function call(res, fn, ...)
    if GetResourceState(res) ~= 'started' then return nil end
    local ok, r = pcall(function(...)
        local exp = exports[res]
        return exp[fn](exp, ...)
    end, ...)
    return ok and r or nil
end

local lastBust = {}
RegisterNetEvent('fivex_police:busted', function(wanted)
    local src = source
    local now = os.time()
    if lastBust[src] and now - lastBust[src] < 10 then return end
    lastBust[src] = now
    wanted = math.max(1, math.min(5, math.floor(tonumber(wanted) or 1)))
    local fine = wanted * (Config.Arrest.fine.perStar or 0)
    local taken = 0
    if fine > 0 then
        local bank = tonumber(call('fivex_bank', 'GetBalance', src)) or 0
        local fromBank = math.min(bank, fine)
        if fromBank > 0 and call('fivex_bank', 'RemoveMoney', src, fromBank, ('Police fine (%d stars)'):format(wanted)) then
            taken = taken + fromBank
        end
        local rest = fine - taken
        local cash = tonumber(call('fivex_jobcenter', 'GetPay', src)) or 0
        local fromCash = math.min(cash, rest)
        if fromCash > 0 and call('fivex_jobcenter', 'RemoveCash', src, fromCash) then
            taken = taken + fromCash
        end
    end
    print(('[fivex_police] %s busted at %d stars, fined $%d'):format(GetPlayerName(src) or src, wanted, taken))
    TriggerClientEvent('fivex_police:fined', src, taken, wanted)
end)

AddEventHandler('playerDropped', function() lastBust[source] = nil end)
