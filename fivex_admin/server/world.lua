-- Authoritative world clock + weather. The server clock keeps running (unless frozen) and is re-sent
-- to everyone every Config.WorldSync.SyncInterval, so all players share one time and weather and
-- nothing else (vMenu, scripts, the game's own weather cycle) can drift it.

local sync = Config.WorldSync or {}
local MINUTE_MS = math.max(100, math.floor(tonumber(sync.MinuteMs) or 2000))

World = World or {
    hour = math.floor(tonumber(sync.StartHour) or 12),
    minute = 0,
    freeze = sync.StartFrozen == true,
    weather = string.upper(tostring(sync.StartWeather or 'CLEAR')),
    blackout = false,
}

-- clock = baseMinutes at baseAt, advancing one in-game minute per MINUTE_MS
local baseMinutes = World.hour * 60 + World.minute
local baseAt = GetGameTimer()

local function advance()
    if World.freeze then return end
    local total = (baseMinutes + math.floor((GetGameTimer() - baseAt) / MINUTE_MS)) % 1440
    World.hour = math.floor(total / 60)
    World.minute = total % 60
end

local function rebase()
    baseMinutes = World.hour * 60 + World.minute
    baseAt = GetGameTimer()
end

function World.Snapshot()
    advance()
    return {
        hour = World.hour,
        minute = World.minute,
        freeze = World.freeze,
        weather = World.weather,
        blackout = World.blackout,
        msPerMinute = MINUTE_MS,
    }
end

function World.Broadcast()
    TriggerClientEvent('fivex_admin:worldSync', -1, World.Snapshot())
end

function World.SetTime(hour, minute, freeze)
    advance()
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
    rebase()
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
    if sync.Enabled == false then return end
    local src = source
    SetTimeout(2000, function()
        if GetPlayerName(src) then
            TriggerClientEvent('fivex_admin:worldSync', src, World.Snapshot())
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(math.max(2000, tonumber(sync.SyncInterval) or 10000))
        if sync.Enabled ~= false then World.Broadcast() end
    end
end)
