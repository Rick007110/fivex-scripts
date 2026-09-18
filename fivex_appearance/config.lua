Config = {}

--- Locale file key (locales/<code>.lua).
Config.Locale = 'en'

--- Discord webhook URL. Empty string disables logging. Server-only; never send to NUI.
Config.Webhook = ''

--- Open the full creator on first join when no saved appearance exists.
Config.ForceCreatorOnFirstJoin = true

--- Chat commands without slash.
Config.CommandCreator = 'appearance'
Config.CommandShop = 'clothing'

--- Default keybind for clothing shop mode (RegisterKeyMapping). Players can rebind in GTA settings.
Config.KeybindShop = 'F6'

--- Marker / 3D text distances (meters).
Config.InteractDistance = 2.0
Config.DrawDistance = 8.0

--- Show map blips for configured shops.
Config.BlipsEnabled = true

--- Max named outfits per license.
Config.MaxOutfits = 16
Config.MaxOutfitName = 24

--- Max tattoos stored on one appearance.
Config.MaxTattoos = 48

--- Rate limit for appearance / outfit saves.
Config.RateLimit = { max = 8, window = 10000 }

--- Hair / makeup / eye palettes (GTA Online counts). Client also queries natives.
Config.HairColors = 64
Config.MakeupColors = 64
Config.EyeColors = 32

--- Head blend parent indices 0–45 (21 male, 21 female, 4 special).
Config.MaxParent = 45

--- Skip these drawable ids per model/component. Empty by default; add ids that
--- are invisible, broken, or crash on your build. Keys are component ids 0–11.
--- Example: mp_m_freemode_01 = { [11] = { 0 } }
Config.Blacklist = {
    mp_m_freemode_01 = {
        -- [1] = { },  -- masks
        -- [11] = { }, -- tops
    },
    mp_f_freemode_01 = {
        -- [1] = { },
        -- [11] = { },
    },
}

--- Same idea for props (0 hats, 1 glasses, 2 ears, 6 watches, 7 bracelets).
Config.PropBlacklist = {
    mp_m_freemode_01 = {},
    mp_f_freemode_01 = {},
}

--- Shop sites. mode = clothing | barber | tattoo
Config.Shops = {
    {
        id = 'ponsonby_rockford',
        label = 'Ponsonby',
        mode = 'clothing',
        x = -712.215, y = -155.352, z = 37.415,
        blip = { sprite = 73, color = 4, scale = 0.7 },
    },
    {
        id = 'suburban_hawick',
        label = 'Suburban',
        mode = 'clothing',
        x = 124.82, y = -219.13, z = 54.56,
        blip = { sprite = 73, color = 4, scale = 0.7 },
    },
    {
        id = 'binco_strawberry',
        label = 'Binco',
        mode = 'clothing',
        x = 425.23, y = -806.27, z = 29.49,
        blip = { sprite = 73, color = 4, scale = 0.7 },
    },
    {
        id = 'hair_hawick',
        label = 'Hair on Hawick',
        mode = 'barber',
        x = -814.308, y = -183.823, z = 37.569,
        blip = { sprite = 71, color = 17, scale = 0.7 },
    },
    {
        id = 'herrkutz_davis',
        label = 'Herr Kutz',
        mode = 'barber',
        x = 136.78, y = -1708.4, z = 29.29,
        blip = { sprite = 71, color = 17, scale = 0.7 },
    },
    {
        id = 'tattoo_vespucci',
        label = 'Los Santos Tattoos',
        mode = 'tattoo',
        x = -1153.6, y = -1425.6, z = 4.95,
        blip = { sprite = 75, color = 1, scale = 0.7 },
    },
    {
        id = 'tattoo_vinewood',
        label = 'Blazing Tattoo',
        mode = 'tattoo',
        x = 322.14, y = 180.47, z = 103.59,
        blip = { sprite = 75, color = 1, scale = 0.7 },
    },
}

Config.Marker = {
    type = 1,
    scale = { x = 0.85, y = 0.85, z = 0.45 },
    color = { r = 91, g = 141, b = 239, a = 140 },
    zOffset = -0.95,
}

--- Camera orbit limits.
Config.Camera = {
    MinZoom = 0.45,
    MaxZoom = 3.2,
    DefaultZoom = 2.15,
    MinPitch = -35.0,
    MaxPitch = 55.0,
    Dof = true,
    --- Higher = snappier Face/Torso/Legs/Full transitions.
    PresetLerp = 8.0,
}
