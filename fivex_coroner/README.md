# fivex_coroner v1.0.2

Standalone coroner job. Requires `fivex_jobcenter`. No QB / ESX / Qbox / ox_lib. Does not change ped clothing or model.

## Workplace — Los Santos County Coroner

| Point | Coords |
|---|---|
| Duty | `240.8, -1379.5, 33.74, 140` |
| Garage (rumpo `CORONER`) | `247.15, -1352.9, 31.93, 230` |
| Delivery bay | `251.5, -1366.8, 29.65` |

Blip 310 / colour 40 “Morgue”. Van capacity 2; **v1 pays one body per trip**.

## Loop (~2–3 min)

1. Hold the `coroner` job at the Job Center.
2. Clock in at the duty marker (E). Rumpo spawns; you are put in the driver seat.
3. GPS to a city call. Local dead ped (not networked).
4. E 4 s bag anim within 2 m → server `coroner:bag` (≤ 25 m of assigned coords).
5. Get out, E at the rumpo **rear doors** 2.5 s → `coroner:load` (marker is the rear offset, not the boot bone; near **server-tracked** van netId).
6. GPS to the bay. E 3 s unload → `coroner:deliver` (≤ 15 m). **+$350**. Next call in 5 s.

`/jobcancel` or clock out clears the assignment (no pay). Death or destroyed van fails and reissues. E at the garage respawns the van (60 s cooldown) if it is gone.

Pay is issued only by the jobcenter export while on duty. Overlay: `CORONER | Recover the remains | $N`.
