# fivex_jobcenter v1.1.0

Standalone job board for FiveX. Vanilla CFX — no QB / ESX / Qbox / ox_lib.

Players apply and leave at the clerk. Pay is a dollar integer stored in MySQL (no money items). Duty is always off on join; workplaces clock you in.

## Ensure

```
ensure fivex_jobcenter
ensure fivex_coroner
ensure fivex_highrise
ensure fivex_marina
```

## Location

City Hall / Mission Row steps: `-266.0, -960.4, 31.22, heading 200.0`
Ped `a_m_y_business_03` with clipboard. Blip 407 / colour 3.

## Commands

| Command | Who | What |
|---|---|---|
| `/job` | anyone | Print job, duty, wallet |
| `/jobcenter` | anyone, within 3 m of clerk | Open NUI |
| `/jobcancel` | on duty | Cancel current assignment |
| `/setjob [id] [job]` | ACE `fivex_jobcenter.staff` | `coroner` `highrise` `marina` `none` |

E at the clerk also opens the board. Players need **no ACE** to apply or leave.

## Persistence (MySQL via oxmysql)

Requires **oxmysql** (`ensure oxmysql` before this resource). Tables are created on first start, and existing KVP data is imported once (the KVP entries are left untouched).

| Table | Key → value |
|---|---|
| `fivex_jobcenter_job` | `license` → `job` id or empty |
| `fivex_jobcenter_pay` | `license` → `cash` (integer dollars) |

No license → apply fails (notify). Duty is not persisted.

State bags (replicated): `fivex_job`, `fivex_duty`, `fivex_pay`.

## Server exports

```
GetJob(src) -> string|nil
HasJob(src, jobId) -> bool
IsDuty(src) -> bool
SetDuty(src, bool) -> bool          -- only if HasJob
AddPay(src, amount, reason) -> newBalance|nil   -- 1..5000, duty required, 20/30s
GetPay(src) -> int
SetJob(src, jobId|nil, actorSrc?) -> bool
AddCash(src, amount) -> newBalance|nil      -- trusted resources only
RemoveCash(src, amount) -> newBalance|nil   -- trusted resources only, nil if short
```

The pay wallet doubles as the player's **cash**. `AddCash` / `RemoveCash` skip the duty gate and the
5000 clamp (cap `Config.CashClamp`), so only resources listed in `Config.TrustedResources`
(default `fivex_bank`, `fivex_dealership`) may call them.

`SetJob` from another resource requires `actorSrc` with ACE `fivex_jobcenter.staff` (or parent `fivex_jobcenter`). Calling from this resource (including `/setjob`) does not.

Client export: `GetJob()` via `LocalPlayer.state.fivex_job`.
Client export: `SetProgress(pct, label)` — NUI hold circle (no focus); `pct` false/nil hides.

## Events

- `fivex_jobcenter:clientJob(jobId|false, balance, duty)` — client, on change
- `fivex_jobcenter:notify(msg, type)` — client (also local TriggerEvent)
- `fivex_jobcenter:jobChanged(src, oldJob, newJob)` — server bus
- `fivex_jobcenter:dutyChanged(src, jobId, duty)` — server bus
- `fivex_jobcenter:internalCancel(src)` — server bus for `/jobcancel`

## Jobs on the board

- `coroner` — Coroner
- `highrise` — High-rise washer
- `marina` — Marina handler

## ACE

See `permissions.cfg.example`. Default deny staff. Parent `fivex_jobcenter` grants all.

## Security

Apply / leave: source, distance ≤ 4 m, valid id, license present, 5 applies / 20 s.
