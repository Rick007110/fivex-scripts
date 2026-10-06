--[[
    FiveX database layer (oxmysql). The same file ships in every fivex resource that stores data.

    Data lives in "spaces": one MySQL table each, keyed by a string (usually a license), holding
    one value (text/JSON or a whole number). Every space is loaded into memory when the resource
    starts, so reads stay synchronous; writes update memory at once and reach MySQL in order
    through a queue. On the first start, existing KVP data under the space's old prefix is
    imported (the KVP entries are left in place, untouched).
]]

FxDB = {}

local spaces = {}
local order = {}
local ready = false
local failed = false -- boot failed: nothing waits, nothing is written (so no data can be overwritten)
local readyHandlers = {}
local queue = {}
local RES = GetCurrentResourceName()

local function log(msg, ...)
    print(('^3[%s:db]^7 ' .. msg):format(RES, ...))
end

-- name: short id used in code; tbl: MySQL table; kind: 'text' | 'int'
-- opts.kvp: old KVP prefix to import from; opts.key / opts.value: column names
function FxDB.space(name, tbl, kind, opts)
    opts = opts or {}
    local s = {
        name = name, tbl = tbl, kind = kind == 'int' and 'int' or 'text',
        kvp = opts.kvp, key = opts.key or 'id', value = opts.value or 'data',
        cache = {},
    }
    spaces[name] = s
    order[#order + 1] = s
    return s
end

local function space(name)
    local s = spaces[name]
    if not s then error(('unknown FxDB space %q'):format(tostring(name)), 3) end
    return s
end

function FxDB.isReady() return ready end

-- Waits (up to 15 s) for the initial load when the caller can wait. Returns whether data is
-- available. Never blocks forever: other resources (sd-phone via ND_Core) call into this.
function FxDB.await()
    if ready then return true end
    if failed or not coroutine.isyieldable() then return false end
    local giveUp = GetGameTimer() + 15000
    while not ready and not failed and GetGameTimer() < giveUp do Wait(50) end
    return ready
end

function FxDB.onReady(fn)
    if ready then CreateThread(fn) else readyHandlers[#readyHandlers + 1] = fn end
end

function FxDB.get(name, key)
    local s = space(name)
    if not FxDB.await() then return nil end
    return s.cache[tostring(key)]
end

-- every key/value in a space (a copy of the key list; values as stored)
function FxDB.all(name)
    local s = space(name)
    FxDB.await()
    local out = {}
    for k, v in pairs(s.cache) do out[k] = v end
    return out
end

local function enqueue(sql, args)
    queue[#queue + 1] = { sql = sql, args = args }
end

function FxDB.set(name, key, value)
    local s = space(name)
    if not FxDB.await() then
        log('write to %s before the database was ready was dropped (key %s)', s.tbl, tostring(key))
        return
    end
    key = tostring(key)
    if value == nil then return FxDB.del(name, key) end
    if s.kind == 'int' then value = math.floor(tonumber(value) or 0) else value = tostring(value) end
    if s.cache[key] == value then return end
    s.cache[key] = value
    enqueue(('INSERT INTO `%s` (`%s`, `%s`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `%s` = VALUES(`%s`)')
        :format(s.tbl, s.key, s.value, s.value, s.value), { key, value })
end

function FxDB.del(name, key)
    local s = space(name)
    if not FxDB.await() then return end
    key = tostring(key)
    if s.cache[key] == nil then return end
    s.cache[key] = nil
    enqueue(('DELETE FROM `%s` WHERE `%s` = ?'):format(s.tbl, s.key), { key })
end

-- Make a space hold exactly `map` (key -> value): writes what changed, deletes what is gone.
function FxDB.sync(name, map)
    local s = space(name)
    if not FxDB.await() then return end
    for k in pairs(s.cache) do
        if map[k] == nil then FxDB.del(name, k) end
    end
    for k, v in pairs(map) do FxDB.set(name, k, v) end
end

-- ── Write queue: one query at a time, in order ───────────
CreateThread(function()
    while true do
        if #queue > 0 then
            local q = table.remove(queue, 1)
            local ok, err = pcall(MySQL.query.await, q.sql, q.args)
            if not ok then log('write failed: %s', tostring(err)) end
        else
            Wait(25)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RES or #queue == 0 then return end
    -- flush what is left before the resource goes away
    for i = 1, #queue do
        local q = queue[i]
        pcall(MySQL.query.await, q.sql, q.args)
    end
    queue = {}
end)

-- ── Boot: tables, load, one-time KVP import ──────────────
local function kvpKeys(prefix)
    local keys = {}
    local h = StartFindKvp(prefix)
    if h == -1 then return keys end
    while true do
        local k = FindKvp(h)
        if not k then break end
        keys[#keys + 1] = k
    end
    EndFindKvp(h)
    return keys
end

local function importKvp(s)
    if not s.kvp then return 0 end
    local n = 0
    for _, fullKey in ipairs(kvpKeys(s.kvp)) do
        local key = fullKey:sub(#s.kvp + 1)
        if key == '' then key = 'main' end
        local value
        -- a KVP read with the wrong type throws "bad cast", and resources stored numbers both ways
        local okInt, asInt = pcall(GetResourceKvpInt, fullKey)
        local okStr, asStr = pcall(GetResourceKvpString, fullKey)
        if not okStr then asStr = nil end
        if s.kind == 'int' then
            value = tonumber(asStr) or (okInt and asInt) or nil
        else
            value = asStr or (okInt and asInt and tostring(asInt)) or nil
        end
        if value ~= nil and s.cache[key] == nil then
            s.cache[key] = value
            MySQL.query.await(('INSERT IGNORE INTO `%s` (`%s`, `%s`) VALUES (?, ?)'):format(s.tbl, s.key, s.value), { key, value })
            n = n + 1
        end
    end
    return n
end

local function boot()
    for _, s in ipairs(order) do
        local valueType = s.kind == 'int' and 'BIGINT NOT NULL DEFAULT 0' or 'LONGTEXT NULL'
        MySQL.query.await(([[
            CREATE TABLE IF NOT EXISTS `%s` (
                `%s` VARCHAR(191) NOT NULL,
                `%s` %s,
                `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                PRIMARY KEY (`%s`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]]):format(s.tbl, s.key, s.value, valueType, s.key))
        local rows = MySQL.query.await(('SELECT `%s` AS k, `%s` AS v FROM `%s`'):format(s.key, s.value, s.tbl)) or {}
        for _, r in ipairs(rows) do
            s.cache[tostring(r.k)] = s.kind == 'int' and (tonumber(r.v) or 0) or r.v
        end
        if #rows == 0 then
            local n = importKvp(s)
            if n > 0 then log('imported %d entries from KVP into %s', n, s.tbl) end
        end
    end
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do
        log('waiting for oxmysql...')
        Wait(1000)
    end
    local ok, err = pcall(boot)
    if not ok then
        failed = true
        print(('^1[%s:db] could not load the database, this resource will not save anything until it is fixed and restarted: %s^7'):format(RES, tostring(err)))
        return
    end
    ready = true
    for _, fn in ipairs(readyHandlers) do CreateThread(fn) end
    readyHandlers = {}
end)
