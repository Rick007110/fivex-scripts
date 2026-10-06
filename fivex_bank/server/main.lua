local RESOURCE = GetCurrentResourceName()

-- MySQL tables (server/db.lua); the first start imports the old KVP data
FxDB.space('balance', 'fivex_bank_balance', 'int',  { kvp = Config.KvpBalance, key = 'license', value = 'balance' })
FxDB.space('account', 'fivex_bank_account', 'text', { kvp = Config.KvpAccount, key = 'license', value = 'account' })
FxDB.space('owner',   'fivex_bank_owner',   'text', { kvp = Config.KvpOwner,   key = 'account', value = 'license' })
FxDB.space('history', 'fivex_bank_history', 'text', { kvp = Config.KvpHistory, key = 'license', value = 'entries' })

local accounts = {}  -- [src] = { license = string, account = string, balance = int }
local byLicense = {} -- [license] = src
local sessions = {}  -- [src] = { mode = 'branch'|'atm', branch = int|nil }
local buckets = {}

local function L(key, ...)
    local pack = Locales[Config.Locale] or Locales['en'] or {}
    local s = pack[key] or key
    if select('#', ...) > 0 then
        return s:format(...)
    end
    return s
end

local function getLicense(src)
    if type(src) ~= 'number' or src <= 0 then return nil end
    local lic = GetPlayerIdentifierByType(src, 'license')
    if not lic or lic == '' then
        lic = GetPlayerIdentifierByType(src, 'license2')
    end
    if type(lic) ~= 'string' or lic == '' then return nil end
    return lic
end

local function rateOk(src, key, spec)
    spec = spec or Config.RateLimit.Generic
    local now = GetGameTimer()
    local id = tostring(src) .. ':' .. key
    local b = buckets[id]
    if not b or (now - b.start) > spec.window then
        buckets[id] = { start = now, n = 1 }
        return true
    end
    if b.n >= spec.max then return false end
    b.n = b.n + 1
    return true
end

local function notify(src, msg, ntype)
    TriggerClientEvent('fivex_bank:notify', src, msg or '', ntype or 'info')
end

local function hasAce(src, node)
    if type(src) ~= 'number' or src <= 0 then return false end
    if IsPlayerAceAllowed(src, 'fivex_bank') then return true end
    if node and IsPlayerAceAllowed(src, node) then return true end
    return false
end

-- jobcenter wallet = cash
local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[fivex_bank] %s^7'):format(msg))
end

local function jc(fn, ...)
    if GetResourceState('fivex_jobcenter') ~= 'started' then
        warnOnce('stopped', 'fivex_jobcenter is not started — cash is unavailable.')
        return nil
    end
    -- index inside pcall: a missing export throws on lookup, not on call
    local ok, res = pcall(function(...)
        local exp = exports['fivex_jobcenter']
        return exp[fn](exp, ...)
    end, ...)
    if not ok then
        warnOnce(fn, ('fivex_jobcenter export %s failed (%s). Needs fivex_jobcenter 1.1.0+ — restart it, '
            .. 'then re-ensure fivex_bank and the job resources.'):format(fn, tostring(res)))
        return nil
    end
    return res
end

local function getCash(src)
    return tonumber(jc('GetPay', src)) or 0
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

local function loadHistory(license)
    local raw = FxDB.get('history', license)
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, list = pcall(json.decode, raw)
    if not ok or type(list) ~= 'table' then return {} end
    return list
end

