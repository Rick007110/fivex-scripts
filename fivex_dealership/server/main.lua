local RESOURCE = GetCurrentResourceName()

-- Vehicles marked 'out' during an earlier server run come back as stored (free) after a restart.
local BOOT = tostring(os.time())

-- MySQL tables (server/db.lua); the first start imports the old KVP data
FxDB.space('vehicles', 'fivex_dealership_vehicles', 'text', { kvp = Config.KvpVehicles, key = 'license', value = 'vehicles' })
FxDB.space('plates',   'fivex_dealership_plates',   'text', { kvp = Config.KvpPlate,    key = 'plate',   value = 'license' })

local out = {}      -- [license] = { plate = string, entity = int }  (one car out per player)
local sessions = {} -- [src] = { kind = 'showroom'|'garage', garage = int|nil }
local busy = {}     -- [src] = true while an action that waits is running
local buckets = {}

local catalogByModel = {}
for _, v in ipairs(Config.Catalog) do catalogByModel[v.model] = v end
local colorById = {}
for _, c in ipairs(Config.Colors) do colorById[c.id] = c end

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
    TriggerClientEvent('fivex_dealership:notify', src, msg or '', ntype or 'info')
end

local function hasAce(src, node)
    if type(src) ~= 'number' or src <= 0 then return false end
    if IsPlayerAceAllowed(src, 'fivex_dealership') then return true end
    if node and IsPlayerAceAllowed(src, node) then return true end
    return false
end

---------------------------------------------------------------------------
-- Money (bank = fivex_bank, cash = fivex_jobcenter wallet)
---------------------------------------------------------------------------

local warned = {}
local function warnOnce(key, msg)
    if warned[key] then return end
    warned[key] = true
    print(('^3[fivex_dealership] %s^7'):format(msg))
end

local function call(res, fn, ...)
    if GetResourceState(res) ~= 'started' then
        warnOnce(res, res .. ' is not started — payments are unavailable.')
        return nil
    end
    -- index inside pcall: a missing export throws on lookup, not on call
    local ok, r = pcall(function(...)
        local exp = exports[res]
        return exp[fn](exp, ...)
    end, ...)
    if not ok then
        warnOnce(res .. ':' .. fn, ('%s export %s failed (%s). Check that %s is up to date and listed in its TrustedResources.')
            :format(res, fn, tostring(r), res))
        return nil
    end
    return r
end

local function bankBalance(src) return tonumber(call('fivex_bank', 'GetBalance', src)) or 0 end
local function cashBalance(src) return tonumber(call('fivex_jobcenter', 'GetPay', src)) or 0 end

local function charge(src, method, amount, reason)
    if method == 'bank' then
        if bankBalance(src) < amount then return false, 'no_funds_bank' end
        if not call('fivex_bank', 'RemoveMoney', src, amount, reason) then return false, 'pay_failed' end
        return true
    elseif method == 'cash' then
        if cashBalance(src) < amount then return false, 'no_funds_cash' end
        if not call('fivex_jobcenter', 'RemoveCash', src, amount) then return false, 'pay_failed' end
        return true
    end
    return false, 'bad_method'
end

local function refund(src, method, amount, reason)
    if method == 'bank' then
        return call('fivex_bank', 'AddMoney', src, amount, reason) ~= nil
    end
    return call('fivex_jobcenter', 'AddCash', src, amount) ~= nil
end

-- Fees come out of the bank first, then cash. Returns ok, errKey, method.
local function chargeFee(src, amount, reason)
    if bankBalance(src) >= amount then
        local ok, err = charge(src, 'bank', amount, reason)
        return ok, err, 'bank'
    end
    if cashBalance(src) >= amount then
        local ok, err = charge(src, 'cash', amount, reason)
        return ok, err, 'cash'
    end
    return false, 'no_funds_fee'
end

---------------------------------------------------------------------------
-- Persistence
---------------------------------------------------------------------------

