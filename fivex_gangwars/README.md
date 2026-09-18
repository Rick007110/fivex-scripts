# fivex_gangwars — Flashpoint v1.0.0

Standalone opt-in turf wave minigame for FiveM. **No ox_lib, no QB/ESX.**

## How it works

1. Approach a Flashpoint turf (Davis / Chamberlain / Rancho). Short-range blips mark each zone.
2. Walk to the **center marker** and press **E** to **arm** Flashpoint for that visit. Random passers-by are never forced in.
3. While armed and inside the turf, a **heat bar** fills (faster if you are moving or holding a weapon).
4. At **100% heat**, a **wave** starts: NPC gang members (custom relationship group, hostile to PLAYER) spawn and attack with fists or pistols.
5. Clear all hostiles → brief calm → next wave (harder: more peds up to **6**, higher pistol chance).
6. **Leave the turf** or **die** → run ends. Score = waves cleared + kills.
7. **Payday**: server stub notify + optional KVP total by license (no framework bank yet). Client never awards money.

## Commands

| Command | Who | Effect |
|---------|-----|--------|
| `/flashpoint` | Anyone | Toggle personal opt-out for this session |
| `/gangwars start [turfId]` | ACE `fivex_gangwars` | Force-start a run (`ballas` / `families` / `vagos`) |
| `/gangwars stop` | ACE `fivex_gangwars` | Force-stop current run |

ACE is **default-deny**. Grant with e.g.:

```
add_ace group.admin fivex_gangwars allow
```

## Install

Already covered if you `ensure [fivex]` — drop this folder into `resources/[fivex]/fivex_gangwars`.

Do **not** require a separate `ensure fivex_gangwars` if the `[fivex]` folder ensure is in `server.cfg`.

```
ensure [fivex]
```

Restart the resource or server after deploy:

```
ensure fivex_gangwars
```

## Turfs (v1 — center + radius)

| Id | Label | Center | Radius |
|----|-------|--------|--------|
| `ballas` | Davis Flashpoint | `105.0, -1940.0, 20.8` | 55 |
| `families` | Chamberlain Flashpoint | `-210.0, -1605.0, 34.0` | 55 |
| `vagos` | Rancho Flashpoint | `331.0, -2041.0, 20.9` | 55 |

## Config highlights

- `HeatPerSecondInside`, `HeatDecayOutside`, `WaveCooldownMs`, `MaxWaves` (0 = infinite)
- `BasePeds` / `PedsPerWave` capped at `MaxLiveHostiles = 6`
- `PistolChanceStart` → `PistolChanceMax` per wave
- Weapons: `WEAPON_UNARMED` and `WEAPON_PISTOL` only
- Player clothing is never changed

## Files

```
fxmanifest.lua
config.lua
locales/en.lua
client/main.lua
server/main.lua
html/index.html
html/style.css
html/app.js
README.md
```

## Notes

- Idle turf checks sleep ~750ms; active runs use a tighter loop. No `Wait(0)` busy loop when idle.
- All peds/blips cleaned on resource stop and run end.
- Server validates wave start / kill registration / payday. Kill reports for unregistered net IDs are ignored.
