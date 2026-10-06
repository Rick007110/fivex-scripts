Config = {}
Config.JobId = 'marina'
Config.Locale = 'en'

---------------------------------------------------------------------------
-- Harbor locations (Puerto Del Sol)
---------------------------------------------------------------------------

Config.Duty = vector4(-816.08, -1346.08, 5.15, 46.93)          -- harbor office: clock in / out
Config.DinghySpawn = vector4(-810.5, -1491.2, 0.15, 110.0)      -- work boat spawns here (in water)
Config.DockStand = vector3(-800.2, -1496.5, 1.6)               -- main dock: passengers, drop-offs, unloading

Config.Slips = {
    { id = 'A', coords = vector3(-793.4, -1501.5, 0.2) },
    { id = 'B', coords = vector3(-786.0, -1488.0, 0.2) },
    { id = 'C', coords = vector3(-772.5, -1505.8, 0.2) },
}

Config.FuelPump = vector3(-798.4, -1513.2, 1.6)

-- Hull detail: a boat is spawned in this slip and cleaned from the docks on both sides.
Config.DetailBoat = vector4(-846.01, -1363.66, 0.12, 288.01)  -- boat position in the water + heading
Config.DetailBoatModel = joaat('dinghy')
Config.DetailSideOffset = 2.4    -- metres from the boat's centreline to each dock
Config.DetailLengthOffset = 1.5  -- metres fore / aft of the boat's centre
Config.DetailPointZ = 1.6        -- standing height on the dock

-- Four clean spots (front/back on each side), worked out from the boat's position and heading
do
    local b = Config.DetailBoat
    local h = math.rad(b.w)
    local fx, fy = -math.sin(h), math.cos(h)  -- forward
    local rx, ry = math.cos(h), math.sin(h)   -- right
    local side, len = Config.DetailSideOffset, Config.DetailLengthOffset
    local function pt(l, s)
        return vector3(b.x + fx * l + rx * s, b.y + fy * l + ry * s, Config.DetailPointZ)
    end
    Config.DetailCenter = vector3(b.x, b.y, Config.DetailPointZ)
    Config.DetailPoints = {
        pt(len, side), pt(-len, side),    -- right dock: front, back
        pt(len, -side), pt(-len, -side),  -- left dock: front, back
    }
end

-- Open-water areas used by sea contracts. Exact spots are picked in-game inside each circle and
-- checked to be open, deep water, so no hand-placed sea coordinates are needed.
Config.SeaAreas = {
    harbor   = { label = 'Harbor approach',       center = vector2(-880.0, -1550.0),  radius = 180.0 },
    vespucci = { label = 'Off Vespucci Beach',    center = vector2(-1750.0, -1650.0), radius = 220.0 },
    delperro = { label = 'Off Del Perro Pier',    center = vector2(-2100.0, -1300.0), radius = 250.0 },
}
Config.SeaMinDistance = 120.0        -- sea objectives are never closer than this to the harbor office
Config.SeaSnapRadius = 200.0         -- how far a spot may be moved if it turns out to be shallow / land
Config.SeaMinDepth = 2.5             -- metres of water required under a sea objective

---------------------------------------------------------------------------
-- Career: ranks unlock contracts, boats and better pay
---------------------------------------------------------------------------

Config.Ranks = {
    { name = 'Deckhand',      xp = 0,    pay = 1.00, boat = 'dinghy2', boatLabel = 'Work Dinghy' },
    { name = 'Dockhand',      xp = 500,  pay = 1.10, boat = 'dinghy2', boatLabel = 'Work Dinghy' },
    { name = 'Boatswain',     xp = 1500, pay = 1.20, boat = 'suntrap', boatLabel = 'Shitzu Suntrap' },
    { name = 'First Mate',    xp = 3500, pay = 1.35, boat = 'speeder', boatLabel = 'Pegassi Speeder' },
    { name = 'Harbor Master', xp = 7000, pay = 1.50, boat = 'toro',    boatLabel = 'Lampadati Toro' },
}
Config.BoatFallback = 'dinghy'
Config.BoatPlate = 'HARBOR'

---------------------------------------------------------------------------
-- Contracts
--   pay / xp  : base reward (pay is multiplied by rank, streak, express and quality)
--   par       : seconds; finishing within par earns the Express bonus
--   limit     : seconds; the contract fails when it runs out
--   minSecs   : (optional) fastest believable completion; anything quicker is rejected (anti-cheat)
---------------------------------------------------------------------------

