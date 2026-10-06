# fivex_drone v1.0.0 — FPV drone

Standalone FPV (first-person view) racing / freestyle drone. Vanilla CFX — no QB / ESX / Qbox / ox_lib.
You fly through analog goggles with a Betaflight-style OSD; everyone near the drone sees it fly and
hears its motors.

## Use

`/fpv` — deploy the drone in front of you and put the goggles on. Run it again to take them off, or to
reconnect to your drone while it is within radio range. Walk up to it and press **E** to pack it away
(a map blip and, close by, a marker show where it is).

Drone wrecked or out of range somewhere you can't reach (roof, tree, water)? Run `/fpv` twice within
6 seconds (`Config.Abandon`) to leave it behind and unpack a new one. A drone that still works and is
in range just reconnects, so you can fly it out yourself.

| Keyboard / mouse | Gamepad | |
|---|---|---|
| W / S | left stick up / down | throttle (keyboard throttle stays where you leave it; pad: down 0 %, centre 50 %, up 100 %) |
| Space (hold) | — | punch out (100 %) |
| Left Ctrl | — | throttle cut |
| Mouse / arrow keys | right stick | pitch / roll |
| A / D | left stick X | yaw |
| X | RB | arm / disarm (throttle must be low) |
| R | LB | acro ↔ angle (self-level) |
| C | D-pad up | camera uptilt 0–40° |
| Backspace | B | goggles off |

Left Ctrl / The gamepad uses Mode 2 like a real transmitter: left stick fully down is 0 % throttle, centre 50 %,
fully up 100 % (`Config.Gamepad.centreThrottle`). After arming the throttle stays at idle until you
first push the left stick up.

Left Ctrl / X / R / C / Backspace are rebindable in **Settings → Key Bindings → FiveM**.

## Kamikaze mode

`/kamikaze` toggles it (`/kamikaze on` / `off` also work), or press **K** (rebindable) / D-pad down.
It can be switched any time, even before deploying, and stays on for your next drone. While it is on,
an impact that would crash the drone — or getting shot down — makes it **explode** instead. The blast
is credited to the pilot and everyone sees it; the drone is used up. The goggles show a blinking red
`!! KAMIKAZE !!` and the drone's LED turns red for everyone. Limit it with `Config.Kamikaze.ace` or
switch it off with `Config.Kamikaze.enabled = false`.

## Physics

- Rigid body: thrust along the body's up axis, gravity, quadratic drag per body axis, wind and gusts
  from GTA's weather.
- Flight controller: **acro** (Betaflight "Actual" rates, sticks command rotation speed) or **angle**
  (self-level, max 55°). Motors spool up and down instead of reacting instantly.
- Battery is **off by default** (infinite flight). With `Config.Battery.enabled = true` you fly a 4S
  1300 mAh LiPo: current draw follows throttle, voltage sags under load and as the pack empties, and
  the quad gets weaker. About 4 minutes of cruising; the OSD then shows voltage and mAh used.
- Ground effect, prop wash wobble when you drop into your own downwash, bounce and scrape on walls.
- Crashes: harder than 9 m/s disarms the drone (re-arm and fly on), harder than 20 m/s destroys it.
  Upside down on the ground with throttle = **turtle mode** to flip back over. Water kills it.
- Tested offline: hover ≈ 32 % throttle, full-throttle climb ≈ 80 km/h, ≈ 105 km/h at 55° in angle
  mode (faster in acro).

## Signal

Video and control share one link (650 m by default). Static starts at 55 % of range; buildings or
terrain between you and the drone count as 2.5× the distance. When the link drops, the drone failsafes
and falls. Your drone has a **map blip** only you can see, so you can always find it. Optionally
(`Config.Beeper = true`) a drone lying still with nobody flying it beeps like a real lost-model buzzer.

## Multiplayer

The pilot's client simulates the drone and sends 15 updates a second. The server checks every update
(no teleporting, must stay near the pilot) and relays it only to players within 350 m. Their clients
interpolate the drone smoothly and play its sound with distance, stereo pan and Doppler. Motor sound
is synthesised live (four detuned motors + prop noise), so pitch follows the throttle. Other players
can **shoot drones down**; the server checks the shot.

## Config

Everything is in `config.lua`: model, rates, physics, battery, crash speeds, range, camera FOV/tilt,
controls, sound, LED, network rates. `Config.Ace = 'fivex_drone'` limits flying to an ACE:

```
add_ace group.admin fivex_drone allow
```

## Notes

- While flying, the pilot holds an RC transmitter (`m24_2_prop_m42_rc_controller_01a`, game build
  3407+; falls back to `p_rc_handset`). To adjust how it sits in the hands, run
  `/fpvprop x y z rx ry rz` while flying and paste the printed line into `Config.Pilot`.

- Command is `/fpv`, so it does not clash with `dl_drone` (`/drone`).
- The default model is `ch_prop_arcade_drone_01a`. If you swap the model and it flies sideways, set
  `Config.Drone.yawOffset`.
