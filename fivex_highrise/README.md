# fivex_highrise v1.0.2

Standalone high-rise washer. Requires `fivex_jobcenter`. You walk roof equipment / exterior bays — you are not hanging off glass. No clothing changes. No parachute by default (`Config.GiveParachute = false`).

## Depot

Duty / bison `WASHER`: `-351.85, -141.22, 39.15` (Power St sidewalk, west of the office hull). Garage `-355.40, -149.80, 39.10`. Blip 475 “Window Depot”. **+$500** per building.

## Buildings

| Site | Door | Roof (walkable) |
|---|---|---|
| Arcadius | `-144.5, -577.2, 32.42` | `-139.0, -620.8, 168.82` (lower terrace) |
| Maze Bank | `-66.7, -802.8, 44.23` | `-75.2, -819.2, 326.18` (helipad) |
| FIB | `109.3, -744.2, 45.75` | `136.1, -749.0, 258.15` |
| Maze Bank West | `-1370.0, -503.3, 33.16` | `-1367.15, -471.55, 84.50` (open helipad, east of stairhouse) |

Each roof has 6–7 clustered bays on the surface.

## Loop

Clock in → bison → drive to door → E service lift (fade + collision wait) → walk bays, E 3 s scrub (`highrise:scrub`, ≤ 8 m, per-index, cannot redo) → when all acked, E lift down (`highrise:complete`) → pay → next building.

Fall: client reports if `z < roof.z - 8`; server verifies entity coords. Fade back to depot, **no pay**, reassign. Debounced (no kill-spam).
