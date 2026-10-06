Config = {}

Config.Locale = 'en'

--- ACE permission (default-deny). Parent grant like fivex_admin:
---   add_ace group.admin fivex_zombies allow
Config.AcePermission = 'fivex_zombies'

--- Timing
Config.AlarmSeconds = 10          -- loud repeating alarm duration after start
Config.GraceSeconds = 10          -- seconds after start before infection / spawn
Config.ScanIntervalMs = 600       -- how often new pedestrians are turned
Config.IdleWaitMs = 2000          -- client idle poll when inactive
Config.InfectionPollMs = 250      -- damage / infection check while near zombies
Config.AlarmRepeatMs = 900        -- frontend fallback sound repeat during alarm window

--- Population. Each player's client keeps a living city around them: zombies that wander until
--- they notice someone, plus hordes that come running from out of sight.
Config.SpawnUseServer = true      -- server CreatePed (client CreatePed returns 0 on this host)
Config.SpawnEnabled = true
Config.SpawnRequestTimeoutMs = 3500
Config.MaxZombies = 300           -- server-spawned, whole server, alive (sv_maxclients 10)
Config.MaxZombiesPerPlayer = 60   -- server-spawned for one player (server enforced)
Config.Wanderers = 55             -- keep at least this many zombies (turned + spawned) within WanderRadius
Config.WanderRadius = 110.0
Config.SpawnRadiusMin = 30.0      -- spawned zombies appear between these, preferably out of view
Config.SpawnRadiusMax = 95.0
Config.SpawnBatch = 10            -- per spawn tick
Config.SpawnIntervalMs = 700
Config.DespawnDistance = 190.0    -- zombies this far from every player are removed (server)

--- Hordes: a pack spawns out of sight and comes running at one player
Config.Hordes = {
    enabled = true,
    firstAfterMs = 12000,         -- first horde this long after the grace period
    intervalMs = { 22000, 40000 },-- then every 22-40 s per player
    size = { 12, 20 },
    distance = { 60.0, 85.0 },
    spread = 5.0,                 -- metres around the horde centre
    warn = true,                  -- "Horde inbound — north-east" on the HUD
}

--- Senses. Zombies wander until they see or hear a player, then hunt that player.
Config.Senses = {
    sight = 32.0,                 -- clear line of sight within this range
    touch = 9.0,                  -- always noticed this close
    gunshot = 95.0,               -- unsuppressed shot
    suppressed = 22.0,
    sprint = 22.0,
    vehicle = 35.0,               -- driving faster than ~30 km/h
    horn = 70.0,
    loseAfterMs = 15000,          -- give up when the target is out of reach this long
    loseDistance = 140.0,
}

--- Variants. weight = how often it spawns, health includes GTA's 100 "dead" baseline.
--- Headshots always kill (critical hits on), so body shots are what health tunes.
Config.Variants = {
    walker  = { weight = 55, health = 260, clipsets = { 'move_m@zombie@core', 'clipset@anim@ingame@move_m@zombie@core', 'move_m@injured' } },
    runner  = { weight = 25, health = 200, sprint = true, clipsets = { 'move_m@zombie@core', 'move_m@injured' } },
    jumper  = { weight = 9,  health = 200, sprint = true, leap = { min = 6.0, max = 30.0, cooldownMs = 4500, lift = 15.0, minPush = 1.5, maxPush = 22.0 }, clipsets = { 'move_m@injured' } },
    stalker = { weight = 8,  health = 230, stealth = true, lunge = 11.0, sight = 55.0, nightOnly = true, clipsets = { 'move_m@zombie@core', 'move_m@injured' } },
    alpha   = { weight = 3,  health = 900, armour = 100, sprint = true, knockdown = true, max = 2, clipsets = { 'move_m@zombie@core', 'move_m@injured' } },
}
Config.HordeVariants = { runner = 70, walker = 20, jumper = 7, alpha = 3 }  -- packs are fast
Config.NightHours = { 21, 5 }     -- stalkers only spawn from 21:00 to 05:59 (game time)
Config.ZombieDamageMult = 1.6     -- AI melee damage while the outbreak is on (reset after)

