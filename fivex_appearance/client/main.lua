local RESOURCE = GetCurrentResourceName()

local open = false
local nuiFocused = false
local mode = 'creator'       -- creator | clothing | barber | tattoo
local forced = false
local hasLicense = true
local canCreator = false
local working = nil
local persisted = nil
local openSnapshot = nil
local outfits = {}
local pendingSkin = nil
local needsCreator = false
local appliedOnce = false
local spawnApplied = false

local function nui(msg)
    SendNUIMessage(msg)
end

local function setFocus(on)
    nuiFocused = on and true or false
    SetNuiFocus(on, on)
    SetNuiFocusKeepInput(false)
end

function Notify(message, ntype)
    ntype = ntype or 'info'
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message or '')
    EndTextCommandThefeedPostTicker(false, false)
    if open then
        nui({ type = 'toast', message = message, level = ntype })
    end
end

local function nuiLocale()
    return Locales[Config.Locale] or Locales['en'] or {}
end

local function nuiConfig()
    return {
        maxOutfits = Config.MaxOutfits or 16,
        maxOutfitName = Config.MaxOutfitName or 24,
        maxParent = Config.MaxParent or 45,
        parents = Defaults.Parents,
        overlays = Defaults.Overlays,
        clothingComponents = Defaults.ClothingComponents,
        propIds = Defaults.PropIds,
        palettes = Appearance.PaletteCounts(),
        tattoos = TattooCatalog,
        zones = TattooZones,
    }
end

local function overlayMaxes()
    local t = {}
    for i = 0, 12 do
        t[tostring(i)] = Appearance.OverlayMax(i)
    end
    return t
end

local function pushOpen()
    nui({
        type = 'open',
        mode = mode,
        forced = forced,
        hasLicense = hasLicense,
        appearance = Appearance.ToNui(working),
        outfits = outfits,
        locale = nuiLocale(),
        config = nuiConfig(),
        overlayMax = overlayMaxes(),
    })
end

local function closeInternal(revert)
    if not open then
        setFocus(false)
        Cam.Close()
        return
    end
    if forced then
        return
    end
    if revert and openSnapshot then
        Appearance.Apply(openSnapshot)
        working = Appearance.Clone(openSnapshot)
    end
    open = false
    forced = false
    setFocus(false)
    nui({ type = 'close' })
    Cam.Close()
end

local TABS = {
    creator  = { 'identity', 'heritage', 'face', 'hair', 'overlays', 'eyes', 'clothing', 'props', 'tattoos', 'outfits' },
    clothing = { 'clothing', 'props', 'outfits' },
    barber   = { 'hair', 'overlays', 'eyes', 'outfits' },
    tattoo   = { 'tattoos', 'outfits' },
}

local function openUi(newMode, opts)
    opts = opts or {}
    if open and not opts.replace then
        return
    end
    local ped = PlayerPedId()
    if IsEntityDead(ped) then
        return
    end
    if IsPedInAnyVehicle(ped, false) then
        Notify(L('in_vehicle'), 'error')
        return
    end
    mode = newMode or 'clothing'
    if not TABS[mode] then
        mode = 'clothing'
    end
    forced = opts.forced and true or false
    if not working then
        if persisted then
            working = Appearance.Clone(persisted)
        else
            working = Defaults.Male()
        end
    end
    working = Appearance.Normalize(working)
    openSnapshot = Appearance.Clone(working)
    Appearance.Apply(working)
    open = true
    Cam.Open()
    setFocus(true)
    pushOpen()
    if forced then
        Notify(L('first_join_hint'), 'info')
    end
    if not hasLicense then
        Notify(L('cannot_save_license'), 'error')
    end
end

local function pedReady()
    local ped = PlayerPedId()
    return ped and ped ~= 0 and DoesEntityExist(ped) and NetworkIsPlayerActive(PlayerId())
end

local function maybeOpenCreator()
    if not needsCreator or not Config.ForceCreatorOnFirstJoin or open then
        return
    end
    if not pedReady() then
        return
    end
    working = working or Defaults.Male()
    openUi('creator', { forced = true, replace = true })
end

