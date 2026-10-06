-- KnoWay server: ride state, fares, payment. The booker's client drives the van; the server checks
-- positions itself (entity coords) before charging, refunding or completing.

local rides = {}   -- [src] = ride
local buckets = {}
local nextId = 0

local function L(key, ...)
    local pack = Locales[Config.Locale] or Locales['en'] or {}
    local s = pack[key] or key
    if select('#', ...) > 0 then
        return s:format(...)
    end
    return s
end

local function rateOk(src)
    local spec = Config.RateLimit
    local now = GetGameTimer()
    local b = buckets[src]
    if not b or (now - b.start) > spec.window then
        buckets[src] = { start = now, n = 1 }
        return true
    end
    if b.n >= spec.max then return false end
    b.n = b.n + 1
    return true
end

local function notify(src, msg, ntype)
    TriggerClientEvent('fivex_knoway:notify', src, msg, ntype or 'info')
end

---------------------------------------------------------------------------
-- Money: bank first, then cash
---------------------------------------------------------------------------

local warned = {}
local function call(res, fn, ...)
    if GetResourceState(res) ~= 'started' then return nil end
    local ok, r = pcall(function(...)
        local exp = exports[res]
        return exp[fn](exp, ...)
    end, ...)
    if not ok then
        if not warned[res .. fn] then
            warned[res .. fn] = true
            print(('^3[fivex_knoway] %s export %s failed (%s). Is fivex_knoway in its TrustedResources?^7'):format(res, fn, tostring(r)))
        end
        return nil
    end
    return r
end

local function balances(src)
    return tonumber(call('fivex_bank', 'GetBalance', src)) or 0, tonumber(call('fivex_jobcenter', 'GetPay', src)) or 0
end

local function charge(src, amount)
    local bank, cash = balances(src)
    if bank >= amount then
        if call('fivex_bank', 'RemoveMoney', src, amount, 'KnoWay ride') then return 'bank' end
        return nil, 'pay_failed'
    end
    if cash >= amount then
        if call('fivex_jobcenter', 'RemoveCash', src, amount) then return 'cash' end
        return nil, 'pay_failed'
    end
    return nil, 'no_funds'
end

local function refund(src, method, amount)
    if amount <= 0 then return end
    if method == 'cash' then
        call('fivex_jobcenter', 'AddCash', src, amount)
    else
        call('fivex_bank', 'AddMoney', src, amount, 'KnoWay refund')
    end
end

---------------------------------------------------------------------------
-- Rides
---------------------------------------------------------------------------

local function fareFor(a, b)
    local d = #(vector2(a.x, a.y) - vector2(b.x, b.y))
    local km = d * Config.Fare.roadFactor / 1000.0
    local fare = math.floor(Config.Fare.base + km * Config.Fare.perKm + 0.5)
    return math.max(Config.Fare.minimum, fare), km, d
end

-- lowest number not used by another active ride -> KNOWAY1, KNOWAY2, …
local function freePlateNo()
    local used = {}
    for _, r in pairs(rides) do used[r.plateNo] = true end
    local n = 1
    while used[n] do n = n + 1 end
    return n
end