local function pushHistory(license, kind, amount, balance, note)
    local list = loadHistory(license)
    table.insert(list, 1, {
        t = os.time(),
        k = kind,
        a = amount,
        b = balance,
        n = type(note) == 'string' and note:sub(1, 64) or '',
    })
    while #list > Config.HistoryMax do
        list[#list] = nil
    end
    FxDB.set('history', license, json.encode(list))
end

local function newAccountNumber()
    for _ = 1, 50 do
        local num = ('FX%06d'):format(math.random(0, 999999))
        local owner = FxDB.get('owner', num)
        if not owner or owner == '' then
            return num
        end
    end
    return nil
end

local function hydrate(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    -- never decide "new account" before the stored accounts are loaded
    if not FxDB.await() then return nil end
    local license = getLicense(src)
    if not license then
        accounts[src] = nil
        return nil
    end
    local acct = FxDB.get('account', license)
    local bal
    if not acct or acct == '' then
        acct = newAccountNumber()
        if not acct then return nil end
        bal = math.max(0, math.floor(Config.StartingBalance or 0))
        FxDB.set('account', license, acct)
        FxDB.set('owner', acct, license)
        FxDB.set('balance', license, bal)
        pushHistory(license, 'open', bal, bal)
    else
        bal = FxDB.get('balance', license) or 0
        if bal < 0 then bal = 0 end
    end
    accounts[src] = { license = license, account = acct, balance = bal }
    byLicense[license] = src
    return accounts[src]
end

local function getAccount(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    return accounts[src] or hydrate(src)
end

local function setBalance(acc, bal)
    acc.balance = bal
    FxDB.set('balance', acc.license, bal)
end

---------------------------------------------------------------------------
-- Ledger
---------------------------------------------------------------------------

local function validAmount(amount, max)
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 then return nil end
    if amount > math.min(max or Config.MaxAmount, Config.MaxAmount) then return nil end
    return amount
end

-- Credit or debit a bank account; returns new balance or nil.
local function credit(src, amount, kind, note)
    local acc = getAccount(src)
    if not acc then return nil end
    setBalance(acc, acc.balance + amount)
    pushHistory(acc.license, kind, amount, acc.balance, note)
    return acc.balance
end

local function debit(src, amount, kind, note)
    local acc = getAccount(src)
    if not acc or acc.balance < amount then return nil end
    setBalance(acc, acc.balance - amount)
    pushHistory(acc.license, kind, -amount, acc.balance, note)
    return acc.balance
end

local function pushBalance(src)
    local acc = accounts[src]
    if not acc then return end
    TriggerClientEvent('fivex_bank:balance', src, acc.balance, acc.account)
end

---------------------------------------------------------------------------
-- Sessions
---------------------------------------------------------------------------

local function nearBranch(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    for i, b in ipairs(Config.Branches) do
        if #(c - b.coords) <= Config.BranchDistance then
            return i
        end
    end
    return nil
end

local function limitsFor(mode)
    if mode == 'atm' then
        return {
            withdraw = math.min(Config.Atm.MaxWithdraw, Config.MaxAmount),
            deposit = math.min(Config.Atm.MaxDeposit, Config.MaxAmount),
            transfer = Config.Atm.AllowTransfer and math.min(Config.Atm.MaxTransfer, Config.MaxAmount) or 0,
        }
    end
    return { withdraw = Config.MaxAmount, deposit = Config.MaxAmount, transfer = Config.MaxAmount }
end

local function nuiState(src)
    local acc = accounts[src]
    local ses = sessions[src]
    if not acc or not ses then return nil end
    return {
        mode = ses.mode,
        location = ses.mode == 'branch' and Config.Branches[ses.branch].label or 'ATM',
        account = acc.account,
        name = GetPlayerName(src) or '',
        balance = acc.balance,
        cash = getCash(src),
        history = loadHistory(acc.license),
        limits = limitsFor(ses.mode),
    }
end

-- Validates the open session; teller sessions re-check distance every action.
local function checkSession(src)
    local ses = sessions[src]
    if not ses then return nil, L('no_session') end
    if ses.mode == 'branch' and not nearBranch(src) then
        sessions[src] = nil
        return nil, L('too_far')
    end
    if not getAccount(src) then return nil, L('no_license') end
    return ses
end

RegisterNetEvent('fivex_bank:open', function(mode)
    local src = source
    if not rateOk(src, 'open', Config.RateLimit.Open) then return end
    if mode ~= 'branch' and mode ~= 'atm' then return end
    if not getAccount(src) then
        notify(src, L('no_license'), 'error')
        return
    end
    local branch
    if mode == 'branch' then
        branch = nearBranch(src)
        if not branch then
            notify(src, L('too_far'), 'error')
            return
        end
    end
    sessions[src] = { mode = mode, branch = branch }
    TriggerClientEvent('fivex_bank:openResult', src, nuiState(src))
end)

RegisterNetEvent('fivex_bank:close', function()
    sessions[source] = nil
end)

local function reply(src, ok, msg, cbId)
    notify(src, msg, ok and 'success' or 'error')
    TriggerClientEvent('fivex_bank:actionResult', src, ok, msg, nuiState(src), cbId)
end

RegisterNetEvent('fivex_bank:deposit', function(amount, cbId)
    local src = source
    if not rateOk(src, 'action', Config.RateLimit.Action) then return reply(src, false, L('rate'), cbId) end
    local ses, err = checkSession(src)
    if not ses then return reply(src, false, err, cbId) end
    local max = limitsFor(ses.mode).deposit
    local amt = validAmount(amount, max)
    if not amt then
        local n = math.floor(tonumber(amount) or 0)
        return reply(src, false, n > max and L('over_limit', max) or L('bad_amount'), cbId)
    end
    if getCash(src) < amt then return reply(src, false, L('no_cash'), cbId) end
    if not jc('RemoveCash', src, amt) then return reply(src, false, L('cash_failed'), cbId) end
    credit(src, amt, 'deposit')
    reply(src, true, L('deposited', amt), cbId)
end)

RegisterNetEvent('fivex_bank:withdraw', function(amount, cbId)
    local src = source
    if not rateOk(src, 'action', Config.RateLimit.Action) then return reply(src, false, L('rate'), cbId) end
    local ses, err = checkSession(src)
    if not ses then return reply(src, false, err, cbId) end
    local max = limitsFor(ses.mode).withdraw
    local amt = validAmount(amount, max)
    if not amt then
        local n = math.floor(tonumber(amount) or 0)
        return reply(src, false, n > max and L('over_limit', max) or L('bad_amount'), cbId)
    end
    if not debit(src, amt, 'withdraw') then
        return reply(src, false, L('no_funds'), cbId)
    end
    if not jc('AddCash', src, amt) then
        -- refund: never lose money if the wallet write fails
        credit(src, amt, 'refund', L('cash_failed'))
        return reply(src, false, L('cash_failed'), cbId)
    end
    reply(src, true, L('withdrew', amt), cbId)
end)

RegisterNetEvent('fivex_bank:transfer', function(target, amount, note, cbId)
    local src = source
    if not rateOk(src, 'action', Config.RateLimit.Action) then return reply(src, false, L('rate'), cbId) end
    local ses, err = checkSession(src)
    if not ses then return reply(src, false, err, cbId) end
    local max = limitsFor(ses.mode).transfer
    if max <= 0 then return reply(src, false, L('atm_no_transfer'), cbId) end
    local amt = validAmount(amount, max)
    if not amt then
        local n = math.floor(tonumber(amount) or 0)
        return reply(src, false, n > max and L('over_limit', max) or L('bad_amount'), cbId)
    end
    if type(target) ~= 'string' then return reply(src, false, L('bad_account'), cbId) end
    target = target:upper():gsub('%s', '')
    if not target:match('^FX%d%d%d%d%d%d$') then return reply(src, false, L('bad_account'), cbId) end
    local toLicense = FxDB.get('owner', target)
    if not toLicense or toLicense == '' then return reply(src, false, L('bad_account'), cbId) end
    local acc = accounts[src]
    if toLicense == acc.license then return reply(src, false, L('self_transfer'), cbId) end
    if acc.balance < amt then return reply(src, false, L('no_funds'), cbId) end

    note = type(note) == 'string' and note:gsub('[%c<>]', ''):sub(1, Config.NoteMaxLength) or ''
    local fromLabel = ('%s (%s)'):format(GetPlayerName(src) or '?', acc.account)
    debit(src, amt, 'transfer_out', note ~= '' and ('%s — %s'):format(target, note) or target)

    local inNote = note ~= '' and ('%s — %s'):format(fromLabel, note) or fromLabel
    local toSrc = byLicense[toLicense]
    if toSrc and accounts[toSrc] then
        credit(toSrc, amt, 'transfer_in', inNote)
        pushBalance(toSrc)
        notify(toSrc, L('received', amt, fromLabel), 'success')
    else
        -- offline recipient: write straight to KVP
        local bal = (FxDB.get('balance', toLicense) or 0) + amt
        FxDB.set('balance', toLicense, bal)
        pushHistory(toLicense, 'transfer_in', amt, bal, inNote)
    end
    reply(src, true, L('sent', amt, target), cbId)
end)

RegisterNetEvent('fivex_bank:requestSync', function()
    local src = source
    if not rateOk(src, 'sync') then return end
    if getAccount(src) then pushBalance(src) end
end)

---------------------------------------------------------------------------
-- Exports (other resources)
---------------------------------------------------------------------------

local function trustedCaller()
    local invoker = GetInvokingResource()
    return invoker == nil or invoker == RESOURCE or Config.TrustedResources[invoker] == true
end

exports('GetBalance', function(src)
    local acc = getAccount(src)
    return acc and acc.balance or 0
end)

exports('GetAccount', function(src)
    local acc = getAccount(src)
    return acc and acc.account or nil
end)

exports('AddMoney', function(src, amount, reason)
    if not trustedCaller() then return nil end
    local amt = validAmount(amount)
    if not amt then return nil end
    reason = type(reason) == 'string' and reason:sub(1, 64) or (GetInvokingResource() or RESOURCE)
    local bal = credit(src, amt, 'income', reason)
    if bal then pushBalance(tonumber(src)) end
    return bal
end)

exports('RemoveMoney', function(src, amount, reason)
    if not trustedCaller() then return nil end
    local amt = validAmount(amount)
    if not amt then return nil end
    reason = type(reason) == 'string' and reason:sub(1, 64) or (GetInvokingResource() or RESOURCE)
    local bal = debit(src, amt, 'purchase', reason)
    if bal then pushBalance(tonumber(src)) end
    return bal
end)

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------

RegisterCommand('bank', function(src)
    if src == 0 then
        print('bank is a player command')
        return
    end
    local acc = getAccount(src)
    if not acc then
        notify(src, L('no_license'), 'error')
        return
    end
    TriggerClientEvent('chat:addMessage', src, {
        color = { 61, 154, 106 },
        args = { 'FiveX Bank', L('status', acc.account, acc.balance, getCash(src)) },
    })
end, false)

local function staffCommand(name, apply)
    RegisterCommand(name, function(src, args)
        if src ~= 0 and not hasAce(src, 'fivex_bank.staff') then
            if src > 0 then notify(src, L('staff_denied'), 'error') end
            return
        end
        local function say(msg, t)
            if src > 0 then notify(src, msg, t) else print(msg) end
        end
        local id = tonumber(args[1] or '')
        local amt = math.floor(tonumber(args[2] or '') or -1)
        if not id or amt < 0 or amt > Config.MaxAmount then
            return say(L('staff_usage', name), 'error')
        end
        if not GetPlayerName(id) then return say(L('staff_bad_id'), 'error') end
        local acc = getAccount(id)
        if not acc then return say(L('no_license'), 'error') end
        local newBal = math.max(0, apply(acc.balance, amt))
        local delta = newBal - acc.balance
        setBalance(acc, newBal)
        pushHistory(acc.license, 'staff', delta, newBal)
        pushBalance(id)
        print(('[fivex_bank] %s %s %s -> $%s (by %s)'):format(name, GetPlayerName(id), amt, newBal,
            src > 0 and (GetPlayerName(src) or src) or 'console'))
        say(L('staff_done', GetPlayerName(id), newBal), 'success')
    end, false)
end

staffCommand('bankgive', function(bal, amt) return bal + amt end)
staffCommand('banktake', function(bal, amt) return bal - amt end)
staffCommand('bankset',  function(_, amt) return amt end)

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(500, function()
        hydrate(src)
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local acc = accounts[src]
    if acc and byLicense[acc.license] == src then
        byLicense[acc.license] = nil
    end
    accounts[src] = nil
    sessions[src] = nil
    for k in pairs(buckets) do
        if k:find('^' .. tostring(src) .. ':') then
            buckets[k] = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res == 'fivex_jobcenter' then
        warned = {}
        return
    end
    if res ~= RESOURCE then return end
    math.randomseed(os.time())
    for _, id in ipairs(GetPlayers()) do
        hydrate(tonumber(id))
    end
end)