local function applyPending(reason)
    if not pendingSkin and not needsCreator then
        return
    end
    if not pedReady() then
        return
    end
    local data = pendingSkin
    if type(data) == 'table' then
        local ok = Appearance.Apply(data)
        if ok then
            working = Appearance.Normalize(data)
            persisted = Appearance.Clone(working)
            appliedOnce = true
        end
    elseif needsCreator then
        working = Defaults.Male()
        Appearance.Apply(working)
        appliedOnce = true
    end
    maybeOpenCreator()
end

RegisterNetEvent('fivex_appearance:load', function(payload)
    payload = payload or {}
    hasLicense = payload.hasLicense ~= false
    canCreator = payload.canCreator and true or false
    outfits = payload.outfits or {}
    if type(payload.appearance) == 'table' then
        pendingSkin = Appearance.Normalize(payload.appearance)
        persisted = Appearance.Clone(pendingSkin)
        working = Appearance.Clone(pendingSkin)
        needsCreator = false
    else
        pendingSkin = nil
        persisted = nil
        working = Defaults.Male()
        needsCreator = payload.needsCreator and true or false
    end
    applyPending('load')
end)

RegisterNetEvent('fivex_appearance:saveResult', function(payload)
    payload = payload or {}
    if payload.ok then
        if type(payload.appearance) == 'table' then
            persisted = Appearance.Normalize(payload.appearance)
            working = Appearance.Clone(persisted)
            openSnapshot = Appearance.Clone(persisted)
        else
            persisted = Appearance.Clone(working)
            openSnapshot = Appearance.Clone(working)
        end
        needsCreator = false
        pendingSkin = Appearance.Clone(persisted or working)
        Notify(L('saved'), 'success')
        if open and forced then
            forced = false
            closeInternal(false)
        elseif open then
            nui({ type = 'saved', appearance = Appearance.ToNui(working), outfits = outfits })
        end
    else
        local reason = payload.reason
        if reason == 'license' then
            Notify(L('cannot_save_license'), 'error')
        elseif reason == 'rate' then
            Notify(L('rate_limited'), 'error')
        elseif reason == 'invalid' then
            Notify(L('invalid_appearance'), 'error')
        else
            Notify(L('cannot_save'), 'error')
        end
    end
end)

RegisterNetEvent('fivex_appearance:outfits', function(list)
    outfits = list or {}
    if open then
        nui({ type = 'outfits', outfits = outfits })
    end
end)

RegisterNetEvent('fivex_appearance:openAllowed', function(payload)
    payload = payload or {}
    canCreator = payload.canCreator and true or false
    hasLicense = payload.hasLicense ~= false
    outfits = payload.outfits or outfits
    if type(payload.appearance) == 'table' then
        persisted = Appearance.Normalize(payload.appearance)
        working = Appearance.Clone(persisted)
        pendingSkin = Appearance.Clone(persisted)
        needsCreator = false
    end
    if payload.kind == 'creator' then
        if payload.ok then
            local first = persisted == nil and hasLicense
            openUi('creator', { forced = first })
        else
            Notify(L('creator_denied'), 'error')
        end
    elseif payload.kind == 'shop' then
        openUi(payload.mode or 'clothing', { forced = false })
    end
end)

RegisterNetEvent('fivex_appearance:notify', function(message, ntype)
    Notify(message, ntype)
end)

local function requestLoad()
    TriggerServerEvent('fivex_appearance:playerReady')
end

AddEventHandler('playerSpawned', function()
    spawnApplied = true
    applyPending('playerSpawned')
    SetTimeout(500, function() applyPending('retry500') end)
    SetTimeout(1500, function() applyPending('retry1500') end)
end)

CreateThread(function()
    local tries = 0
    while not NetworkIsPlayerActive(PlayerId()) and tries < 200 do
        Wait(100)
        tries = tries + 1
    end
    requestLoad()
    -- If spawnmanager already spawned before we listened, still apply.
    SetTimeout(2000, function()
        if not spawnApplied then
            applyPending('fallback')
        end
    end)
end)

