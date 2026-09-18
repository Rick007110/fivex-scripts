function CollectIdentifiers(src)
    local map = {}
    local count = GetNumPlayerIdentifiers(src)
    for i = 0, count - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            local prefix, value = id:match('^([^:]+):(.+)$')
            if prefix and value then
                map[prefix] = id
            end
        end
    end
    return map
end

function PlayerOnline(id)
    id = tonumber(id)
    if not id then return false end
    return GetPlayerName(id) ~= nil
end

function BuildPlayerEntry(src, includeIdentifiers)
    local ped = GetPlayerPed(src)
    local coords = vector3(0.0, 0.0, 0.0)
    if ped and ped ~= 0 then
        coords = GetEntityCoords(ped)
    end
    local bucket = 0
    pcall(function()
        bucket = GetPlayerRoutingBucket(src) or 0
    end)
    local entry = {
        id = src,
        name = GetPlayerName(src) or ('Player ' .. tostring(src)),
        ping = GetPlayerPing(src) or 0,
        bucket = bucket,
        coords = { x = coords.x, y = coords.y, z = coords.z },
    }
    if includeIdentifiers then
        entry.identifiers = CollectIdentifiers(src)
    end
    return entry
end

function BuildPlayerList(includeIdentifiers)
    local list = {}
    local players = GetPlayers()
    for i = 1, #players do
        local src = tonumber(players[i])
        list[#list + 1] = BuildPlayerEntry(src, includeIdentifiers)
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end