local function plateText(n)
    local suffix = tostring(n)
    return Config.Plate:upper():sub(1, 8 - #suffix) .. suffix
end

-- Weighted pick from Config.Vehicles, skipping custom vehicles whose resource isn't running.
local function pickVehicle()
    local pool, total = {}, 0
    for i, v in ipairs(Config.Vehicles) do
        if (not v.resource or GetResourceState(v.resource) == 'started') and (v.weight or 0) > 0 then
            pool[#pool + 1] = i
            total = total + v.weight
        end
    end
    if total <= 0 then return 1 end
    local roll = math.random() * total
    for _, i in ipairs(pool) do
        roll = roll - Config.Vehicles[i].weight
        if roll <= 0 then return i end
    end
    return pool[#pool]
end

local function activeCount()
    local n = 0
    for _ in pairs(rides) do n = n + 1 end
    return n
end

local function public(r)
    return {
        id = r.id,
        state = r.state,
        dest = r.dest,
        fare = r.fare,
        km = r.km,
        paid = r.paid,
        refund = r.refund,
        plate = plateText(r.plateNo),
        vehicle = r.vehicle,
        vehicleLabel = Config.Vehicles[r.vehicle] and Config.Vehicles[r.vehicle].label or 'KnoWay',
        reason = r.reason,
    }
end

local function push(src)
    local r = rides[src]
    if r then TriggerClientEvent('fivex_knoway:state', src, public(r)) end
end

local function entity(netId)
    if not netId then return nil end
    local e = NetworkGetEntityFromNetworkId(netId)
    if e and e ~= 0 and DoesEntityExist(e) then return e end
    return nil
end

local function deleteEntities(r)
    for _, net in ipairs({ r.netPed, r.netVeh }) do
        local e = entity(net)
        if e then DeleteEntity(e) end
    end
end

-- Final state for the booker, then forget the ride.
local function finish(src, state, reason)
    local r = rides[src]
    if not r then return end
    r.state = state
    r.reason = reason
    push(src)
    rides[src] = nil
end

RegisterNetEvent('fivex_knoway:request', function(dest)
    local src = source
    if not rateOk(src) then return notify(src, L('rate'), 'error') end
    if rides[src] then return notify(src, L('busy'), 'error') end
    if activeCount() >= Config.MaxActiveRides then return notify(src, L('no_cars'), 'error') end

    -- destination: a configured place (by index) or a validated map waypoint
    local d
    if type(dest) == 'table' and dest.kind == 'place' then
        local p = Config.Places[tonumber(dest.index) or 0]
        if p then d = { label = p.label, area = p.area, x = p.coords.x, y = p.coords.y, z = p.coords.z, exact = p.exact == true } end
    elseif type(dest) == 'table' and dest.kind == 'waypoint' then
        local x, y, z = tonumber(dest.x), tonumber(dest.y), tonumber(dest.z) or 0.0
        local B = Config.Bounds
        if x and y and x >= B.minX and x <= B.maxX and y >= B.minY and y <= B.maxY then
            d = {
                label = type(dest.label) == 'string' and dest.label:sub(1, 48) or 'Map destination',
                area = type(dest.area) == 'string' and dest.area:sub(1, 48) or '',
                x = x, y = y, z = z,
            }
        end
    end
    if not d then return notify(src, L('bad_dest'), 'error') end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local pickup = GetEntityCoords(ped)
    local fare, km, dist = fareFor(pickup, d)
    if dist < Config.MinTripDistance then return notify(src, L('too_close'), 'error') end
    local bank, cash = balances(src)
    if bank < fare and cash < fare then return notify(src, L('no_funds', fare), 'error') end

    nextId = nextId + 1
    rides[src] = {
        id = nextId,
        plateNo = freePlateNo(),
        vehicle = pickVehicle(),
        state = 'searching',
        pickup = pickup,
        dest = d,
        fare = fare,
        km = math.floor(km * 10 + 0.5) / 10,
        paid = 0,
        refund = 0,
        createdAt = os.time(),
    }
    push(src)
    local id = nextId
    SetTimeout(math.random(Config.DispatchDelay.min, Config.DispatchDelay.max), function()
        local r = rides[src]
        if not r or r.id ~= id or r.state ~= 'searching' then return end
        r.state = 'dispatched'
        push(src)
        TriggerClientEvent('fivex_knoway:dispatch', src, public(r))
    end)
end)

RegisterNetEvent('fivex_knoway:spawned', function(netVeh, netPed)
    local src = source
    local r = rides[src]
    if not r or r.state ~= 'dispatched' then return end
    r.netVeh, r.netPed = tonumber(netVeh), tonumber(netPed)
    r.state = 'enroute'
    push(src)
end)

RegisterNetEvent('fivex_knoway:spawnFailed', function()
    local src = source
    local r = rides[src]
    if not r or (r.state ~= 'dispatched' and r.state ~= 'enroute') then return end
    deleteEntities(r)
    notify(src, L('vehicle_failed'), 'error')
    finish(src, 'cancelled', 'vehicle_failed')
end)

-- Booker client hit an error mid-ride: clean up in any state and give back whatever was paid.
RegisterNetEvent('fivex_knoway:failed', function()
    local src = source
    local r = rides[src]
    if not r then return end
    deleteEntities(r)
    local back = (r.paid or 0) - (r.refund or 0)
    if back > 0 then
        refund(src, r.method, back)
        r.refund = (r.refund or 0) + back
        notify(src, L('refunded', back), 'success')
    end
    notify(src, L('vehicle_failed'), 'error')
    finish(src, 'cancelled', 'vehicle_failed')
end)

RegisterNetEvent('fivex_knoway:arrived', function()
    local src = source
    local r = rides[src]
    if not r or r.state ~= 'enroute' then return end
    local veh = entity(r.netVeh)
    if not veh or #(GetEntityCoords(veh) - GetEntityCoords(GetPlayerPed(src))) > 150.0 then return end
    r.state = 'arrived'
    push(src)
end)

RegisterNetEvent('fivex_knoway:go', function()
    local src = source
    if not rateOk(src) then return end
    local r = rides[src]
    if not r or r.state ~= 'arrived' then return end
    local veh = entity(r.netVeh)
    if not veh or GetVehiclePedIsIn(GetPlayerPed(src), false) ~= veh then
        return notify(src, L('not_inside'), 'error')
    end
    local method, err = charge(src, r.fare)
    if not method then
        notify(src, err == 'no_funds' and L('no_funds', r.fare) or L(err), 'error')
        return TriggerClientEvent('fivex_knoway:goResult', src, false)
    end
    r.method = method
    r.paid = r.fare
    r.state = 'riding'
    r.rideFrom = GetEntityCoords(veh)
    notify(src, L('paid', r.fare), 'success')
    push(src)
    TriggerClientEvent('fivex_knoway:goResult', src, true)
end)

RegisterNetEvent('fivex_knoway:dropped', function()
    local src = source
    local r = rides[src]
    if not r or r.state ~= 'riding' then return end
    local veh = entity(r.netVeh)
    -- the client stops at the nearest usable road, which can be a way from the pin (pier, plaza…)
    if not veh or #(vector2(GetEntityCoords(veh).x, GetEntityCoords(veh).y) - vector2(r.dest.x, r.dest.y)) > 320.0 then return end
    r.state = 'dropoff'
    push(src)
end)

-- Cancel at any point. Mid-ride: refund the unused share of the distance part of the fare.
RegisterNetEvent('fivex_knoway:cancel', function()
    local src = source
    if not rateOk(src) then return end
    local r = rides[src]
    if not r then return end
    if r.state == 'searching' then
        notify(src, L('cancelled'), 'info')
        return finish(src, 'cancelled', 'user')
    end
    if r.state == 'riding' then
        local veh = entity(r.netVeh)
        local total = #(vector2(r.rideFrom.x, r.rideFrom.y) - vector2(r.dest.x, r.dest.y))
        local left = veh and #(vector2(GetEntityCoords(veh).x, GetEntityCoords(veh).y) - vector2(r.dest.x, r.dest.y)) or 0.0
        local share = total > 0 and math.max(0.0, math.min(1.0, left / total)) or 0.0
        local amount = math.floor((r.paid - Config.Fare.base) * share)
        if amount > 0 then
            refund(src, r.method, amount)
            r.refund = amount
            notify(src, L('refunded', amount), 'success')
        end
        r.state = 'dropoff'
        r.reason = 'user'
        push(src)
        return TriggerClientEvent('fivex_knoway:cancelled', src, 'dropoff')
    end
    if r.state == 'dispatched' or r.state == 'enroute' or r.state == 'arrived' then
        r.state = 'leaving'
        r.reason = 'user'
        notify(src, L('cancelled'), 'info')
        push(src)
        return TriggerClientEvent('fivex_knoway:cancelled', src, 'leave')
    end
end)

-- Booker client: nobody got in in time.
RegisterNetEvent('fivex_knoway:noShow', function()
    local src = source
    local r = rides[src]
    if not r or r.state ~= 'arrived' then return end
    r.state = 'leaving'
    r.reason = 'no_show'
    notify(src, L('no_show'), 'error')
    push(src)
end)

-- Ask every player still sitting in the van to get out.
RegisterNetEvent('fivex_knoway:ejectRiders', function()
    local src = source
    local r = rides[src]
    if not r or (r.state ~= 'dropoff' and r.state ~= 'leaving') then return end
    local veh = entity(r.netVeh)
    if not veh then return end
    for _, id in ipairs(GetPlayers()) do
        local p = tonumber(id)
        if GetVehiclePedIsIn(GetPlayerPed(p), false) == veh then
            TriggerClientEvent('fivex_knoway:exitVehicle', p, r.netVeh)
        end
    end
end)

RegisterNetEvent('fivex_knoway:leaving', function()
    local src = source
    local r = rides[src]
    if not r or r.state == 'leaving' then return end
    if r.state == 'dropoff' or r.state == 'arrived' or r.state == 'enroute' then
        r.state = 'leaving'
        push(src)
    end
end)

RegisterNetEvent('fivex_knoway:finished', function()
    local src = source
    local r = rides[src]
    if not r then return end
    deleteEntities(r)
    if r.paid > 0 then
        finish(src, 'complete', r.reason)
    else
        finish(src, 'cancelled', r.reason or 'user')
    end
end)

---------------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------------

CreateThread(function()
    while true do
        Wait(30000)
        local now = os.time()
        for src, r in pairs(rides) do
            if now - r.createdAt > Config.MaxRideMinutes * 60 or not GetPlayerName(src) then
                deleteEntities(r)
                if GetPlayerName(src) then notify(src, L('timed_out'), 'error') end
                TriggerClientEvent('fivex_knoway:reset', src)
                rides[src] = nil
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local r = rides[src]
    if r then deleteEntities(r) end
    rides[src] = nil
    buckets[src] = nil
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, r in pairs(rides) do deleteEntities(r) end
end)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then math.randomseed(os.time()) end
end)

-- /knoway_van: staff can spawn a styled KnoWay van for themselves
RegisterNetEvent('fivex_knoway:requestVan', function(which)
    local src = source
    if IsPlayerAceAllowed(src, 'fivex_knoway') or IsPlayerAceAllowed(src, Config.SpawnAce) then
        TriggerClientEvent('fivex_knoway:spawnVan', src, type(which) == 'string' and which:sub(1, 32) or nil)
    else
        notify(src, ('You need %s to spawn a KnoWay van.'):format(Config.SpawnAce), 'error')
    end
end)
