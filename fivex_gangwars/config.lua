Config = {}

Config.Locale = 'en'

-- Heat / wave pacing
Config.HeatPerSecondInside = 8.0       -- heat fill rate while armed & inside turf
Config.HeatDecayOutside = 2.0          -- slow decay when leaving turf while armed
Config.HeatArmedBonus = 0.0            -- reserved; armed state already gates heat
Config.HeatMovingBonus = 2.0           -- extra heat/sec while moving (speed > 1.0)
Config.HeatArmedWeaponBonus = 3.0      -- extra heat/sec while holding a weapon
Config.WaveCooldownMs = 4000           -- calm between waves
Config.MaxWaves = 0                    -- 0 = infinite until leave/die
Config.BasePeds = 3                    -- peds in wave 1
Config.PedsPerWave = 1                 -- +1 each wave
Config.MaxLiveHostiles = 6             -- hard cap live peds
Config.PistolChanceStart = 0.2         -- wave 1 pistol ratio
Config.PistolChanceMax = 0.7           -- asymptote
Config.PistolChanceStep = 0.1          -- +per wave after 1

-- Opt-in / markers
Config.ArmKey = 38                     -- E (INPUT_PICKUP)
Config.ArmInteractDistance = 2.5       -- must be near center marker to arm
Config.MarkerDrawDistance = 40.0
Config.TurfCheckIdleMs = 750           -- idle poll when no run active
Config.TurfCheckActiveMs = 100         -- while run / heat building
Config.PromptDistance = 60.0           -- show "press E" when this close to turf

-- Relationship
Config.RelationshipGroup = 'FIVEX_FLASHPOINT'

-- Payday stub (client never awards; server KVP optional)
Config.PaydayEnabled = true
Config.PaydayPerWave = 150
Config.PaydayPerKill = 25
Config.PaydayNotify = true
Config.PaydayKvpPrefix = 'fivex_gw_pay_'  -- by license

-- Blips
Config.BlipSprite = 437
Config.BlipScale = 0.75
Config.BlipShortRange = true

-- Debug ACE (parent permission fivex_gangwars)
Config.AcePermission = 'fivex_gangwars'
Config.DebugCommand = 'gangwars'       -- /gangwars start|stop [turfId]

-- Turfs (center + radius v1)
Config.Turfs = {
    {
        id = 'ballas',
        label = 'Davis Flashpoint',
        center = vector3(105.0, -1940.0, 20.8),
        radius = 55.0,
        blipColor = 27, -- purple
        models = {
            `g_m_y_ballas_01`,
            `g_m_y_ballaeast_01`,
            `g_m_y_ballaorig_01`,
        },
    },
    {
        id = 'families',
        label = 'Chamberlain Flashpoint',
        center = vector3(-210.0, -1605.0, 34.0),
        radius = 55.0,
        blipColor = 2, -- green
        models = {
            `g_m_y_famca_01`,
            `g_m_y_famdnf_01`,
            `g_m_y_famfor_01`,
        },
    },
    {
        id = 'vagos',
        label = 'Rancho Flashpoint',
        center = vector3(331.0, -2041.0, 20.9),
        radius = 55.0,
        blipColor = 46, -- yellow
        models = {
            `g_m_y_mexgoon_01`,
            `g_m_y_mexgoon_02`,
            `g_m_y_mexgoon_03`,
        },
    },
}
