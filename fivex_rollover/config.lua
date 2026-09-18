Config = {}

Config.Enabled = true

Config.BaseChance = 0.08
Config.SpeedMin = 12.0
Config.SpeedFull = 28.0
Config.ChanceAtFullSpeed = 0.45

-- Blowout: tip onto the side and settle — NOT a continuous barrel roll.
Config.SideLandDegrees = 78.0  -- land on blown side (~90 = flat on side)
Config.PitchDip = 8.0          -- slight nose-down so it digs into the road
Config.AngularKick = 1.6       -- one short shove (was 5.5 → barrel rolls)
Config.MaxSpin = 2.2           -- damp anything above this after the shove
Config.DampMs = 650            -- how long to bleed excess spin
Config.LiftForce = 4.0
Config.LateralForce = 1.2
Config.SideOffset = 0.7
Config.PreserveSpeed = true

Config.ClassesAllowed = {
    [0] = true, [1] = true, [2] = true, [3] = true, [4] = true,
    [5] = true, [6] = true, [7] = true, [8] = true, [9] = true,
    [10] = true, [11] = true, [12] = true,
    [17] = true, [18] = true, [19] = true, [20] = true, [22] = true,
}

Config.PlayerVehicles = true
Config.NpcVehicles = true
Config.RespectBulletproof = true
Config.RequireNetworkControl = true
Config.ControlRequestTimeoutMs = 400
Config.CooldownMs = 8000
Config.ScanIntervalMs = 100
Config.ScanRadius = 80.0
Config.Debug = false
