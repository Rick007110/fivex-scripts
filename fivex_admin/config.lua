Config = {}

--- Default keybind (RegisterKeyMapping). Players can rebind in GTA settings.
Config.Keybind = 'F10'

--- Chat command without slash.
Config.Command = 'admin'

--- Locale file key (locales/<code>.lua).
Config.Locale = 'en'

--- Discord webhook URL. Empty string disables logging. Server-only; never send to NUI.
Config.Webhook = ''

--- Freeze the local ped while the menu is open. Default off so staff can still move.
Config.FreezeOnOpen = false

Config.Noclip = {
    BaseSpeed = 1.5,
    MinSpeed = 0.1,
    MaxSpeed = 20.0,
    SpeedStep = 0.25,
    FastMult = 3.0,
    SlowMult = 0.25,
}

--- Radius (meters) for "delete nearby vehicles".
Config.DeleteRadius = 8.0

--- Radius (meters) for world clear-area actions.
Config.ClearRadius = 80.0

--- Ban duration presets shown in the confirm modal (seconds). 0 = permanent.
Config.BanDurations = {
    { id = '1h',  label = '1 hour',        seconds = 3600 },
    { id = '1d',  label = '1 day',         seconds = 86400 },
    { id = '7d',  label = '7 days',        seconds = 604800 },
    { id = '30d', label = '30 days',       seconds = 2592000 },
    { id = 'perm', label = 'Permanent',    seconds = 0 },
}

Config.MaxReasonLength = 200
Config.MinReasonLength = 3
Config.MaxAnnounceLength = 240
--- Staff → Announcement uses txAdmin's announcement popup (and its server log) when txAdmin runs.
--- Falls back to the FiveX Admin popup without txAdmin or with txAdmin-hideDefaultAnnouncement set.
Config.AnnounceViaTxAdmin = true

--- Player screenshots (screenshot-basic) are stored in MySQL (table fivex_admin_screenshots) and shown
--- under the player's Screenshots tab. Older ones beyond keepPerPlayer are deleted automatically.
Config.Screenshots = {
    quality = 0.6,       -- JPEG quality 0–1
    keepPerPlayer = 25,
}
Config.MaxPlateLength = 8

--- Rate limits: max actions per window (ms).
Config.RateLimit = {
    Kick = { max = 5, window = 10000 },
    Ban = { max = 5, window = 10000 },
    Announce = { max = 3, window = 30000 },
    Generic = { max = 20, window = 5000 },
}

--- Built-in teleport locations (world coordinates).
Config.Locations = {
    { id = 'legion',     label = 'Legion Square',     x = 195.17,  y = -933.77,  z = 30.69,  w = 50.0 },
    { id = 'mrpd',       label = 'Mission Row PD',    x = 428.23,  y = -984.28,  z = 30.71,  w = 90.0 },
    { id = 'hospital',   label = 'Pillbox Hospital',  x = 298.66,  y = -584.47,  z = 43.26,  w = 70.0 },
    { id = 'garage',     label = 'Legion Garage',     x = 215.76,  y = -810.12,  z = 30.73,  w = 340.0 },
    { id = 'airport',    label = 'Los Santos Airport', x = -1037.0, y = -2737.0, z = 20.17,  w = 330.0 },
    { id = 'paleto',     label = 'Paleto Bay',        x = -448.23, y = 6010.12,  z = 31.72,  w = 45.0 },
    { id = 'sandy',      label = 'Sandy Shores',      x = 1848.54, y = 3670.14,  z = 33.93,  w = 210.0 },
    { id = 'prison',     label = 'Bolingbroke Prison', x = 1845.33, y = 2585.94, z = 45.67,  w = 270.0 },
    { id = 'mazebank',   label = 'Maze Bank Roof',    x = -75.15,  y = -819.14,  z = 326.18, w = 350.0 },
}

-- fivex_admin owns time + weather for everyone (vMenu's sync is off in vMenu/config/permissions.cfg).
Config.WorldSync = {
    Enabled = true,
    StartHour = 12,           -- after a server restart
    StartWeather = 'CLEAR',
    StartFrozen = false,
    MinuteMs = 2000,          -- real ms per in-game minute (2000 = GTA default, 48 min day)
    SyncInterval = 10000,     -- ms between re-syncs to all players
}

Config.WeatherPresets = {
    'CLEAR', 'EXTRASUNNY', 'CLOUDS', 'OVERCAST', 'RAIN', 'THUNDER',
    'CLEARING', 'NEUTRAL', 'SNOW', 'BLIZZARD', 'SNOWLIGHT', 'XMAS', 'FOGGY', 'HALLOWEEN',
}

Config.PlayerRefreshMs = 4000
