Config = {}

Config.Locale = 'en'

--- ACE permission (default-deny). Parent grant like fivex_admin:
---   add_ace group.admin fivex_zombies allow
Config.AcePermission = 'fivex_zombies'

--- Timing
Config.AlarmSeconds = 10          -- loud repeating alarm duration after start
Config.GraceSeconds = 10          -- seconds after start before infection / spawn
Config.ScanIntervalMs = 1500      -- ambient convert scan while apocalypse active
Config.IdleWaitMs = 2000          -- client idle poll when inactive
Config.InfectionPollMs = 250      -- damage / infection check while near zombies
Config.AlarmRepeatMs = 900        -- frontend fallback sound repeat during alarm window

--- Conversion (ambient CPed → zombie)
--- Default OFF: spawn-only apocalypse. Ambient convert breaks NPC recycling on stop.
Config.ConvertAmbient = false
Config.ConvertRadius = 120.0      -- metres around local player
Config.MaxZombies = 40            -- live converted + spawned (perf cap)
Config.ZombieWeapon = `WEAPON_UNARMED`  -- claw/melee; knife optional below
Config.GiveKnifeChance = 0.0      -- 0.0–1.0; prefer unarmed
--- When ConvertAmbient was on: prefer 'delete' (broken scenario peds don't recycle well).
--- 'restore' also calls SetPedAsNoLongerNeeded after reset.
Config.CleanupOnStop = 'delete'   -- ambient converted: 'delete' | 'restore'
                                  -- spawned peds are always deleted on stop
--- Dead zombie bodies linger before DeleteEntity (ms)
Config.CorpseDespawnMs = 60000

--- Spawn (mission peds when streets are empty)
--- Client CreatePed returns 0 on this server; server CreatePed is authoritative.
Config.SpawnUseServer = true
Config.SpawnEnabled = true
Config.SpawnRequestTimeoutMs = 3500
Config.MaxZombiesPerPlayer = 16  -- soft cap near one requester (server enforced)
Config.MinNearby = 12             -- if alive nearby < this, spawn more
Config.SpawnBatch = 4             -- peds per spawn tick
Config.SpawnIntervalMs = 1200
Config.SpawnRadiusMin = 12.0
Config.SpawnRadiusMax = 40.0
--- Prefer real GTA zombie, then ragged fallbacks if model load fails
Config.SpawnModels = {
    `u_m_y_zombie_01`,
    `a_m_m_hillbilly_02`,
    `a_m_o_acult_02`,
}

--- Population restore pulse after /zombies stop (ms)
Config.DensityRestoreMs = 45000

--- Relationship
Config.RelationshipGroup = 'FIVEX_ZOMBIE'

--- Movement clipsets (tried in order; fallback = injured limp)
Config.ZombieClipsets = {
    'move_m@zombie@core',
    'clipset@anim@ingame@move_m@zombie@core',
    'move_m@injured',
}

--- Player infection
--- 'zombie' | 'kill' | 'zombie_or_kill' (50/50 when both options)
Config.PlayerInfectMode = 'zombie'
Config.HitsToInfect = 5
Config.HitDecayMs = 12000         -- ms without zombie damage before hit counter decays by 1
Config.PlayerMeleeOnly = true     -- strip/block shoot weapons when turned
Config.InfectScreenEffect = 'DrugsMichaelAliensFight'  -- timecycle / animpostfx
Config.InfectNotifyDurationMs = 6000

--- Alarm: NUI custom audio first, frontend sound as fallback if file missing
--- NUI file path relative to ui_page: html/audio/alarm.ogg → 'audio/alarm.ogg'
Config.AlarmNuiSrc = 'audio/alarm.ogg'
Config.AlarmNuiVolume = 0.55
Config.AlarmSoundName = 'ScreenFlash'           -- PlaySoundFrontend fallback
Config.AlarmSoundSet = 'MissionFailedSounds'
Config.UseNuiAlarm = true
Config.UseFrontendAlarmFallback = false

--- Announce NUI
Config.AnnounceDurationStartMs = 9000
Config.AnnounceDurationStopMs = 8000

--- Chat announcement style (chat:addMessage)
Config.ChatPrefix = '[FiveX Zombies]'
Config.ChatColor = { 200, 30, 30 }

--- Debug (spawn/convert counts + CreatePed failures)
Config.Debug = false
