# fivex_zombies

**Version:** 1.0.6  
**Author:** FiveX  

Staff-triggered zombie apocalypse for **vanilla CFX** (no QBCore / ESX / ox_lib).

## Install

1. Drop `fivex_zombies` into your resources folder (e.g. `resources/[fivex]/fivex_zombies`).
2. Ensure the `[fivex]` folder (or this resource) is started — do **not** require a separate `server.cfg` line if `[fivex]` is already ensured.
3. Grant ACE to staff (default-deny):

```
add_ace group.admin fivex_zombies allow
```

Same parent-grant pattern as `fivex_admin`.

## Commands

| Command | ACE | Description |
|---------|-----|-------------|
| `/zombies start` | `fivex_zombies` | Start apocalypse (server-authoritative) |
| `/zombies stop` | `fivex_zombies` | Stop and restore normal |
| `/apocalypse start\|stop` | `fivex_zombies` | Alias |

Console (src 0) can always run them.

## Behaviour

### On START

1. Server sets `GlobalState.fivex_zombies_active = true` and fires `fivex_zombies:setActive(true)` to all clients.
2. Chat announcement to all players (prepare warning) — **kept**.
3. Client shows **NUI announce** (`action: announce`, `kind: start`) with APOCALYPSE + grace countdown.
4. Client plays **custom NUI alarm** (`html/audio/alarm.ogg`) via `playAlarm`; optional `PlaySoundFrontend` fallback if enabled.
5. After `Config.GraceSeconds`, **burst spawn** then ongoing spawn/convert begin; server announces “infection has begun”.
6. Does **not** call `ClearAreaOfPeds` on start.

### During apocalypse (client)

Separate threads so conversion/spawn keep running **while the alarm window is active**:

- **Spawn-only by default** (`Config.ConvertAmbient = false`) — ambient convert is optional (breaks NPC recycling when left on).
- **Spawn** local mission zombies when **alive nearby** count &lt; `Config.MinNearby` (within `SpawnRadiusMax+10`).
- Grace end: immediate burst until `MinNearby` / `MaxZombies` (max 20 create attempts).
- Relationship `FIVEX_ZOMBIE`, clipsets, unarmed melee.
- Cap: `Config.MaxZombies` across converted + spawned.
- Spawned tracked separately → **deleted** on stop; ambient converted → **deleted** by default (or restore + `SetPedAsNoLongerNeeded`).

### Player infection

- Hits from zombie peds via `CEventNetworkEntityDamage` + damage poll.
- `Config.HitsToInfect` (default **5**).
- Mode `Config.PlayerInfectMode` (default **`zombie`**).
- Hit counter decays every `Config.HitDecayMs`.
- Death clears infection; can be re-infected while apocalypse is on.

### On STOP

- Chat “Apocalypse over” **and** NUI `announce` / `kind: stop` (**ALL CLEAR**).
- `stopAlarm`; delete spawned; cleanup converted; clear infection / FX.
- Clear zombie↔CIV/PLAYER hostility (do not leave CIV groups hostile).
- **45s density pulse** (every frame): ped/scenario/vehicle density multipliers at 1.0 + `SetCreateRandomCops(true)` so normal NPCs return.

## Spawn config (1.0.4)

| Key | Default | Notes |
|-----|---------|-------|
| `ConvertAmbient` | `false` | Spawn-only apocalypse; set `true` to convert street civs |
| `SpawnEnabled` | `true` | Mission ped spawn while active + past grace |
| `MinNearby` | `12` | Spawn if **alive nearby** &lt; this |
| `SpawnBatch` | `4` | Per spawn tick |
| `SpawnIntervalMs` | `1200` | Spawn cadence |
| `SpawnRadiusMin` | `12` | Ring around player (visible) |
| `SpawnRadiusMax` | `40` | Ring around player |
| `MaxZombies` | `40` | Converted + spawned cap |
| `CleanupOnStop` | `delete` | Converted ambient: `delete` (preferred) or `restore` |
| `DensityRestoreMs` | `45000` | Post-stop density pulse duration |
| `SpawnModels` | `u_m_y_zombie_01`, hillbilly, acult | Prefer real zombie model |

Spawn uses **local mission peds only**: `CreatePed(4|26, model, …, false, true)` after spawn-point collision/`GetGroundZ` gate + Z-offset retries. No networked client CreatePed (avoids OneSync entity storms / lockdown zeros). Model stays loaded for the whole batch; dead spawned peds are `DeleteEntity`’d on prune. CreatePed failures print a console breadcrumb.

Set `Config.Debug = true` for spawn/convert count prints.

## NUI

- `ui_page 'html/index.html'`, files include `html/**` and `html/audio/alarm.ogg`.
- No cursor / no focus (`SetNuiFocus(false,false)` always).
- Messages:
  - `{ action='announce', kind='start'|'stop', grace?, durationMs? }`
  - `{ action='playAlarm', src='audio/alarm.ogg', volume? }`
  - `{ action='stopAlarm' }`

## Security

- Only ACE holders (or console) can start/stop.
- Clients **cannot** force start; they only react to server events / `GlobalState`.

## Alarm

Primary: royalty-free generated siren at `html/audio/alarm.ogg` (NUI `<Audio>` loop).  
Fallback: `PlaySoundFrontend` when `Config.UseFrontendAlarmFallback = true` or NUI disabled.

## Exports (server)

```lua
exports['fivex_zombies']:IsApocalypseActive()
exports['fivex_zombies']:StartApocalypse()
exports['fivex_zombies']:StopApocalypse()
```
