# FiveX Scripts

Public monorepo for FiveX FiveM resources. Vanilla CFX: no QB / ESX / Qbox framework.

**Layout:** one folder per resource on `main` (not branch-per-script).  
**Versioning:** [`fivex_versioncheck`](./fivex_versioncheck) — GitHub Releases with tags `{resource}-v{semver}` (Eschiclers `version_control` does not support multiple scripts in one repo).

## Requirements

| Needed for | What |
|---|---|
| Everything | A FiveM server (tested on game build 3751, `sv_enforceGameBuild 3751`) |
| Resources marked *oxmysql* | [oxmysql](https://github.com/overextended/oxmysql) and a MySQL / MariaDB database: `set mysql_connection_string "mysql://USER:PASSWORD@localhost/DATABASE?charset=utf8mb4"`. Tables are created on first start. |
| `fivex_flexa` (and `fivex_knoway`, which runs on it) | sd-phone + `sd-phone-props`, [ox_lib](https://github.com/overextended/ox_lib), oxmysql and the FiveX `ND_Core` compatibility core (not in this repo yet; see the flexa README) |
| `fivex_spawn` | `spawnmanager` (ships with the default server data) |
| Update notices | `fivex_versioncheck` (most resources list it as a dependency, so start it) |

## Resources

| Resource | What it is | Requires |
|---|---|---|
| [`fivex_admin`](./fivex_admin) | ACE-gated staff / admin menu | oxmysql · optional: screenshot-basic |
| [`fivex_appearance`](./fivex_appearance) | Character creator, clothing, barber and tattoo shops | oxmysql |
| [`fivex_bank`](./fivex_bank) | Bank accounts, branches, ATMs, transfers, history | oxmysql, fivex_jobcenter |
| [`fivex_coroner`](./fivex_coroner) | Coroner job | fivex_jobcenter |
| [`fivex_dealership`](./fivex_dealership) | Vehicle dealership and garages | oxmysql, fivex_jobcenter, fivex_bank |
| [`fivex_drone`](./fivex_drone) | FPV racing / freestyle drone | — |
| [`fivex_flexa`](./fivex_flexa) | Flexa foldable phone (sd-phone that unfolds) | sd-phone stack (see above) |
| [`fivex_gangwars`](./fivex_gangwars) | Flashpoint turf-wave minigame | oxmysql |
| [`fivex_highrise`](./fivex_highrise) | High-rise window washer job | fivex_jobcenter |
| [`fivex_jobcenter`](./fivex_jobcenter) | Job board, pay wallet (cash), duty state | oxmysql |
| [`fivex_knoway`](./fivex_knoway) | Driverless taxi booked from Flexa | fivex_flexa, fivex_bank, fivex_jobcenter |
| [`fivex_marina`](./fivex_marina) | Harbor Authority marina career job | oxmysql, fivex_jobcenter |
| [`fivex_police`](./fivex_police) | Realistic AI police and SWAT | — |
| [`fivex_rollover`](./fivex_rollover) | Tire bursts can roll cars at speed | — |
| [`fivex_spawn`](./fivex_spawn) | Spawn selector and hospital respawns | oxmysql, spawnmanager |
| [`fivex_staffvest`](./fivex_staffvest) | Staff vest clothing replace | — (stream assets, see below) |
| [`fivex_versioncheck`](./fivex_versioncheck) | Version checker for this repo | — |
| [`fivex_zombies`](./fivex_zombies) | Staff-triggered zombie outbreak | — |

Every resource except `fivex_drone` and `fivex_versioncheck` declares `dependency 'fivex_versioncheck'`.
Each folder has its own README (install, config, commands, exports, events).

## Install

1. Copy the resource folders you need into your server `resources` tree (e.g. `resources/[fivex]/`),
   or download a release zip (see below) and unzip it there.
2. In `server.cfg`, start the shared pieces first, then the FiveX folder:

```cfg
set mysql_connection_string "mysql://USER:PASSWORD@localhost/DATABASE?charset=utf8mb4"

ensure fivex_versioncheck
ensure oxmysql

# only for fivex_flexa / fivex_knoway:
setr ox:locale "en"
ensure ox_lib
ensure ND_Core
ensure sd-phone-props
ensure sd-phone

ensure [fivex]
```

`dependency` lines in each `fxmanifest.lua` make FiveM start `fivex_jobcenter` before `fivex_bank`,
`fivex_bank` before `fivex_dealership`, and so on, so `ensure [fivex]` starts them in the right order.

3. Permissions are ACE. Players need none for normal use; staff features are default-deny. See
   `permissions.cfg.example` in `fivex_admin`, `fivex_appearance`, `fivex_bank`, `fivex_dealership` and
   `fivex_jobcenter`, and the ACE section of each README (`fivex_drone`, `fivex_gangwars`, `fivex_knoway`,
   `fivex_police`, `fivex_zombies`). A parent node grants all its children, e.g.
   `add_ace group.admin fivex_bank allow`.
4. Restore any omitted binaries (see [OMITTED_ASSETS.md](./OMITTED_ASSETS.md)) from your live server if required.

## Releases

Each resource is released on its own: [Releases](https://github.com/Rick007110/fivex-scripts/releases) has a
`{resource}-v{version}.zip` per release containing just that resource folder.

## Shipping a new version

Releases are automatic. On every push to `main`, [`.github/workflows/release.yml`](./.github/workflows/release.yml):

1. finds the resource folders that changed in the push;
2. reads `version` from each folder's `fxmanifest.lua` — if that version was already released, it bumps the
   patch number and commits the new `fxmanifest.lua` (`[skip ci]`);
3. publishes a GitHub **Release** tagged `{resource}-v{version}` (e.g. `fivex_flexa-v4.1.1`) with
   `{resource}-v{version}.zip` attached (the resource folder, ready to unzip into `resources/`).

Bump `version` yourself for a minor / major release. To re-release specific folders, run the workflow by hand
(Actions → *Release changed resources* → *Run workflow*, optionally listing folders).

Servers running `fivex_versioncheck` print an update notice when a newer tag exists for that resource.

## License / authorship

FiveX — Rick007110
