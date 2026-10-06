--- Persistence: notes, warns, mutes, audit (server KVP).
--- Loaded before server/main.lua. Client is untrusted; nothing here is sent
--- unless the caller already passed ACE checks.

Notes = Notes or {}
Warns = Warns or {}
Mutes = Mutes or {}
Audit = Audit or {}

local NOTES_KEY = 'fivex_admin_notes_v1'
local WARNS_KEY = 'fivex_admin_warns_v1'
local MUTES_KEY = 'fivex_admin_mutes_v1'
local AUDIT_KEY = 'fivex_admin_audit_v1'

local MAX_NOTE_CHARS = 240
local MAX_NOTES = 40
local MAX_WARNS = 50
local MAX_AUDIT = 250

local notesMap = {}
local warnsMap = {}
local mutesMap = {}
local auditList = {}
local sessionMutes = {}
local chatHooked = false

local function now()
    return os.time()
end

local function newId()
    return tostring(now()) .. '-' .. tostring(math.random(10000, 99999))
end

-- MySQL tables (server/db.lua). The *_KEY names are the old single-key KVP lists, imported once.
FxDB.space('notes', 'fivex_admin_notes', 'text', { key = 'license', value = 'notes' })
FxDB.space('warns', 'fivex_admin_warns', 'text', { key = 'license', value = 'warns' })
FxDB.space('mutes', 'fivex_admin_mutes', 'text', { key = 'license', value = 'mute' })
FxDB.space('audit', 'fivex_admin_audit', 'text', { key = 'id', value = 'entry' })
local SPACE = { [NOTES_KEY] = 'notes', [WARNS_KEY] = 'warns', [MUTES_KEY] = 'mutes', [AUDIT_KEY] = 'audit' }

local function decodeAll(space)
    local out = {}
    for k, raw in pairs(FxDB.all(space)) do
        local ok, v = pcall(json.decode, raw)
        if ok and v ~= nil then out[k] = v end
    end
    return out
end

local function loadMap(key)
    return decodeAll(SPACE[key])
end

