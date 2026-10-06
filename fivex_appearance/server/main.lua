local RESOURCE = GetCurrentResourceName()

local SKIN_PREFIX = 'fivex_appearance_skin_v1:'
local OUTFIT_PREFIX = 'fivex_appearance_outfits_v1:'

-- MySQL tables (server/db.lua); the first start imports the old KVP data
FxDB.space('skin',    'fivex_appearance_skin',    'text', { kvp = SKIN_PREFIX,   key = 'license', value = 'appearance' })
FxDB.space('outfits', 'fivex_appearance_outfits', 'text', { kvp = OUTFIT_PREFIX, key = 'license', value = 'outfits' })

local rateBuckets = {}
--- Last menu mode the server granted per player (creator | clothing | barber | tattoo).
local openModes = {}

local function hasAce(src, node)
    if type(src) ~= 'number' or src <= 0 then return false end
    if IsPlayerAceAllowed(src, 'fivex_appearance') then return true end
    if node and IsPlayerAceAllowed(src, node) then return true end
    return false
end

local function getLicense(src)
    local ids = GetPlayerIdentifiers(src)
    if type(ids) ~= 'table' then return nil end
    for i = 1, #ids do
        local id = ids[i]
        if type(id) == 'string' and id:sub(1, 8) == 'license:' and #id >= 16 then
            return id
        end
    end
    return nil
end

local function notify(src, message, ntype)
    TriggerClientEvent('fivex_appearance:notify', src, message or '', ntype or 'info')
end

local function rateOk(src, key)
    local spec = Config.RateLimit or { max = 8, window = 10000 }
    local now = GetGameTimer()
    local id = tostring(src) .. ':' .. key
    local b = rateBuckets[id]
    if not b or (now - b.start) > spec.window then
        rateBuckets[id] = { start = now, n = 1 }
        return true
    end
    b.n = b.n + 1
    return b.n <= spec.max
end

