# FiveX Appearance

Standalone FiveM character creator and clothing / barber / tattoo shops. No QBCore, ESX, Qbox, or ox_lib. Vanilla CFX (spawnmanager). Player-facing — this is not an admin menu.

The **client is untrusted**. Appearance is keyed by the player's `license:` identifier on the server. Models, numbers, and tattoos are validated before they are saved. The Discord webhook URL is never sent to NUI.

## Install

1. Copy `fivex_appearance` into your server `resources` folder.
2. Grant ACE **before** `ensure` (only needed for `/appearance` creator reopen).
3. Start **after** spawnmanager:

```
ensure spawnmanager
ensure fivex_appearance
```

4. Optional: `exec permissions.cfg` after copying `permissions.cfg.example`.

Players need **no ACE** for first-join creator or shops.

## Commands & keybind

| Input | Default | Who |
| --- | --- | --- |
| Key | `F6` (`RegisterKeyMapping` — rebind in GTA Settings → Key Bindings → FiveM) | Everyone (clothing shop mode) |
| Chat | `/clothing` | Everyone (clothing shop mode) |
| Chat | `/appearance` | ACE `fivex_appearance.creator` (or parent). First-join creator does **not** need ACE. |

`ESC` in a shop reverts unsaved preview and closes. First-join creator ignores `ESC` until Save. ACE reopen of the creator: `ESC` reverts and closes.

## Modes (one NUI)

Right-side dock (~380px) so the ped stays visible on the left. Live preview on every change; persist only on Save.

| Mode | Tabs | How to open |
| --- | --- | --- |
| **creator** | Identity, Heritage, Face, Hair, Overlays, Eyes, Clothing, Props, Tattoos, Outfits | First join if no saved skin (`Config.ForceCreatorOnFirstJoin`). `/appearance` if ACE. |
| **clothing** | Clothing, Props, Outfits | Marker + E, `/clothing`, F6 |
| **barber** | Hair, Overlays (beard / eyebrows / makeup / lipstick), Eyes, Outfits | Marker + E |
| **tattoo** | Tattoos, Outfits | Marker + E |

Sex change is **creator-only**. Switching sex applies a modest default outfit (not underwear).

## ACE

Default deny for creator reopen. Parent grants everything:

```
add_ace group.admin fivex_appearance allow
add_principal identifier.license:YOUR_LICENSE_HASH group.admin
```

| Node | Purpose |
| --- | --- |
| `fivex_appearance` | Parent — all of the below |
| `fivex_appearance.creator` | Reopen the full creator with `/appearance` |
| `fivex_appearance.staff` | Reserved (staff-remote-set is **not** implemented in v1) |

## Persistence (MySQL via oxmysql)

Requires **oxmysql** (`ensure oxmysql` before this resource). Tables are created on first start, and existing KVP data is imported once (the KVP entries are left untouched).

| Table | Key → value |
| --- | --- |
| `fivex_appearance_skin` | `license` → `appearance` JSON |
| `fivex_appearance_outfits` | `license` → `outfits`: `{ name, skin }[]` — max 16, name clamped to 24 chars |

If the connecting player has no license, they can preview in-session but cannot save (they are notified).

Saves are rate-limited: **max 8 / 10 seconds**.

### On join

1. Server loads skin by license.
2. Client applies after spawnmanager spawn (`playerSpawned`) and retries at 500 ms and 1500 ms so clothing sticks.
3. If no skin and `Config.ForceCreatorOnFirstJoin`, the creator opens forced until Save.

### Outfits

List, save current as a named outfit, load, delete. **Load applies the outfit and saves it as the active skin** (one click). Overwrite / load / delete are confirmed in NUI.

## Appearance table

