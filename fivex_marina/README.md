# fivex_marina v2 — Harbor Authority

A career marina job for FiveX. Clock in at the harbor office in Puerto Del Sol, pick contracts from the
dispatch tablet, rank up, and unlock better boats and higher pay. Vanilla CFX, no framework.
Requires `fivex_jobcenter` (job, duty, wallet).

```
ensure fivex_jobcenter
ensure fivex_marina
```

## How it plays

1. Apply as **Marina handler** at the Job Center.
2. Go to the harbor office and press **E** to clock in. Your work boat spawns at the marina and the tablet opens.
3. Pick a contract on the tablet (**F5** while on duty, rebindable). The HUD shows objectives, the timer, and estimated pay.
4. Clock out at the office (**G**) for a shift summary.

## Contracts

| Contract | Rank | What you do |
|---|---|---|
| Hull Detail | 1 | A dirty client boat waits in the detail slip. Scrub 4 spots from the docks; the hull visibly gets cleaner. |
| Slip Refuel | 1 | Fill a jerry can at the pump, then pour into a moored boat. Skill check: let go of E inside the green band. Spilling costs pay. |
| Adrift Recovery | 1 | A runner drifts at sea. Board it, bleed the fuel line to get the engine going, and dock it at the assigned slip. Pay scales with hull condition. Your work boat is towed home. |
| Debris Sweep | 2 | Drive through floating junk to scoop it up, then unload at the main dock. |
| Harbor Charter | 2 | Pick up a tourist, hit 3 sightseeing stops, and return. Bumps and airtime cost stars; stars decide the tip. |
| Mayday Rescue | 3 | Follow the red flare, pull the swimmer aboard, and rush them to the medics. |

Sea locations are picked live inside configured open-water areas and checked to be deep, open water, so no hand-placed sea coordinates are needed.

## Pay and progression

- **Pay** = offer × rank rate × (1 + streak + express) × quality.
  - **Streak:** +5% per contract in a row, up to +30%. Resets on fail or cancel.
  - **Express:** +20% pay and +25% XP when you finish within par.
  - **Quality:** depends on the contract (perfect fill, hull condition, charter stars, rescue time).
- **Ranks:** Deckhand → Dockhand → Boatswain → First Mate → Harbor Master. Each rank unlocks contracts, a better pay rate, and a better work boat (Dinghy → Suntrap → Speeder → Toro).
- **Saved data:** career XP, contract count, lifetime earnings and best streak are stored per license in MySQL (`fivex_marina_profile`, leaderboard in `fivex_marina_board`; needs oxmysql, old KVP data is imported once). The tablet shows a top-10 leaderboard.

## Security

The server decides everything. Contracts come from a server-generated board, and every step is checked:
- duty status and contract id
- distance to the objective
- in-vehicle state where relevant
- entity ownership and model for reported boats
- order of steps
- minimum believable time, based on route length plus a per-contract floor

Sea spots reported by the client must fall inside the contract's area, away from the harbor, and can be corrected once.

## Config

Everything is in `config.lua`: locations, sea areas, ranks and boats, contract pay/XP/par/limit, bonuses, refuel mini-game tuning, models, and particle effects.
