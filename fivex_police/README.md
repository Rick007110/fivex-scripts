# fivex_police v1.0.0

More realistic AI police for FiveX. Vanilla CFX, client-side AI (each wanted player's machine runs
the cops around them), no framework.

## What it does

**All AI cops near a wanted player** (`Config.Cops`): higher accuracy, armour, professional combat
ability, cover use, no fleeing, better pursuit driving.

**Perimeter instead of a rush** (`Config.Perimeter`): while the suspect is inside a building or has
fired in the last 10 s, patrol cops further than 25 m away hold their position (a 6 m defensive area),
take cover and return fire. They go back to normal pursuit when the standoff ends.

**SWAT / NOOSE squads** (`Config.Swat`) replace GTA's own SWAT dispatch (which just rushes):
at 4★ (1 squad) / 5★ (2 squads), after the suspect has been barricaded in a building or shooting for
8 s, a NOOSE riot van arrives with sirens from out of sight and stops on a road ~35 m away.
Four heavily armoured officers (carbine / SMG / shotgun, weapon lights) dismount and form a squad:

1. **Bound** — the point man walks toward the suspect along the navmesh, weapon up; the rest follow in formation.
2. **Hold** — every ~9 m the stack stops for 2 s, the point covers ahead, the others cover different angles.
3. **Contact** — any officer with line of sight within 45 m engages from cover.
4. **Regroup** — 8 s without sight: they re-form on the point man and keep clearing.
5. Point man down → the next officer takes point.
6. **Withdraw** — 30 s after the suspect is dead or no longer wanted (or the squad is wiped), they leave
   and despawn out of sight; 2 min cooldown before the next squad.

Expect GTA AI with scripted tactics on top: squads move and hold together, but in interiors without
good navmesh the pathing can still get confused.

## Arrests (`Config.Arrest`)

Cops try to **arrest** first: non-lethal officers carry tasers and chase on foot. Close to officers
you get **Press X to surrender** — hands up, they hold fire, the nearest officer walks up and cuffs you
(paired arrest animation). Getting tased / knocked down near an officer also ends in cuffs.

It turns **lethal** (their own guns, until the wanted level clears) when you shoot, aim at an officer,
hurt an officer, keep a gun drawn after "Drop your weapon!" (4 s grace), or reach 4★.

**Busted:** fine of $500 per star (bank first, then cash — whatever you have; needs `fivex_police` in
the TrustedResources of fivex_bank and fivex_jobcenter), weapons removed, wanted cleared, released on
the Mission Row PD steps.

## Commands

| Command | Who | What |
|---|---|---|
| `/swat_test` | ACE `fivex_police.test` (or `fivex_police`) | 4★ + a squad right away (lose the stars to end it) |

`group.admin` has `fivex_police` in server.cfg. `Config.Debug = true` prints squad state changes in F8.

## Dispatch

`Config.Dispatch`: built-in SWAT van/heli off, police helicopter and roadblocks on (toggle each).
