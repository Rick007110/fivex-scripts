# fivex_zombies

**Version:** 2.1.0  
**Author:** FiveX  

Staff-triggered zombie outbreak for **vanilla CFX** (no QBCore / ESX / ox_lib). The city fills with
bloodied dead that wander until they see or hear you, hordes come running from out of sight, and
five variants each fight differently. A backup of 1.0.6 is in `txData/.../backups/fivex_zombies_backup_2026-10-04`.

## Install

1. Keep `fivex_zombies` in `resources/[fivex]/` (`ensure [fivex]` starts it).
2. Grant ACE to staff (default-deny):

```
add_ace group.admin fivex_zombies allow
```

## Commands

| Command | ACE | Description |
|---------|-----|-------------|
| `/zombies start` | `fivex_zombies` | Start the outbreak (server-authoritative) |
| `/zombies stop` | `fivex_zombies` | Stop and restore normal streets |
| `/apocalypse start\|stop` | `fivex_zombies` | Alias |

Console can always run them.

## How the dead behave

**The whole city turns** (`Config.ConvertAmbient`). Pedestrians keep spawning at the game's normal
density, and every one within `ConvertRadius` becomes a zombie as it appears, so the dead never run
out. Each client turns the pedestrians it owns (up to `MaxConverted`). Script peds (mission
entities: job clerks, shop staff, drivers) and people in vehicles are left alone. Traffic drops to
almost nothing.

**Topped up.** On top of that, every player's client keeps at least `Config.Wanderers` (55) zombies
within `Config.WanderRadius`, spawning up to 10 every 0.7 s, `SpawnRadiusMin`–`SpawnRadiusMax`
away and preferably where the camera can't see them. Zombies shamble about until they notice someone.

**Senses** (`Config.Senses`). A zombie notices a player when it:

| Sense | Range |
|---|---|
| sees you (in front of it, clear line of sight) | `sight` 32 m (stalkers 55 m) |
| is right next to you | `touch` 9 m |
| hears a gunshot | `gunshot` 95 m, suppressed 22 m |
| hears you sprint | `sprint` 22 m |
| hears a car (faster than ~30 km/h) / a horn | `vehicle` 35 m / `horn` 70 m |

It hunts that player until it loses them (`loseAfterMs` out of sight, or beyond `loseDistance`).
A closer, louder player can steal the chase. Turned players are ignored.

**Hordes** (`Config.Hordes`). Every 22–40 s per player a pack of 12–20 spawns 60–85 m away *behind the
camera*, already hunting you. The HUD warns "Horde inbound — coming from the north-east".

**Variants** (`Config.Variants`). Headshots always kill. Health tunes how many body shots it takes.

| Variant | Weight | Behaviour |
|---|---|---|
| Walker | 55 | Shambles toward you |
| Runner | 25 | Sprints |
| Jumper | 9 | Sprints, and leaps at you from 6–30 m: an ~11 m high arc that lands on you (`lift`, cooldown 4.5 s). No fall damage from its own landing |
| Stalker | 8 | Night only (21:00–05:59). Sees further, creeps up crouched, lunges from 11 m |
| Alpha | 3 | 900 health + armour, sprints, each hit knocks you down. Max 2 alive |

Hordes use their own mix (`Config.HordeVariants`: mostly runners).

**Look.** Random civilians from `Config.SpawnModels` (plus `u_m_y_zombie_01`), random outfits and
1–2 damage packs (`Config.DamagePacks`) for blood and burns.

**Streets.** While active, `Config.StreetDensity` applies (full crowd, almost no traffic). AI melee damage is
multiplied by `Config.ZombieDamageMult`. Both reset on stop, followed by a 45 s density restore pulse.

## Networking

Zombies are created by the server (`CreatePed`, OneSync) at a point the requesting client chose,
and tagged with state bags: `fivex_zombie`, `fivex_zvar` (variant) and `fivex_zhunt` (a horde's
target). Whichever client **owns** a zombie runs its brain, so the AI follows OneSync's ownership
migration. Players publish their noise in `Player(id).state.fivex_znoise`, so a zombie owned by
another client still hears your gunshot.

Server limits for spawned zombies: `MaxZombies` (300, server-wide), `MaxZombiesPerPlayer` (60), max 2 alphas, a
model allowlist (`SpawnModels`), a per-player spawn rate limit, and spawn distance checks. Zombies
farther than `DespawnDistance` (190 m) from every player are removed to free the caps.

## Player infection

- Hits from zombies count up to `Config.HitsToInfect` (5). The counter decays after `HitDecayMs`.
- At the threshold: `PlayerInfectMode` `zombie` (you turn: melee only, screen effect, zombies
  ignore you), `kill`, or `zombie_or_kill`.
- Death clears the infection.

## Screen

- **Start:** an Emergency Alert takeover: glitching OUTBREAK title, the grace countdown ring, a
  ticker, and the alarm (`html/audio/alarm.ogg`).
- **During:** an HUD top-right: elapsed time, threat level (Calm → Overrun), zombies nearby /
  hunting you, your kills, the infection meter, and "Night: stalkers are out". Hidden while the
  pause menu is open. It goes green when you've turned.
- **Horde warning:** a toast next to the HUD with the direction and pack size.
- **Stop:** ALL CLEAR with how many you killed and how long you survived.

No cursor, never takes focus. Text is in `locales/en.lua`.

NUI messages: `announce` (`kind` start|stop, `grace`, `kills`, `survived`), `hud`, `horde`,
`playAlarm`, `stopAlarm`.

## Exports (server)

```lua
exports['fivex_zombies']:IsApocalypseActive()
exports['fivex_zombies']:StartApocalypse()
exports['fivex_zombies']:StopApocalypse()
```

## Performance

Expect 100+ zombies around a player. If FPS drops, lower in this order: `Wanderers`,
`MaxConverted`, `Hordes.size`, `StreetDensity.peds`.

## Changelog

### 2.1.0
- The whole city turns: ambient pedestrians are converted as they spawn (constant supply), at full pedestrian density.
- Many more zombies: 55+ kept around each player, faster top-up, bigger and more frequent hordes.
- Jumpers leap far higher (~11 m apex, aimed to land on you) and take no fall damage from it.
- On stop, every zombie a client owns is removed, including ones that migrated from other players.

### 2.0.0
- Zombies wander and notice players by sight, proximity and noise (gunshots, sprinting, cars, horns), then hunt; lose interest when they lose you.
- Hordes spawn out of view and come running, with an HUD warning.
- Variants: walker, runner, jumper (leaps), stalker (night, creeps), alpha (tank, knockdown).
- Bloodied random civilians instead of one model. Headshots kill.
- AI runs on whichever client owns the zombie (survives ownership migration).
- Streets empty out while active. Far-away zombies are recycled server-side.
- New UI: Emergency Alert takeover, live outbreak HUD, horde toast, end-of-outbreak summary.

### 1.0.6
- `ensureNetworkControl` before setup on server peds; server model allowlist and spawn rate limit.

### 1.0.5
- Server-side `CreatePed`; corpses linger `CorpseDespawnMs`.
