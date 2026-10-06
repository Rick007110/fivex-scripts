# fivex_flexa — Flexa, the foldable

Version **4.1.0**. Flexa **is sd-phone**. Unfolded, the same phone opens sideways to a
double-width screen (880 instead of 440, same height, anchored bottom-right), using sd-phone's own
foldable body: two home pages side by side, list and detail at once, split view. It is one device,
so everything carries over when you fold or unfold: the open app, lock state, calls, settings, data.
sd-phone remembers which way it was left and comes back out that way.

## Controls

| Action | Default | Notes |
|---|---|---|
| Open / close | **F1** or `/flexa` | |
| Fold / unfold | **G** or `/flexa_fold` | While open. Also the Unfold / Fold button on the phone's right side |

Rebind both in Settings → Key Bindings → FiveM. sd-phone's own keybind is off.

## What it needs (server.cfg order)

```cfg
set mysql_connection_string "mysql://USER:PASSWORD@localhost/play112_theory?charset=utf8mb4"
setr ox:locale "en"
ensure ox_lib
ensure oxmysql
ensure ND_Core        # FiveX compatibility core, NOT the real ND_Core (see resources/ND_Core)
ensure sd-phone-props # includes the foldable phone props (shut and open)
ensure sd-phone
ensure [fivex]        # includes fivex_flexa
```

`ND_Core` here is a small FiveX resource that gives sd-phone the framework it insists on: one
character per player (by license, named after the player), bank balance from **fivex_bank**,
cash in the database. sd-phone creates all of its own tables on first boot.

## Changes made to sd-phone

All marked `[FiveX/Flexa]`. An untouched copy is in `txData/.../backups/`.

| File | Change |
|---|---|
| `configs/phone.lua` | `RequireItem = false` (no phone item needed), `Keybind = ''` |
| `server/main.lua` | honours `RequireItem = false` |
| `client/main.lua` | `exports['sd-phone']:open({ unlocked = true })` (used by `OpenApp`) |
| `bridge/shared/ndcore.lua`, `oxcore.lua` | server detection made truthy (`IsDuplicityVersion() and true`): on this FXServer build the strict `== true` check failed, so sd-phone could never resolve a player |
| `server/apps/init.lua` | logs the reason when an app install is refused |

## Exports (client)

| Export | Does |
|---|---|
| `IsOpen()` / `ClosePhone()` / `Open()` | |
| `IsFolded()` / `SetFolded(bool)` | `SetFolded` only acts while the phone is open |
| `RegisterApp(def)` | v2 App API, kept: the app becomes an sd-phone custom app |
| `UnregisterApp(id)` / `SendAppMessage(id, data)` / `Notify(id, { title, body })` / `OpenApp(id)` | |

Pages built on `html/sdk/flexa-app.js` keep working inside sd-phone: `FlexaApp.post`, `on('init' |
'message' | 'theme' | 'visibility')` and `toast` are translated to sd's app shell. `back()` / `home()`
do nothing there (sd has its own gestures). Inside sd the SDK pads the page so it clears the status
bar and home indicator, and on the unfolded screen centres it in a 720px column (the old unfolded
width). `OpenApp` opens the phone unlocked, straight into the app; an app disappears when its
resource stops.
