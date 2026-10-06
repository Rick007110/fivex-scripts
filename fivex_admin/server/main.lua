local RESOURCE = GetCurrentResourceName()

local ACE_NODES = {
    'fivex_admin',
    'fivex_admin.open',
    'fivex_admin.self',
    'fivex_admin.players',
    'fivex_admin.kick',
    'fivex_admin.ban',
    'fivex_admin.unban',
    'fivex_admin.warn',
    'fivex_admin.teleport',
    'fivex_admin.spectate',
    'fivex_admin.freeze',
    'fivex_admin.world',
    'fivex_admin.spawn.vehicle',
    'fivex_admin.spawn.weapon',
    'fivex_admin.dev',
    'fivex_admin.resources',
    'fivex_admin.audit',
    'fivex_admin.notes',
    'fivex_admin.spawn.prop',
    'fivex_admin.spawn.ped',
}

local rateBuckets = {}

local function hasAce(src, node)
    if type(src) ~= 'number' or src <= 0 then return false end
    if IsPlayerAceAllowed(src, 'fivex_admin') then return true end
    if node and IsPlayerAceAllowed(src, node) then return true end
    return false
end

local function actionAllowed(src, def)
    if not def then return false end
    if hasAce(src, def.ace) then return true end
    if type(def.aceOr) == 'string' and hasAce(src, def.aceOr) then return true end
    if type(def.aceOr) == 'table' then
        for i = 1, #def.aceOr do
            if hasAce(src, def.aceOr[i]) then return true end
        end
    end
    return false
end

