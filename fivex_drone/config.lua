Config = {}

Config.Locale = 'en'
Config.Debug = false            -- print deploy / crash / network steps in F8
Config.Command = 'fpv'          -- /fpv: deploy, or reconnect to your drone if it is still out there
Config.Ace = false              -- false = everyone may fly; or an ACE name, e.g. 'fivex_drone'
Config.DeployCooldown = 3000    -- ms between deploys

-- The drone everyone sees. Any small prop works; yawOffset turns the model if its nose is not +Y.
Config.Drone = {
    model = 'ch_prop_arcade_drone_01a',
    yawOffset = 0.0,                    -- degrees
    offset = vector3(0.0, 0.0, 0.0),    -- model pivot → drone centre, in drone space
    radius = 0.18,                      -- collision sphere (m)
    lodDistance = 400,
}

-- What the pilot holds while flying, held in both hands at chest height (prop = false for none).
-- First model that exists is used: the RC transmitter needs game build 3407+, else the RC handset.
-- Tune pos / rot live with /fpvprop x y z rx ry rz while flying, then paste the printed line here.
Config.Pilot = {
    prop = { 'm24_2_prop_m42_rc_controller_01a', 'p_rc_handset' },
    bone = 60309,
    pos = vector3(0.03, 0.002, 0.0),
    rot = vector3(10.0, 160.0, 0.0),
    dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base',
    anim = 'base',
    flags = 49,
}

-- 5-inch freestyle quad. All SI units.
Config.Physics = {
    mass = 0.65,              -- kg (with battery)
    twr = 5.0,                -- thrust-to-weight on a full battery
    thrustExpo = 1.5,         -- thrust = throttle ^ expo (props: thrust ~ rpm²) → hover ≈ 34 %
    idle = 0.05,              -- motor idle while armed (airmode)
    motorResponse = 0.03,     -- s, motor spool time constant
    rateResponse = 0.045,     -- s, how fast the flight controller reaches the commanded rates
    drag = vector3(0.016, 0.015, 0.030), -- quadratic drag per body axis: side, forward, top/bottom
    tumbleDamping = 0.6,      -- 1/s, angular damping while disarmed / tumbling
    groundEffect = 0.25,      -- extra thrust right above the ground
    groundEffectHeight = 0.5, -- m
    propWash = { speed = 3.0, strength = 1.1 }, -- descending into your own wash shakes the quad
    wind = 0.45,              -- share of GTA's wind that pushes the drone
    restitution = 0.25,       -- bounce
    friction = 0.35,          -- scrape along surfaces
    impactSpin = 1.6,         -- tumble added per m/s of impact
}

-- Betaflight "Actual" rates (deg/s).
Config.Rates = {
    roll  = { center = 180, max = 640, expo = 0.50 },
    pitch = { center = 180, max = 640, expo = 0.50 },
    yaw   = { center = 160, max = 420, expo = 0.30 },
}

-- Angle (self-level) mode.
Config.Angle = { maxAngle = 55.0, strength = 7.0 }
Config.DefaultMode = 'angle' -- 'angle' (self-level, easier) or 'acro' (real FPV)

-- 4S 1300 mAh LiPo. Off by default (infinite flight). Set enabled = true for drain, voltage sag and
-- weaker punch as the pack empties (~4 min cruising); the OSD then shows voltage and mAh used.
Config.Battery = {
    enabled = false,
    cells = 4,
    capacity = 1300,     -- mAh
    maxAmps = 110,       -- full throttle draw
    idleAmps = 1.5,
    standbyAmps = 0.4,   -- disarmed (VTX + FC)
    resistance = 0.025,  -- pack internal resistance (Ω) → voltage sag under load
    warnCell = 3.5,      -- LOW BATTERY (per cell, under load)
    criticalCell = 3.3,  -- BATTERY CRITICAL
}

-- Impact speed (m/s, into the surface) that disarms / destroys the drone.
Config.Crash = { disarmSpeed = 9.0, destroySpeed = 20.0 }

