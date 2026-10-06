# fivex_dealership v1.0.0

Standalone vehicle dealership and garages for FiveX. Vanilla CFX — no QB / ESX / Qbox / ox_lib.
Requires `fivex_bank` (card payments) and `fivex_jobcenter` 1.1.0+ (cash).

The **client is untrusted**. Prices come from the server's config, every action re-checks distance,
and parking checks the actual entity the server spawned — not the plate text (vMenu can copy plates).

## Ensure

```
ensure fivex_jobcenter
ensure fivex_bank
ensure fivex_dealership
```

`fivex_dealership` must be listed in `Config.TrustedResources` of **both** `fivex_bank` and
`fivex_jobcenter` (it is by default).

## Where

| Point | Notes |
|---|---|
| Showroom desk | Premium Deluxe Motorsport. Blip 326. Opens the catalog with a live preview car + camera. |
| Garages ×4 | Alta St, Legion Square, Sandy Shores, Paleto Bay. Blip 357. Shared — any garage holds any car. |

All coords are best guesses — check each in game and nudge `Config.Showroom` / `Config.Garages`.

### Showroom interior

Vanilla FiveM leaves PDM on its "closed" placeholder (white panes, empty floor). This resource loads it
on every client: requests IPL `shr_int`, removes `fakeint`, enables entity sets `csr_beforeMission`
(intact glass) and `shutter_open`. If you add an IPL loader such as bob74_ipl later, set
`Config.Showroom.loadInterior = false`.

## Catalog

`data/vehicles.lua` holds **633 base-game land vehicles** across 17 categories (compacts → open wheel,
including bicycles, utility, commercial, industrial and service), generated from the game data dump
[DurtyFree/gta-v-data-dumps](https://github.com/DurtyFree/gta-v-data-dumps) up to the 2025 DLCs.

Never sold:
- anything with **weapons** (Oppressors, Ruiner 2000, Arena War, Scramjet, Deluxo, Vigilante, …)
- **gimmick / armored online variants**: Rocket Voltic, Ramp Buggies, Phantom Wedge, Brickade + 6x6,
  RC Bandito, wrecked Ruiner, Wastelander, Duke O'Death, Kuruma + all "(Armored)" limos, Hauler / Phantom Custom
- **emergency, military**, aircraft, boats, trains, trailers

Prices are generated per class from handling data (e.g. Panto $7,500 · Sultan $32,000 · T20 $425,000).
Tune them in `config.lua` without touching the generated file:

```lua
Config.PriceMultiplier = 1.0                 -- scale everything
Config.PriceOverrides = { sultan = 45000 }   -- exact prices
Config.ExcludeModels = { adder = true }      -- hide more models
```

Remove a line from `Config.Categories` to hide a whole category. After a new GTA DLC, regenerate with
`data/gen_catalog.py` (instructions at the top of the script).

## How it works

- **Buy** at the desk: pick a category, a car and one of 10 colours; pay by card (bank) or cash.
  The car is delivered outside and you are put in it. If you already have a car out, the new one goes
  to your garages instead.
- **One car out at a time.** Drive an owned car onto a garage marker and press **E** to park it
  (engine / body / dirt are saved).
- **Recall / recover** for `Config.RecoverFee` ($250, bank first then cash): brings back a car that is
  out somewhere, deleted by another script, or wrecked — repaired.
- **Disconnect** parks your car automatically. After a **server restart**, cars that were out are back in
  the garage for free. A wrecked car stays *Lost* until recovered.
- **Sell back** in *My vehicles* at the showroom for `Config.SellBackPercent` (50%) of what you paid,
  paid into your bank. The car must be parked. Staff-given cars resell for $0.
- Max `Config.MaxOwned` (10) vehicles per player. Plates are unique, e.g. `12ABC345`.

Not included (yet): vehicle keys / locking, test drives, impound, mods/tuning. vMenu vehicle spawning is
untouched; vMenu cars cannot be parked in these garages.

## Commands

| Command | Who | What |
|---|---|---|
| `/givecar [id] [model]` | ACE `fivex_dealership.staff` | Give a catalog vehicle (goes to garage) |
| `/takecar [plate]` | ACE `fivex_dealership.staff` | Remove an owned vehicle (online or offline owner) |

Purchases, sales and staff actions are logged to the server console.

## Persistence (MySQL via oxmysql)

Requires **oxmysql** (`ensure oxmysql` before this resource). Tables are created on first start, and existing KVP data is imported once (the KVP entries are left untouched).

| Table | Key → value |
|---|---|
| `fivex_dealership_vehicles` | `license` → `vehicles` (JSON array of owned vehicles) |
| `fivex_dealership_plates` | `plate` → owner `license` (plate uniqueness / lookup) |

## Server exports

```
GetVehicles(src) -> { { plate, model, label, color, status = stored|out|lost, value, engine, body } }
GetPlateOwner(plate) -> license|nil
IsOwnedEntity(entity) -> plate, license | nil
```

Spawned cars carry the replicated state bag `fivex_plate`.

## ACE

See `permissions.cfg.example`. Players need no ACE. Parent `fivex_dealership` grants all.
