Config = {}

Config.Locale = 'en'
Config.Debug = false -- print ride / route steps in F8
Config.AppId = 'knoway' -- Flexa app id

-- KnoWay fleet: each ride gets one of these, picked by weight when the ride is booked.
-- resource = only used while that resource is started (custom vehicles).
Config.Vehicles = {
    {
        model = 'vivanite2',          -- Karin Vivanite (Service), base game (mp2025_02)
        label = 'KnoWay Van',
        weight = 50,
        mods = { [6] = 1, [48] = 0 }, -- grille: 2nd option · livery: KnoWay (mod-kit livery)
        primary = 111, secondary = 111,
        door = 3,                     -- rear right
    },
    {
        model = 'knowayest',          -- custom KnoWay car (resource "knowayest", livery in its textures)
        label = 'KnoWay Car',
        weight = 50,
        resource = 'knowayest',
        mods = {},
        primary = 134, secondary = 134,
        door = 3,
    },
}
-- Models whose doors GTA's F-key entry doesn't pick up properly: the script enters the nearest free door.
Config.EntryAssistModels = { 'knowayest' }
Config.Plate = 'KNOWAY' -- + ride number: KNOWAY1, KNOWAY2, … (8 characters max, uppercase in game)

Config.DriverModel = 's_m_m_gentransport' -- invisible, but needs a model to drive

Config.DispatchDelay = { min = 3000, max = 7000 }  -- ms before the van sets off
Config.SpawnDistance = { min = 90, max = 180 }     -- metres from the pickup (spawns out of sight when it can)
-- pier road, lots, service roads) and never take shortcut links, so the van drives every real road.
-- Closed roads (flag 2097152 in the styles below) are only used within this many metres of the pickup /
-- drop-off; the rest of the trip follows the same roads as the GPS line.
Config.ClosedRoadsWithin = 0.0 -- closed roads off (default driving only)
-- Pickup / road snapping only uses roads within this many metres of the player's / destination's height.
Config.SameLevel = 4.0
-- Destinations off the road: within `within` m the van retargets the nearest road, but only one at most
-- `maxOffset` m from the destination (otherwise it keeps driving to the exact spot like the GPS).
Config.SnapRoad = { within = 120.0, maxOffset = 60.0 }
Config.DriveStyle = { -- GTA's default style everywhere (786603: obeys lights, stays in lane, normal traffic)
    pickup = 786603,
    ride = 786603,
    unstick = 786603,
    approach = 786603,
}
-- After reaching the pickup road: if the player is further than stopAt (and within maxDistance),
-- creep across the lot / driveway towards them.
-- Spawn/despawn only out of sight: not on the booker's screen and not near/visible to other players.
Config.Visibility = {
    otherPlayerSpawnRange = 120.0, -- m: never spawn this close to another player
    otherPlayerRange = 150.0,      -- m: a nearby player with line of sight counts as "seen"
    maxExtraDrive = 90,            -- s: extra driving after DespawnAfter while still seen, then remove anyway
}
Config.SpawnAce = 'fivex_knoway.spawn' -- /knoway_van: spawn a styled KnoWay vehicle for yourself

-- maxDistance: pickup (towards the player); dropoffMaxDistance: last road node -> exact drop-off point
-- goodEnough: stopped this close (m) for 2 s counts as arrived
Config.FinalApproach = { stopAt = 7.0, goodEnough = 15.0, maxDistance = 60.0, dropoffMaxDistance = 30.0, speed = 5.0, timeout = 20 }
Config.Speed = { pickup = 17.0, ride = 17.0 }       -- m/s (~61 km/h), like normal traffic
-- Coming in: drop to normal traffic-obeying driving within slowWithin m, crawl the last crawlWithin m,
-- then roll to a stop over stopDistance m (m/s: 12.5 ~ 45 km/h, 7 ~ 25 km/h).
Config.Arrival = { slowWithin = 120.0, slowSpeed = 12.5, crawlWithin = 45.0, crawlSpeed = 7.0, stopDistance = 6.0 }
Config.ArriveDistance = 12.0                        -- metres from target counts as arrived
Config.BoardTimeout = 180                           -- s to get in before the ride is cancelled (free)
Config.ExitTimeout = 25                             -- s for riders to get out at the destination
Config.DepartDelay = 4                             -- s after the doors close before it pulls away
Config.DepartClearance = 5.0                       -- m: also wait (max 10 s) until nobody stands this close
Config.DespawnAfter = 20                            -- s the van drives off before it despawns
Config.StuckSeconds = 12                            -- no progress for this long -> unstick
-- At traffic lights: re-issue the drive after `nudge` s (AI sometimes ignores the green),
-- and treat it as stuck after `max` s.
Config.LightGrace = { nudge = 25, max = 45 }

Config.Fare = {
    base = 25,          -- $
    perKm = 18,         -- $ per road km
    minimum = 40,       -- $
    roadFactor = 1.3,   -- straight line x this ~= road distance
}
Config.MinTripDistance = 150    -- metres
Config.MaxActiveRides = 10      -- server-wide
Config.MaxRideMinutes = 20      -- hard cleanup

-- Default keys (players can rebind in Settings > Key Bindings > FiveM)
Config.Keys = { go = 'Y', cancel = 'X', cursor = 'LMENU' }

-- Quick destinations in the app (plus "Pick on map" and the current waypoint).
-- exact = true: drive to exactly this point (e.g. a lot the road snapping would skip) instead of the
-- nearest road; use /knoway_coords in game to get the line for a spot.
Config.Places = {
    { label = 'Legion Square',              area = 'Downtown',        coords = vector3(195.2, -933.8, 30.7) },
    { label = 'Pillbox Hill Medical',       area = 'Pillbox Hill',    coords = vector3(298.7, -584.5, 43.3) },
    { label = 'Mission Row Police',         area = 'Mission Row',     coords = vector3(428.2, -984.3, 29.7) },
    { label = 'Job Center',                 area = 'Mission Row',     coords = vector3(-266.0, -960.4, 31.2) },
    { label = 'Premium Deluxe Motorsport',  area = 'Pillbox Hill',    coords = vector3(-56.8, -1109.9, 26.4) },
    { label = 'Los Santos International',   area = 'LSIA',            coords = vector3(-1037.0, -2737.0, 20.2) },
    { label = 'Pier',                       area = 'Del Perro Pier',  coords = vector3(-1561.63, -1021.30, 13.02), exact = true }, -- pier parking lot
    { label = 'Puerto Del Sol Marina',      area = 'La Puerta',       coords = vector3(-816.1, -1346.1, 5.0) },
    { label = 'Vinewood Boulevard',         area = 'Vinewood',        coords = vector3(301.0, 180.0, 104.0) },
    { label = 'Mirror Park',                area = 'Mirror Park',     coords = vector3(1078.0, -706.0, 57.5) },
    { label = 'Sandy Shores',               area = 'Blaine County',   coords = vector3(1848.5, 3670.1, 33.8) },
    { label = 'Paleto Bay',                 area = 'Blaine County',   coords = vector3(-448.2, 6010.1, 31.7) },
}

-- Rough island bounds for custom (waypoint) destinations
Config.Bounds = { minX = -4500.0, maxX = 4500.0, minY = -4500.0, maxY = 8500.0 }

Config.RateLimit = { max = 10, window = 10000 }
