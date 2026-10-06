local RESOURCE = GetCurrentResourceName()

-- MySQL tables (server/db.lua); the first start imports the old KVP data
FxDB.space('job', 'fivex_jobcenter_job', 'text', { kvp = Config.KvpJob, key = 'license', value = 'job' })
FxDB.space('pay', 'fivex_jobcenter_pay', 'int',  { kvp = Config.KvpPay, key = 'license', value = 'cash' })

local players = {} -- [src] = { job = string|nil, duty = bool, balance = int, license = string }
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

local function jobLabel(id)
    if not id then return L('job_none') end
    for i = 1, #Config.Jobs do
        if Config.Jobs[i].id == id then return Config.Jobs[i].label end
    end
    return id
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

local function distToCenter(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return 9999.0 end
    local c = GetEntityCoords(ped)
    local p = Config.Center
    return #(c - vector3(p.x, p.y, p.z))
end

local function persist(st)
    if not st or not st.license then return end
    FxDB.set('job', st.license, st.job or '')
    FxDB.set('pay', st.license, st.balance or 0)
end

local function push(src)
    local st = players[src]
    local job = (st and st.job and st.job ~= '') and st.job or false
    local duty = st and st.duty or false
    local bal = st and st.balance or 0
    local pid = Player(src)
    if pid and pid.state then
        pid.state:set('fivex_job', job, true)
        pid.state:set('fivex_duty', duty, true)
        pid.state:set('fivex_pay', bal, true)
    end
    TriggerClientEvent('fivex_jobcenter:clientJob', src, job, bal, duty)
end

local function hydrate(src)
    src = tonumber(src)
    if not src or src <= 0 then return end
    -- a default (empty) record must never be created before the stored ones are loaded
    if not FxDB.await() then return end
    local license = getLicense(src)
    local job, bal = nil, 0
    if license then
        local saved = FxDB.get('job', license)
        if type(saved) == 'string' and saved ~= '' and Config.ValidJobs[saved] then
            job = saved
        end
        bal = FxDB.get('pay', license) or 0
        if bal < 0 then bal = 0 end
    end
    players[src] = {
        job = job,
        duty = false,
        balance = bal,
        license = license,
    }
    push(src)
end

local function nuiState(src)
    local st = players[src] or { job = nil, duty = false, balance = 0 }
    local job = st.job
    return {
        job = job or false,
        jobLabel = job and jobLabel(job) or 'Unemployed',
        balance = st.balance or 0,
        duty = st.duty and true or false,
        jobs = Config.Jobs,
    }
end

local function setJobInternal(src, jobId)
    src = tonumber(src)
    if not src then return false, 'bad_src' end
    if jobId == 'none' or jobId == '' then jobId = nil end
    if jobId ~= nil then
        if type(jobId) ~= 'string' or not Config.ValidJobs[jobId] then
            return false, 'invalid_job'
        end
    end
    local st = players[src]
    if not st then
        hydrate(src)
        st = players[src]
    end
    if not st then return false, 'no_player' end
    if not st.license then return false, 'no_license' end
    local old = st.job
    st.job = jobId
    st.duty = false
    persist(st)
    push(src)
    TriggerEvent('fivex_jobcenter:jobChanged', src, old, jobId)
    return true, old
end

local function hasAce(src, node)
    if type(src) ~= 'number' or src <= 0 then return false end
    if IsPlayerAceAllowed(src, 'fivex_jobcenter') then return true end
    if node and IsPlayerAceAllowed(src, node) then return true end
    return false
end

local function notify(src, msg, ntype)
    TriggerClientEvent('fivex_jobcenter:notify', src, msg or '', ntype or 'info')
end

exports('GetJob', function(src)
    src = tonumber(src)
    local st = src and players[src]
    if not st or not st.job or st.job == '' then return nil end
    return st.job
end)

exports('HasJob', function(src, jobId)
    src = tonumber(src)
    local st = src and players[src]
    return st ~= nil and st.job ~= nil and st.job == jobId
end)

exports('IsDuty', function(src)
    src = tonumber(src)
    local st = src and players[src]
    return st ~= nil and st.duty == true
end)

exports('SetDuty', function(src, bool)
    src = tonumber(src)
    if not src then return false end
    local st = players[src]
    if not st or not st.job or st.job == '' then return false end
    st.duty = bool and true or false
    push(src)
    TriggerEvent('fivex_jobcenter:dutyChanged', src, st.job, st.duty)
    return true
end)

exports('GetPay', function(src)
    src = tonumber(src)
    local st = src and players[src]
    return st and st.balance or 0
end)

exports('AddPay', function(src, amount, reason)
    src = tonumber(src)
    if not src then return nil end
    local st = players[src]
    if not st or not st.duty then return nil end
    if not st.license then return nil end
    amount = math.floor(tonumber(amount) or 0)
    if amount < Config.PayClamp.min or amount > Config.PayClamp.max then return nil end
    if not rateOk(src, 'pay', Config.RateLimit.Pay) then return nil end
    reason = type(reason) == 'string' and reason:sub(1, 64) or 'job'
    st.balance = (st.balance or 0) + amount
    persist(st)
    push(src)
    notify(src, ('+$%s  (%s)  wallet $%s'):format(amount, reason, st.balance), 'success')
    return st.balance
end)

-- Wallet = cash. Only resources in Config.TrustedResources may move it (no duty gate, no 5000 clamp).
local function cashCaller()
    local invoker = GetInvokingResource()
    return invoker == nil or invoker == RESOURCE or Config.TrustedResources[invoker] == true
end

local function cashState(src)
    src = tonumber(src)
    if not src or src <= 0 or not GetPlayerName(src) then return nil end
    if not players[src] then hydrate(src) end
    local st = players[src]
    if not st or not st.license then return nil end
    return st
end

local function cashAmount(amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > Config.CashClamp then return nil end
    return amount
end

exports('AddCash', function(src, amount)
    if not cashCaller() then return nil end
    local st = cashState(src)
    amount = cashAmount(amount)
    if not st or not amount then return nil end
    st.balance = (st.balance or 0) + amount
    persist(st)
    push(tonumber(src))
    return st.balance
end)

exports('RemoveCash', function(src, amount)
    if not cashCaller() then return nil end
    local st = cashState(src)
    amount = cashAmount(amount)
    if not st or not amount then return nil end
    if (st.balance or 0) < amount then return nil end
    st.balance = st.balance - amount
    persist(st)
    push(tonumber(src))
    return st.balance
end)

exports('SetJob', function(src, jobId, actorSrc)
    src = tonumber(src)
    local invoker = GetInvokingResource()
    if invoker and invoker ~= RESOURCE then
        actorSrc = tonumber(actorSrc)
        if not actorSrc or not hasAce(actorSrc, 'fivex_jobcenter.staff') then
            return false
        end
    end
    local ok = setJobInternal(src, jobId)
    return ok and true or false
end)

local function applyJob(src, jobId)
    if not rateOk(src, 'apply', Config.RateLimit.Apply) then
        return false, L('rate')
    end
    if distToCenter(src) > Config.ApplyDistance then
        return false, L('too_far')
    end
    local st = players[src]
    if not st then
        hydrate(src)
        st = players[src]
    end
    if not st or not st.license then
        return false, L('no_license')
    end
    if jobId == nil then
        if not st.job then return false, L('not_employed') end
        local ok = setJobInternal(src, nil)
        if ok then return true, L('left') end
        return false, L('no_license')
    end
    if type(jobId) ~= 'string' or not Config.ValidJobs[jobId] then
        return false, L('invalid_job')
    end
    if st.job == jobId then
        return false, L('already')
    end
    local old = st.job
    local ok = setJobInternal(src, jobId)
    if not ok then return false, L('no_license') end
    if old then
        return true, L('switched', jobLabel(old), jobLabel(jobId))
    end
    return true, L('applied', jobLabel(jobId))
end

RegisterNetEvent('fivex_jobcenter:requestSync', function()
    local src = source
    -- Already hydrated: just re-push. Re-hydrating would silently reset duty without dutyChanged.
    if players[src] then
        push(src)
    else
        hydrate(src)
    end
end)

RegisterNetEvent('fivex_jobcenter:open', function()
    local src = source
    if distToCenter(src) > (Config.OpenDistance + 0.6) then
        notify(src, L('opened_remote'), 'error')
        TriggerClientEvent('fivex_jobcenter:openDenied', src)
        return
    end
    if not players[src] then hydrate(src) end
    TriggerClientEvent('fivex_jobcenter:openResult', src, nuiState(src))
end)

RegisterNetEvent('fivex_jobcenter:apply', function(jobId, cbId)
    local src = source
    local ok, msg = applyJob(src, jobId)
    notify(src, msg, ok and 'success' or 'error')
    TriggerClientEvent('fivex_jobcenter:applyResult', src, ok, msg, nuiState(src), cbId)
end)

RegisterNetEvent('fivex_jobcenter:leave', function(cbId)
    local src = source
    local ok, msg = applyJob(src, nil)
    notify(src, msg, ok and 'success' or 'error')
    TriggerClientEvent('fivex_jobcenter:applyResult', src, ok, msg, nuiState(src), cbId)
end)

RegisterCommand('job', function(src)
    if src == 0 then
        print('job is a player command')
        return
    end
    if not players[src] then hydrate(src) end
    local st = players[src] or { job = nil, duty = false, balance = 0 }
    local msg = L('status', jobLabel(st.job), st.duty and L('duty_on') or L('duty_off'), tostring(st.balance or 0))
    TriggerClientEvent('chat:addMessage', src, {
        color = { 91, 141, 239 },
        args = { 'FiveX Jobs', msg },
    })
end, false)

RegisterCommand('setjob', function(src, args)
    if src ~= 0 and not hasAce(src, 'fivex_jobcenter.staff') then
        if src > 0 then notify(src, L('staff_denied'), 'error') end
        return
    end
    local id = tonumber(args[1] or '')
    local job = args[2]
    if not id or not job then
        if src > 0 then notify(src, L('staff_usage'), 'error') else print(L('staff_usage')) end
        return
    end
    if job == 'none' then job = nil end
    if job ~= nil and not Config.ValidJobs[job] then
        if src > 0 then notify(src, L('invalid_job'), 'error') end
        return
    end
    if not GetPlayerName(id) then
        if src > 0 then notify(src, L('staff_bad_id'), 'error') else print(L('staff_bad_id')) end
        return
    end
    if not players[id] then hydrate(id) end
    local ok, err = setJobInternal(id, job)
    if not ok then
        local msg = err == 'no_license' and L('no_license') or L('invalid_job')
        if src > 0 then notify(src, msg, 'error') else print(msg) end
        return
    end
    local name = GetPlayerName(id) or tostring(id)
    if job then
        notify(id, L('applied', jobLabel(job)), 'success')
        if src > 0 then notify(src, L('staff_set', name, jobLabel(job)), 'success') end
    else
        notify(id, L('left'), 'info')
        if src > 0 then notify(src, L('staff_cleared', name), 'success') end
    end
end, false)

RegisterCommand('jobcancel', function(src)
    if src == 0 then return end
    if not players[src] or not players[src].duty then
        notify(src, L('not_on_duty'), 'error')
        return
    end
    TriggerEvent('fivex_jobcenter:internalCancel', src)
    TriggerClientEvent('fivex_jobcenter:clientCancel', src)
    notify(src, L('cancelled'), 'info')
end, false)

AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(500, function()
        hydrate(src)
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    players[src] = nil
    for k in pairs(buckets) do
        if k:find('^' .. tostring(src) .. ':') then
            buckets[k] = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= RESOURCE then return end
    for _, id in ipairs(GetPlayers()) do
        hydrate(tonumber(id))
    end
end)