```
{
  model = 'mp_m_freemode_01' | 'mp_f_freemode_01',
  headBlend = { shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird, shapeMix, skinMix, thirdMix },
  faceFeatures = { [0]=n, ... [19]=n },  -- -1.0 .. 1.0
  overlays = { [id] = { index, opacity, colourType, colour, secondColour } },
  hair = { style, texture, color, highlight },
  eyeColor = n,
  components = { [id] = { drawable, texture } },  -- 0-11
  props = { [id] = { drawable, texture } },       -- 0,1,2,6,7; drawable -1 = none
  tattoos = { { collection, overlay }, ... }      -- names resolved against data/tattoos.lua
}
```

Applied with: `SetPlayerModel`, `SetPedDefaultComponentVariation`, `SetPedHeadBlendData`, `SetPedFaceFeature`, `SetPedHeadOverlay`, `SetPedHeadOverlayColor`, `SetPedHairColor`, `SetPedEyeColor`, `SetPedComponentVariation`, `ClearAllPedProps`, `SetPedPropIndex`, `ClearPedDecorations`, `AddPedDecorationFromHashes`.

Hair is **component 2 and** `SetPedHairColor`. Overlay colour types: 0 none, 1 hair palette, 2 makeup palette. Tattoos always `ClearPedDecorations` first. Model load uses `RequestModel` with a timeout.

Freemode models only (`mp_m_freemode_01` / `mp_f_freemode_01`). No animals, no other peds.

## Clothing enumeration

There is **no** 10k static clothing dump. When a component or prop is selected, the client enumerates `GetNumberOfPedDrawableVariations` / `GetNumberOfPedTextureVariations` (and the prop equivalents) and sends counts to NUI. Empty texture counts are skipped. `Config.Blacklist[model][component] = { drawable ids }` hides broken slots (empty table with comments by default).

## Tattoos

`data/tattoos.lua` — curated vanilla list grouped by zone (head, torso, left_arm, right_arm, left_leg, right_leg). Collection and overlay are joaat name strings. NUI: zone filter, toggle, clear zone, clear all. Server rejects unknown pairs.

## Shops

Configured in `config.lua`. Distance 2.0 interact, 8.0 draw. Blips on/off via `Config.BlipsEnabled`.

| Type | Locations |
| --- | --- |
| Clothing (3) | Ponsonby (Rockford), Suburban (Hawick), Binco (Strawberry) |
| Barber (2) | Hair on Hawick, Herr Kutz (Davis) |
| Tattoo (2) | Los Santos Tattoos (Vespucci), Blazing Tattoo (Vinewood) |

No money, items, jobs, or paid shops.

## Config

Edit `config.lua`:

- Locale, commands, F6 keybind
- Discord webhook (server-only; empty = off) — logs saves and outfit mutations
- `ForceCreatorOnFirstJoin`
- Shop coordinates, blips, marker, distances
- Blacklists
- Rate limit, max outfits / name length, max tattoos
- Camera zoom / pitch / DOF

## Camera

Scripted cam while the UI is open: radar/HUD hidden, ped frozen, facing the camera. Drag on the left (not over the panel) to orbit; scroll to zoom. Face / Torso / Legs / Full presets. Space flips the ped 180° (camera orbit stays). Light DOF — the world is not blacked out.

## Security

- Identity is never trusted from the client. Rows are keyed by the server `license:` identifier.
- Model whitelist, clamped numbers, tattoos against the catalog.
- No event that sets another player's appearance (staff-remote-set skipped in v1).
- NUI callbacks are ignored unless the local UI is open.
- Webhook URL is server-only.

## Exports (client)

```
exports.fivex_appearance:getAppearance()
exports.fivex_appearance:applyAppearance(data)
```

## Files

```
fivex_appearance/
  fxmanifest.lua
  config.lua
  README.md
  permissions.cfg.example
  locales/en.lua
  data/tattoos.lua
  data/defaults.lua
  client/main.lua
  client/appearance.lua
  client/camera.lua
  server/main.lua
  html/index.html
  html/style.css
  html/app.js
```
