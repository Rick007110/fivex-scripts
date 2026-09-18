# fivex_jobcenter v1.0.1

Standalone job board for FiveX. Vanilla CFX — no QB / ESX / Qbox / ox_lib.

Players apply and leave at the clerk. Pay is a KVP dollar integer (no money items). Duty is always off on join; workplaces clock you in.

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

## Persistence

| KVP | Value |
|---|---|
| `fivex_job_v1:<license>` | job id or empty |
| `fivex_job_pay_v1:<license>` | integer dollars |

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
```

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
