local KVP_KEY = 'fivex_admin_bans_v1' -- old storage, imported once into MySQL

Bans = Bans or {}
Bans.list = {}
Bans.loaded = false

-- MySQL table (server/db.lua): one row per ban
FxDB.space('bans', 'fivex_admin_bans', 'text', { key = 'id', value = 'ban' })

local function now()
    return os.time()
end

local function save()
    if not Bans.loaded then return end -- an unloaded (empty) list must never overwrite the table
    local rows = {}
    for i = 1, #Bans.list do
        local b = Bans.list[i]
        if b.id then rows[b.id] = json.encode(b) end
    end
    FxDB.sync('bans', rows)
end

local function load()
    local list = {}
    for _, raw in pairs(FxDB.all('bans')) do
        local ok, b = pcall(json.decode, raw)
        if ok and type(b) == 'table' then list[#list + 1] = b end
    end
    table.sort(list, function(a, b) return (a.created or 0) < (b.created or 0) end)
    Bans.list = list
end

-- first start on MySQL: bring the bans over from the old KVP list
local function importOld()
    if next(FxDB.all('bans')) ~= nil then return end
    local raw = GetResourceKvpString(KVP_KEY)
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return end
    for i, b in ipairs(data) do
        if type(b) == 'table' then
            b.id = b.id or ('import-' .. i)
            FxDB.set('bans', b.id, json.encode(b))
        end
    end
    print(('^3[fivex_admin:db]^7 imported %d bans from KVP'):format(#data))
end

local function identifiersOverlap(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then
        return false
    end
    local keys = { 'license', 'discord', 'fivem', 'steam' }
    for i = 1, #keys do
        local k = keys[i]
        if a[k] and b[k] and a[k] == b[k] then
            return true
        end
    end
    return false
end

function Bans.Find(identifiers)
    local t = now()
    local changed = false
    for i = #Bans.list, 1, -1 do
        local ban = Bans.list[i]
        if ban.expires and ban.expires > 0 and t >= ban.expires then
            table.remove(Bans.list, i)
            changed = true
        elseif identifiersOverlap(ban.identifiers, identifiers) then
            if changed then save() end
            return ban
        end
    end
    if changed then save() end
    return nil
end

function Bans.Add(entry)
    entry.id = entry.id or (tostring(now()) .. '-' .. tostring(math.random(10000, 99999)))
    entry.created = entry.created or now()
    Bans.list[#Bans.list + 1] = entry
    save()
    return entry
end

function Bans.Remove(banId)
    for i = 1, #Bans.list do
        if Bans.list[i].id == banId then
            local removed = Bans.list[i]
            table.remove(Bans.list, i)
            save()
            return removed
        end
    end
    return nil
end

function Bans.Serialize()
    local out = {}
    for i = 1, #Bans.list do
        local b = Bans.list[i]
        out[i] = {
            id = b.id,
            name = b.name,
            reason = b.reason,
            staff = b.staff,
            staffName = b.staffName,
            created = b.created,
            expires = b.expires or 0,
            durationId = b.durationId,
            identifiers = b.identifiers,
        }
    end
    return out
end

FxDB.onReady(function()
    importOld()
    load()
    Bans.loaded = true
end)

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    deferrals.defer()
    -- Yield once so identifiers are available.
    Wait(0)
    -- never let someone in before the ban list is loaded
    local waitUntil = GetGameTimer() + 15000
    while not Bans.loaded and GetGameTimer() < waitUntil do Wait(100) end
    local ids = CollectIdentifiers(src)
    if not ids or not ids.license then
        -- Cannot match a license-based ban reliably; allow connect (ban path requires license).
        deferrals.done()
        return
    end
    local ban = Bans.Find(ids)
    if not ban then
        deferrals.done()
        return
    end
    local msg = L('banned_connecting')
    if ban.reason and ban.reason ~= '' then
        msg = msg .. ' ' .. ban.reason
    end
    if ban.expires and ban.expires > 0 then
        msg = msg .. ' | ' .. L('ban_until', os.date('!%Y-%m-%d %H:%M UTC', ban.expires))
    else
        msg = msg .. ' | ' .. L('ban_permanent')
    end
    setKickReason(msg)
    deferrals.done(msg)
end)

-- (loaded from MySQL in FxDB.onReady above)
