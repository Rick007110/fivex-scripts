# fivex_flexa — Flexa (Whiz Mobile)

Standalone **foldable phone** for FiveM (vanilla CFX). No QBCore, ESX, or ox_lib.  
NUI-only by default (no phone prop). Real player **SMS** + **call signaling**; optional **pma-voice**.  
**Whiz UI** is One UI–inspired (foldable dual-pane, dock hinge) — **no Samsung / Galaxy branding** in user-facing strings.

Version: **1.2.1**

## Install

1. Place `fivex_flexa` in your `resources` folder.
2. For **real Camera photos**, also ensure [screenshot-basic](https://github.com/citizenfx/screenshot-basic) **before** Flexa:
   `ensure screenshot-basic` then `ensure fivex_flexa` (after `pma-voice` if you use it).
3. Without screenshot-basic, Camera still works with a stamped placeholder image (F8 warns once).
4. Restart or `ensure fivex_flexa`.

## Keybinds / commands

| Action | Default | Notes |
|--------|---------|--------|
| Open / close | `/flexa` or **F1** | Rebind in FiveM Settings → Key Bindings → FiveM |
| Fold / unfold | `/flexa_fold` or **G** | While open; also the hinge button in the UI |

ESC closes the phone.

## Phone numbers

- Assigned on first identity request: `555-XXXX` (prefix from `Config.PhoneNumberPrefix`).
- Bound to player identifier preference: `license:` → `fivem:` → `steam:`.
- Persisted in resource KVP (`flexa:num:…` / `flexa:id:…`).
- Export: `exports['fivex_flexa']:GetPlayerNumber(src)`.

## SMS

- Threads keyed by sorted number pair; history capped ~100 messages.
- Rate limit: `Config.SmsRateLimitMs` (default 800).
- Max body: `Config.MaxMessageLength` (default 500).
- Server never trusts client `from`.

## Calls

- Signaling: start / accept / reject / end; ringing timeout `Config.CallTimeoutMs` (30s).
- Offline or busy peer → call fails (UI goes to ended).
- Voice: `Config.VoiceBridge = 'auto'|'pma-voice'|'none'`.  
  If `pma-voice` is started, both clients join a call channel (best-effort `pcall`). UI works without voice.

## App Store

Home grid shows **installed apps only**. Core apps cannot be removed.

| Config | Role |
|--------|------|
| `Config.CoreApps` | Always installed (`phone`, `messages`, `settings`, `store`) |
| `Config.AppCatalog` | Full catalog (id, label, icon, color, blurb, category, core?) |
| `Config.DefaultInstalled` | First-run extras (notes, calculator, …) + core forced in |
| `Config.Apps` | Derived home list for backward compat; client overrides from KVP |

**Persistence (v1):** client resource KVP `fivex_flexa:installed` = JSON array of app ids.  
**Later:** optional server sync per license — not required for v1.

### NUI store contract

| Direction | Name | Payload |
|-----------|------|---------|
| NUI → Lua | `storeGetCatalog` | `{}` |
| NUI → Lua | `storeInstall` | `{ id }` |
| NUI → Lua | `storeUninstall` | `{ id }` (rejected if core) |
| Lua → NUI | `setStoreCatalog` | `{ catalog: [{ id, label, icon, color, blurb, category, core, installed }] }` |
| Lua → NUI | `setApps` | installed-only `{ apps: [{ id, label, icon, color }] }` |

### Adding a catalog entry

1. Append to `Config.AppCatalog`:
   ```lua
   { id = 'maps', label = 'Maps', icon = 'maps', color = '#ff9f0a',
     blurb = 'City navigation stub.', category = 'Tools' }
   ```
2. Optionally add the id to `Config.DefaultInstalled` if it should ship pre-installed.
3. Implement UI in `html/app.js` `renderAppBody` (or leave the “Coming soon” stub until UIXpert ships a screen).
4. Restart the resource. Players install it from **Store**.

Labels must stay Flexa / Whiz Mobile — never Samsung, Galaxy, or One UI product names in UI copy.

## Config highlights

```lua
Config.UsePhoneAnim = false   -- NUI-only; no ped anim / no prop
Config.PhoneNumberPrefix = '555'
Config.MaxMessageLength = 500
Config.SmsRateLimitMs = 800
Config.CallTimeoutMs = 30000
Config.VoiceBridge = 'auto'   -- auto|pma-voice|none
Config.NowBarMax = 5
Config.CoreApps = { 'phone', 'messages', 'settings', 'store' }
Config.DefaultInstalled = { 'phone', 'messages', 'settings', 'store', 'notes', 'calculator' }
-- Config.SettingsDefaults — wallpaper, foldAnimMs, sound, Now Bar, brightness, …
```

## NUI contract

See `html/HANDOFF.md` (UIXpert). Client Lua maps server events to those actions exactly, e.g.:

- `callStart` `{ number }`
- `callState` / `incomingCall`
- `smsGetThread` `{ threadId }` (peer number)
- `smsSend` `{ threadId?, number?, text }`
- `setThreads` / `setMessages` / `smsIncoming`
- Store callbacks above (`storeGetCatalog` / `storeInstall` / `storeUninstall`)

## Two-player test

1. Start resource on a server with two clients.
2. Both open Flexa (`/flexa`). Note each number (Settings / dialer context — numbers are assigned server-side; use `exports` or ask the other player).
3. **SMS:** Messages → New → enter `555-XXXX` → send. Peer should see live `smsIncoming`; reopen inbox to confirm persistence.
4. **Call:** Phone dialer → enter peer number → Call. Peer gets incoming UI → Accept / Reject. With `pma-voice`, voice channel joins on accept.
5. **Store:** Open Store → Get Weather (or another non-core app) → confirm it appears on home; Remove → confirm it leaves. Core apps show as Core (not removable).
6. **Camera:** open Camera → shutter → photo appears in Gallery. With screenshot-basic, capture is the game view.
7. **Clock:** status/widget match; Settings → Time format switches 12h/24h.
8. Confirm no prop spawns (`UsePhoneAnim = false`).

## Whiz UI 1.2.1 (Now Bar, Camera, clocks)

Home widgets are Clock + Weather only. Camera writes into Gallery. Clocks default to 24h.

| Feature | Status |
|---------|--------|
| **Now Bar** | Client pushes `{ action: 'nowBar', items }` (max `Config.NowBarMax`). SMS / incoming call / store install feed items. NUI callbacks `nowBarOpen` / `nowBarDismiss`. |
| **Settings persistence** | Full `Config.SettingsDefaults` object via KVP; `setSetting` accepts wallpaper, foldAnimMs, sound, vibration, darkMode, nowBarEnabled, airplane/wifi/bt/location fakes, brightness, textSize. Pushed as `setSettings` on open/ready. |
| **Camera + Gallery** | Shutter → `cameraCapture` → screenshot-basic (or placeholder) → server `gallery/` files + KVP index. Gallery `setGallery` / `galleryDelete`. Cap `Config.MaxGalleryPhotos` (30). |
| **Clock format** | Default `clockFormat = '24h'`. Settings → Display → Time format toggles `24h` / `12h` (status, widgets, Clock app, message times). |

Wallpaper presets: `default` | `dark` | `aurora` | `sunset` | `ocean`. Text size: `small` | `default` | `large`.

```lua
Config.NowBarMax = 5
Config.SettingsDefaults = { wallpaper = 'aurora', foldAnimMs = 560, ... }
```

## Structure


```
fivex_flexa/
  fxmanifest.lua
  config.lua
  locales/en.lua
  client/main.lua
  server/main.lua
  html/          # UIXpert NUI + HANDOFF.md
  gallery/       # saved photos (runtime)
  README.md
```