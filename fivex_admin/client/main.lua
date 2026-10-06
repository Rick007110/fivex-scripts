local RESOURCE = GetCurrentResourceName()

MenuOpen = false
AllowedActions = {}
GrantedAces = {}
NuiLocale = {}
NuiConfig = {}

local frozenByMenu = false

local function nui(msg)
    SendNUIMessage(msg)
end

function Notify(message, ntype)
    ntype = ntype or 'info'
    if GetResourceState('ox_lib') == 'started' then
        pcall(function()
            exports.ox_lib:notify({ description = message, type = ntype == 'error' and 'error' or (ntype == 'success' and 'success' or 'inform') })
        end)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message or '')
        EndTextCommandThefeedPostTicker(false, false)
    end
    if MenuOpen then
        nui({ type = 'toast', message = message, level = ntype })
    end
end

local function setFocus(on)
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(false)
end

function CloseMenu()
    if not MenuOpen then
        setFocus(false)
        return
    end
    MenuOpen = false
    setFocus(false)
    nui({ type = 'close' })
    if frozenByMenu then
        frozenByMenu = false
        if not (SelfState and SelfState.freeze) then
            FreezeEntityPosition(PlayerPedId(), false)
        end
    end
end

function OpenMenu()
    if MenuOpen then
        CloseMenu()
        return
    end
    TriggerServerEvent('fivex_admin:requestOpen')
end

RegisterNetEvent('fivex_admin:openResult', function(payload)
    if type(payload) ~= 'table' then return end
    AllowedActions = payload.actions or {}
    GrantedAces = payload.aces or {}
    NuiLocale = payload.locale or {}
    NuiConfig = payload.config or {}
    MenuOpen = true
    setFocus(true)
    if Config.FreezeOnOpen then
        frozenByMenu = true
        FreezeEntityPosition(PlayerPedId(), true)
    end
    payload.type = 'open'
    payload.savedVehicles = LoadSavedVehicles()
    payload.savedLocations = LoadSavedLocations()
    payload.toggles = CollectToggleState()
    nui(payload)
    PushToggleState()
end)

RegisterNetEvent('fivex_admin:notify', function(message, ntype)
    Notify(message, ntype)
end)

RegisterNetEvent('fivex_admin:playerList', function(list)
    if not MenuOpen then return end
    nui({ type = 'players', players = list or {} })
end)

RegisterNetEvent('fivex_admin:banList', function(list)
    if not MenuOpen then return end
    nui({ type = 'bans', bans = list or {} })
end)

RegisterNetEvent('fivex_admin:resourceList', function(list)
    if not MenuOpen then return end
    nui({ type = 'resources', resources = list or {} })
end)

RegisterNetEvent('fivex_admin:playerRecord', function(record)
    if not MenuOpen then return end
    nui({ type = 'playerRecord', record = record or {} })
end)

RegisterNetEvent('fivex_admin:auditLog', function(list)
    if not MenuOpen then return end
    nui({ type = 'audit', audit = list or {} })
end)

RegisterNetEvent('fivex_admin:lookupResult', function(result)
    if not MenuOpen then return end
    nui({ type = 'lookup', lookup = result or {} })
end)

RegisterNetEvent('fivex_admin:clipboard', function(text)
    nui({ type = 'clipboard', text = tostring(text or '') })
    Notify(L('copied'), 'success')
end)

RegisterNetEvent('fivex_admin:announce', function(author, message)
    nui({ type = 'announce', author = author, message = message })
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(('~b~%s~s~: %s'):format(author or 'Staff', message or ''))
    EndTextCommandThefeedPostTicker(false, true)
end)

RegisterNetEvent('fivex_admin:staffMessage', function(author, message)
    Notify(('Staff (%s): %s'):format(author or 'Staff', message or ''), 'info')
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(('~y~Staff~s~ (%s): %s'):format(author or 'Staff', message or ''))
    EndTextCommandThefeedPostTicker(false, true)
end)

RegisterNetEvent('fivex_admin:worldSync', function(state)
    ApplyWorldState(state)
    if MenuOpen then
        nui({ type = 'world', world = state })
    end
end)

RegisterNetEvent('fivex_admin:clearArea', function(coords, radius, mode)
    if type(coords) ~= 'table' then return end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    radius = tonumber(radius) or Config.ClearRadius
    if not x then return end
    if mode == 'peds' or mode == 'all' then
        ClearAreaOfPeds(x, y, z, radius, 1)
    end
    if mode == 'vehicles' or mode == 'all' then
        ClearAreaOfVehicles(x, y, z, radius, false, false, false, false, false)
    end
end)

RegisterNetEvent('fivex_admin:playerDropped', function(id)
    if SpectateTarget == id then
        StopSpectate(true)
        Notify(L('spectate_dropped'), 'info')
    end
    if MenuOpen then
        nui({ type = 'playerDropped', id = id })
    end
end)