local function loadVehicles(license)
    local raw = FxDB.get('vehicles', license)
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, list = pcall(json.decode, raw)
    if not ok or type(list) ~= 'table' then return {} end
    for _, v in ipairs(list) do
        if v.state == 'out' and v.outBoot ~= BOOT then
            v.state = 'stored'
        end
    end
    return list
end

local function saveVehicles(license, list)
    FxDB.set('vehicles', license, json.encode(list))
end

local function findVehicle(list, plate)
    for i, v in ipairs(list) do
        if v.plate == plate then return v, i end
    end
    return nil
end

local PLATE_LETTERS = 'ABCDEFGHJKLMNPRSTUVWXYZ'
local function letter()
    local i = math.random(1, #PLATE_LETTERS)
    return PLATE_LETTERS:sub(i, i)
end

local function newPlate()
    for _ = 1, 50 do
        local plate = ('%d%d%s%s%s%d%d%d'):format(math.random(0, 9), math.random(0, 9),
            letter(), letter(), letter(), math.random(0, 9), math.random(0, 9), math.random(0, 9))
        local owner = FxDB.get('plates', plate)
        if not owner or owner == '' then return plate end
    end
    return nil
end

local function addVehicle(license, entry, colorId, paid)
    local plate = newPlate()
    if not plate then return nil end
    local list = loadVehicles(license)
    local veh = {
        plate = plate,
        model = entry.model,
        label = entry.label,
        brand = entry.brand,
        color = colorId,
        paid = paid,
        state = 'stored',
        engine = 1000.0,
        body = 1000.0,
        dirt = 0.0,
        bought = os.time(),
    }
    list[#list + 1] = veh
    saveVehicles(license, list)
    FxDB.set('plates', plate, license)
    return veh
end

local function patchVehicle(license, plate, patch)
    local list = loadVehicles(license)
    local veh = findVehicle(list, plate)
    if not veh then return nil end
    for k, v in pairs(patch) do veh[k] = v end
    saveVehicles(license, list)
    return veh
end

local function srcByLicense(license)
    for _, id in ipairs(GetPlayers()) do
        local n = tonumber(id)
        if getLicense(n) == license then return n end
    end
    return nil
end

---------------------------------------------------------------------------
-- World vehicles
---------------------------------------------------------------------------

local function clamp(n, lo, hi)
    n = tonumber(n) or hi
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function liveEntity(license)
    local o = out[license]
    if o and o.entity and DoesEntityExist(o.entity) then return o.entity end
    return nil
end

local function freeSpot(spots)
    local vehicles = GetAllVehicles()
    for _, s in ipairs(spots) do
        local p = vector3(s.x, s.y, s.z)
        local blocked = false
        for _, v in ipairs(vehicles) do
            if DoesEntityExist(v) and #(GetEntityCoords(v) - p) < 3.0 then
                blocked = true
                break
            end
        end
        if not blocked then return s end
    end
    return nil
end

-- Spawns veh for src at spot and marks it out. Returns entity or nil (vehicle stays stored).
local function spawnVehicle(src, license, veh, spot)
    local entry = catalogByModel[veh.model]
    local ent = CreateVehicleServerSetter(joaat(veh.model), (entry and entry.type) or 'automobile',
        spot.x, spot.y, spot.z, spot.w)
    local untilT = GetGameTimer() + 3000
    while (not ent or ent == 0 or not DoesEntityExist(ent)) and GetGameTimer() < untilT do
        Wait(0)
    end
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    SetVehicleNumberPlateText(ent, veh.plate)
    SetVehicleColours(ent, veh.color or 0, veh.color or 0)
    if SetEntityOrphanMode then SetEntityOrphanMode(ent, 2) end -- we clean up ourselves
    Entity(ent).state:set('fivex_plate', veh.plate, true)

    out[license] = { plate = veh.plate, entity = ent }
    patchVehicle(license, veh.plate, { state = 'out', outBoot = BOOT })
    TriggerClientEvent('fivex_dealership:spawned', src, NetworkGetNetworkIdFromEntity(ent), {
        engine = math.max(tonumber(veh.engine) or 1000.0, 100.0),
        body = math.max(tonumber(veh.body) or 1000.0, 100.0),
        dirt = tonumber(veh.dirt) or 0.0,
    })
    return ent
end

-- Saves condition, deletes the car. Wrecked cars stay 'out' (lost) and need a paid recovery.
-- Returns 'stored', 'wrecked' or nil.
local function parkOut(license)
    local o = out[license]
    if not o then return nil end
    out[license] = nil
    local list = loadVehicles(license)
    local veh = findVehicle(list, o.plate)
    local result = nil
    if veh then
        if o.entity and DoesEntityExist(o.entity) then
            local engine = GetVehicleEngineHealth(o.entity)
            veh.engine = clamp(engine, 0.0, 1000.0)
            veh.body = clamp(GetVehicleBodyHealth(o.entity), 0.0, 1000.0)
            veh.dirt = clamp(GetVehicleDirtLevel(o.entity), 0.0, 15.0)
            if (tonumber(engine) or 0) <= 0 then
                veh.state = 'out'
                veh.outBoot = BOOT
                result = 'wrecked'
            else
                veh.state = 'stored'
                result = 'stored'
            end
        else
            veh.state = 'stored'
            result = 'stored'
        end
        saveVehicles(license, list)
    end
    if o.entity and DoesEntityExist(o.entity) then DeleteEntity(o.entity) end
    return result, veh
end

---------------------------------------------------------------------------
-- NUI payloads
---------------------------------------------------------------------------

local function vehiclesPayload(license)
    local list = loadVehicles(license)
    local livePlate = liveEntity(license) and out[license].plate or nil
    local res = {}
    for _, v in ipairs(list) do
        local status = 'stored'
        if v.state == 'out' then
            status = (v.plate == livePlate) and 'out' or 'lost'
        end
        res[#res + 1] = {
            plate = v.plate,
            model = v.model,
            label = v.label or v.model,
            brand = v.brand or (catalogByModel[v.model] and catalogByModel[v.model].brand) or '',
            color = v.color or 0,
            status = status,
            value = math.floor((tonumber(v.paid) or 0) * Config.SellBackPercent / 100),
            engine = math.floor((tonumber(v.engine) or 1000) / 10),
            body = math.floor((tonumber(v.body) or 1000) / 10),
        }
    end
    return res
end

local function statePayload(src)
    local ses = sessions[src]
    local license = getLicense(src)
    if not ses or not license then return nil end
    return {
        kind = ses.kind,
        location = ses.kind == 'garage' and Config.Garages[ses.garage].label or Config.Showroom.label,
        vehicles = vehiclesPayload(license),
        bank = bankBalance(src),
        cash = cashBalance(src),
        max = Config.MaxOwned,
        fee = Config.RecoverFee,
    }
end

local function reply(src, ok, msg, cbId)
    notify(src, msg, ok and 'success' or 'error')
    TriggerClientEvent('fivex_dealership:actionResult', src, ok, msg, statePayload(src), cbId)
end

---------------------------------------------------------------------------
-- Sessions
---------------------------------------------------------------------------

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function nearShowroom(src)
    local c = pedCoords(src)
    return c ~= nil and #(c - Config.Showroom.desk) <= Config.OpenDistance + 0.6
end

local function nearGarage(src)
    local c = pedCoords(src)
    if not c then return nil end
    for i, g in ipairs(Config.Garages) do
        if #(c - g.coords) <= Config.OpenDistance + 0.6 then return i end
    end
    return nil
end

RegisterNetEvent('fivex_dealership:open', function(kind)
    local src = source
    if not rateOk(src, 'open', Config.RateLimit.Open) then return end
    if kind ~= 'showroom' and kind ~= 'garage' then return end
    if not getLicense(src) then
        notify(src, L('no_license'), 'error')
        return
    end
    local garage
    if kind == 'showroom' then
        if not nearShowroom(src) then return notify(src, L('too_far'), 'error') end
    else
        garage = nearGarage(src)
        if not garage then return notify(src, L('too_far'), 'error') end
    end
    sessions[src] = { kind = kind, garage = garage }
    TriggerClientEvent('fivex_dealership:openResult', src, statePayload(src))
end)

RegisterNetEvent('fivex_dealership:close', function()
    sessions[source] = nil
end)

-- Common gate for menu actions. Returns license or nil (and replies).
local function begin(src, kind, cbId)
    if busy[src] then reply(src, false, L('busy'), cbId) return nil end
    if not rateOk(src, 'action', Config.RateLimit.Action) then reply(src, false, L('rate'), cbId) return nil end
    local ses = sessions[src]
    local here = ses and ((kind == 'showroom' and nearShowroom(src)) or (kind == 'garage' and nearGarage(src) == ses.garage))
    if not ses or ses.kind ~= kind or not here then
        sessions[src] = nil
        reply(src, false, L('too_far'), cbId)
        return nil
    end
    local license = getLicense(src)
    if not license then reply(src, false, L('no_license'), cbId) return nil end
    return license
end

---------------------------------------------------------------------------
-- Showroom: buy / sell
---------------------------------------------------------------------------

RegisterNetEvent('fivex_dealership:buy', function(model, colorId, method, cbId)
    local src = source
    local license = begin(src, 'showroom', cbId)
    if not license then return end
    local entry = type(model) == 'string' and catalogByModel[model] or nil
    if not entry then return reply(src, false, L('bad_vehicle'), cbId) end
    colorId = tonumber(colorId)
    if not colorId or not colorById[colorId] then return reply(src, false, L('bad_color'), cbId) end
    if method ~= 'bank' and method ~= 'cash' then return reply(src, false, L('bad_method'), cbId) end
    if #loadVehicles(license) >= Config.MaxOwned then
        return reply(src, false, L('max_owned', Config.MaxOwned), cbId)
    end

    busy[src] = true
    local ok, err = charge(src, method, entry.price, L('reason_buy', entry.label))
    if not ok then
        busy[src] = nil
        return reply(src, false, L(err), cbId)
    end
    local veh = addVehicle(license, entry, colorId, entry.price)
    if not veh then
        refund(src, method, entry.price, L('reason_buy', entry.label))
        busy[src] = nil
        return reply(src, false, L('pay_failed'), cbId)
    end
    print(('[fivex_dealership] %s bought %s for $%s (%s, plate %s)'):format(
        GetPlayerName(src) or src, entry.model, entry.price, method, veh.plate))

    local delivered = false
    if not liveEntity(license) then
        local spot = freeSpot(Config.Showroom.delivery)
        delivered = spot ~= nil and spawnVehicle(src, license, veh, spot) ~= nil
    end
    busy[src] = nil
    reply(src, true, L('bought', entry.label, entry.price, veh.plate), cbId)
    notify(src, delivered and L('delivered', entry.label) or L('bought_stored', entry.label), 'info')
end)

RegisterNetEvent('fivex_dealership:sell', function(plate, cbId)
    local src = source
    local license = begin(src, 'showroom', cbId)
    if not license then return end
    if type(plate) ~= 'string' then return reply(src, false, L('not_owned'), cbId) end
    local list = loadVehicles(license)
    local veh, idx = findVehicle(list, plate)
    if not veh then return reply(src, false, L('not_owned'), cbId) end
    if veh.state ~= 'stored' then return reply(src, false, L('sell_out'), cbId) end
    local value = math.floor((tonumber(veh.paid) or 0) * Config.SellBackPercent / 100)
    -- pay first: removal cannot fail, a payout can
    if value > 0 and not call('fivex_bank', 'AddMoney', src, value, L('reason_sell', veh.label)) then
        return reply(src, false, L('pay_failed'), cbId)
    end
    table.remove(list, idx)
    saveVehicles(license, list)
    FxDB.del('plates', plate)
    print(('[fivex_dealership] %s sold %s (plate %s) for $%s'):format(GetPlayerName(src) or src, veh.model, plate, value))
    reply(src, true, L('sold', veh.label, value), cbId)
end)

---------------------------------------------------------------------------
-- Garage: take out / recover / park
---------------------------------------------------------------------------

local function outLabel(license)
    local o = out[license]
    local veh = o and findVehicle(loadVehicles(license), o.plate)
    return veh and veh.label or 'vehicle'
end

RegisterNetEvent('fivex_dealership:takeout', function(plate, cbId)
    local src = source
    local license = begin(src, 'garage', cbId)
    if not license then return end
    local veh = type(plate) == 'string' and findVehicle(loadVehicles(license), plate) or nil
    if not veh then return reply(src, false, L('not_owned'), cbId) end
    if veh.state ~= 'stored' then return reply(src, false, L('not_stored'), cbId) end
    if liveEntity(license) then return reply(src, false, L('already_out', outLabel(license)), cbId) end
    local spot = freeSpot(Config.Garages[sessions[src].garage].spawns)
    if not spot then return reply(src, false, L('no_spawn'), cbId) end

    busy[src] = true
    local ent = spawnVehicle(src, license, veh, spot)
    busy[src] = nil
    if not ent then return reply(src, false, L('spawn_failed'), cbId) end
    reply(src, true, L('taken_out', veh.label), cbId)
end)

RegisterNetEvent('fivex_dealership:recover', function(plate, cbId)
    local src = source
    local license = begin(src, 'garage', cbId)
    if not license then return end
    local veh = type(plate) == 'string' and findVehicle(loadVehicles(license), plate) or nil
    if not veh then return reply(src, false, L('not_owned'), cbId) end
    if veh.state == 'stored' then return reply(src, false, L('recover_not_needed'), cbId) end
    local live = liveEntity(license)
    if live and out[license].plate ~= plate then
        return reply(src, false, L('already_out', outLabel(license)), cbId)
    end
    local spot = freeSpot(Config.Garages[sessions[src].garage].spawns)
    if not spot then return reply(src, false, L('no_spawn'), cbId) end

    busy[src] = true
    local ok, err = chargeFee(src, Config.RecoverFee, L('reason_fee', veh.label))
    if not ok then
        busy[src] = nil
        return reply(src, false, err == 'no_funds_fee' and L('no_funds_fee', Config.RecoverFee) or L(err), cbId)
    end
    if live then DeleteEntity(live) end
    out[license] = nil
    veh = patchVehicle(license, plate, { state = 'stored', engine = 1000.0, body = 1000.0, dirt = 0.0 })
    local ent = veh and spawnVehicle(src, license, veh, spot)
    busy[src] = nil
    if not ent then return reply(src, false, L('spawn_failed'), cbId) end
    reply(src, true, L('recovered', veh.label, Config.RecoverFee), cbId)
end)

RegisterNetEvent('fivex_dealership:store', function(netId)
    local src = source
    if busy[src] then return notify(src, L('busy'), 'error') end
    if not rateOk(src, 'action', Config.RateLimit.Action) then return notify(src, L('rate'), 'error') end
    local license = getLicense(src)
    if not license then return notify(src, L('no_license'), 'error') end
    local live = liveEntity(license)
    local ent = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    -- entity identity, not plate text: vMenu can copy any plate onto any car
    if not live or ent ~= live then return notify(src, L('store_not_owned'), 'error') end
    if GetPedInVehicleSeat(ent, -1) ~= GetPlayerPed(src) then return notify(src, L('store_not_driver'), 'error') end
    local c = GetEntityCoords(ent)
    local near = false
    for _, g in ipairs(Config.Garages) do
        if #(c - g.coords) <= Config.StoreDistance + 2.0 then
            near = true
            break
        end
    end
    if not near then return notify(src, L('store_too_far'), 'error') end
    local result, veh = parkOut(license)
    local label = veh and veh.label or 'Vehicle'
    if result == 'wrecked' then
        notify(src, L('wrecked', label), 'error')
    else
        notify(src, L('stored', label), 'success')
    end
end)

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------

exports('GetVehicles', function(src)
    local license = getLicense(tonumber(src))
    if not license then return {} end
    return vehiclesPayload(license)
end)

exports('GetPlateOwner', function(plate)
    if type(plate) ~= 'string' then return nil end
    local owner = FxDB.get('plates', (plate:upper():gsub('%s', '')))
    if not owner or owner == '' then return nil end
    return owner
end)

-- Returns plate, license if entity is a live dealership-owned vehicle.
exports('IsOwnedEntity', function(entity)
    for license, o in pairs(out) do
        if o.entity == entity and DoesEntityExist(entity) then
            return o.plate, license
        end
    end
    return nil
end)

---------------------------------------------------------------------------
-- Staff
---------------------------------------------------------------------------

local function staffOnly(src)
    if src == 0 or hasAce(src, 'fivex_dealership.staff') then return true end
    notify(src, L('staff_denied'), 'error')
    return false
end

local function say(src, msg, t)
    if src > 0 then notify(src, msg, t) else print(msg) end
end

RegisterCommand('givecar', function(src, args)
    if not staffOnly(src) then return end
    local id = tonumber(args[1] or '')
    local entry = catalogByModel[(args[2] or ''):lower()]
    if not id or not entry then return say(src, L('staff_give_usage'), 'error') end
    if not GetPlayerName(id) then return say(src, L('staff_bad_id'), 'error') end
    local license = getLicense(id)
    if not license then return say(src, L('no_license'), 'error') end
    local veh = addVehicle(license, entry, Config.Colors[1].id, 0)
    if not veh then return say(src, L('pay_failed'), 'error') end
    print(('[fivex_dealership] givecar %s %s plate %s (by %s)'):format(GetPlayerName(id), entry.model, veh.plate,
        src > 0 and (GetPlayerName(src) or src) or 'console'))
    notify(id, L('received_car', entry.label), 'success')
    say(src, L('staff_given', GetPlayerName(id), entry.label, veh.plate), 'success')
end, false)

RegisterCommand('takecar', function(src, args)
    if not staffOnly(src) then return end
    local plate = (args[1] or ''):upper()
    if plate == '' then return say(src, L('staff_take_usage'), 'error') end
    local license = FxDB.get('plates', plate)
    if not license or license == '' then return say(src, L('staff_no_plate'), 'error') end
    local list = loadVehicles(license)
    local veh, idx = findVehicle(list, plate)
    if out[license] and out[license].plate == plate then
        local live = liveEntity(license)
        if live then DeleteEntity(live) end
        out[license] = nil
    end
    if idx then
        table.remove(list, idx)
        saveVehicles(license, list)
    end
    FxDB.del('plates', plate)
    print(('[fivex_dealership] takecar %s (by %s)'):format(plate, src > 0 and (GetPlayerName(src) or src) or 'console'))
    local owner = srcByLicense(license)
    if owner then notify(owner, L('lost_car', veh and veh.label or plate), 'error') end
    say(src, L('staff_taken', plate), 'success')
end, false)

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

-- Cars deleted by other scripts / cleanup become 'lost' (recoverable at a garage).
CreateThread(function()
    while true do
        Wait(Config.TrackInterval)
        for license, o in pairs(out) do
            if not o.entity or not DoesEntityExist(o.entity) then
                out[license] = nil
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local license = getLicense(src)
    if license and out[license] then parkOut(license) end
    sessions[src] = nil
    busy[src] = nil
    for k in pairs(buckets) do
        if k:find('^' .. tostring(src) .. ':') then
            buckets[k] = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res == 'fivex_bank' or res == 'fivex_jobcenter' then
        warned = {}
        return
    end
    if res ~= RESOURCE then return end
    math.randomseed(os.time())
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    for license in pairs(out) do
        parkOut(license)
    end
end)
