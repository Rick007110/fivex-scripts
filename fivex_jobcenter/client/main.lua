local RESOURCE = GetCurrentResourceName()

local clerkPed = 0
local clerkBlip = 0
local menuOpen = false
local jobId = false
local balance = 0
local onDuty = false
local cbWait = {}

local function L(key, ...)
    local pack = Locales[Config.Locale] or Locales['en'] or {}
    local s = pack[key] or key
    if select('#', ...) > 0 then
        return s:format(...)
    end
    return s
end

local function nui(msg)
    SendNUIMessage(msg)
end

local function setFocus(on)
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(false)
end

local function notify(message, ntype)
    ntype = ntype or 'info'
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message or '')
    EndTextCommandThefeedPostTicker(false, false)
    nui({ type = 'toast', message = message, level = ntype })
end

RegisterNetEvent('fivex_jobcenter:notify', function(message, ntype)
    notify(message, ntype)
end)

exports('GetJob', function()
    local j = LocalPlayer.state.fivex_job
    if j == false or j == nil or j == '' then return nil end
    return j
end)

exports('SetProgress', function(pct, label)
    if pct == nil or pct == false then
        nui({ type = 'progress', pct = false })
        return
    end
    local n = tonumber(pct)
    if not n then
        nui({ type = 'progress', pct = false })
        return
    end
    nui({ type = 'progress', pct = n, label = label })
end)


local function distToCenter(coords)
    local p = Config.Center
    return #(coords - vector3(p.x, p.y, p.z))
end

local function help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function drawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.28, 0.28)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(230, 237, 243, 220)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function requestModel(hash, timeout)
    if type(hash) == 'string' then hash = joaat(hash) end
    if not IsModelValid(hash) and not IsModelInCdimage(hash) then return 0 end
    RequestModel(hash)
    local untilT = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(hash) and GetGameTimer() < untilT do
        Wait(10)
    end
    if not HasModelLoaded(hash) then return 0 end
    return hash
end

local function deleteClerk()
    if clerkPed ~= 0 and DoesEntityExist(clerkPed) then
        DeleteEntity(clerkPed)
    end
    clerkPed = 0
end