local function loadArray(key)
    local list = {}
    for _, e in pairs(decodeAll(SPACE[key])) do
        if type(e) == 'table' then list[#list + 1] = e end
    end
    table.sort(list, function(a, b) return (a.ts or 0) > (b.ts or 0) end) -- newest first
    return list
end

local recordsLoaded = false

local function saveMap(key, map)
    if not recordsLoaded then return end -- an unloaded (empty) map must never overwrite the table
    local rows = {}
    for k, v in pairs(map) do rows[k] = json.encode(v) end
    FxDB.sync(SPACE[key], rows)
end

-- audit entries never change once written: encode each once
local encoded = setmetatable({}, { __mode = 'k' })
local function saveArray(key, list)
    if not recordsLoaded then return end
    local rows = {}
    for i, e in ipairs(list) do
        local id = e.id or (tostring(e.ts or 0) .. '-' .. i)
        e.id = id
        encoded[e] = encoded[e] or json.encode(e)
        rows[id] = encoded[e]
    end
    FxDB.sync(SPACE[key], rows)
end

-- first start on MySQL: bring the old KVP lists over
local function importOld()
    for key, space in pairs(SPACE) do
        if next(FxDB.all(space)) == nil then
            local raw = GetResourceKvpString(key)
            local ok, data = pcall(json.decode, raw or '')
            if ok and type(data) == 'table' then
                local n = 0
                if space == 'audit' then
                    for i, e in ipairs(data) do
                        if type(e) == 'table' then
                            local id = e.id or ('import-' .. i)
                            e.id = id
                            FxDB.set(space, id, json.encode(e)); n = n + 1
                        end
                    end
                else
                    for k, v in pairs(data) do FxDB.set(space, k, json.encode(v)); n = n + 1 end
                end
                if n > 0 then print(('^3[fivex_admin:db]^7 imported %d %s entries from KVP'):format(n, space)) end
            end
        end
    end
end

local function clampText(s, maxLen)
    if type(s) ~= 'string' then return '' end
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if #s > maxLen then
        return s:sub(1, maxLen)
    end
    return s
end

local function staffMeta(src)
    local ids = CollectIdentifiers(src)
    return {
        staff = (ids and ids.license) or tostring(src),
        staffName = GetPlayerName(src) or 'staff',
    }
end

function RecordsLicenseOf(src)
    local ids = CollectIdentifiers(src)
    return ids and ids.license or nil
end

-- Notes -----------------------------------------------------------------

function Notes.List(license)
    if type(license) ~= 'string' or license == '' then return {} end
    local list = notesMap[license]
    if type(list) ~= 'table' then return {} end
    return list
end

function Notes.Add(license, src, text)
    if type(license) ~= 'string' or license == '' then return nil, 'no_license' end
    text = clampText(text, MAX_NOTE_CHARS)
    if text == '' then return nil, 'empty' end
    local sm = staffMeta(src)
    local entry = {
        id = newId(),
        text = text,
        staff = sm.staff,
        staffName = sm.staffName,
        created = now(),
    }
    local list = notesMap[license]
    if type(list) ~= 'table' then list = {} end
    table.insert(list, 1, entry)
    while #list > MAX_NOTES do
        list[#list] = nil
    end
    notesMap[license] = list
    saveMap(NOTES_KEY, notesMap)
    return entry
end

-- Warns -----------------------------------------------------------------

function Warns.List(license)
    if type(license) ~= 'string' or license == '' then return {} end
    local list = warnsMap[license]
    if type(list) ~= 'table' then return {} end
    return list
end

function Warns.Add(license, src, reason)
    if type(license) ~= 'string' or license == '' then return nil, 'no_license' end
    reason = clampText(reason, Config.MaxReasonLength or 200)
    if reason == '' then return nil, 'empty' end
    local sm = staffMeta(src)
    local entry = {
        id = newId(),
        reason = reason,
        staff = sm.staff,
        staffName = sm.staffName,
        created = now(),
    }
    local list = warnsMap[license]
    if type(list) ~= 'table' then list = {} end
    table.insert(list, 1, entry)
    while #list > MAX_WARNS do
        list[#list] = nil
    end
    warnsMap[license] = list
    saveMap(WARNS_KEY, warnsMap)
    return entry
end

-- Mutes -----------------------------------------------------------------

function Mutes.Get(license)
    if type(license) ~= 'string' or license == '' then return nil end
    local e = mutesMap[license]
    if type(e) == 'table' then return e end
    return nil
end

function Mutes.IsLicenseMuted(license)
    return Mutes.Get(license) ~= nil
end

function Mutes.IsPlayerMuted(src)
    src = tonumber(src)
    if not src then return false end
    if sessionMutes[src] then return true end
    local license = RecordsLicenseOf(src)
    if license and Mutes.IsLicenseMuted(license) then return true end
    return false
end

local function applyVoiceMute(tid, on)
    pcall(function()
        MumbleSetPlayerMuted(tid, on and true or false)
    end)
end

function Mutes.Mute(tid, src)
    if not tid or not PlayerOnline(tid) then return nil, 'invalid_target' end
    applyVoiceMute(tid, true)
    sessionMutes[tid] = true
    local license = RecordsLicenseOf(tid)
    if not license then
        return { persisted = false, voice = true }
    end
    local sm = staffMeta(src)
    mutesMap[license] = {
        staff = sm.staff,
        staffName = sm.staffName,
        created = now(),
        voice = true,
    }
    saveMap(MUTES_KEY, mutesMap)
    return { persisted = true, voice = true, license = license }
end

function Mutes.Unmute(tid, src)
    if not tid or not PlayerOnline(tid) then return nil, 'invalid_target' end
    applyVoiceMute(tid, false)
    sessionMutes[tid] = nil
    local license = RecordsLicenseOf(tid)
    if license and mutesMap[license] then
        mutesMap[license] = nil
        saveMap(MUTES_KEY, mutesMap)
    end
    return { persisted = license ~= nil, license = license }
end

function Mutes.Reapply(tid)
    if not tid or not PlayerOnline(tid) then return end
    local license = RecordsLicenseOf(tid)
    if license and Mutes.IsLicenseMuted(license) then
        sessionMutes[tid] = true
        applyVoiceMute(tid, true)
        return true
    end
    return false
end

-- Audit -----------------------------------------------------------------

function Audit.Serialize()
    local out = {}
    for i = 1, #auditList do
        local e = auditList[i]
        out[i] = {
            id = e.id,
            ts = e.ts,
            staff = e.staff,
            staffName = e.staffName,
            action = e.action,
            target = e.target,
            targetName = e.targetName,
            license = e.license,
            detail = e.detail,
        }
    end
    return out
end

local WEBHOOK_COLORS = {
    kick = 15158332,
    ban = 10038562,
    unban = 3066993,
    warn = 15844367,
    mute = 15105570,
    unmute = 3066993,
    note = 3447003,
    bucket = 3447003,
    screenshot = 10181046,
    ['offline-ban'] = 10038562,
    spawn = 5793266,
    freeze = 9807270,
    bring = 3447003,
}

function Audit.Log(src, action, meta)
    meta = meta or {}
    local sm = staffMeta(src)
    local target = meta.target
    local targetName = meta.targetName
    if target and not targetName and PlayerOnline(target) then
        targetName = GetPlayerName(target)
    end
    local license = meta.license
    if not license and target and PlayerOnline(target) then
        license = RecordsLicenseOf(target)
    end
    local detail = meta.detail
    if detail ~= nil then
        detail = tostring(detail)
        if #detail > 240 then detail = detail:sub(1, 240) end
    else
        detail = ''
    end
    local entry = {
        id = newId(),
        ts = now(),
        staff = sm.staff,
        staffName = sm.staffName,
        action = tostring(action or ''),
        target = target and tonumber(target) or nil,
        targetName = targetName,
        license = license,
        detail = detail,
    }
    table.insert(auditList, 1, entry)
    while #auditList > MAX_AUDIT do
        auditList[#auditList] = nil
    end
    saveArray(AUDIT_KEY, auditList)

    if type(SendAdminWebhook) == 'function' then
        local who = sm.staffName .. ' (' .. tostring(src) .. ')'
        local tgt = ''
        if targetName then
            tgt = (' → **%s** (%s)'):format(targetName, tostring(target or license or ''))
        elseif license then
            tgt = ' → `' .. license .. '`'
        end
        local desc = ('**%s**%s'):format(who, tgt)
        if detail ~= '' then
            desc = desc .. '\n' .. detail
        end
        local color = WEBHOOK_COLORS[action] or 6001135
        SendAdminWebhook(tostring(action or 'audit'), desc, color)
    end
    return entry
end

-- Lookup ----------------------------------------------------------------

local function identPrefix(s)
    if type(s) ~= 'string' then return nil, nil end
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if s == '' then return nil, nil end
    local prefix, value = s:match('^([%w]+):(.+)$')
    if prefix and value then
        return string.lower(prefix), value
    end
    return nil, s
end

function NormalizeLicense(raw)
    if type(raw) ~= 'string' then return nil end
    raw = raw:gsub('^%s+', ''):gsub('%s+$', '')
    if raw == '' then return nil end
    local hash = raw
    local lower = raw:lower()
    if lower:sub(1, 8) == 'license:' then
        hash = raw:sub(9)
    elseif lower:sub(1, 9) == 'license2:' then
        -- Rockstar license2 is a different identifier; reject for license-keyed stores.
        return nil
    end
    hash = hash:gsub('^%s+', ''):gsub('%s+$', '')
    if #hash < 8 or #hash > 80 then return nil end
    if not hash:match('^[%w]+$') then return nil end
    return 'license:' .. hash
end

function ParseLookupQuery(raw)
    if type(raw) ~= 'string' then return nil end
    raw = raw:gsub('^%s+', ''):gsub('%s+$', '')
    if raw == '' then return nil end
    local prefix, value = identPrefix(raw)
    if prefix == 'license' then
        local lic = NormalizeLicense(raw)
        if not lic then return nil end
        return { license = lic }
    end
    if prefix == 'discord' then
        value = value:gsub('^%s+', ''):gsub('%s+$', '')
        if #value < 5 or not value:match('^[%w]+$') then return nil end
        return { discord = 'discord:' .. value }
    end
    if prefix == 'steam' then
        value = value:gsub('^%s+', ''):gsub('%s+$', '')
        if #value < 5 or not value:match('^[%w]+$') then return nil end
        return { steam = 'steam:' .. value }
    end
    -- Raw hex-ish hash → license
    if raw:match('^[%w]+$') and #raw >= 8 and #raw <= 80 then
        if raw:match('^%d+$') and #raw >= 15 then
            return { discord = 'discord:' .. raw }
        end
        if raw:lower():match('^1100001[%w]+$') then
            return { steam = 'steam:' .. raw }
        end
        return { license = 'license:' .. raw }
    end
    return nil
end

function FindPlayerByIdentifiers(idents)
    if type(idents) ~= 'table' then return nil end
    local players = GetPlayers()
    for i = 1, #players do
        local src = tonumber(players[i])
        local ids = CollectIdentifiers(src)
        if ids then
            if idents.license and ids.license == idents.license then return src, ids end
            if idents.discord and ids.discord == idents.discord then return src, ids end
            if idents.steam and ids.steam == idents.steam then return src, ids end
        end
    end
    return nil, nil
end

function LookupRecords(idents)
    idents = idents or {}
    local license = idents.license
    local bans = {}
    local allBans = Bans.Serialize()
    for i = 1, #allBans do
        local b = allBans[i]
        local ids = b.identifiers or {}
        local hit = false
        if license and ids.license == license then hit = true end
        if idents.discord and ids.discord == idents.discord then hit = true end
        if idents.steam and ids.steam == idents.steam then hit = true end
        if hit then
            bans[#bans + 1] = b
            if not license and ids.license then license = ids.license end
        end
    end
    if not license then
        local online, ids = FindPlayerByIdentifiers(idents)
        if online and ids and ids.license then
            license = ids.license
        end
    end
    local muted = false
    if license then
        muted = Mutes.IsLicenseMuted(license)
    end
    return {
        license = license,
        bans = bans,
        notes = license and Notes.List(license) or {},
        warns = license and Warns.List(license) or {},
        muted = muted,
    }
end

function BuildPlayerRecord(tid)
    if not PlayerOnline(tid) then return nil end
    local license = RecordsLicenseOf(tid)
    local bucket = 0
    pcall(function()
        bucket = GetPlayerRoutingBucket(tid) or 0
    end)
    return {
        target = tid,
        notes = license and Notes.List(license) or {},
        warns = license and Warns.List(license) or {},
        muted = Mutes.IsPlayerMuted(tid),
        bucket = bucket,
        hasLicense = license ~= nil,
    }
end

-- Chat mute hook --------------------------------------------------------

local function attachChatHook()
    if chatHooked then return true end
    if GetResourceState('chat') ~= 'started' then return false end
    local ok = pcall(function()
        exports.chat:registerMessageHook(function(src, outMessage, hookRef)
            if not Mutes.IsPlayerMuted(src) then return end
            if type(hookRef) == 'table' and type(hookRef.cancel) == 'function' then
                hookRef.cancel()
                return
            end
            if type(outMessage) == 'table' then
                outMessage.args = { '', '' }
                if outMessage.body ~= nil then outMessage.body = '' end
            end
        end)
    end)
    if ok then
        chatHooked = true
        return true
    end
    return false
end

function Mutes.EnsureChatHook()
    return attachChatHook()
end

-- Load ------------------------------------------------------------------

local function loadAll()
    notesMap = loadMap(NOTES_KEY)
    warnsMap = loadMap(WARNS_KEY)
    mutesMap = loadMap(MUTES_KEY)
    auditList = loadArray(AUDIT_KEY)
end

FxDB.onReady(function()
    importOld()
    loadAll()
    recordsLoaded = true
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then
        if res == 'chat' then
            chatHooked = false
            attachChatHook()
        end
        return
    end
    -- data itself loads from MySQL in FxDB.onReady above
    SetTimeout(250, function()
        attachChatHook()
    end)
end)

AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(400, function()
        if PlayerOnline(src) then
            Mutes.Reapply(src)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    sessionMutes[source] = nil
end)
