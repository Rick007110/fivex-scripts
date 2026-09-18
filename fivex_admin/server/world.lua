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
    if hour < 0 then hour = 0 end
    if hour > 23 then hour = 23 end
    if minute < 0 then minute = 0 end
    if minute > 59 then minute = 59 end
    World.hour = hour
    World.minute = minute
    if freeze ~= nil then
        World.freeze = freeze and true or false
    end
    World.Broadcast()
end

function World.SetWeather(weather)
    weather = string.upper(tostring(weather or 'CLEAR'))
    local ok = false
    for i = 1, #Config.WeatherPresets do
        if Config.WeatherPresets[i] == weather then
            ok = true
            break
        end
    end
    if not ok then return false end
    World.weather = weather
    World.Broadcast()
    return true
end

function World.SetBlackout(on)
    World.blackout = on and true or false
    World.Broadcast()
end

AddEventHandler('playerJoining', function()
    local src = source
    TriggerClientEvent('fivex_admin:worldSync', src, World.Snapshot())
end)