local function spawnClerk()
    deleteClerk()
    local hash = requestModel(Config.PedModel, 5000)
    if hash == 0 then return end
    local c = Config.Center
    local z = c.z
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    if found then z = gz end
    local ped = CreatePed(4, hash, c.x, c.y, z, c.w, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not DoesEntityExist(ped) then return end
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedDefaultComponentVariation(ped)
    TaskStartScenarioInPlace(ped, Config.PedScenario, 0, true)
    clerkPed = ped
end

local function ensureBlip()
    if clerkBlip ~= 0 and DoesBlipExist(clerkBlip) then return end
    local c = Config.Center
    clerkBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(clerkBlip, Config.Blip.sprite)
    SetBlipDisplay(clerkBlip, 4)
    SetBlipScale(clerkBlip, Config.Blip.scale)
    SetBlipColour(clerkBlip, Config.Blip.color)
    SetBlipAsShortRange(clerkBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Blip.label)
    EndTextCommandSetBlipName(clerkBlip)
end

local function closeMenu()
    menuOpen = false
    setFocus(false)
    nui({ type = 'close' })
end

local function tryOpen()
    local p = GetEntityCoords(PlayerPedId())
    if distToCenter(p) > Config.OpenDistance then
        notify(L('opened_remote'), 'error')
        return
    end
    TriggerServerEvent('fivex_jobcenter:open')
end

RegisterNetEvent('fivex_jobcenter:openResult', function(payload)
    if type(payload) ~= 'table' then return end
    menuOpen = true
    setFocus(true)
    payload.type = 'open'
    nui(payload)
end)

RegisterNetEvent('fivex_jobcenter:openDenied', function()
    closeMenu()
end)

RegisterNetEvent('fivex_jobcenter:clientJob', function(job, bal, duty)
    jobId = job
    balance = tonumber(bal) or 0
    onDuty = duty and true or false
    nui({
        type = 'state',
        job = jobId or false,
        jobLabel = (function()
            if not jobId then return 'Unemployed' end
            for i = 1, #Config.Jobs do
                if Config.Jobs[i].id == jobId then return Config.Jobs[i].label end
            end
            return tostring(jobId)
        end)(),
        balance = balance,
        duty = onDuty,
        jobs = Config.Jobs,
    })
end)

RegisterNetEvent('fivex_jobcenter:applyResult', function(ok, _msg, state, cbId)
    if cbId and cbWait[cbId] then
        cbWait[cbId]({ ok = ok and true or false, state = state })
        cbWait[cbId] = nil
    end
    if type(state) == 'table' then
        state.type = 'state'
        nui(state)
    end
end)

local nuiSeq = 0
local function nuiCallback(name, handler)
    RegisterNUICallback(name, function(data, cb)
        handler(data or {}, cb)
    end)
end

nuiCallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

nuiCallback('apply', function(data, cb)
    nuiSeq = nuiSeq + 1
    local id = nuiSeq
    cbWait[id] = cb
    TriggerServerEvent('fivex_jobcenter:apply', data.id, id)
    SetTimeout(4000, function()
        if cbWait[id] then
            cbWait[id]({ ok = false })
            cbWait[id] = nil
        end
    end)
end)

nuiCallback('leave', function(_, cb)
    nuiSeq = nuiSeq + 1
    local id = nuiSeq
    cbWait[id] = cb
    TriggerServerEvent('fivex_jobcenter:leave', id)
    SetTimeout(4000, function()
        if cbWait[id] then
            cbWait[id]({ ok = false })
            cbWait[id] = nil
        end
    end)
end)

RegisterCommand('jobcenter', function()
    if menuOpen then
        closeMenu()
        return
    end
    tryOpen()
end, false)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/job', 'Show your current job, duty status, and pay wallet')
    TriggerEvent('chat:addSuggestion', '/jobcenter', 'Open the job board (must be at the clerk)')
    TriggerEvent('chat:addSuggestion', '/jobcancel', 'Cancel your current assignment')
    TriggerEvent('chat:addSuggestion', '/setjob', 'Staff: set a player job', {
        { name = 'id', help = 'server id' },
        { name = 'job', help = 'coroner | highrise | marina | none' },
    })
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(200) end
    Wait(800)
    ensureBlip()
    spawnClerk()
    TriggerServerEvent('fivex_jobcenter:requestSync')
end)

CreateThread(function()
    local c = Config.Center
    local m = Config.Marker
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        local dist = distToCenter(p)
        if dist < Config.DrawDistance then
            sleep = 0
            DrawMarker(m.type, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                m.scale.x, m.scale.y, m.scale.z, m.color.r, m.color.g, m.color.b, m.color.a,
                false, false, 2, false, nil, nil, false)
            if clerkPed ~= 0 and DoesEntityExist(clerkPed) then
                local coords = GetEntityCoords(clerkPed)
                drawText3D(coords.x, coords.y, coords.z + 1.05, 'Job Center')
            else
                drawText3D(c.x, c.y, c.z + 1.05, 'Job Center')
            end
            if dist < Config.InteractDistance and not menuOpen then
                help(L('prompt_open'))
                if IsControlJustPressed(0, 38) then
                    tryOpen()
                end
            end
        elseif clerkPed == 0 and dist < 80.0 then
            spawnClerk()
        end
        Wait(sleep)
    end
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == RESOURCE then
        ensureBlip()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    closeMenu()
    nui({ type = 'progress', pct = false })
    deleteClerk()
    if clerkBlip ~= 0 then
        RemoveBlip(clerkBlip)
        clerkBlip = 0
    end
end)

-- keep locals referenced
jobId, balance, onDuty = jobId, balance, onDuty
