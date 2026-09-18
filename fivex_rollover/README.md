# fivex_rollover

Standalone FiveM resource (v1.0.1). When a vehicle tire **bursts**, there is a configurable chance the vehicle tips / rolls like a high-speed blowout.

## Behaviour

- Detects intact → burst transitions via `IsVehicleTyreBurst` per wheel.
- Chance scales with speed (`SpeedMin` → `SpeedFull`).
- Impulse applied only by the client that has network control of the entity.
- Player vehicles with bulletproof tires (`GetVehicleTyresCanBurst` == false) are skipped.
- NPC vehicles are always eligible (when `NpcVehicles` is true).
- Per-vehicle cooldown prevents multi-tire pops from stacking flips.
- Never force-bursts tires — only reacts when the game already burst them.

## Install

1. Drop `fivex_rollover` into your resources folder (e.g. `resources/[fivex]/`).
2. `ensure fivex_rollover` in `server.cfg` (or start via txAdmin).
3. Restart or `ensure` the resource.

No framework, NUI, or money systems required.

## Config highlights

| Key | Default | Notes |
|-----|---------|-------|
| `BaseChance` | `0.05` | Chance near `SpeedMin` |
| `SpeedMin` | `10.0` m/s | Below this: no attempt |
| `SpeedFull` | `25.0` m/s | Full chance / force |
| `ChanceAtFullSpeed` | `0.40` | At highway speed |
| `ForceScale` / `TorqueScale` | `12` / `18` | Impulse strength |
| `CooldownMs` | `8000` | Per netId |
| `Debug` | `false` | Console prints |

## Ownership & bulletproof

- **Ownership:** Only the client with `NetworkHasControlOfEntity` (or a brief `NetworkRequestControlOfEntity`) applies `ApplyForceToEntity` / angular velocity. Prevents duplicate impulses across clients.
- **Bulletproof:** If `RespectBulletproof` and the vehicle is player-relevant, `GetVehicleTyresCanBurst(veh) == false` → skip. Tires are never forcibly popped.

## License

FiveX / server use.


## 1.0.1
- Fixed GetEntityMatrix unpack (vectors, not floats) that nil'd rY and aborted flips.
- Real tip: SetEntityRotation past tipping point + angular kick + relative lift.