local function grantedAces(src)
    local out = {}
    for i = 1, #ACE_NODES do
        local n = ACE_NODES[i]
        if IsPlayerAceAllowed(src, n) or IsPlayerAceAllowed(src, 'fivex_admin') then
            out[#out + 1] = n
        end
    end
    return out
end

local function notify(src, message, ntype)
    TriggerClientEvent('fivex_admin:notify', src, message or '', ntype or 'info')
end

local function validReason(reason)
    if type(reason) ~= 'string' then return false end
    reason = reason:gsub('^%s+', ''):gsub('%s+$', '')
    local n = #reason
    return n >= Config.MinReasonLength and n <= Config.MaxReasonLength, reason
end

local function clampString(s, maxLen)
    if type(s) ~= 'string' then return '' end
    if #s > maxLen then
        return s:sub(1, maxLen)
    end
    return s
end

local function rateOk(src, key, spec)
    spec = spec or Config.RateLimit.Generic
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
        username = 'fivex_admin',
        embeds = {{
            title = title,
            description = description,
            color = color or 6001135,
            footer = { text = RESOURCE },
        }},
    })
    PerformHttpRequest(url, function() end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

SendAdminWebhook = webhook

local function durationSeconds(durationId)
    for i = 1, #Config.BanDurations do
        local d = Config.BanDurations[i]
        if d.id == durationId then
            return d.seconds, d.label
        end
    end
    return nil, nil
end

local function resourceNameOk(name)
    return type(name) == 'string' and name:match('^[%w_%-]+$') ~= nil and #name <= 64
end

--- Action catalog (sent to NUI after ACE filter).
local Catalog = {}

local function add(entry)
    Catalog[#Catalog + 1] = entry
end

-- Self
add({ id = 'self.noclip', label = 'Noclip', category = 'self', keywords = 'fly ghost noclip clip', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'self.godmode', label = 'Godmode', category = 'self', keywords = 'invincible god mode', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'self.invisibility', label = 'Invisibility', category = 'self', keywords = 'invisible hide stealth', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'self.superjump', label = 'Super jump', category = 'self', keywords = 'jump super', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'self.fastrun', label = 'Fast run', category = 'self', keywords = 'sprint speed run', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'self.infstamina', label = 'Infinite stamina', category = 'self', keywords = 'stamina sprint', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'self.infoxygen', label = 'Infinite oxygen', category = 'self', keywords = 'oxygen swim drown', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'self.heal', label = 'Heal self', category = 'self', keywords = 'health hp heal', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'self.armor', label = 'Full armor', category = 'self', keywords = 'armour armor kevlar', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'self.revive', label = 'Revive self', category = 'self', keywords = 'revive up death', ace = 'fivex_admin.self', kind = 'command' })
for lvl = 0, 5 do
    add({ id = 'self.wanted.' .. lvl, label = 'Wanted level ' .. lvl, category = 'self', keywords = 'stars wanted police ' .. lvl, ace = 'fivex_admin.self', kind = 'command', payload = { level = lvl } })
end
add({ id = 'self.wanted.disable', label = 'Disable wanted', category = 'self', keywords = 'wanted stars never police', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'self.ragdoll', label = 'Ragdoll', category = 'self', keywords = 'fall ragdoll trip', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'self.freeze', label = 'Freeze self', category = 'self', keywords = 'freeze freeze self ice', ace = 'fivex_admin.freeze', kind = 'toggle' })
add({ id = 'self.overlay.names', label = 'Player names overlay', category = 'self', keywords = 'names nametags overlay', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'self.overlay.blips', label = 'Player blips', category = 'self', keywords = 'blips map players', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'self.overlay.ids', label = 'Player IDs overlay', category = 'self', keywords = 'id ids gamer tags', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'self.copy.vector3', label = 'Copy vector3', category = 'self', keywords = 'copy coords vector3 xyz', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'self.copy.vector4', label = 'Copy vector4', category = 'self', keywords = 'copy coords vector4 xyzw heading', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'self.copy.heading', label = 'Copy heading', category = 'self', keywords = 'copy heading rotation', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'self.clear.blood', label = 'Clear blood', category = 'self', keywords = 'blood clean damage', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'self.clear.wetness', label = 'Clear wetness', category = 'self', keywords = 'wet dry water', ace = 'fivex_admin.self', kind = 'command' })

-- Vehicles
add({ id = 'veh.spawn', label = 'Spawn vehicle', category = 'vehicles', keywords = 'spawn car vehicle', ace = 'fivex_admin.spawn.vehicle', kind = 'form' })
add({ id = 'veh.repair', label = 'Repair vehicle', category = 'vehicles', keywords = 'repair fix engine body', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.wash', label = 'Wash vehicle', category = 'vehicles', keywords = 'wash clean dirt', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.flip', label = 'Flip vehicle', category = 'vehicles', keywords = 'flip upright roll', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.engine.on', label = 'Engine on', category = 'vehicles', keywords = 'engine start ignition', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.engine.off', label = 'Engine off', category = 'vehicles', keywords = 'engine stop ignition', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.delete', label = 'Delete current vehicle', category = 'vehicles', keywords = 'delete remove current vehicle', ace = 'fivex_admin.spawn.vehicle', kind = 'confirm' })
add({ id = 'veh.deleteNearby', label = 'Delete nearby vehicles', category = 'vehicles', keywords = 'delete nearby radius vehicles', ace = 'fivex_admin.spawn.vehicle', kind = 'confirm' })
add({ id = 'veh.godmode', label = 'Vehicle godmode', category = 'vehicles', keywords = 'godmode invincible vehicle', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'veh.freeze', label = 'Freeze vehicle', category = 'vehicles', keywords = 'freeze vehicle park', ace = 'fivex_admin.freeze', kind = 'toggle' })
add({ id = 'veh.boost', label = 'Boost vehicle', category = 'vehicles', keywords = 'boost speed nitro', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.drift', label = 'Drift tires', category = 'vehicles', keywords = 'drift tires grip', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'veh.enter', label = 'Enter as driver', category = 'vehicles', keywords = 'enter warp driver seat', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.door.0', label = 'Toggle front left door', category = 'vehicles', keywords = 'door fl driver', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.door.1', label = 'Toggle front right door', category = 'vehicles', keywords = 'door fr passenger', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.door.2', label = 'Toggle rear left door', category = 'vehicles', keywords = 'door rl', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.door.3', label = 'Toggle rear right door', category = 'vehicles', keywords = 'door rr', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.hood', label = 'Toggle hood', category = 'vehicles', keywords = 'hood bonnet', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.trunk', label = 'Toggle trunk', category = 'vehicles', keywords = 'trunk boot', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.windows', label = 'Toggle windows', category = 'vehicles', keywords = 'windows roll', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'veh.extras', label = 'Toggle extra', category = 'vehicles', keywords = 'extras livery extra', ace = 'fivex_admin.self', kind = 'form' })
add({ id = 'veh.livery', label = 'Set livery', category = 'vehicles', keywords = 'livery paint skin', ace = 'fivex_admin.self', kind = 'form' })
add({ id = 'veh.xenon', label = 'Xenon headlights', category = 'vehicles', keywords = 'xenon lights color', ace = 'fivex_admin.self', kind = 'form' })
add({ id = 'veh.tint', label = 'Window tint', category = 'vehicles', keywords = 'tint windows', ace = 'fivex_admin.self', kind = 'form' })
add({ id = 'veh.plate', label = 'Set plate text', category = 'vehicles', keywords = 'plate license number', ace = 'fivex_admin.self', kind = 'form' })
add({ id = 'veh.save', label = 'Save current vehicle', category = 'vehicles', keywords = 'save garage personal kvp', ace = 'fivex_admin.spawn.vehicle', kind = 'form' })
add({ id = 'veh.saved.spawn', label = 'Spawn saved vehicle', category = 'vehicles', keywords = 'saved garage spawn', ace = 'fivex_admin.spawn.vehicle', kind = 'form' })
add({ id = 'veh.saved.delete', label = 'Delete saved vehicle', category = 'vehicles', keywords = 'saved garage delete', ace = 'fivex_admin.spawn.vehicle', kind = 'form' })

-- Weapons
add({ id = 'weap.give', label = 'Give weapon', category = 'weapons', keywords = 'give gun weapon spawn', ace = 'fivex_admin.spawn.weapon', kind = 'form' })
add({ id = 'weap.giveAll', label = 'Give all weapons', category = 'weapons', keywords = 'give all loadout', ace = 'fivex_admin.spawn.weapon', kind = 'command' })
add({ id = 'weap.removeAll', label = 'Remove all weapons', category = 'weapons', keywords = 'strip remove all weapons', ace = 'fivex_admin.spawn.weapon', kind = 'command' })
add({ id = 'weap.refill', label = 'Refill ammo', category = 'weapons', keywords = 'ammo refill reload', ace = 'fivex_admin.self', kind = 'command' })
add({ id = 'weap.infammo', label = 'Infinite ammo', category = 'weapons', keywords = 'infinite ammo', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'weap.noreload', label = 'No reload', category = 'weapons', keywords = 'no reload clip', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'weap.norecoil', label = 'No recoil', category = 'weapons', keywords = 'recoil no kick', ace = 'fivex_admin.self', kind = 'toggle' })
add({ id = 'weap.maxclip', label = 'Max clip', category = 'weapons', keywords = 'clip ammo max', ace = 'fivex_admin.self', kind = 'command' })

-- Teleport
add({ id = 'tp.waypoint', label = 'Teleport to waypoint', category = 'teleport', keywords = 'waypoint gps marker tp', ace = 'fivex_admin.teleport', kind = 'command' })
add({ id = 'tp.coords', label = 'Teleport to coordinates', category = 'teleport', keywords = 'paste coords xyz teleport', ace = 'fivex_admin.teleport', kind = 'form' })
for i = 1, #Config.Locations do
    local loc = Config.Locations[i]
    add({
        id = 'tp.location.' .. loc.id,
        label = 'Teleport: ' .. loc.label,
        category = 'teleport',
        keywords = loc.id .. ' ' .. loc.label .. ' teleport location',
        ace = 'fivex_admin.teleport',
        kind = 'command',
        payload = { id = loc.id },
    })
end
add({ id = 'tp.saveLocation', label = 'Save current location', category = 'teleport', keywords = 'save location kvp personal', ace = 'fivex_admin.teleport', kind = 'form' })
add({ id = 'tp.saved', label = 'Teleport to saved location', category = 'teleport', keywords = 'saved location personal', ace = 'fivex_admin.teleport', kind = 'form' })
add({ id = 'tp.saved.delete', label = 'Delete saved location', category = 'teleport', keywords = 'delete saved location', ace = 'fivex_admin.teleport', kind = 'form' })
add({ id = 'tp.toPlayer', label = 'Teleport to player', category = 'teleport', keywords = 'goto player teleport', ace = 'fivex_admin.teleport', kind = 'target' })
add({ id = 'tp.bring', label = 'Bring player', category = 'teleport', keywords = 'bring player teleport here', ace = 'fivex_admin.teleport', kind = 'target' })

-- Players
add({ id = 'ply.spectate', label = 'Spectate player', category = 'players', keywords = 'spectate watch cam', ace = 'fivex_admin.spectate', kind = 'target' })
add({ id = 'ply.spectate.stop', label = 'Stop spectating', category = 'players', keywords = 'spectate stop cam', ace = 'fivex_admin.spectate', kind = 'command' })
add({ id = 'ply.teleportTo', label = 'Teleport to selected player', category = 'players', keywords = 'goto teleport player', ace = 'fivex_admin.teleport', kind = 'target' })
add({ id = 'ply.bring', label = 'Bring selected player', category = 'players', keywords = 'bring player here', ace = 'fivex_admin.teleport', kind = 'target' })
add({ id = 'ply.freeze', label = 'Freeze player', category = 'players', keywords = 'freeze player ice', ace = 'fivex_admin.freeze', kind = 'target' })
add({ id = 'ply.heal', label = 'Heal player', category = 'players', keywords = 'heal player hp', ace = 'fivex_admin.players', kind = 'target' })
add({ id = 'ply.revive', label = 'Revive player', category = 'players', keywords = 'revive player up', ace = 'fivex_admin.players', kind = 'target' })
add({ id = 'ply.armor', label = 'Armor player', category = 'players', keywords = 'armor player kevlar', ace = 'fivex_admin.players', kind = 'target' })
add({ id = 'ply.strip', label = 'Strip weapons', category = 'players', keywords = 'strip weapons remove guns', ace = 'fivex_admin.players', kind = 'target' })
add({ id = 'ply.kick', label = 'Kick player', category = 'players', keywords = 'kick player drop', ace = 'fivex_admin.kick', kind = 'confirm' })
add({ id = 'ply.warn', label = 'Warn player', category = 'players', keywords = 'warn warning', ace = 'fivex_admin.warn', kind = 'confirm' })
add({ id = 'ply.ban', label = 'Ban player', category = 'players', keywords = 'ban player 1h 1d 7d 30d perm', ace = 'fivex_admin.ban', kind = 'confirm' })
add({ id = 'ply.message', label = 'Message player', category = 'players', keywords = 'pm message tell staff', ace = 'fivex_admin.players', kind = 'form' })
add({ id = 'ply.copyIds', label = 'Copy identifiers', category = 'players', keywords = 'identifiers license discord steam copy', ace = 'fivex_admin.players', kind = 'target' })
add({ id = 'ply.note', label = 'Add player note', category = 'players', keywords = 'note notes staff memo', ace = 'fivex_admin.notes', aceOr = 'fivex_admin.players', kind = 'form' })
add({ id = 'ply.mute', label = 'Mute player', category = 'players', keywords = 'mute voice chat silence', ace = 'fivex_admin.players', kind = 'target' })
add({ id = 'ply.unmute', label = 'Unmute player', category = 'players', keywords = 'unmute voice chat', ace = 'fivex_admin.players', kind = 'target' })
add({ id = 'ply.bucket', label = 'Set routing bucket', category = 'players', keywords = 'bucket routing instance dimension', ace = 'fivex_admin.players', kind = 'form' })
add({ id = 'ply.screenshot', label = 'Screenshot player', category = 'players', keywords = 'screenshot capture photo', ace = 'fivex_admin.players', kind = 'target' })

-- Bans
add({ id = 'ban.unban', label = 'Unban', category = 'bans', keywords = 'unban remove ban', ace = 'fivex_admin.unban', kind = 'confirm' })
add({ id = 'ban.offline', label = 'Ban offline', category = 'bans', keywords = 'offline ban license', ace = 'fivex_admin.ban', kind = 'form' })
add({ id = 'ban.lookup', label = 'Lookup identifier', category = 'bans', keywords = 'lookup license discord steam notes warns', ace = 'fivex_admin.ban', aceOr = { 'fivex_admin.unban', 'fivex_admin.players', 'fivex_admin.notes' }, kind = 'form' })

-- World
add({ id = 'world.time', label = 'Set time', category = 'world', keywords = 'time clock hour', ace = 'fivex_admin.world', kind = 'form' })
add({ id = 'world.time.morning', label = 'Time: morning (6:00)', category = 'world', keywords = 'time morning dawn 6', ace = 'fivex_admin.world', kind = 'command', payload = { hour = 6, minute = 0 } })
add({ id = 'world.time.noon', label = 'Time: noon (12:00)', category = 'world', keywords = 'time noon midday 12', ace = 'fivex_admin.world', kind = 'command', payload = { hour = 12, minute = 0 } })
add({ id = 'world.time.evening', label = 'Time: evening (18:00)', category = 'world', keywords = 'time evening sunset 18', ace = 'fivex_admin.world', kind = 'command', payload = { hour = 18, minute = 0 } })
add({ id = 'world.time.night', label = 'Time: night (21:00)', category = 'world', keywords = 'time night 21', ace = 'fivex_admin.world', kind = 'command', payload = { hour = 21, minute = 0 } })
add({ id = 'world.freezeTime', label = 'Freeze time', category = 'world', keywords = 'freeze time clock pause', ace = 'fivex_admin.world', kind = 'toggle' })
for i = 1, #Config.WeatherPresets do
    local w = Config.WeatherPresets[i]
    add({ id = 'world.weather.' .. w, label = 'Weather: ' .. w, category = 'world', keywords = 'weather ' .. w:lower(), ace = 'fivex_admin.world', kind = 'command', payload = { weather = w } })
end
add({ id = 'world.blackout', label = 'Blackout', category = 'world', keywords = 'blackout lights city dark', ace = 'fivex_admin.world', kind = 'toggle' })
add({ id = 'world.clearPeds', label = 'Clear area peds', category = 'world', keywords = 'clear peds npcs area', ace = 'fivex_admin.world', kind = 'command' })
add({ id = 'world.clearVehicles', label = 'Clear area vehicles', category = 'world', keywords = 'clear vehicles cars area', ace = 'fivex_admin.world', kind = 'command' })
add({ id = 'world.clearAll', label = 'Clear area (peds + vehicles)', category = 'world', keywords = 'clear both area peds vehicles', ace = 'fivex_admin.world', kind = 'command' })

-- Dev
add({ id = 'dev.overlay', label = 'Dev overlay', category = 'dev', keywords = 'coords speed aim entity overlay', ace = 'fivex_admin.dev', kind = 'toggle' })
add({ id = 'dev.copyVehHash', label = 'Copy vehicle hash', category = 'dev', keywords = 'copy hash vehicle model', ace = 'fivex_admin.dev', kind = 'command' })
add({ id = 'dev.copyWeapHash', label = 'Copy weapon hash', category = 'dev', keywords = 'copy hash weapon', ace = 'fivex_admin.dev', kind = 'command' })

-- Entities
add({ id = 'ent.prop.spawn', label = 'Spawn prop', category = 'entities', keywords = 'prop object spawn cone barrier', ace = 'fivex_admin.spawn.prop', kind = 'form' })
add({ id = 'ent.prop.deleteLast', label = 'Delete last prop', category = 'entities', keywords = 'prop delete last', ace = 'fivex_admin.spawn.prop', kind = 'command' })
add({ id = 'ent.prop.deleteNearby', label = 'Delete nearby props', category = 'entities', keywords = 'prop delete nearby radius', ace = 'fivex_admin.spawn.prop', kind = 'command' })
add({ id = 'ent.ped.spawn', label = 'Spawn ped', category = 'entities', keywords = 'ped npc spawn', ace = 'fivex_admin.spawn.ped', kind = 'form' })
add({ id = 'ent.ped.deleteLast', label = 'Delete last ped', category = 'entities', keywords = 'ped delete last', ace = 'fivex_admin.spawn.ped', kind = 'command' })
add({ id = 'ent.ped.deleteNearby', label = 'Delete nearby peds', category = 'entities', keywords = 'ped delete nearby radius', ace = 'fivex_admin.spawn.ped', kind = 'command' })

-- Audit
add({ id = 'audit.refresh', label = 'Refresh audit log', category = 'audit', keywords = 'audit log history staff', ace = 'fivex_admin.audit', kind = 'command' })

-- Staff
add({ id = 'staff.announce', label = 'Announcement', category = 'staff', keywords = 'announce broadcast staff', ace = 'fivex_admin.players', kind = 'form' })
add({ id = 'staff.restart', label = 'Restart resource', category = 'staff', keywords = 'restart resource ensure', ace = 'fivex_admin.resources', kind = 'confirm' })

local CatalogById = {}
for i = 1, #Catalog do
    CatalogById[Catalog[i].id] = Catalog[i]
end

local function filteredCatalog(src)
    local out = {}
    for i = 1, #Catalog do
        local a = Catalog[i]
        if actionAllowed(src, a) then
            out[#out + 1] = {
                id = a.id,
                label = a.label,
                category = a.category,
                keywords = a.keywords,
                kind = a.kind,
                payload = a.payload,
            }
        end
    end
    return out
end

local function publicConfig()
    return {
        banDurations = Config.BanDurations,
        locations = Config.Locations,
        weather = Config.WeatherPresets,
        deleteRadius = Config.DeleteRadius,
        clearRadius = Config.ClearRadius,
        maxAnnounce = Config.MaxAnnounceLength,
        maxReason = Config.MaxReasonLength,
        minReason = Config.MinReasonLength,
        maxPlate = Config.MaxPlateLength,
        playerRefreshMs = Config.PlayerRefreshMs,
        command = Config.Command,
        keybind = Config.Keybind,
    }
end

local function localePack()
    return Locales[Config.Locale] or Locales['en'] or {}
end

local function resourceList()
    local out = {}
    local n = GetNumResources()
    for i = 0, n - 1 do
        local name = GetResourceByFindIndex(i)
        if name then
            out[#out + 1] = { name = name, state = GetResourceState(name) }
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local function openPayload(src)
    local canPlayers = hasAce(src, 'fivex_admin.players')
    local canUnban = hasAce(src, 'fivex_admin.unban') or hasAce(src, 'fivex_admin.ban')
    local canRes = hasAce(src, 'fivex_admin.resources')
    return {
        type = 'open',
        actions = filteredCatalog(src),
        players = canPlayers and BuildPlayerList(true) or {},
        bans = canUnban and Bans.Serialize() or {},
        resources = canRes and resourceList() or {},
        aces = grantedAces(src),
        locale = localePack(),
        config = publicConfig(),
        vehicles = VehicleCatalog,
        weapons = WeaponCatalog,
        props = PropCatalog,
        peds = PedCatalog,
        world = World.Snapshot(),
        audit = hasAce(src, 'fivex_admin.audit') and Audit.Serialize() or {},
    }
end

RegisterNetEvent('fivex_admin:requestOpen', function()
    local src = source
    if not hasAce(src, 'fivex_admin.open') then
        notify(src, L('open_denied'), 'error')
        return
    end
    if not rateOk(src, 'open', { max = 8, window = 5000 }) then
        notify(src, L('rate_limited'), 'error')
        return
    end
    TriggerClientEvent('fivex_admin:openResult', src, openPayload(src))
end)

RegisterNetEvent('fivex_admin:refreshPlayers', function()
    local src = source
    if not hasAce(src, 'fivex_admin.players') then return end
    TriggerClientEvent('fivex_admin:playerList', src, BuildPlayerList(true))
end)

RegisterNetEvent('fivex_admin:refreshBans', function()
    local src = source
    if not (hasAce(src, 'fivex_admin.unban') or hasAce(src, 'fivex_admin.ban')) then return end
    TriggerClientEvent('fivex_admin:banList', src, Bans.Serialize())
end)

RegisterNetEvent('fivex_admin:refreshResources', function()
    local src = source
    if not hasAce(src, 'fivex_admin.resources') then return end
    TriggerClientEvent('fivex_admin:resourceList', src, resourceList())
end)

RegisterNetEvent('fivex_admin:playerRecord', function(target)
    local src = source
    if not (hasAce(src, 'fivex_admin.players') or hasAce(src, 'fivex_admin.notes')) then return end
    if not rateOk(src, 'record', Config.RateLimit.Generic) then return end
    local tid = tonumber(target)
    if not tid or not PlayerOnline(tid) then
        notify(src, L('invalid_target'), 'error')
        return
    end
    local rec = BuildPlayerRecord(tid)
    if rec then
        TriggerClientEvent('fivex_admin:playerRecord', src, rec)
    end
end)

local function requireTarget(src, payload)
    local tid = tonumber(payload and payload.target)
    if not tid or not PlayerOnline(tid) then
        notify(src, L('invalid_target'), 'error')
        return nil
    end
    return tid
end

local function selfApply(src, actionId, payload)
    TriggerClientEvent('fivex_admin:applySelf', src, actionId, payload or {})
end

local function vehApply(src, actionId, payload)
    TriggerClientEvent('fivex_admin:applyVehicle', src, actionId, payload or {})
end

local function weapApply(src, actionId, payload)
    TriggerClientEvent('fivex_admin:applyWeapon', src, actionId, payload or {})
end

local Handlers = {}

local function register(id, fn)
    Handlers[id] = fn
end

register('self.noclip', function(src) selfApply(src, 'self.noclip') end)
register('self.godmode', function(src) selfApply(src, 'self.godmode') end)
register('self.invisibility', function(src) selfApply(src, 'self.invisibility') end)
register('self.superjump', function(src) selfApply(src, 'self.superjump') end)
register('self.fastrun', function(src) selfApply(src, 'self.fastrun') end)
register('self.infstamina', function(src) selfApply(src, 'self.infstamina') end)
register('self.infoxygen', function(src) selfApply(src, 'self.infoxygen') end)
register('self.heal', function(src) selfApply(src, 'self.heal') end)
register('self.armor', function(src) selfApply(src, 'self.armor') end)
register('self.revive', function(src) selfApply(src, 'self.revive') end)
for lvl = 0, 5 do
    register('self.wanted.' .. lvl, function(src) selfApply(src, 'self.wanted', { level = lvl }) end)
end
register('self.wanted.disable', function(src) selfApply(src, 'self.wanted.disable') end)
register('self.ragdoll', function(src) selfApply(src, 'self.ragdoll') end)
register('self.freeze', function(src) selfApply(src, 'self.freeze') end)
register('self.overlay.names', function(src) selfApply(src, 'self.overlay.names') end)
register('self.overlay.blips', function(src) selfApply(src, 'self.overlay.blips') end)
register('self.overlay.ids', function(src) selfApply(src, 'self.overlay.ids') end)
register('self.copy.vector3', function(src) selfApply(src, 'self.copy.vector3') end)
register('self.copy.vector4', function(src) selfApply(src, 'self.copy.vector4') end)
register('self.copy.heading', function(src) selfApply(src, 'self.copy.heading') end)
register('self.clear.blood', function(src) selfApply(src, 'self.clear.blood') end)
register('self.clear.wetness', function(src) selfApply(src, 'self.clear.wetness') end)

register('veh.spawn', function(src, payload)
    local model = payload and payload.model
    if type(model) ~= 'string' or not FindVehicleInCatalog(model) then
        notify(src, L('invalid_model'), 'error')
        return
    end
    vehApply(src, 'veh.spawn', { model = string.lower(model) })
end)
register('veh.repair', function(src) vehApply(src, 'veh.repair') end)
register('veh.wash', function(src) vehApply(src, 'veh.wash') end)
register('veh.flip', function(src) vehApply(src, 'veh.flip') end)
register('veh.engine.on', function(src) vehApply(src, 'veh.engine', { on = true }) end)
register('veh.engine.off', function(src) vehApply(src, 'veh.engine', { on = false }) end)
register('veh.delete', function(src) vehApply(src, 'veh.delete') end)
register('veh.deleteNearby', function(src)
    vehApply(src, 'veh.deleteNearby', { radius = Config.DeleteRadius })
end)
register('veh.godmode', function(src) vehApply(src, 'veh.godmode') end)
register('veh.freeze', function(src) vehApply(src, 'veh.freeze') end)
register('veh.boost', function(src) vehApply(src, 'veh.boost') end)
register('veh.drift', function(src) vehApply(src, 'veh.drift') end)
register('veh.enter', function(src) vehApply(src, 'veh.enter') end)
for d = 0, 3 do
    register('veh.door.' .. d, function(src) vehApply(src, 'veh.door', { index = d }) end)
end
register('veh.hood', function(src) vehApply(src, 'veh.door', { index = 4 }) end)
register('veh.trunk', function(src) vehApply(src, 'veh.door', { index = 5 }) end)
register('veh.windows', function(src) vehApply(src, 'veh.windows') end)
register('veh.extras', function(src, payload)
    local extra = tonumber(payload and payload.extra)
    if not extra or extra < 1 or extra > 14 then return end
    vehApply(src, 'veh.extras', { extra = extra })
end)
register('veh.livery', function(src, payload)
    local idx = tonumber(payload and payload.livery)
    if idx == nil then return end
    vehApply(src, 'veh.livery', { livery = math.floor(idx) })
end)
register('veh.xenon', function(src, payload)
    local color = tonumber(payload and payload.color)
    if color == nil or color < 0 or color > 12 then return end
    vehApply(src, 'veh.xenon', { color = math.floor(color) })
end)
register('veh.tint', function(src, payload)
    local tint = tonumber(payload and payload.tint)
    if tint == nil or tint < 0 or tint > 6 then return end
    vehApply(src, 'veh.tint', { tint = math.floor(tint) })
end)
register('veh.plate', function(src, payload)
    local plate = clampString(tostring(payload and payload.plate or ''), Config.MaxPlateLength)
    plate = plate:upper():gsub('[^%w ]', '')
    if plate == '' then return end
    vehApply(src, 'veh.plate', { plate = plate })
end)
register('veh.save', function(src, payload)
    local name = clampString(tostring(payload and payload.name or 'Saved'), 32)
    vehApply(src, 'veh.save', { name = name })
end)
register('veh.saved.spawn', function(src, payload)
    local id = tostring(payload and payload.id or '')
    if id == '' then return end
    vehApply(src, 'veh.saved.spawn', { id = id })
end)
register('veh.saved.delete', function(src, payload)
    local id = tostring(payload and payload.id or '')
    if id == '' then return end
    vehApply(src, 'veh.saved.delete', { id = id })
end)

register('weap.give', function(src, payload)
    local name = payload and payload.weapon
    if type(name) ~= 'string' or not FindWeaponInCatalog(name) then
        notify(src, L('invalid_weapon'), 'error')
        return
    end
    weapApply(src, 'weap.give', { weapon = string.upper(name) })
end)
register('weap.giveAll', function(src) weapApply(src, 'weap.giveAll') end)
register('weap.removeAll', function(src) weapApply(src, 'weap.removeAll') end)
register('weap.refill', function(src) weapApply(src, 'weap.refill') end)
register('weap.infammo', function(src) weapApply(src, 'weap.infammo') end)
register('weap.noreload', function(src) weapApply(src, 'weap.noreload') end)
register('weap.norecoil', function(src) weapApply(src, 'weap.norecoil') end)
register('weap.maxclip', function(src) weapApply(src, 'weap.maxclip') end)

register('tp.waypoint', function(src)
    TriggerClientEvent('fivex_admin:applyTeleport', src, 'waypoint', {})
end)
register('tp.coords', function(src, payload)
    local x, y, z = tonumber(payload and payload.x), tonumber(payload and payload.y), tonumber(payload and payload.z)
    local w = tonumber(payload and payload.w) or 0.0
    if not x or not y or not z then
        notify(src, L('invalid_coords'), 'error')
        return
    end
    if x ~= x or y ~= y or z ~= z then
        notify(src, L('invalid_coords'), 'error')
        return
    end
    if math.abs(x) > 12000 or math.abs(y) > 12000 or z < -400 or z > 2500 then
        notify(src, L('invalid_coords'), 'error')
        return
    end
    TriggerClientEvent('fivex_admin:applyTeleport', src, 'coords', { x = x, y = y, z = z, w = w })
end)

local locById = {}
for i = 1, #Config.Locations do
    locById[Config.Locations[i].id] = Config.Locations[i]
    local loc = Config.Locations[i]
    register('tp.location.' .. loc.id, function(src)
        TriggerClientEvent('fivex_admin:applyTeleport', src, 'coords', { x = loc.x, y = loc.y, z = loc.z, w = loc.w })
    end)
end

register('tp.saveLocation', function(src, payload)
    local name = clampString(tostring(payload and payload.name or 'Saved'), 32)
    TriggerClientEvent('fivex_admin:applyTeleport', src, 'save', { name = name })
end)
register('tp.saved', function(src, payload)
    local id = tostring(payload and payload.id or '')
    if id == '' then return end
    TriggerClientEvent('fivex_admin:applyTeleport', src, 'saved', { id = id })
end)
register('tp.saved.delete', function(src, payload)
    local id = tostring(payload and payload.id or '')
    if id == '' then return end
    TriggerClientEvent('fivex_admin:applyTeleport', src, 'savedDelete', { id = id })
end)

local function teleportStaffTo(src, target)
    local tped = GetPlayerPed(target)
    if not tped or tped == 0 then
        notify(src, L('invalid_target'), 'error')
        return
    end
    local c = GetEntityCoords(tped)
    local h = GetEntityHeading(tped)
    TriggerClientEvent('fivex_admin:applyTeleport', src, 'coords', { x = c.x, y = c.y, z = c.z, w = h })
end

local function bringPlayer(src, target)
    local sped = GetPlayerPed(src)
    if not sped or sped == 0 then return end
    local c = GetEntityCoords(sped)
    local h = GetEntityHeading(sped)
    TriggerClientEvent('fivex_admin:targetAction', target, 'teleport', { x = c.x + 1.0, y = c.y, z = c.z, w = h }, src)
end

register('tp.toPlayer', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    teleportStaffTo(src, tid)
end)
register('tp.bring', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    bringPlayer(src, tid)
    Audit.Log(src, 'bring', { target = tid, targetName = GetPlayerName(tid), license = RecordsLicenseOf(tid) })
end)
register('ply.teleportTo', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    teleportStaffTo(src, tid)
end)
register('ply.bring', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    bringPlayer(src, tid)
    Audit.Log(src, 'bring', { target = tid, targetName = GetPlayerName(tid), license = RecordsLicenseOf(tid) })
end)

register('ply.spectate', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    if tid == src then
        notify(src, L('invalid_target'), 'error')
        return
    end
    local tped = GetPlayerPed(tid)
    local coords = nil
    if tped and tped ~= 0 then
        local c = GetEntityCoords(tped)
        coords = { x = c.x, y = c.y, z = c.z }
    end
    TriggerClientEvent('fivex_admin:spectateStart', src, tid, coords)
end)
register('ply.spectate.stop', function(src)
    TriggerClientEvent('fivex_admin:spectateStop', src)
end)

register('ply.freeze', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    TriggerClientEvent('fivex_admin:targetAction', tid, 'freeze', {}, src)
    Audit.Log(src, 'freeze', { target = tid, targetName = GetPlayerName(tid), license = RecordsLicenseOf(tid) })
end)
register('ply.heal', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    TriggerClientEvent('fivex_admin:targetAction', tid, 'heal', {}, src)
end)
register('ply.revive', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    TriggerClientEvent('fivex_admin:targetAction', tid, 'revive', {}, src)
end)
register('ply.armor', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    TriggerClientEvent('fivex_admin:targetAction', tid, 'armor', {}, src)
end)
register('ply.strip', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    TriggerClientEvent('fivex_admin:targetAction', tid, 'strip', {}, src)
end)

register('ply.kick', function(src, payload)
    if not rateOk(src, 'kick', Config.RateLimit.Kick) then
        notify(src, L('rate_limited'), 'error')
        return
    end
    local tid = requireTarget(src, payload)
    if not tid then return end
    local ok, reason = validReason(payload and payload.reason)
    if not ok then
        notify(src, L('invalid_reason'), 'error')
        return
    end
    local tname = GetPlayerName(tid) or '?'
    Audit.Log(src, 'kick', { target = tid, targetName = tname, license = RecordsLicenseOf(tid), detail = reason })
    DropPlayer(tid, L('kicked', reason))
    notify(src, 'Kicked ' .. tname, 'success')
end)

register('ply.warn', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    local ok, reason = validReason(payload and payload.reason)
    if not ok then
        notify(src, L('invalid_reason'), 'error')
        return
    end
    TriggerClientEvent('fivex_admin:targetAction', tid, 'warn', { reason = reason }, src)
    local license = RecordsLicenseOf(tid)
    if license then
        Warns.Add(license, src, reason)
    end
    Audit.Log(src, 'warn', { target = tid, targetName = GetPlayerName(tid), license = license, detail = reason })
    notify(src, 'Warned ' .. (GetPlayerName(tid) or '?'), 'success')
    local rec = BuildPlayerRecord(tid)
    if rec then TriggerClientEvent('fivex_admin:playerRecord', src, rec) end
end)

register('ply.ban', function(src, payload)
    if not rateOk(src, 'ban', Config.RateLimit.Ban) then
        notify(src, L('rate_limited'), 'error')
        return
    end
    local tid = requireTarget(src, payload)
    if not tid then return end
    local ok, reason = validReason(payload and payload.reason)
    if not ok then
        notify(src, L('invalid_reason'), 'error')
        return
    end
    local seconds, durLabel = durationSeconds(payload and payload.durationId or 'perm')
    if seconds == nil then
        notify(src, L('invalid_reason'), 'error')
        return
    end
    local ids = CollectIdentifiers(tid)
    if not ids.license then
        notify(src, 'Target has no license identifier; cannot ban.', 'error')
        return
    end
    local expires = 0
    if seconds > 0 then
        expires = os.time() + seconds
    end
    local tname = GetPlayerName(tid) or '?'
    Bans.Add({
        name = tname,
        reason = reason,
        staff = CollectIdentifiers(src).license or tostring(src),
        staffName = GetPlayerName(src) or 'staff',
        expires = expires,
        durationId = payload.durationId or 'perm',
        identifiers = {
            license = ids.license,
            discord = ids.discord,
            fivem = ids.fivem,
            steam = ids.steam,
        },
    })
    Audit.Log(src, 'ban', { target = tid, targetName = tname, license = ids.license, detail = (durLabel or 'perm') .. ' — ' .. reason })
    DropPlayer(tid, L('banned', reason))
    notify(src, 'Banned ' .. tname, 'success')
    if hasAce(src, 'fivex_admin.unban') or hasAce(src, 'fivex_admin.ban') then
        TriggerClientEvent('fivex_admin:banList', src, Bans.Serialize())
    end
end)

register('ply.message', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    local msg = clampString(tostring(payload and payload.message or ''), Config.MaxAnnounceLength)
    if #msg < 1 then return end
    TriggerClientEvent('fivex_admin:staffMessage', tid, GetPlayerName(src) or 'Staff', msg)
    notify(src, 'Message sent', 'success')
end)

register('ply.copyIds', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    local ids = CollectIdentifiers(tid)
    local parts = {}
    for _, k in ipairs({ 'license', 'discord', 'fivem', 'steam', 'live', 'xbl', 'ip' }) do
        -- Never send IP to NUI.
        if k ~= 'ip' and ids[k] then
            parts[#parts + 1] = ids[k]
        end
    end
    TriggerClientEvent('fivex_admin:clipboard', src, table.concat(parts, '\n'))
end)

register('ban.unban', function(src, payload)
    local banId = tostring(payload and payload.banId or '')
    if banId == '' then return end
    local removed = Bans.Remove(banId)
    if not removed then
        notify(src, 'Ban not found.', 'error')
        return
    end
    local lic = removed.identifiers and removed.identifiers.license or nil
    Audit.Log(src, 'unban', { targetName = removed.name, license = lic, detail = removed.id })
    notify(src, L('deleted'), 'success')
    TriggerClientEvent('fivex_admin:banList', src, Bans.Serialize())
end)

register('world.time', function(src, payload)
    World.SetTime(payload and payload.hour, payload and payload.minute, World.freeze)
end)
register('world.time.morning', function() World.SetTime(6, 0, World.freeze) end)
register('world.time.noon', function() World.SetTime(12, 0, World.freeze) end)
register('world.time.evening', function() World.SetTime(18, 0, World.freeze) end)
register('world.time.night', function() World.SetTime(21, 0, World.freeze) end)
register('world.freezeTime', function()
    World.SetTime(World.hour, World.minute, not World.freeze)
end)
for i = 1, #Config.WeatherPresets do
    local w = Config.WeatherPresets[i]
    register('world.weather.' .. w, function() World.SetWeather(w) end)
end
register('world.blackout', function() World.SetBlackout(not World.blackout) end)
register('world.clearPeds', function(src)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    TriggerClientEvent('fivex_admin:clearArea', -1, { x = c.x, y = c.y, z = c.z }, Config.ClearRadius, 'peds')
end)
register('world.clearVehicles', function(src)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    TriggerClientEvent('fivex_admin:clearArea', -1, { x = c.x, y = c.y, z = c.z }, Config.ClearRadius, 'vehicles')
end)
register('world.clearAll', function(src)
    local ped = GetPlayerPed(src)
    local c = GetEntityCoords(ped)
    TriggerClientEvent('fivex_admin:clearArea', -1, { x = c.x, y = c.y, z = c.z }, Config.ClearRadius, 'all')
end)

register('dev.overlay', function(src) selfApply(src, 'dev.overlay') end)
register('dev.copyVehHash', function(src) selfApply(src, 'dev.copyVehHash') end)
register('dev.copyWeapHash', function(src) selfApply(src, 'dev.copyWeapHash') end)

register('staff.announce', function(src, payload)
    if not rateOk(src, 'announce', Config.RateLimit.Announce) then
        notify(src, L('rate_limited'), 'error')
        return
    end
    local msg = clampString(tostring(payload and payload.message or ''), Config.MaxAnnounceLength)
    if #msg < 3 then
        notify(src, L('invalid_reason'), 'error')
        return
    end
    TriggerClientEvent('fivex_admin:announce', -1, GetPlayerName(src) or 'Staff', msg)
    webhook(L('webhook_announce'), ('**%s** (%s)\n%s'):format(GetPlayerName(src), src, msg), 3447003)
    notify(src, L('announced'), 'success')
end)

register('staff.restart', function(src, payload)
    local name = payload and payload.resource
    if not resourceNameOk(name) then return end
    if name == RESOURCE then
        notify(src, L('resource_protected'), 'error')
        return
    end
    if GetResourceState(name) == 'missing' then
        notify(src, 'Resource not found.', 'error')
        return
    end
    webhook(L('webhook_restart'), ('**%s** (%s) restarted `%s`'):format(GetPlayerName(src), src, name), 15105570)
    notify(src, L('resource_restarted', name), 'success')
    SetTimeout(300, function()
        StopResource(name)
        SetTimeout(400, function()
            StartResource(name)
        end)
    end)
end)

RegisterNetEvent('fivex_admin:action', function(actionId, payload)
    local src = source
    if type(actionId) ~= 'string' or #actionId > 64 then return end
    if payload ~= nil and type(payload) ~= 'table' then return end
    payload = payload or {}
    local def = CatalogById[actionId]
    if not def then return end
    if not actionAllowed(src, def) then
        notify(src, L('action_denied'), 'error')
        return
    end
    if not rateOk(src, 'act:' .. def.ace, Config.RateLimit.Generic) then
        notify(src, L('rate_limited'), 'error')
        return
    end
    local fn = Handlers[actionId]
    if not fn then return end
    fn(src, payload)
end)


local function pushRecord(src, tid)
    local rec = BuildPlayerRecord(tid)
    if rec then
        TriggerClientEvent('fivex_admin:playerRecord', src, rec)
    end
end

register('ply.note', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    local license = RecordsLicenseOf(tid)
    if not license then
        notify(src, L('persist_no_license'), 'error')
        return
    end
    local entry, err = Notes.Add(license, src, payload and payload.text)
    if not entry then
        notify(src, (err == 'empty') and L('note_empty') or L('persist_no_license'), 'error')
        return
    end
    Audit.Log(src, 'note', { target = tid, targetName = GetPlayerName(tid), license = license, detail = entry.text })
    notify(src, L('note_added'), 'success')
    pushRecord(src, tid)
end)

register('ply.mute', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    local res = Mutes.Mute(tid, src)
    if not res then
        notify(src, L('invalid_target'), 'error')
        return
    end
    if not res.persisted then
        notify(src, L('mute_session_only'), 'info')
    end
    if not Mutes.EnsureChatHook() then
        notify(src, L('mute_chat_unavailable'), 'info')
    end
    Audit.Log(src, 'mute', { target = tid, targetName = GetPlayerName(tid), license = res.license, detail = res.persisted and 'persisted' or 'session' })
    notify(src, L('muted', GetPlayerName(tid) or '?'), 'success')
    pushRecord(src, tid)
end)

register('ply.unmute', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    local res = Mutes.Unmute(tid, src)
    if not res then
        notify(src, L('invalid_target'), 'error')
        return
    end
    Audit.Log(src, 'unmute', { target = tid, targetName = GetPlayerName(tid), license = res.license })
    notify(src, L('unmuted', GetPlayerName(tid) or '?'), 'success')
    pushRecord(src, tid)
end)

register('ply.bucket', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    local n = tonumber(payload and payload.bucket)
    if n == nil or n ~= n then
        notify(src, L('invalid_bucket'), 'error')
        return
    end
    n = math.floor(n)
    if n < 0 then n = 0 end
    if n > 63 then n = 63 end
    SetPlayerRoutingBucket(tid, n)
    Audit.Log(src, 'bucket', { target = tid, targetName = GetPlayerName(tid), license = RecordsLicenseOf(tid), detail = tostring(n) })
    notify(src, L('bucket_set', n), 'success')
    pushRecord(src, tid)
end)

register('ply.screenshot', function(src, payload)
    local tid = requireTarget(src, payload)
    if not tid then return end
    if GetResourceState('screenshot-basic') ~= 'started' then
        notify(src, L('screenshot_missing'), 'error')
        return
    end
    local tname = GetPlayerName(tid) or '?'
    local license = RecordsLicenseOf(tid)
    -- Saved server-side by screenshot-basic (mv into an existing directory).
    local fileName = ('%s/screenshots/%d_%d_%d.jpg'):format(GetResourcePath(RESOURCE), os.time(), tid, math.random(1000, 9999))
    local ok = pcall(function()
        exports['screenshot-basic']:requestClientScreenshot(tid, { fileName = fileName, encoding = 'jpg', quality = 0.6 }, function(err, data)
            if err then
                if PlayerOnline(src) then notify(src, L('screenshot_fail'), 'error') end
                return
            end
            local path = type(data) == 'string' and data or fileName
            Audit.Log(src, 'screenshot', { target = tid, targetName = tname, license = license, detail = path })
            if PlayerOnline(src) then
                notify(src, L('screenshot_saved', tname, path), 'success')
            end
        end)
    end)
    if not ok then
        notify(src, L('screenshot_fail'), 'error')
        return
    end
    notify(src, L('screenshot_requested'), 'info')
end)

register('ban.offline', function(src, payload)
    if not rateOk(src, 'ban', Config.RateLimit.Ban) then
        notify(src, L('rate_limited'), 'error')
        return
    end
    local license = NormalizeLicense(payload and payload.license)
    if not license then
        notify(src, L('invalid_license'), 'error')
        return
    end
    local ok, reason = validReason(payload and payload.reason)
    if not ok then
        notify(src, L('invalid_reason'), 'error')
        return
    end
    local seconds, durLabel = durationSeconds(payload and payload.durationId or 'perm')
    if seconds == nil then
        notify(src, L('invalid_reason'), 'error')
        return
    end
    local expires = 0
    if seconds > 0 then expires = os.time() + seconds end
    local name = clampString(tostring(payload and payload.name or ''), 64)
    if name == '' then name = license end
    local discordRaw = clampString(tostring(payload and payload.discord or ''), 80)
    local discordId = nil
    if discordRaw ~= '' then
        local d = discordRaw
        if d:lower():sub(1, 8) == 'discord:' then
            d = d:sub(9)
        end
        d = d:gsub('^%s+', ''):gsub('%s+$', '')
        if d:match('^[%w]+$') and #d >= 5 then
            discordId = 'discord:' .. d
        end
    end
    local online = select(1, FindPlayerByIdentifiers({ license = license }))
    Bans.Add({
        name = name,
        reason = reason,
        staff = CollectIdentifiers(src).license or tostring(src),
        staffName = GetPlayerName(src) or 'staff',
        expires = expires,
        durationId = payload.durationId or 'perm',
        identifiers = {
            license = license,
            discord = discordId,
        },
    })
    Audit.Log(src, 'offline-ban', { target = online, targetName = name, license = license, detail = (durLabel or 'perm') .. ' — ' .. reason })
    if online then
        DropPlayer(online, L('banned', reason))
    end
    notify(src, L('offline_banned', name), 'success')
    if hasAce(src, 'fivex_admin.unban') or hasAce(src, 'fivex_admin.ban') then
        TriggerClientEvent('fivex_admin:banList', src, Bans.Serialize())
    end
end)

register('ban.lookup', function(src, payload)
    local idents = ParseLookupQuery(payload and payload.query)
    if not idents then
        notify(src, L('lookup_invalid'), 'error')
        TriggerClientEvent('fivex_admin:lookupResult', src, { error = 'invalid' })
        return
    end
    local result = LookupRecords(idents)
    TriggerClientEvent('fivex_admin:lookupResult', src, result)
end)

register('audit.refresh', function(src)
    TriggerClientEvent('fivex_admin:auditLog', src, Audit.Serialize())
end)

register('ent.prop.spawn', function(src, payload)
    local model = payload and payload.model
    if type(model) ~= 'string' or not FindPropInCatalog(model) then
        notify(src, L('invalid_model'), 'error')
        return
    end
    model = string.lower(model)
    local frozen = payload and (payload.frozen == true or payload.frozen == 'true' or payload.frozen == 1 or payload.frozen == 'on')
    TriggerClientEvent('fivex_admin:spawnEntity', src, 'prop', { model = model, frozen = frozen and true or false })
    Audit.Log(src, 'spawn', { detail = 'prop ' .. model })
end)

register('ent.prop.deleteLast', function(src)
    TriggerClientEvent('fivex_admin:deleteEntities', src, 'prop', 'last')
end)

register('ent.prop.deleteNearby', function(src)
    TriggerClientEvent('fivex_admin:deleteEntities', src, 'prop', 'nearby', Config.DeleteRadius)
end)

register('ent.ped.spawn', function(src, payload)
    local model = payload and payload.model
    if type(model) ~= 'string' or not FindPedInCatalog(model) then
        notify(src, L('invalid_model'), 'error')
        return
    end
    model = string.lower(model)
    local frozen = payload and (payload.frozen == true or payload.frozen == 'true' or payload.frozen == 1 or payload.frozen == 'on')
    TriggerClientEvent('fivex_admin:spawnEntity', src, 'ped', { model = model, frozen = frozen and true or false })
    Audit.Log(src, 'spawn', { detail = 'ped ' .. model })
end)

register('ent.ped.deleteLast', function(src)
    TriggerClientEvent('fivex_admin:deleteEntities', src, 'ped', 'last')
end)

register('ent.ped.deleteNearby', function(src)
    TriggerClientEvent('fivex_admin:deleteEntities', src, 'ped', 'nearby', Config.DeleteRadius)
end)

AddEventHandler('playerDropped', function()
    local src = source
    TriggerClientEvent('fivex_admin:playerDropped', -1, src)
end)