RegisterCommand(Config.CommandShop, function()
    if open then
        if not forced then
            closeInternal(true)
        end
        return
    end
    TriggerServerEvent('fivex_appearance:requestOpen', 'shop', 'clothing')
end, false)

RegisterKeyMapping(Config.CommandShop, 'Open FiveX clothing', 'keyboard', Config.KeybindShop)

RegisterCommand(Config.CommandCreator, function()
    if open then
        if not forced then
            closeInternal(true)
        end
        return
    end
    TriggerServerEvent('fivex_appearance:requestOpen', 'creator', 'creator')
end, false)

RegisterNUICallback('close', function(_, cb)
    if forced then
        cb({ ok = false, forced = true })
        return
    end
    closeInternal(true)
    Notify(L('reverted'), 'info')
    cb({ ok = true })
end)

RegisterNUICallback('setHover', function(data, cb)
    if not open then cb({ ok = false }) return end
    Cam.SetHover(data and data.hover)
    cb({ ok = true })
end)

RegisterNUICallback('camDrag', function(data, cb)
    if not open then cb({ ok = false }) return end
    Cam.Drag(data and data.dx, data and data.dy)
    cb({ ok = true })
end)

RegisterNUICallback('camZoom', function(data, cb)
    if not open then cb({ ok = false }) return end
    Cam.Zoom(data and data.delta)
    cb({ ok = true })
end)

RegisterNUICallback('camPreset', function(data, cb)
    if not open then cb({ ok = false }) return end
    Cam.SetPreset(data and data.name)
    cb({ ok = true })
end)


RegisterNUICallback('camFlip', function(_, cb)
    if not open then cb({ ok = false }) return end
    Cam.FlipPed()
    cb({ ok = true })
end)


RegisterNUICallback('preview', function(data, cb)
    if not open then cb({ ok = false }) return end
    if type(data) ~= 'table' then cb({ ok = false }) return end
    local nextApp = Appearance.Normalize(data.appearance or data)
    if mode ~= 'creator' then
        -- Shops cannot change sex. Keep the working model.
        nextApp.model = working.model
    end
    working = nextApp
    local ok = Appearance.Apply(working)
    cb({ ok = ok and true or false })
end)

RegisterNUICallback('setSex', function(data, cb)
    if not open or mode ~= 'creator' then
        cb({ ok = false })
        return
    end
    local model = Defaults.NormalizeModel(data and data.model)
    if not model then
        cb({ ok = false })
        return
    end
    working = Defaults.ForModel(model)
    local ok = Appearance.Apply(working)
    cb({ ok = ok and true or false, appearance = Appearance.ToNui(working) })
end)

RegisterNUICallback('enumerate', function(data, cb)
    if not open then cb({ ok = false }) return end
    local kind = data and data.kind
    local id = tonumber(data and data.id)
    local ped = PlayerPedId()
    if kind == 'prop' then
        cb({ ok = true, items = Appearance.EnumerateProp(ped, id), textures = Appearance.TextureCount(ped, 'prop', id, tonumber(data.drawable)) })
        return
    end
    cb({ ok = true, items = Appearance.EnumerateComponent(ped, id), textures = Appearance.TextureCount(ped, 'component', id, tonumber(data.drawable)) })
end)

RegisterNUICallback('textures', function(data, cb)
    if not open then cb({ ok = false }) return end
    local ped = PlayerPedId()
    local kind = data and data.kind or 'component'
    local id = tonumber(data and data.id) or 0
    local drawable = tonumber(data and data.drawable) or 0
    cb({ ok = true, textures = Appearance.TextureCount(ped, kind, id, drawable) })
end)

RegisterNUICallback('randomize', function(data, cb)
    if not open then cb({ ok = false }) return end
    local tab = data and data.tab
    if mode == 'creator' and data and data.all then
        tab = 'all'
    end
    working = Appearance.Randomize(working, tab or 'all')
    Appearance.Apply(working)
    cb({ ok = true, appearance = Appearance.ToNui(working) })
end)