Config.Contracts = {
    detail = {
        label = 'Hull Detail', icon = 'sponge', rank = 1, pay = 240, xp = 40, par = 75, limit = 300, minSecs = 14,
        blurb = 'A client boat is in the detail slip. Scrub the hull from the docks until it shines.',
    },
    refuel = {
        label = 'Slip Refuel', icon = 'fuel', rank = 1, pay = 220, xp = 40, par = 70, limit = 300, minSecs = 12,
        blurb = 'Grab a jerry can at the pump and top off a moored boat. Don\'t spill — the owner is watching.',
    },
    recovery = {
        label = 'Adrift Recovery', icon = 'anchor', rank = 1, pay = 480, xp = 85, par = 240, limit = 600,
        blurb = 'A runner broke loose and is drifting at sea. Reach it, get the engine running, bring it home.',
        sea = true, areas = { 'harbor', 'vespucci' },
    },
    debris = {
        label = 'Debris Sweep', icon = 'net', rank = 2, pay = 420, xp = 75, par = 210, limit = 600,
        blurb = 'Storm junk is floating in the shipping lane. Scoop it all up and unload at the dock.',
        sea = true, areas = { 'harbor', 'vespucci', 'delperro' },
    },
    charter = {
        label = 'Harbor Charter', icon = 'ticket', rank = 2, pay = 520, xp = 95, par = 300, limit = 720,
        blurb = 'A tourist booked a sightseeing ride. Hit every stop and keep it smooth — tips depend on it.',
        sea = true, areas = { 'vespucci', 'delperro' },
    },
    rescue = {
        label = 'Mayday Rescue', icon = 'lifebuoy', rank = 3, pay = 680, xp = 130, par = 180, limit = 360,
        blurb = 'Swimmer in distress. Follow the flare, pull them out of the water and get them to the medics.',
        sea = true, areas = { 'harbor', 'vespucci', 'delperro' },
    },
}
Config.ContractOrder = { 'detail', 'refuel', 'recovery', 'debris', 'charter', 'rescue' }

Config.PayVariance = 0.12            -- offers vary ±12% so the board feels alive
Config.OfferRefreshMs = 240000       -- board re-rolls every 4 minutes
Config.StreakStep = 0.05             -- +5% pay per completed contract in a row...
Config.StreakMax = 0.30              -- ...up to +30%
Config.ExpressBonus = 0.20           -- +20% pay (and +25% XP) when finished within par
Config.LeaderboardSize = 10

-- Contract specifics
Config.DebrisCount = 6
Config.DebrisSpacing = 70.0          -- debris is spread around the area within this radius
Config.DebrisScoopRadius = 5.5
Config.DebrisModels = { 'prop_barrel_01a', 'prop_rub_tyre_01', 'prop_bin_05a', 'prop_cs_cardbox_01', 'prop_barrel_02a' }
Config.CharterStops = 3
Config.CharterPassengers = { 'a_f_y_tourist_01', 'a_m_y_hipster_01', 'a_f_y_bevhills_02', 'a_m_m_tourist_01' }
Config.RescueVictims = { 'a_m_y_beach_01', 'a_f_y_beach_01', 'a_m_y_surfer_01' }
Config.ParamedicModel = 's_m_m_paramedic_01'
Config.RunnerModels = { 'speeder', 'jetmax', 'squalo', 'tropic' }
Config.RefuelBoatModels = { 'tropic', 'jetmax', 'squalo' }

-- Refuel mini-game: hold E to pour, let go inside the green band.
Config.Pour = {
    rate = 0.22,          -- tank fraction per second
    perfectMin = 0.92,    -- 92%..100% = perfect fill
    okMin = 0.75,         -- 75%..92% = acceptable
    spillAt = 1.08,       -- pouring past this spills and ends the pour
}

---------------------------------------------------------------------------
-- General
---------------------------------------------------------------------------

Config.TabletKey = 'F5'              -- open the harbor tablet while on duty (players can rebind)
Config.TabletCommand = 'harbortablet'
Config.InteractDistance = 2.0
Config.DutyRadius = 4.0
Config.DockRadius = 9.0
Config.DockSpeed = 6.0
Config.VehicleCooldown = 45000

-- Anti-teleport: a paid contract is only accepted once enough time has passed since it was accepted.
-- Travel legs are timed at MaxTravelSpeed (m/s, deliberately generous), never sooner than MinTaskMs.
Config.MaxTravelSpeed = 60.0
Config.MinTaskMs = 8000

Config.Blip = {
    sprite = 410,
    color = 3,
    scale = 0.85,
    label = 'Harbor Authority',
}

Config.Marker = {
    type = 1,
    scale = vector3(1.2, 1.2, 0.5),
    color = { r = 56, g = 189, b = 248, a = 150 },
}

Config.Anim = {
    grab = { dict = 'mini@repair', clip = 'fixing_a_ped', ms = 1600 },
    scrub = { scenario = 'WORLD_HUMAN_MAID_CLEAN', ms = 3000 },
    pour = { dict = 'weapon@w_sp_jerrycan', clip = 'fire' },
    repair = { ms = 4500 },
    unload = { dict = 'anim@heists@box_carry@', clip = 'idle', ms = 2500 },
    tablet = { dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base', clip = 'base' },
}

-- Particle effects (asset, effect). Missing assets are skipped silently.
Config.Fx = {
    soap  = { asset = 'scr_carwash', name = 'ent_amb_car_wash_jet_soap', scale = 1.0 },
    splash = { asset = 'core', name = 'water_splash_veh_out', scale = 1.5 },
    flare = { asset = 'core', name = 'exp_grd_flare', scale = 1.0 },
}
