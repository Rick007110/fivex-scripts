-- Saves each spawned player's position (KVP per license) so they can pick "Last location" next time.

local KVP = 'fivex_spawn_last_v1:'
-- MySQL table (server/db.lua); the first start imports the old KVP data
FxDB.space('last', 'fivex_spawn_last', 'text', { kvp = KVP, key = 'license', value = 'position' })
local ready = {} -- [src] = true once the player has actually spawned (not while in the selector)

local function license(src)
    local lic = GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifierByType(src, 'license2')
    if type(lic) ~= 'string' or lic == '' then return nil end
    return lic
end

local function save(src)
    if not ready[src] then return end
    local lic = license(src)
    local ped = GetPlayerPed(src)
    if not lic or not ped or ped == 0 then return end
    if GetEntityHealth(ped) <= 0 then return end -- don't remember where someone died
    local c = GetEntityCoords(ped)
    if c.z < -50.0 or (math.abs(c.x) < 1.0 and math.abs(c.y) < 1.0) then return end
    FxDB.set('last', lic, json.encode({ x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped), t = os.time() }))
end

RegisterNetEvent('fivex_spawn:requestLast', function()
    local src = source
    local lic = license(src)
    local raw = lic and FxDB.get('last', lic)
    local last = nil
    if Config.LastLocation and raw and raw ~= '' then
        local ok, d = pcall(json.decode, raw)
        if ok and type(d) == 'table' and tonumber(d.x) then last = d end
    end
    TriggerClientEvent('fivex_spawn:last', src, last)
end)

RegisterNetEvent('fivex_spawn:spawned', function()
    ready[source] = true
end)

CreateThread(function()
    while true do
        Wait(math.max(10, Config.SaveInterval) * 1000)
        for src in pairs(ready) do
            if GetPlayerName(src) then save(src) else ready[src] = nil end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    save(src) -- usually too late (ped gone), the periodic save covers it
    ready[src] = nil
end)