RegisterNetEvent('fivex_admin:targetAction', function(kind, payload, _staff)
    payload = payload or {}
    local ped = PlayerPedId()
    if kind == 'teleport' then
        TeleportTo(payload.x, payload.y, payload.z, payload.w)
    elseif kind == 'freeze' then
        SelfState.remoteFreeze = not SelfState.remoteFreeze
        FreezeEntityPosition(ped, SelfState.remoteFreeze or SelfState.freeze)
    elseif kind == 'heal' then
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
    elseif kind == 'revive' then
        ReviveLocalPed()
    elseif kind == 'armor' then
        SetPedArmour(ped, 100)
    elseif kind == 'strip' then
        RemoveAllPedWeapons(ped, true)
    elseif kind == 'warn' then
        Notify(L('warned', payload.reason or ''), 'error')
        nui({ type = 'announce', author = 'Warning', message = payload.reason or '' })
    end
end)


RegisterCommand(Config.Command, function()
    OpenMenu()
end, false)

RegisterKeyMapping(Config.Command, 'Open FiveX Admin', 'keyboard', Config.Keybind)

RegisterNUICallback('close', function(_, cb)
    CloseMenu()
    cb({ ok = true })
end)

RegisterNUICallback('action', function(data, cb)
    if type(data) ~= 'table' or type(data.id) ~= 'string' then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('fivex_admin:action', data.id, data.payload or {})
    cb({ ok = true })
end)

RegisterNUICallback('refreshPlayers', function(_, cb)
    TriggerServerEvent('fivex_admin:refreshPlayers')
    cb({ ok = true })
end)

RegisterNUICallback('refreshBans', function(_, cb)
    TriggerServerEvent('fivex_admin:refreshBans')
    cb({ ok = true })
end)

RegisterNUICallback('refreshResources', function(_, cb)
    TriggerServerEvent('fivex_admin:refreshResources')
    cb({ ok = true })
end)

RegisterNUICallback('playerRecord', function(data, cb)
    local tid = tonumber(data and data.target)
    if tid then
        TriggerServerEvent('fivex_admin:playerRecord', tid)
    end
    cb({ ok = true })
end)

RegisterNUICallback('copied', function(_, cb)
    Notify(L('copied'), 'success')
    cb({ ok = true })
end)

function TeleportTo(x, y, z, w)
    local ped = PlayerPedId()
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if not x or not y or not z then return end
    local veh = GetVehiclePedIsIn(ped, false)
    RequestCollisionAtCoord(x, y, z)
    local ent = (veh ~= 0) and veh or ped
    SetEntityCoordsNoOffset(ent, x, y, z, false, false, false)
    if w then
        SetEntityHeading(ent, tonumber(w) or 0.0)
    end
end

function ReviveLocalPed()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, h, true, false)
    ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 0)
    ClearPedBloodDamage(ped)
    SetPlayerSprint(PlayerId(), true)
    ClearPedTasksImmediately(ped)
end

WorldState = { hour = 12, minute = 0, freeze = false, weather = 'CLEAR', blackout = false }

local appliedWeather = nil
WorldClock = { minutes = 12 * 60, at = 0, msPerMinute = 2000, synced = false }

-- Server sends this on join and every few seconds. Only corrects what is actually off, so regular
-- syncs are invisible: clock fixed if >1 min out, weather blended in only when it changes.
function ApplyWorldState(state)
    if type(state) ~= 'table' then return end
    WorldState.hour = tonumber(state.hour) or WorldState.hour
    WorldState.minute = tonumber(state.minute) or WorldState.minute
    WorldState.freeze = state.freeze and true or false
    WorldState.weather = state.weather or WorldState.weather
    WorldState.blackout = state.blackout and true or false

    -- new base for the per-frame clock below
    WorldClock.minutes = WorldState.hour * 60 + WorldState.minute
    WorldClock.at = GetGameTimer()
    WorldClock.msPerMinute = math.max(100, math.floor(tonumber(state.msPerMinute) or WorldClock.msPerMinute))

    if appliedWeather == nil then
        SetWeatherTypeNowPersist(WorldState.weather)      -- first sync: no transition
    elseif appliedWeather ~= WorldState.weather then
        SetWeatherTypeOvertimePersist(WorldState.weather, 15.0)
    end
    appliedWeather = WorldState.weather
    WorldClock.synced = true
    SetOverrideWeather(WorldState.weather)                -- re-asserted every sync: nothing else can drift it
    SetWeatherTypePersist(WorldState.weather)
    SetArtificialLightsState(WorldState.blackout)
    SetArtificialLightsStateAffectsVehicles(WorldState.blackout)
    if PushToggleState then
        PushToggleState()
    end
end

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    setFocus(false)
    MenuOpen = false
    if NoclipActive then StopNoclip() end
    if Spectating then StopSpectate(false) end
    RestoreSelfDefaults()
    FreezeEntityPosition(PlayerPedId(), false)
    NetworkClearClockTimeOverride()
end)

-- Set the clock every frame from the server's base (like vSync/weathersync). The game's own network
-- clock sync otherwise pulls the time back every second or so and it visibly flips.
CreateThread(function()
    while true do
        if WorldClock.synced then
            local h, m, sec
            if WorldState.freeze then
                h, m, sec = WorldState.hour, WorldState.minute, 0
            else
                local elapsed = GetGameTimer() - WorldClock.at
                local total = WorldClock.minutes + elapsed / WorldClock.msPerMinute
                local whole = math.floor(total)
                sec = math.floor((total - whole) * 60)
                whole = whole % 1440
                h, m = math.floor(whole / 60), whole % 60
            end
            NetworkOverrideClockTime(h, m, sec)
            Wait(0)
        else
            Wait(500)
        end
    end
end)