local function webhook(title, description, color)
    local url = Config.Webhook
    if type(url) ~= 'string' or url == '' then return end
    local payload = json.encode({
        username = 'fivex_appearance',
        embeds = {{
            title = title,
            description = description,
            color = color or 6001135,
            footer = { text = RESOURCE },
        }},
    })
    PerformHttpRequest(url, function() end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

local function clamp(n, lo, hi, fallback)
    n = tonumber(n)
    if not n then return fallback or lo end
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

local function clampInt(n, lo, hi, fallback)
    return math.floor(clamp(n, lo, hi, fallback) + 0.0)
end

local function at(t, i)
    if type(t) ~= 'table' then return nil end
    local v = t[i]
    if v ~= nil then return v end
    return t[tostring(i)]
end

local function clampName(s, maxLen)
    if type(s) ~= 'string' then return '' end
    s = s:gsub('^%s+', ''):gsub('%s+$', '')
    if #s > maxLen then
        s = s:sub(1, maxLen)
    end
    return s
end

local function validateAppearance(raw)
    if type(raw) ~= 'table' then return nil, 'invalid' end
    local model = Defaults.NormalizeModel(raw.model)
    if not model then return nil, 'model' end
    local hb = type(raw.headBlend) == 'table' and raw.headBlend or {}
    local hair = type(raw.hair) == 'table' and raw.hair or {}
    local maxP = Config.MaxParent or 45
    local out = {
        model = model,
        headBlend = {
            shapeFirst = clampInt(hb.shapeFirst, 0, maxP, 0),
            shapeSecond = clampInt(hb.shapeSecond, 0, maxP, 0),
            shapeThird = clampInt(hb.shapeThird, 0, maxP, 0),
            skinFirst = clampInt(hb.skinFirst, 0, maxP, 0),
            skinSecond = clampInt(hb.skinSecond, 0, maxP, 0),
            skinThird = clampInt(hb.skinThird, 0, maxP, 0),
            shapeMix = clamp(hb.shapeMix, 0.0, 1.0, 0.5),
            skinMix = clamp(hb.skinMix, 0.0, 1.0, 0.5),
            thirdMix = clamp(hb.thirdMix, 0.0, 1.0, 0.0),
        },
        faceFeatures = {},
        overlays = {},
        hair = {
            style = clampInt(hair.style, 0, 512, 0),
            texture = clampInt(hair.texture, 0, 128, 0),
            color = clampInt(hair.color, 0, 63, 0),
            highlight = clampInt(hair.highlight, 0, 63, 0),
        },
        eyeColor = clampInt(raw.eyeColor, 0, 31, 0),
        components = {},
        props = {},
        tattoos = {},
    }
    for i = 0, 19 do
        out.faceFeatures[tostring(i)] = clamp(at(raw.faceFeatures, i), -1.0, 1.0, 0.0)
    end
    for i = 0, 12 do
        local ov = at(raw.overlays, i)
        local meta = Defaults.Overlays[i + 1]
        if type(ov) ~= 'table' then ov = {} end
        out.overlays[tostring(i)] = {
            index = clampInt(ov.index, 0, 255, 255),
            opacity = clamp(ov.opacity, 0.0, 1.0, 0.0),
            colourType = clampInt(ov.colourType or (meta and meta.colourType) or 0, 0, 2, 0),
            colour = clampInt(ov.colour, 0, 63, 0),
            secondColour = clampInt(ov.secondColour, 0, 63, 0),
        }
    end
    local comps = type(raw.components) == 'table' and raw.components or {}
    for i = 0, 11 do
        local c = at(comps, i)
        if type(c) ~= 'table' then c = {} end
        out.components[tostring(i)] = {
            drawable = clampInt(c.drawable, 0, 512, 0),
            texture = clampInt(c.texture, 0, 128, 0),
        }
    end
    out.components['2'] = { drawable = out.hair.style, texture = out.hair.texture }
    local props = type(raw.props) == 'table' and raw.props or {}
    local propIds = { 0, 1, 2, 6, 7 }
    for i = 1, #propIds do
        local pid = propIds[i]
        local p = at(props, pid)
        if type(p) ~= 'table' then p = { drawable = -1, texture = 0 } end
        out.props[tostring(pid)] = {
            drawable = clampInt(p.drawable, -1, 512, -1),
            texture = clampInt(p.texture, 0, 128, 0),
        }
    end
    local tats = raw.tattoos
    if type(tats) == 'table' then
        local maxT = Config.MaxTattoos or 48
        local seen = {}
        for i = 1, #tats do
            if #out.tattoos >= maxT then break end
            local t = tats[i]
            if type(t) == 'table' then
                local rec = TattooLookup(t.collection, t.overlay)
                if rec then
                    local key = rec.collection .. ':' .. rec.overlay
                    if not seen[key] then
                        seen[key] = true
                        out.tattoos[#out.tattoos + 1] = {
                            collection = rec.collection,
                            overlay = rec.overlay,
                            zone = rec.zone,
                        }
                    end
                end
            end
        end
    end
    return out
end

local function readJson(space, key)
    local raw = FxDB.get(space, key)
    if type(raw) ~= 'string' or raw == '' then return nil end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then return decoded end
    return nil
end

local function writeJson(space, key, value)
    FxDB.set(space, key, json.encode(value))
end

local function loadSkin(license)
    if not license then return nil end
    return readJson('skin', license)
end

local function saveSkin(license, appearance)
    writeJson('skin', license, appearance)
end

local function loadOutfits(license)
    if not license then return {} end
    local list = readJson('outfits', license)
    if type(list) ~= 'table' then return {} end
    return list
end

local function saveOutfits(license, list)
    writeJson('outfits', license, list)
end

--- Outside the creator, sex / heritage / face stay as stored. No stored skin = first save, allow all.
local function lockIdentity(src, license, appearance)
    if openModes[src] == 'creator' then return appearance end
    local stored = loadSkin(license)
    if type(stored) ~= 'table' then return appearance end
    local base = validateAppearance(stored)
    if not base then return appearance end
    appearance.model = base.model
    appearance.headBlend = base.headBlend
    appearance.faceFeatures = base.faceFeatures
    return appearance
end

local function payloadFor(src)
    local license = getLicense(src)
    local appearance = license and loadSkin(license) or nil
    local outfits = license and loadOutfits(license) or {}
    return {
        hasLicense = license ~= nil,
        canCreator = hasAce(src, 'fivex_appearance.creator'),
        appearance = appearance,
        outfits = outfits,
        needsCreator = license ~= nil and appearance == nil and Config.ForceCreatorOnFirstJoin or false,
    }
end

RegisterNetEvent('fivex_appearance:playerReady', function()
    local src = source
    local p = payloadFor(src)
    if p.needsCreator then
        openModes[src] = 'creator'
    end
    TriggerClientEvent('fivex_appearance:load', src, p)
end)

RegisterNetEvent('fivex_appearance:requestOpen', function(kind, mode)
    local src = source
    kind = tostring(kind or '')
    mode = tostring(mode or 'clothing')
    if mode ~= 'clothing' and mode ~= 'barber' and mode ~= 'tattoo' and mode ~= 'creator' then
        mode = 'clothing'
    end
    local p = payloadFor(src)
    if kind == 'creator' then
        local firstJoin = p.appearance == nil
        local allowed = firstJoin or p.canCreator
        p.kind = 'creator'
        p.ok = allowed
        p.mode = 'creator'
        if allowed then
            openModes[src] = 'creator'
        end
        TriggerClientEvent('fivex_appearance:openAllowed', src, p)
        return
    end
    if mode == 'creator' then
        mode = 'clothing'
    end
    p.kind = 'shop'
    p.ok = true
    p.mode = mode
    openModes[src] = mode
    TriggerClientEvent('fivex_appearance:openAllowed', src, p)
end)

RegisterNetEvent('fivex_appearance:save', function(raw)
    local src = source
    if not rateOk(src, 'save') then
        TriggerClientEvent('fivex_appearance:saveResult', src, { ok = false, reason = 'rate' })
        return
    end
    local license = getLicense(src)
    if not license then
        TriggerClientEvent('fivex_appearance:saveResult', src, { ok = false, reason = 'license' })
        notify(src, L('cannot_save_license'), 'error')
        return
    end
    local appearance, err = validateAppearance(raw)
    if not appearance then
        TriggerClientEvent('fivex_appearance:saveResult', src, { ok = false, reason = 'invalid' })
        return
    end
    appearance = lockIdentity(src, license, appearance)
    saveSkin(license, appearance)
    -- First-join creator grant ends once a skin exists; reopening needs the ACE.
    if openModes[src] == 'creator' and not hasAce(src, 'fivex_appearance.creator') then
        openModes[src] = nil
    end
    TriggerClientEvent('fivex_appearance:saveResult', src, { ok = true, appearance = appearance })
    webhook('Appearance saved', ('**%s** (%s) saved their appearance (%s).'):format(GetPlayerName(src) or '?', src, appearance.model), 6001135)
end)

RegisterNetEvent('fivex_appearance:outfitSave', function(name, raw)
    local src = source
    if not rateOk(src, 'save') then
        notify(src, L('rate_limited'), 'error')
        return
    end
    local license = getLicense(src)
    if not license then
        notify(src, L('cannot_save_license'), 'error')
        return
    end
    name = clampName(name, Config.MaxOutfitName or 24)
    if name == '' then
        notify(src, L('outfit_named'), 'error')
        return
    end
    local appearance, err = validateAppearance(raw)
    if not appearance then
        notify(src, L('invalid_appearance'), 'error')
        return
    end
    appearance = lockIdentity(src, license, appearance)
    local list = loadOutfits(license)
    local maxN = Config.MaxOutfits or 16
    local replaced = false
    for i = 1, #list do
        if list[i].name == name then
            list[i] = { name = name, skin = appearance }
            replaced = true
            break
        end
    end
    if not replaced then
        if #list >= maxN then
            notify(src, L('outfit_max'), 'error')
            return
        end
        list[#list + 1] = { name = name, skin = appearance }
    end
    saveOutfits(license, list)
    TriggerClientEvent('fivex_appearance:outfits', src, list)
    notify(src, L('saved'), 'success')
    webhook('Outfit saved', ('**%s** (%s) saved outfit `%s`.'):format(GetPlayerName(src) or '?', src, name), 6001135)
end)

RegisterNetEvent('fivex_appearance:outfitLoad', function(id)
    local src = source
    if not rateOk(src, 'save') then
        notify(src, L('rate_limited'), 'error')
        return
    end
    local license = getLicense(src)
    if not license then
        notify(src, L('cannot_save_license'), 'error')
        return
    end
    local list = loadOutfits(license)
    local idx = tonumber(id)
    local found
    if idx then
        found = list[idx]
    elseif type(id) == 'string' then
        for i = 1, #list do
            if list[i].name == id then
                found = list[i]
                break
            end
        end
    end
    if type(found) ~= 'table' or type(found.skin) ~= 'table' then
        return
    end
    local appearance = validateAppearance(found.skin)
    if not appearance then return end
    saveSkin(license, appearance)
    TriggerClientEvent('fivex_appearance:applyOutfit', src, appearance)
    TriggerClientEvent('fivex_appearance:saveResult', src, { ok = true, appearance = appearance })
    webhook('Outfit loaded', ('**%s** (%s) loaded outfit `%s`.'):format(GetPlayerName(src) or '?', src, found.name or '?'), 6001135)
end)

RegisterNetEvent('fivex_appearance:outfitDelete', function(id)
    local src = source
    if not rateOk(src, 'save') then
        notify(src, L('rate_limited'), 'error')
        return
    end
    local license = getLicense(src)
    if not license then
        notify(src, L('cannot_save_license'), 'error')
        return
    end
    local list = loadOutfits(license)
    local idx = tonumber(id)
    if not idx or idx < 1 or idx > #list then return end
    local name = list[idx].name
    table.remove(list, idx)
    saveOutfits(license, list)
    TriggerClientEvent('fivex_appearance:outfits', src, list)
    notify(src, L('deleted') ~= 'deleted' and L('deleted') or 'Deleted.', 'success')
    webhook('Outfit deleted', ('**%s** (%s) deleted outfit `%s`.'):format(GetPlayerName(src) or '?', src, name or '?'), 13369344)
end)

AddEventHandler('playerDropped', function()
    local src = source
    openModes[src] = nil
    local prefix = tostring(src) .. ':'
    for k in pairs(rateBuckets) do
        if k:sub(1, #prefix) == prefix then
            rateBuckets[k] = nil
        end
    end
end)
