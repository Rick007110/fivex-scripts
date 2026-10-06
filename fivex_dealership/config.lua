Config = {}

Config.Locale = 'en'
Config.SpeedUnit = 'kmh' -- kmh | mph

-- Premium Deluxe Motorsport. Coords are best guesses — verify in game and nudge.
Config.Showroom = {
    label = 'Premium Deluxe Motorsport',
    desk = vector3(-56.50, -1096.60, 26.42),          -- on-foot marker that opens the catalog
    preview = vector4(-43.31, -1099.02, 26.42, 52.5),  -- local preview car (only you see it)
    camera = vector3(-38.60, -1102.20, 27.60),         -- fixed camera looking at the preview
    delivery = {                                       -- new purchases spawn at the first free spot
        vector4(-56.79, -1109.85, 26.43, 71.5),
        vector4(-50.66, -1112.27, 26.43, 71.5),
    },
    blip = { sprite = 326, color = 3, scale = 0.8, label = 'Vehicle Dealer' },

    -- The showroom interior is not loaded by default (you see a white "closed" placeholder through the
    -- windows). Set false if another resource (e.g. bob74_ipl) already handles it.
    loadInterior = true,
    ipl = {
        request = { 'shr_int' },  -- showroom interior
        remove = { 'fakeint' },   -- closed-shop placeholder
    },
    entitySets = {
        on = { 'csr_beforeMission', 'shutter_open' },                            -- intact glass, back door open
        off = { 'csr_afterMissionA', 'csr_afterMissionB', 'csr_inMission', 'shutter_closed' }, -- smashed / boarded
    },
}

-- Shared garages: any stored vehicle can be taken out at any garage.
Config.Garages = {
    {
        id = 'alta',
        label = 'Alta Street Parking',
        coords = vector3(275.29, -345.70, 45.17),
        spawns = {
            vector4(266.02, -332.07, 44.43, 250.5),
            vector4(267.50, -328.50, 44.43, 250.5),
        },
    },
    {
        id = 'legion',
        label = 'Legion Square Parking',
        coords = vector3(215.80, -810.06, 30.73),
        spawns = {
            vector4(229.70, -800.11, 30.57, 157.3),
            vector4(232.70, -793.10, 30.57, 157.3),
        },
    },
    {
        id = 'sandy',
        label = 'Sandy Shores Parking',
        coords = vector3(1737.59, 3710.20, 34.14),
        spawns = {
            vector4(1737.84, 3719.28, 33.04, 21.2),
            vector4(1733.30, 3717.40, 33.04, 21.2),
        },
    },
    {
        id = 'paleto',
        label = 'Paleto Bay Parking',
        coords = vector3(107.32, 6611.77, 31.98),
        spawns = {
            vector4(110.84, 6607.82, 31.86, 265.3),
            vector4(114.50, 6603.50, 31.86, 265.3),
        },
    },
}
Config.GarageBlip = { sprite = 357, color = 3, scale = 0.65, label = 'Garage' }

Config.Marker = {
    type = 1,
    scale = vector3(0.55, 0.55, 0.45),
    color = { r = 91, g = 141, b = 239, a = 140 },
}
Config.StoreMarker = {
    type = 1,
    scale = vector3(3.0, 3.0, 0.4),
    color = { r = 61, g = 154, b = 106, a = 90 },
}

Config.InteractDistance = 1.6
Config.DrawDistance = 15.0
Config.OpenDistance = 3.0      -- server re-check for opening menus
Config.StoreDistance = 10.0    -- drive within this of a garage marker to park

Config.MaxOwned = 10
Config.RecoverFee = 250        -- recall a car that is out, or recover a lost/destroyed one (also repairs it)
Config.SellBackPercent = 50    -- of the price paid; staff-given cars sell for $0
Config.TrackInterval = 10000   -- ms between checks for vanished vehicles

Config.RateLimit = {
    Open    = { max = 6, window = 10000 },
    Action  = { max = 6, window = 10000 },
    Generic = { max = 12, window = 10000 },
}

-- GTA paint indices. hex is only for the swatch in the UI.
Config.Colors = {
    { id = 0,   label = 'Black',       hex = '#0d1116' },
    { id = 111, label = 'White',       hex = '#eef0f2' },
    { id = 4,   label = 'Silver',      hex = '#9ea2a8' },
    { id = 27,  label = 'Red',         hex = '#b01c1c' },
    { id = 38,  label = 'Orange',      hex = '#e8742a' },
    { id = 88,  label = 'Yellow',      hex = '#f0c419' },
    { id = 53,  label = 'Green',       hex = '#1f6b34' },
    { id = 64,  label = 'Blue',        hex = '#2354a5' },
    { id = 145, label = 'Purple',      hex = '#5b2a86' },
    { id = 12,  label = 'Matte Black', hex = '#1b1b1b' },
}

-- Menu order + labels. Remove a line to hide that whole category from the shop.
Config.Categories = {
    { id = 'compacts',    label = 'Compacts' },
    { id = 'sedans',      label = 'Sedans' },
    { id = 'suvs',        label = 'SUVs' },
    { id = 'coupes',      label = 'Coupes' },
    { id = 'muscle',      label = 'Muscle' },
    { id = 'classics',    label = 'Sports Classics' },
    { id = 'sports',      label = 'Sports' },
    { id = 'super',       label = 'Super' },
    { id = 'motorcycles', label = 'Motorcycles' },
    { id = 'offroad',     label = 'Off-road' },
    { id = 'vans',        label = 'Vans' },
    { id = 'cycles',      label = 'Bicycles' },
    { id = 'utility',     label = 'Utility' },
    { id = 'commercial',  label = 'Commercial' },
    { id = 'industrial',  label = 'Industrial' },
    { id = 'service',     label = 'Service' },
    { id = 'openwheel',   label = 'Open Wheel' },
}

-- The vehicle list lives in data/vehicles.lua (all base-game land vehicles, minus weaponised,
-- emergency, military and online gimmick/armored variants). Adjust it here instead of editing it:
Config.PriceMultiplier = 1.0   -- scales every generated price (e.g. 0.5 = half price)
Config.ExcludeModels = {        -- hide extra models, e.g. ['adder'] = true
}
Config.PriceOverrides = {       -- set exact prices, e.g. ['sultan'] = 45000
}

Config.KvpVehicles = 'fivex_veh_v1:'   -- <license> -> JSON array
Config.KvpPlate    = 'fivex_plate_v1:' -- <plate>   -> license
