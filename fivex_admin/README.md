# fivex_admin

Standalone FiveM staff/admin menu. No QBCore, ESX, or Qbox. ACE-gated. Professional dark NUI with a command palette.

The **client is untrusted**. Every privileged action is a server event that re-checks ACE for that node. A modified client cannot kick, freeze, strip, or ban anyone. Self natives (noclip, godmode) only run after the server confirms ACE, and are re-checked on each toggle.

## Install

1. Copy `fivex_admin` into your server `resources` folder.
2. Add ACE grants (see below) **before** `ensure`.
3. `ensure fivex_admin` in `server.cfg`.
4. Optional: `exec permissions.cfg` after copying `permissions.cfg.example`.

Restart the resource (or the server) after changing ACE.

## Keybind & command

| Input | Default |
| --- | --- |
| Key | `F10` (`RegisterKeyMapping` — rebind in GTA Settings → Key Bindings → FiveM) |
| Chat | `/admin` |

`ESC` or the same key closes the menu. Focus is cleared on resource stop.

Optional: `ox_lib` is used for notifications if started; otherwise native + NUI toasts.

## ACE

Default deny. The parent node grants everything:

```
add_ace group.admin fivex_admin allow
add_principal identifier.license:YOUR_LICENSE_HASH group.admin
```

Individual nodes:

| Node | Purpose |
| --- | --- |
| `fivex_admin.open` | Open the menu |
| `fivex_admin.self` | Self toggles, heal, overlays, copy coords |
| `fivex_admin.players` | Player list, inspect, heal/revive/armor others |
| `fivex_admin.kick` | Kick |
| `fivex_admin.ban` | Ban |
| `fivex_admin.unban` | Unban + ban list |
| `fivex_admin.warn` | Warn |
| `fivex_admin.teleport` | Waypoint, locations, to/bring player |
| `fivex_admin.spectate` | Spectate (server-authorized) |
| `fivex_admin.freeze` | Freeze self or others |
| `fivex_admin.world` | Time, weather, blackout, clear area |
| `fivex_admin.spawn.vehicle` | Spawn vehicles, saved garage |
| `fivex_admin.spawn.weapon` | Give weapons |
| `fivex_admin.dev` | Coord overlay, copy hashes |
| `fivex_admin.resources` | List/restart resources (cannot restart itself) |
| `fivex_admin.audit` | View the in-menu audit log |
| `fivex_admin.notes` | Write/read player notes (players ACE can also read+write) |
| `fivex_admin.spawn.prop` | Spawn/delete catalog props |
| `fivex_admin.spawn.ped` | Spawn/delete catalog peds |
| `fivex_admin` | Parent — all of the above |

Kick, freeze, strip, heal-other, etc. never execute on a target unless the **server** relays the action to that client.

## Config

Edit `config.lua`:

- Keybind, command, locale
- Discord webhook (server-only; empty = off)
- Noclip speeds
- Nearby-vehicle delete radius
- Ban duration presets
- `FreezeOnOpen` (default `false`)
- Max announce length
- Built-in teleport locations

## Bans

Stored with server resource KVP (`GetResourceKvpString` / `SetResourceKvp`). They survive resource restarts. `playerConnecting` drops matching `license` (required) plus `discord` / `fivem` / `steam` when present.

Offline ban (Bans tab) accepts `license:HASH` or a raw hash, optional name/discord, and the same duration presets as live bans. If that license is online they are dropped as well.

Lookup accepts license, discord, or steam and returns matching bans plus notes/warns/mute state for the resolved license.

## Records (server KVP)

| Key | Contents |
| --- | --- |
| `fivex_admin_bans_v1` | Ban list |
| `fivex_admin_notes_v1` | Map license → notes (max 40, 240 chars, newest first) |
| `fivex_admin_warns_v1` | Map license → warns (max 50) |
| `fivex_admin_mutes_v1` | Map license → voice mute |
| `fivex_admin_audit_v1` | Audit array (newest first, cap 250) |

Notes/warns/mutes require a `license` identifier. Kick still works without one.

Voice mute uses `MumbleSetPlayerMuted` and is re-applied on `playerJoining`. Chat mute uses `exports.chat:registerMessageHook` when the `chat` resource is started.

`screenshot-basic` is optional. If it is not started, Screenshot notifies staff and does nothing else. The Discord webhook URL is never sent to NUI or to the target client.

## Entities

Curated prop/ped catalogs (`data/props.lua`, `data/peds.lua`). The server validates the model, then the client spawns after ACK. Nearby delete is ACE-gated, catalog-filtered, capped at 40, and skips player peds.

## Security notes

- No Lua eval, no run-command-as-server, no money/item events.
- Vehicle, weapon, prop, and ped models must exist in the bundled lists; client `IsModelInCdimage` / `IsModelValid` / `IsWeaponValid` is an extra check.
- Kick / ban / announce are rate limited. Offline ban uses the ban limiter. Routing bucket is clamped 0–63.
- Event names are prefixed `fivex_admin:`.
