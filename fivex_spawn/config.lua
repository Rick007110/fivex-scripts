Config = {}

-- Ped model used for the very first spawn (fivex_appearance applies the saved look right after).
Config.DefaultModel = 'mp_m_freemode_01'

-- Offer "Last location" (saved every SaveInterval seconds once a player has spawned).
Config.LastLocation = true
Config.SaveInterval = 30

-- Spawn choices. coords = vector4(x, y, z, heading). z is snapped to the ground on spawn.
-- icon: city | hospital | police | briefcase | car | plane | pier | star | desert | forest
Config.Locations = {
    { id = 'legion',   label = 'Legion Square',             area = 'Downtown Los Santos', icon = 'city',      coords = vector4(195.17, -933.77, 30.69, 144.0) },
    { id = 'pillbox',  label = 'Pillbox Hill Medical',      area = 'Pillbox Hill',        icon = 'hospital',  coords = vector4(298.70, -584.50, 43.26, 70.0) },
    { id = 'jobs',     label = 'Job Center',                area = 'Mission Row',         icon = 'briefcase', coords = vector4(-262.0, -965.0, 31.22, 200.0) },
    { id = 'pdm',      label = 'Premium Deluxe Motorsport', area = 'Pillbox Hill',        icon = 'car',       coords = vector4(-46.50, -1112.0, 26.43, 70.0) },
    { id = 'pier',     label = 'Del Perro Pier',            area = 'Del Perro',           icon = 'pier',      coords = vector4(-1561.63, -1021.30, 13.02, 140.0) },
    { id = 'vinewood', label = 'Vinewood Boulevard',        area = 'Vinewood',            icon = 'star',      coords = vector4(301.0, 180.0, 104.0, 160.0) },
    { id = 'lsia',     label = 'Los Santos International',  area = 'LSIA',                icon = 'plane',     coords = vector4(-1037.0, -2737.0, 20.17, 330.0) },
    { id = 'sandy',    label = 'Sandy Shores',              area = 'Blaine County',       icon = 'desert',    coords = vector4(1848.54, 3670.14, 33.93, 210.0) },
    { id = 'paleto',   label = 'Paleto Bay',                area = 'Blaine County',       icon = 'forest',    coords = vector4(-448.23, 6010.12, 31.72, 45.0) },
}

-- After dying: respawn at the nearest of these (no menu).
Config.Hospitals = {
    vector4(298.70, -584.50, 43.26, 70.0),     -- Pillbox Hill
    vector4(340.40, -1396.0, 32.51, 50.0),     -- Central Los Santos
    vector4(-449.67, -340.83, 34.50, 80.0),    -- Mount Zonah
    vector4(1839.60, 3672.93, 34.28, 210.0),   -- Sandy Shores
    vector4(-247.76, 6331.23, 32.43, 225.0),   -- Paleto Bay
}

-- Story-mode "switch" style camera (scripted, so it's faster than story mode and goes where you pick):
-- changing location rises `altitude` m, glides across, then drops to the aerial shot; spawning dives
-- down behind your character. Times in ms. enabled = false -> plain fades.
Config.Transition = {
    enabled = true,
    altitude = 1200.0,  -- high enough to rise up into the clouds
    up = 1300,          -- rise
    across = 1200,      -- glide (+ acrossPerKm per km of distance, capped at acrossMax)
    acrossPerKm = 200,
    acrossMax = 2400,
    down = 1400,        -- drop out of the clouds to the aerial shot
    intro = 2000,       -- first shot on join: drop in from the sky
    land = 1300,        -- spawn: dive from the aerial shot to behind the player
    handoff = 600,      -- blend into the gameplay camera
}

-- Preview camera: distance behind / height above the spot, field of view. If something blocks the
-- view it rises in `step` m increments up to `maxHeight`.
Config.Camera = { distance = 50.0, height = 60.0, maxHeight = 200.0, step = 15.0, fov = 50.0, blendMs = 1400 }
