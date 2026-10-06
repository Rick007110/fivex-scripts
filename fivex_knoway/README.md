# fivex_knoway v1.0.0

Driverless taxi for FiveX. Book a **KnoWay** van from the KnoWay app on your Flexa phone; an invisible
driver brings a white Karin Vivanite (Service) to you, opens the back right door, and drives you to
your destination when you press **Go**. Vanilla CFX, no framework. Also the reference app for the
Flexa App API (see `fivex_flexa` README, "Building apps").

Requires `fivex_flexa` 2.1.0+, `fivex_bank`, `fivex_jobcenter` 1.1.0+. Game build 3570+ (the Vivanite
Service is from mp2025_02).

```
ensure fivex_flexa
ensure fivex_bank
ensure fivex_knoway
```

`fivex_knoway` must be in `Config.TrustedResources` of **fivex_bank** and **fivex_jobcenter** (it is by default).

## Ride flow

1. **Book** in the KnoWay app: *Pick on map* (opens the pause map — set a waypoint and close it, the app
   reopens on the confirm screen), your current waypoint, or one of the quick places. You see the fare first.
2. After 3–7 s a van is dispatched 90–180 m away (out of sight when possible) and hurries to the nearest
   road next to you — the empty van drives rushed; with passengers it drives normally.
3. It stops and opens the **back right door**. Get in (friends can ride too).
4. Press **Go** (`Y`, or click — `Left Alt` toggles the mouse). The fare is charged now: bank first, then cash.
5. At the destination it stops, opens the door and waits up to 25 s for everyone to get out
   (stragglers are asked to leave), closes **all** doors, waits 4 s and until nobody stands within 5 m,
   then drives off and despawns after 20 s.

**Cancel** any time from the app or the HUD (`X` while in the van):
before Go it's free; mid-trip the van pulls over and you get back the unused share of the distance fare.
If nobody gets in within 3 minutes, the van leaves (free).

## Driving

The van uses GTA's default driving style everywhere (786603): it obeys lights, stays in its lane and
uses the same main roads as the GPS, at normal traffic speed. Pickups use the kerb / nearest main road on
the player's own level (not a bridge or highway overhead); within 45 m it slows down and rolls to a
gentle stop. Destinations off the road end at the nearest main road; a place with `exact = true` is
driven to exactly.

It never appears or disappears on camera: it spawns where you can't see it and at least 120 m from
other players, and after driving off it keeps going until no player can see it (max +90 s).
If the ride logic ever errors, the van is removed, the ride cancelled and anything paid refunded
(`[fivex_knoway] ride failed` in F8).
If it gets boxed in (no progress for 12 s; red lights don't count) it escalates:
reverse and retry → retry with an aggressive swerve style → hop ~35 m ahead along the road
(unseen when empty; a short screen fade when riders are inside).

## Adding destinations

Stand where the van should drop people off and run `/knoway_coords` — a ready-to-paste
`Config.Places` line is printed in F8. Edit the label, add it to `config.lua`, restart the resource.

## Fare

`$25 + $18 per road km` (straight line × 1.3), minimum `$40`. Tune `Config.Fare`.

## Vehicles

Each ride gets one vehicle from `Config.Vehicles`, picked by weight when it's booked (default 50/50):

| Model | What | Look |
|---|---|---|
| `vivanite2` | KnoWay Van — Karin Vivanite (Service), base game | grille 2nd option, livery mod `[48] = 0`, white |
| `knowayest` | custom KnoWay car (`knowayest` resource) | livery in its textures, white |

Vehicles with `resource = '…'` are only picked while that resource runs (otherwise the van is used).
The app shows which vehicle is coming next to the plate. `/knoway_van [model]` spawns one for yourself.

If a different livery shows up, change the `[48]` index. Each active ride gets the lowest free number on
its plate: `KNOWAY1`, `KNOWAY2`, … The driver ped is invisible, completely silent (no voice, pain or
ambient speech; horn disabled) and cannot be dragged out. Vehicle + driver are owned by the booker's
client (migration off) so the AI keeps driving; the server deletes both if the booker disconnects, the
resource stops, or a ride passes 20 minutes.

`/knoway_van` (ACE `fivex_knoway.spawn` or `fivex_knoway`) spawns a styled van for yourself. The separate
custom KnoWay car is the `knowayest` resource (vMenu → Addon Vehicles).

## Keys

| Default | Action (rebind in Settings → Key Bindings → FiveM) |
|---|---|
| `Y` | Go (inside the van at pickup) |
| `X` | Cancel ride (inside the van) |
| `Left Alt` | Mouse on/off for the HUD buttons |

## Security

The server computes the fare from the player's real position, validates destinations (configured place
index, or a waypoint inside the island bounds), checks the booker is actually inside the van entity before
charging, and measures the van's real position for drop-off and refunds. One ride per player,
`Config.MaxActiveRides` server-wide, rate limited.
