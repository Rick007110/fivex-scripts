function CollectIdentifiers(src)
    local out = {}
    local n = GetNumPlayerIdentifiers(src)
    for i = 0, n - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id then
            local colon = id:find(':')
            if colon then
                out[id:sub(1, colon - 1)] = id
            end
        end
    end
    return out
end

function IsPlayerOnline(id)
    id = tonumber(id)
    if not id then return false end
    return GetPlayerName(id) ~= nil
end

function BuildPlayerRow(src, withIds)
    local ped = GetPlayerPed(src)
    local c = vector3(0.0, 0.0, 0.0)
    if ped and ped ~= 0 then
        c = GetEntityCoords(ped)
    end
    local bucket = 0
    pcall(function()
        bucket = GetPlayerRoutingBucket(src) or 0
    end)
    local row = {
        id = src,
        name = GetPlayerName(src) or ('ID ' .. tostring(src)),
        ping = GetPlayerPing(src) or 0,
        bucket = bucket,
        coords = { x = c.x, y = c.y, z = c.z },
    }
    if withIds then
        row.identifiers = CollectIdentifiers(src)
    end
    return row
end

function BuildPlayerList(withIds)
    local list = {}
    for _, sid in ipairs(GetPlayers()) do
        list[#list + 1] = BuildPlayerRow(tonumber(sid), withIds)
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end
