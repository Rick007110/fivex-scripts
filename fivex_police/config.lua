Config = {}

Config.Debug = true -- print squad state changes in F8

---------------------------------------------------------------------------
-- All AI police (cops + SWAT spawned by the game near a wanted player)
---------------------------------------------------------------------------
Config.Cops = {
    accuracy = 38,          -- 0-100 (GTA default ~ 20-30)
    armour = 50,
    combatAbility = 2,      -- 0 poor · 1 average · 2 professional
    combatRange = 1,        -- 0 near · 1 medium · 2 far
    seeingRange = 120.0,
    hearingRange = 90.0,
    driverAbility = 1.0,    -- pursuit driving 0.0-1.0
    driverAggression = 0.65,
    driveBy = false,        -- false: no shooting from inside vehicles; they stop and fight on foot
    scanRadius = 160.0,     -- m around the wanted player
}

---------------------------------------------------------------------------
-- Pursuit: patrol cars chase with sirens before anyone tries an arrest on foot.
---------------------------------------------------------------------------
Config.Pursuit = {
    sirens = true,
    followDistance = 12.0,   -- m: ideal gap while chasing a suspect's vehicle
    dismountDistance = 30.0, -- m: officers only leave their car within this of a suspect on foot
}

---------------------------------------------------------------------------
-- Perimeter: when the suspect is inside a building or has been shooting recently, patrol cops
-- hold their position in cover and return fire instead of running in.
---------------------------------------------------------------------------
Config.Perimeter = {
    enabled = true,
    shootingMemory = 10,    -- s: "actively shooting" if the suspect fired within this window
    holdRadius = 6.0,       -- m: how far a cop may move from the spot he's holding
    minDistance = 25.0,     -- m: cops closer than this to the suspect are allowed to fight normally
}

---------------------------------------------------------------------------
-- Dispatch: GTA's own SWAT units just rush like everyone else, so they're replaced by squads below.
---------------------------------------------------------------------------
Config.Dispatch = {
    disableGameSwat = true,      -- turn off the built-in SWAT van / SWAT heli dispatch
    policeHelicopter = true,
    roadblocks = true,
}

---------------------------------------------------------------------------
-- Scripted SWAT / NOOSE squads
---------------------------------------------------------------------------
Config.Swat = {
    enabled = true,
    minWanted = 4,               -- stars before squads can be sent
    squadsByWanted = { [4] = 1, [5] = 2 },
    triggerSeconds = 8,          -- suspect inside a building / shooting for this long before dispatch
    cooldown = 120,              -- s between dispatches once a squad is wiped / withdrawn
    vehicle = 'riot',            -- NOOSE riot van
    ped = 's_m_y_swat_01',
    size = 4,                    -- officers per squad (van seats)
    armour = 100,
    health = 300,
    accuracy = 45,
    loadout = {                  -- officer 1 is the point man
        { weapon = 'WEAPON_CARBINERIFLE', components = { 'COMPONENT_AT_AR_FLSH' } },
        { weapon = 'WEAPON_SMG',          components = { 'COMPONENT_AT_AR_FLSH' } },
        { weapon = 'WEAPON_PUMPSHOTGUN',  components = { 'COMPONENT_AT_AR_FLSH' } },
        { weapon = 'WEAPON_CARBINERIFLE', components = { 'COMPONENT_AT_AR_FLSH' } },
    },
    spawnDistance = { min = 180, max = 320 }, -- van spawns this far away, out of sight
    stagingDistance = 35.0,      -- van stops ~this far from the suspect (nearest road)
    driveSpeed = 22.0,           -- m/s with sirens
    advanceSpeed = 1.0,          -- 1.0 walk (weapon up) · 2.0 jog
    advanceStep = 9.0,           -- m per bound before the stack holds
    holdSeconds = 2.0,           -- hold / cover angles between bounds
    engageRange = 45.0,          -- m: officers with line of sight inside this range engage
    lostSightRegroup = 8,        -- s without line of sight before the squad regroups and keeps clearing
    withdrawAfter = 30,          -- s after the suspect is dead / no longer wanted -> withdraw
    maxLifetime = 600,           -- s hard cap per squad
}

---------------------------------------------------------------------------
-- Arrests: cops try to arrest (tasers, surrender) and only go lethal when the suspect escalates.
---------------------------------------------------------------------------
Config.Arrest = {
    enabled = true,
    lethalWanted = 4,            -- at this many stars it's lethal regardless (SWAT territory)
    drawGrace = 4,               -- s a suspect may hold a gun near cops ("Drop your weapon!") before it turns lethal
    warnDistance = 35.0,         -- m: cops this close (with line of sight) react to a drawn weapon / offer surrender
    taser = true,                -- non-lethal cops carry only a WEAPON_STUNGUN (all guns are taken until it turns lethal)
    lethalWeapons = { 'WEAPON_COMBATPISTOL', 'WEAPON_PUMPSHOTGUN' }, -- handed out once it's lethal
    longGunChance = 0.35,        -- share of officers that also get the weapons after the first
    stunArrestDistance = 6.0,    -- m: tased / ragdolled within this of a cop -> cuffed
    cuffDistance = 1.8,          -- m: a surrendered suspect is cuffed when the officer gets this close
    surrenderTimeout = 25,       -- s: no officer reached you -> you're processed anyway
    fine = { perStar = 500 },    -- taken from bank first, then cash (whatever is available)
    removeWeapons = true,
    release = vector4(434.10, -981.90, 30.71, 90.0), -- Mission Row PD front steps
}
Config.SurrenderKey = 'X'       -- rebind in Settings > Key Bindings > FiveM

-- ACE for /swat_test (calls a squad on yourself)
Config.TestAce = 'fivex_police.test'
