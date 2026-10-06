# fivex_spawn v1.0.0

Spawn selector for FiveX. Vanilla CFX — works with `spawnmanager` + `basic-gamemode`, no framework.

**Why:** `basic-gamemode` lets spawnmanager pick a random spawnpoint from the active map
(fivem-map-skater / hipster), which are scattered over hilltops near Mount Chiliad, rooftops and cranes.
This resource registers spawnmanager's auto-spawn callback, so those random points are never used.

## What happens

- **On join:** the loading screen closes into a full-screen selector over a camera preview.
  *Last location* (if any) is first, then the places in `Config.Locations`. Click or `↑`/`↓` to preview,
  **Spawn here** or `Enter` to spawn. The spot's ground height is snapped after collision loads.
- **Last location:** saved every 30 s (`Config.SaveInterval`) once a player has spawned, per Rockstar
  license (MySQL table `fivex_spawn_last`, needs oxmysql; old KVP data is imported once). Not saved while dead.
- **Switch-style camera** (`Config.Transition`): picking another place makes the camera rise into the
  sky, glide across and drop to an aerial shot of it; spawning dives down behind your character and
  blends into the gameplay camera — like a story-mode character switch, but faster.
- **After dying:** respawn at the nearest hospital in `Config.Hospitals` — no menu (quick fade, no switch).
- **Map changes / forced respawns while alive:** you stay where you are.
- The first spawn uses `mp_m_freemode_01`; `fivex_appearance` applies the saved look on `playerSpawned`.

## Ensure

```
ensure spawnmanager
ensure basic-gamemode
ensure fivex_spawn
```

(`ensure [fivex]` covers it.)

## Config

```lua
Config.Locations = {
    { id = 'legion', label = 'Legion Square', area = 'Downtown Los Santos', icon = 'city',
      coords = vector4(195.17, -933.77, 30.69, 144.0) },
    …
}
```

Icons: `city hospital police briefcase car plane pier star desert forest` (anything else shows a pin).
`Config.Camera` sets the preview distance / height / FOV / blend time.