-- Analog video + control link. Walls and buildings between pilot and drone eat range.
Config.Signal = {
    range = 650.0,           -- m, link lost (failsafe → drone drops)
    noiseStart = 0.55,       -- video static starts at this share of range
    obstructedFactor = 2.5,  -- no line of sight = counts as this much farther away
}

Config.Camera = {
    fov = 105.0,
    tilts = { 0, 10, 20, 30, 40 }, -- FPV camera uptilt presets (degrees), cycle in flight
    defaultTilt = 3,
    offset = vector3(0.0, 0.08, 0.03),
    vibration = 0.12,              -- degrees of motor jitter at full throttle
}

-- Keyboard + mouse: W/S throttle, Space punch, Ctrl cut, A/D yaw, mouse or arrows pitch/roll.
Config.Keyboard = {
    throttleRate = 0.7,      -- throttle per second while W / S is held
    mouseSensitivity = 10.0,
    mouseRecenter = 5.0,     -- mouse stick springs back to centre (1/s)
    arrowRate = 4.0,
    invertMouseY = false,
}

-- Gamepad (Mode 2, like a real transmitter): left stick up/down throttle, left stick left/right yaw,
-- right stick pitch/roll, RB arm, LB mode, D-pad up tilt, B exit.
-- Throttle: full down = 0 %, centre = centreThrottle, full up = 100 % (0.5 = linear, like a real
-- transmitter; ~0.32 makes a released stick roughly hover). After arming, throttle stays at idle until
-- you first push the stick up.
Config.Gamepad = { deadzone = 0.05, centreThrottle = 0.5 }

-- Keyboard defaults; players can rebind in Settings → Key Bindings → FiveM.
Config.Keys = { arm = 'X', mode = 'R', tilt = 'C', exit = 'BACK', cut = 'LCONTROL' }

Config.Sound = {
    volume = 0.6,
    onboard = 0.5,       -- your own drone while in the goggles
    refDistance = 6.0,   -- m, half volume
    rolloff = 1.5,
    maxDistance = 220.0, -- m, inaudible beyond
    idleRpm = 5000,
    maxRpm = 28000,
    blades = 2,
}

-- Small LED everyone can see (handy at night).
Config.Led = { enabled = true, color = { 0, 190, 255 }, range = 1.8, intensity = 3.0 }

Config.Net = {
    sendRate = 15,           -- state updates per second while the drone moves
    streamDistance = 350.0,  -- players within this distance of a drone see and hear it
}

Config.Pickup = { distance = 2.0 }

-- Map blip on your own drone (only you see it).
Config.Blip = { enabled = true, sprite = 627, colour = 5, scale = 0.8 } -- 627 = radar_bat_drone

-- Bobbing marker over your own drone while it lies still within this distance (only you see it).
Config.Marker = { enabled = true, distance = 40.0, color = { 255, 210, 0, 200 } }

-- Drone stuck where you can't reach it (roof, tree, water, out of range)? Run /fpv twice within this
-- many seconds to leave it behind and unpack a new one. false = must always be picked up.
Config.Abandon = 6

-- Lost-model buzzer: the drone beeps (audible to everyone nearby) while it lies still and nobody flies it.
Config.Beeper = false

-- Kamikaze mode: /kamikaze (or K / D-pad down) toggles it. While on, any impact that would crash the
-- drone — or getting shot down — makes it explode instead (credited to the pilot). The drone is used up.
Config.Kamikaze = {
    enabled = true,
    ace = false,              -- false = everyone; or an ACE name, e.g. 'fivex_drone.kamikaze'
    command = 'kamikaze',
    key = 'K',
    explosion = 4,            -- GTA explosion type (4 = rocket, 2 = sticky bomb, 0 = grenade, 7 = car)
    damage = 1.0,             -- damage scale
    shake = 1.0,              -- camera shake for people nearby
    ledColor = { 255, 30, 30 },
}

-- Other players can shoot drones down.
Config.Shootable = true
Config.ShotRange = 200.0
Config.HitRadius = 0.35
