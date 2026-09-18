World = World or {
    hour = 12,
    minute = 0,
    freeze = false,
    weather = 'CLEAR',
    blackout = false,
}

function World.Snapshot()
    return {
        hour = World.hour,
        minute = World.minute,
        freeze = World.freeze,
        weather = World.weather,
        blackout = World.blackout,
    }
end

function World.Broadcast()
    TriggerClientEvent('fivex_admin:worldSync', -1, World.Snapshot())
end

function World.SetTime(hour, minute, freeze)
    hour = math.floor(tonumber(hour) or 12)
    minute = math.floor(tonumber(minute) or 0)
    hour = math.max(0, math.min(23, hour))
    minute = math.max(0, math.min(59, minute))
    World.hour = hour
    World.minute = minute
    if freeze ~= nil then
        World.freeze = not not freeze
    end
    World.Broadcast()
end

function World.SetWeather(weather)
    weather = string.upper(tostring(weather or 'CLEAR'))
    local ok = false
    for _, w in ipairs(Config.WeatherPresets or {}) do
        if w == weather then ok = true break end
    end
    if not ok then return false end
    World.weather = weather
    World.Broadcast()
    return true
end

function World.SetBlackout(on)
    World.blackout = not not on
    World.Broadcast()
end

AddEventHandler('playerJoining', function()
    TriggerClientEvent('fivex_admin:worldSync', source, World.Snapshot())
end)