RegisterNUICallback('reset', function(_, cb)
    if not open then cb({ ok = false }) return end
    if persisted then
        working = Appearance.Clone(persisted)
    else
        working = Defaults.ForModel(working and working.model or Defaults.MaleModel)
    end
    Appearance.Apply(working)
    Notify(L('reset_done'), 'info')
    cb({ ok = true, appearance = Appearance.ToNui(working) })
end)

RegisterNUICallback('save', function(data, cb)
    if not open then cb({ ok = false }) return end
    if type(data) == 'table' and type(data.appearance) == 'table' then
        working = Appearance.Normalize(data.appearance)
        if mode ~= 'creator' then
            working.model = openSnapshot and openSnapshot.model or working.model
        end
        Appearance.Apply(working)
    end
    TriggerServerEvent('fivex_appearance:save', Appearance.ToNui(working))
    cb({ ok = true })
end)

RegisterNUICallback('outfitSave', function(data, cb)
    if not open then cb({ ok = false }) return end
    local name = type(data) == 'table' and data.name or ''
    TriggerServerEvent('fivex_appearance:outfitSave', name, Appearance.ToNui(working))
    cb({ ok = true })
end)

RegisterNUICallback('outfitLoad', function(data, cb)
    if not open then cb({ ok = false }) return end
    local id = data and data.id
    TriggerServerEvent('fivex_appearance:outfitLoad', id)
    cb({ ok = true })
end)

RegisterNUICallback('outfitDelete', function(data, cb)
    if not open then cb({ ok = false }) return end
    TriggerServerEvent('fivex_appearance:outfitDelete', data and data.id)
    cb({ ok = true })
end)

RegisterNetEvent('fivex_appearance:applyOutfit', function(skin)
    if type(skin) ~= 'table' then return end
    working = Appearance.Normalize(skin)
    persisted = Appearance.Clone(working)
    pendingSkin = Appearance.Clone(working)
    Appearance.Apply(working)
    if open then
        nui({ type = 'appearance', appearance = Appearance.ToNui(working) })
    end
end)

-- Shops: markers + 3D text + E
local blips = {}

local function draw3d(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(230, 237, 243, 220)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

CreateThread(function()
    if Config.BlipsEnabled then
        for i = 1, #Config.Shops do
            local s = Config.Shops[i]
            local b = AddBlipForCoord(s.x, s.y, s.z)
            local meta = s.blip or {}
            SetBlipSprite(b, meta.sprite or 73)
            SetBlipDisplay(b, 4)
            SetBlipScale(b, meta.scale or 0.7)
            SetBlipColour(b, meta.color or 4)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(s.label or 'Shop')
            EndTextCommandSetBlipName(b)
            blips[#blips + 1] = b
        end
    end
end)

CreateThread(function()
    local mk = Config.Marker or {}
    local sc = mk.scale or { x = 0.85, y = 0.85, z = 0.45 }
    local col = mk.color or { r = 91, g = 141, b = 239, a = 140 }
    while true do
        local sleep = 1000
        if not open then
            local coords = GetEntityCoords(PlayerPedId())
            for i = 1, #Config.Shops do
                local s = Config.Shops[i]
                local dist = #(coords - vector3(s.x, s.y, s.z))
                if dist < Config.DrawDistance then
                    sleep = 0
                    DrawMarker(
                        mk.type or 1,
                        s.x, s.y, s.z + (mk.zOffset or -0.95),
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        sc.x, sc.y, sc.z,
                        col.r, col.g, col.b, col.a,
                        false, false, 2, false, nil, nil, false
                    )
                    if dist < Config.InteractDistance then
                        draw3d(s.x, s.y, s.z + 0.35, L('shop_prompt', s.label or 'shop'))
                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('fivex_appearance:requestOpen', 'shop', s.mode or 'clothing')
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= RESOURCE then return end
    setFocus(false)
    Cam.Close()
    open = false
    for i = 1, #blips do
        if DoesBlipExist(blips[i]) then
            RemoveBlip(blips[i])
        end
    end
end)

exports('getAppearance', function()
    return Appearance.ToNui(working or persisted or Appearance.GetCurrent())
end)

exports('applyAppearance', function(data)
    if type(data) ~= 'table' then return false end
    working = Appearance.Normalize(data)
    return Appearance.Apply(working)
end)