--- Look: random civilians, bloodied. u_m_y_zombie_01 is listed twice so it shows up more.
Config.SpawnModels = {
    `u_m_y_zombie_01`, `u_m_y_zombie_01`,
    `a_m_m_skidrow_01`, `a_m_m_tramp_01`, `a_m_o_tramp_01`, `a_f_m_tramp_01`,
    `a_m_y_methhead_01`, `a_m_m_hillbilly_01`, `a_m_m_hillbilly_02`, `a_m_m_salton_01`,
    `a_m_y_hippy_01`, `a_f_y_hipster_02`, `a_m_y_downtown_01`, `a_m_y_business_01`,
    `a_f_y_business_01`, `a_m_y_skater_01`, `a_m_m_farmer_01`, `a_f_m_fatwhite_01`,
    `s_m_y_construct_01`, `s_m_m_doctor_01`, `s_m_y_dealer_01`, `a_m_o_acult_02`,
}
Config.DamagePacks = { 'BigHitByVehicle', 'SCR_Torture', 'SCR_Dumpster', 'Explosion_Med', 'Car_Crash_Heavy', 'Burnt_Ped_0' }

--- While the outbreak is on: a full crowd of pedestrians (every one of them gets turned) and almost
--- no traffic. 1.0 = the game's normal amount.
Config.StreetDensity = { peds = 1.0, vehicles = 0.08, parked = 0.6 }

--- The whole city turns: every pedestrian around a player becomes a zombie as the game spawns
--- them, so the dead never run out. Script peds (mission entities) and people in cars are left alone.
Config.ConvertAmbient = true
Config.ConvertRadius = 250.0
Config.MaxConverted = 90          -- turned pedestrians alive per client
Config.GiveKnifeChance = 0.0      -- 0.0–1.0; prefer unarmed
Config.CleanupOnStop = 'delete'   -- ambient converted: 'delete' | 'restore'
--- Dead zombie bodies linger before DeleteEntity (ms)
Config.CorpseDespawnMs = 60000

--- Population restore pulse after /zombies stop (ms)
Config.DensityRestoreMs = 45000

--- Relationship
Config.RelationshipGroup = 'FIVEX_ZOMBIE'

--- Player infection
--- 'zombie' | 'kill' | 'zombie_or_kill' (50/50 when both options)
Config.PlayerInfectMode = 'zombie'
Config.HitsToInfect = 5
Config.HitDecayMs = 12000         -- ms without zombie damage before hit counter decays by 1
Config.PlayerMeleeOnly = true     -- strip/block shoot weapons when turned
Config.InfectScreenEffect = 'DrugsMichaelAliensFight'
Config.ZombieClipsets = { 'move_m@zombie@core', 'move_m@injured' }  -- turned players

--- Alarm: NUI custom audio first, frontend sound as fallback if file missing
Config.AlarmNuiSrc = 'audio/alarm.ogg'
Config.AlarmNuiVolume = 0.55
Config.AlarmSoundName = 'ScreenFlash'
Config.AlarmSoundSet = 'MissionFailedSounds'
Config.UseNuiAlarm = true
Config.UseFrontendAlarmFallback = false

--- HUD
Config.Hud = true                 -- outbreak HUD (top-right) while active
Config.AnnounceDurationStartMs = 9000
Config.AnnounceDurationStopMs = 9000
Config.NearbyRadius = 60.0        -- "nearby" counter on the HUD

--- Chat announcement style (chat:addMessage)
Config.ChatPrefix = '[FiveX Zombies]'
Config.ChatColor = { 200, 30, 30 }

--- Debug (spawn counts + CreatePed failures)
Config.Debug = false
