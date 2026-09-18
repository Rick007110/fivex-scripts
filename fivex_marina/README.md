# fivex_marina v1.0.1

Standalone marina handler. Requires `fivex_jobcenter`. Puerto Del Sol.

## Workplace

| Point | Coords |
|---|---|
| Duty | `-802.9, -1364.6, 5.18, 80` |
| Dinghy spawn (in water) | `-810.5, -1491.2, 0.15, 110` (`dinghy2`, plate `MARINA`) |
| Slip A / B / C | `-793.4,-1501.5,0.2` / `-786.0,-1488.0,0.2` / `-772.5,-1505.8,0.2` |
| Fuel pump | `-798.4, -1513.2, 1.6` |
| Detail | `-816.2, -1346.8, 5.15` (4 points) |
| Fetch spawn | `-880.0, -1550.0, 0.1` (`speeder`) |

Blip 410 “Marina”.

## Tasks (server rotates, never the same twice)

1. **Fetch** — board the offshore runner, drive to the assigned slip (≤ 8 m, speed < 8). `marina:dock`. **+$280**. Boat entity ids are not trusted for pay.
2. **Fuel** — E 2 s at the pump (`grabCan`) then 3 s pour at the slip. **+$180**.
3. **Detail** — four 2.5 s scrubs. **+$220** when all four are acked.

Next task after 4 s. If the runner sinks, fail and reissue. Clock out deletes dinghy + fetch boat. Overlay: `MARINA | Dock the runner | $N`.
