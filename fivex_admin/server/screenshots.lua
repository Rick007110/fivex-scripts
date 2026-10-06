--[[
    Player screenshots in MySQL (table fivex_admin_screenshots). Not part of the FxDB spaces:
    images are large, so nothing is cached in memory. The record only lists them (id, time, staff);
    an image is read from the database when staff opens it.
]]

Shots = {}

local TABLE = 'fivex_admin_screenshots'
local ready = false
local lastView = {}

MySQL.ready(function()
    MySQL.query(([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `license` VARCHAR(100) NOT NULL,
            `target_name` VARCHAR(100) NULL,
            `staff_name` VARCHAR(100) NULL,
            `staff_license` VARCHAR(100) NULL,
            `created` INT UNSIGNED NOT NULL,
            `image` MEDIUMTEXT NOT NULL,
            PRIMARY KEY (`id`),
            KEY `license` (`license`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
    ]]):format(TABLE), {}, function()
        ready = true
    end)
end)

-- dataUri: "data:image/jpeg;base64,..." as screenshot-basic returns it (stored as-is)
function Shots.Save(license, targetName, staffSrc, dataUri, cb)
    if not ready then cb(nil) return end
    local staffName = GetPlayerName(staffSrc) or 'Staff'
    local staffLicense = RecordsLicenseOf(staffSrc)
    MySQL.insert(('INSERT INTO `%s` (license, target_name, staff_name, staff_license, created, image) VALUES (?, ?, ?, ?, ?, ?)'):format(TABLE),
        { license, targetName, staffName, staffLicense, os.time(), dataUri },
        function(id)
            -- keep only the newest N per player
            local keep = math.max(1, tonumber(Config.Screenshots.keepPerPlayer) or 25)
            MySQL.query(([[DELETE FROM `%s` WHERE license = ? AND id NOT IN
                (SELECT id FROM (SELECT id FROM `%s` WHERE license = ? ORDER BY id DESC LIMIT %d) newest)]]):format(TABLE, TABLE, keep),
                { license, license })
            cb(id)
        end)
end

-- newest first, without the image data
function Shots.List(license, cb)
    if not ready or not license then cb({}) return end
    MySQL.query(('SELECT id, created, staff_name FROM `%s` WHERE license = ? ORDER BY id DESC LIMIT 50'):format(TABLE),
        { license }, function(rows)
            local list = {}
            for i, r in ipairs(rows or {}) do
                list[i] = { id = r.id, created = r.created, staffName = r.staff_name }
            end
            cb(list)
        end)
end

local function canView(src)
    return IsPlayerAceAllowed(src, 'fivex_admin') or IsPlayerAceAllowed(src, 'fivex_admin.players')
end

-- Every record sent to staff goes through here so it carries the screenshot list.
function SendPlayerRecord(src, rec)
    if not rec then return end
    local license = RecordsLicenseOf(rec.target)
    if not canView(src) or not license then
        rec.shots = {}
        TriggerClientEvent('fivex_admin:playerRecord', src, rec)
        return
    end
    Shots.List(license, function(list)
        rec.shots = list
        TriggerClientEvent('fivex_admin:playerRecord', src, rec)
    end)
end

-- Staff opens one screenshot: sent with a latent event (images are a few hundred KB)
RegisterNetEvent('fivex_admin:screenshotImage', function(id)
    local src = source
    id = tonumber(id)
    if not id or not canView(src) or not ready then return end
    local now = GetGameTimer()
    if lastView[src] and now - lastView[src] < 750 then return end
    lastView[src] = now
    MySQL.single(('SELECT id, license, target_name, staff_name, created, image FROM `%s` WHERE id = ?'):format(TABLE), { id }, function(row)
        if not row then
            TriggerClientEvent('fivex_admin:screenshotImage', src, { id = id, missing = true })
            return
        end
        TriggerLatentClientEvent('fivex_admin:screenshotImage', src, 250000, {
            id = row.id,
            targetName = row.target_name,
            staffName = row.staff_name,
            created = row.created,
            image = row.image,
        })
    end)
end)

AddEventHandler('playerDropped', function() lastView[source] = nil end)
