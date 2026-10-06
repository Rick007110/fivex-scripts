local RESOURCE = GetCurrentResourceName()

local blips = {}
local menuOpen = false
local menuMode = nil
local balance = 0
local account = nil
local cbWait = {}
local nuiSeq = 0
local atmHashes = {}

for i, model in ipairs(Config.AtmModels) do
    atmHashes[i] = joaat(model)
end

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
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message or '')
    EndTextCommandThefeedPostTicker(false, false)
    nui({ type = 'toast', message = message, level = ntype or 'info' })
end

RegisterNetEvent('fivex_bank:notify', function(message, ntype)
    notify(message, ntype)
end)

exports('GetBalance', function()
    return balance
end)

exports('GetAccount', function()
    return account
end)

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

local function ensureBlips()
    for i, b in ipairs(Config.Branches) do
        if not blips[i] or not DoesBlipExist(blips[i]) then
            local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
            SetBlipSprite(blip, Config.Blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.Blip.scale)
            SetBlipColour(blip, Config.Blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(Config.Blip.label)
            EndTextCommandSetBlipName(blip)
            blips[i] = blip
        end
    end
end

local function closestAtm(coords)
    for i = 1, #atmHashes do
        local obj = GetClosestObjectOfType(coords.x, coords.y, coords.z, Config.AtmDistance, atmHashes[i], false, false, false)
        if obj ~= 0 then return obj end
    end
    return 0
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    setFocus(false)
    nui({ type = 'close' })
    TriggerServerEvent('fivex_bank:close')
    if menuMode == 'atm' then
        ClearPedTasks(PlayerPedId())
    end
    menuMode = nil
end

local openPendingUntil = 0

local function open(mode)
    if menuOpen then return end
    -- one request in flight at a time; cleared by openResult or after 2 s
    local now = GetGameTimer()
    if now < openPendingUntil then return end
    openPendingUntil = now + 2000
    TriggerServerEvent('fivex_bank:open', mode)
end

RegisterNetEvent('fivex_bank:openResult', function(payload)
    if type(payload) ~= 'table' then return end
    openPendingUntil = 0
    menuOpen = true
    menuMode = payload.mode
    balance = tonumber(payload.balance) or balance
    account = payload.account or account
    if menuMode == 'atm' then
        TaskStartScenarioInPlace(PlayerPedId(), 'PROP_HUMAN_ATM', 0, true)
    end
    setFocus(true)
    payload.type = 'open'
    nui(payload)
end)

RegisterNetEvent('fivex_bank:balance', function(bal, acct)
    balance = tonumber(bal) or 0
    account = acct or account
    nui({ type = 'balance', balance = balance })
end)

RegisterNetEvent('fivex_bank:actionResult', function(ok, _msg, state, cbId)
    if cbId and cbWait[cbId] then
        cbWait[cbId]({ ok = ok and true or false })
        cbWait[cbId] = nil
    end
    if type(state) == 'table' then
        balance = tonumber(state.balance) or balance
        state.type = 'state'
        nui(state)
    elseif menuOpen and not ok then
        -- session ended server-side (walked away)
        closeMenu()
    end
end)

-- Sends event(..., cbId) and resolves the NUI callback on actionResult or after 4 s.
local function serverAction(cb, event, ...)
    nuiSeq = nuiSeq + 1
    local id = nuiSeq
    cbWait[id] = cb
    local args = table.pack(...)
    args[args.n + 1] = id
    TriggerServerEvent(event, table.unpack(args, 1, args.n + 1))
    SetTimeout(4000, function()
        if cbWait[id] then
            cbWait[id]({ ok = false })
            cbWait[id] = nil
        end
    end)
end

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('deposit', function(data, cb)
    serverAction(cb, 'fivex_bank:deposit', tonumber(data and data.amount))
end)

RegisterNUICallback('withdraw', function(data, cb)
    serverAction(cb, 'fivex_bank:withdraw', tonumber(data and data.amount))
end)

RegisterNUICallback('transfer', function(data, cb)
    data = data or {}
    serverAction(cb, 'fivex_bank:transfer', tostring(data.account or ''), tonumber(data.amount), tostring(data.note or ''))
end)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/bank', 'Show your bank account, balance, and cash')
    local staff = {
        { name = 'id', help = 'server id' },
        { name = 'amount', help = 'dollars' },
    }
    TriggerEvent('chat:addSuggestion', '/bankgive', 'Staff: add to a bank balance', staff)
    TriggerEvent('chat:addSuggestion', '/banktake', 'Staff: remove from a bank balance', staff)
    TriggerEvent('chat:addSuggestion', '/bankset', 'Staff: set a bank balance', staff)
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(200) end
    Wait(1000)
    ensureBlips()
    TriggerServerEvent('fivex_bank:requestSync')
end)

-- Teller counters
CreateThread(function()
    local m = Config.Marker
    while true do
        local sleep = 500
        local p = GetEntityCoords(PlayerPedId())
        for _, b in ipairs(Config.Branches) do
            local dist = #(p - b.coords)
            if dist < Config.DrawDistance then
                sleep = 0
                DrawMarker(m.type, b.coords.x, b.coords.y, b.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    m.scale.x, m.scale.y, m.scale.z, m.color.r, m.color.g, m.color.b, m.color.a,
                    false, false, 2, false, nil, nil, false)
                drawText3D(b.coords.x, b.coords.y, b.coords.z + 0.35, b.label)
                if dist < Config.InteractDistance and not menuOpen then
                    help(L('prompt_branch'))
                    if IsControlJustPressed(0, 38) then
                        open('branch')
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ATMs (map props)
CreateThread(function()
    local nearAtm = false
    local nextScan = 0
    while true do
        local ped = PlayerPedId()
        local now = GetGameTimer()
        if menuOpen or IsPedInAnyVehicle(ped, false) then
            nearAtm = false
        elseif now >= nextScan then
            -- prop scan is the expensive part; do it twice a second
            nearAtm = closestAtm(GetEntityCoords(ped)) ~= 0
            nextScan = now + 500
        end
        if nearAtm then
            help(L('prompt_atm'))
            if IsControlJustPressed(0, 38) then
                open('atm')
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == RESOURCE then
        ensureBlips()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    closeMenu()
    for i, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        blips[i] = nil
    end
end)
