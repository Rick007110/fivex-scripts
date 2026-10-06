-- FPV quad flight model. Rigid body with thrust along body up, per-axis quadratic drag, a rate
-- controller (acro) or self-level (angle), motor spool, LiPo sag, ground effect and prop wash.
-- Collisions are swept rays against the GTA world; impacts bounce, tumble, disarm or destroy.
Flight = {}

local P, B, R = Config.Physics, Config.Battery, Config.Rates
local G = 9.81
local abs, exp, sqrt, rad, tan, random = math.abs, math.exp, math.sqrt, math.rad, math.tan, math.random
local clamp, qrot, qrotInv = FD.clamp, FD.qrot, FD.qrotInv

local RAY_FLAGS = 1 + 2 + 4 + 8 + 16 + 256 -- map, vehicles, peds, ragdolls, objects, foliage

function Flight.new(x, y, z, heading)
    local qw, qx, qy, qz = FD.qaxis(0, 0, 1, rad(heading or 0.0))
    return {
        px = x, py = y, pz = z, vx = 0.0, vy = 0.0, vz = 0.0,
        qw = qw, qx = qx, qy = qy, qz = qz,
        wx = 0.0, wy = 0.0, wz = 0.0,  -- body rates (rad/s): pitch, roll, yaw
        motor = 0.0,                   -- average motor output 0..1
        armed = false, broken = false, battDead = false,
        contact = true, turtle = false, wet = false,
        height = 0.0, groundZ = z,
        mah = 0.0, amps = 0.0, vcell = 4.2,
        windX = 0.0, windY = 0.0,
        activity = 0.0,                -- how hard the sticks are worked (motor desync for sound)
    }
end

-- Betaflight "Actual" rates → rad/s
local function rate(x, r)
    local ax = abs(x)
    local expof = ax * ((x ^ 5) * r.expo + x * (1 - r.expo))
    return rad(x * r.center + math.max(0, r.max - r.center) * expof)
end

-- resting LiPo cell voltage by state of charge
local CURVE = { { 0.0, 3.30 }, { 0.05, 3.45 }, { 0.1, 3.60 }, { 0.2, 3.70 }, { 0.5, 3.80 }, { 0.9, 4.05 }, { 1.0, 4.20 } }
local function restCell(soc)
    if soc <= 0 then return 3.30 + soc * 6.0 end -- falls off a cliff past empty
    for i = 2, #CURVE do
        local a, b = CURVE[i - 1], CURVE[i]
        if soc <= b[1] then return a[2] + (b[2] - a[2]) * (soc - a[1]) / (b[1] - a[1]) end
    end
    return 4.2
end

function Flight.live(s)
    return s.armed and not s.broken and not s.battDead and not s.wet
end

function Flight.soc(s)
    return 1 - s.mah / B.capacity
end

function Flight.step(s, inp, dt)
    local live = Flight.live(s)
    local bx, by, bz = qrotInv(s.qw, s.qx, s.qy, s.qz, 0, 0, 1) -- world up seen from the body
    s.turtle = live and s.contact and bz < -0.15

    -- flight controller: commanded body rates
    if live then
        local tx, ty, tz
        if s.turtle then
            -- turtle mode: motors spin backwards to flip the quad over
            tx, ty, tz = -inp.pitch * 6.0, inp.roll * 6.0, 0.0
            if abs(inp.roll) + abs(inp.pitch) < 0.15 then ty = inp.thr * 7.0 end
        elseif inp.mode == 'angle' then
            local a = rad(Config.Angle.maxAngle)
            local dx, dy, dz = -tan(inp.roll * a), -tan(inp.pitch * a), 1.0
            local l = sqrt(dx * dx + dy * dy + dz * dz)
            dx, dy, dz = dx / l, dy / l, dz / l
            -- rotate by the full error angle (not its sine), so an inverted quad still rights itself
            local k = Config.Angle.strength
            local cx, cy = dy * bz - dz * by, dz * bx - dx * bz
            local sn = sqrt(cx * cx + cy * cy)
            local err = math.atan(sn, dx * bx + dy * by + dz * bz)
            if sn < 1e-4 then
                tx, ty = 0.0, (err > 1.5) and 10.0 or 0.0 -- exactly upside down: roll out
            else
                tx = clamp(cx / sn * err * k, -10, 10)
                ty = clamp(cy / sn * err * k, -10, 10)
            end
            tz = -rate(inp.yaw, R.yaw)
        else
            tx, ty, tz = -rate(inp.pitch, R.pitch), rate(inp.roll, R.roll), -rate(inp.yaw, R.yaw)
        end
        local a = 1 - exp(-dt / P.rateResponse)
        s.wx = s.wx + (tx - s.wx) * a
        s.wy = s.wy + (ty - s.wy) * a
        s.wz = s.wz + (tz - s.wz) * a
        s.activity = s.activity + ((abs(inp.roll) + abs(inp.pitch) + abs(inp.yaw)) / 3 - s.activity) * a
    else
        local d = exp(-dt * P.tumbleDamping)
        s.wx, s.wy, s.wz = s.wx * d, s.wy * d, s.wz * d
        s.activity = s.activity * d
    end

    -- motors
    local cmd = 0.0
    if live then
        cmd = s.turtle and inp.thr * 0.6 or (P.idle + (1 - P.idle) * inp.thr)
    end
    s.motor = s.motor + (cmd - s.motor) * (1 - exp(-dt / P.motorResponse))
    local out = s.motor ^ P.thrustExpo

    -- battery: draw → mAh used → sagging voltage → less punch (off = infinite, always full power)
    local punch = 1.0
    if B.enabled then
        s.amps = live and (B.idleAmps + B.maxAmps * out ^ 1.3) or B.standbyAmps
        s.mah = s.mah + s.amps * dt / 3.6
        s.vcell = restCell(Flight.soc(s)) - s.amps * B.resistance / B.cells
        if Flight.soc(s) < -0.08 then s.battDead = true end
        punch = clamp(s.vcell / 4.2, 0, 1) ^ 2
    end

    -- orientation
    s.qw, s.qx, s.qy, s.qz = FD.qintegrate(s.qw, s.qx, s.qy, s.qz, s.wx, s.wy, s.wz, dt)
    local q1, q2, q3, q4 = s.qw, s.qx, s.qy, s.qz
    local ux, uy, uz = qrot(q1, q2, q3, q4, 0, 0, 1)

    -- thrust (+ ground effect)
    local thrust = 0.0
    if not s.turtle then
        local ge = 1 + P.groundEffect * clamp(1 - (s.height - Config.Drone.radius) / P.groundEffectHeight, 0, 1)
        thrust = P.mass * G * P.twr * out * punch * ge
    end

    -- drag on air-relative velocity, per body axis
    local rx, ry, rz = s.vx - s.windX, s.vy - s.windY, s.vz
    local lx, ly, lz = qrotInv(q1, q2, q3, q4, rx, ry, rz)
    local D = P.drag
    local fx, fy, fz = qrot(q1, q2, q3, q4, -D.x * lx * abs(lx), -D.y * ly * abs(ly), -D.z * lz * abs(lz))

    -- prop wash: sinking into your own downwash shakes the quad
    if live and s.motor > 0.2 and lz < -P.propWash.speed then
        local k = (-lz - P.propWash.speed) * P.propWash.strength * sqrt(dt) * 0.6 -- random walk, step-size independent
        s.wx = s.wx + (random() * 2 - 1) * k
        s.wy = s.wy + (random() * 2 - 1) * k
    end

    local m = P.mass
    s.vx = s.vx + (ux * thrust + fx) / m * dt
    s.vy = s.vy + (uy * thrust + fy) / m * dt
    s.vz = s.vz + ((uz * thrust + fz) / m - G) * dt
    s.px = s.px + s.vx * dt
    s.py = s.py + s.vy * dt
    s.pz = s.pz + s.vz * dt
end

local function ray(x1, y1, z1, x2, y2, z2, ignore)
    local h = StartExpensiveSynchronousShapeTestLosProbe(x1, y1, z1, x2, y2, z2, RAY_FLAGS, ignore or 0, 7)
    local _, hit, pos, normal, ent = GetShapeTestResult(h)
    if hit == true or hit == 1 then return pos, normal, ent end
    return nil
end
Flight.ray = ray

-- Sweep from the previous position to the new one. Returns 'bump' | 'crash' | 'destroyed', impact speed.
function Flight.collide(s, ox, oy, oz, ignore)
    local dx, dy, dz = s.px - ox, s.py - oy, s.pz - oz
    local len = sqrt(dx * dx + dy * dy + dz * dz)
    if len < 1e-4 then return nil end
    dx, dy, dz = dx / len, dy / len, dz / len
    local r = Config.Drone.radius
    local hit, n = ray(ox, oy, oz, s.px + dx * r, s.py + dy * r, s.pz + dz * r, ignore)
    if not hit then return nil end

    local nx, ny, nz = n.x, n.y, n.z
    local nl = sqrt(nx * nx + ny * ny + nz * nz)
    if nl < 1e-3 then nx, ny, nz = -dx, -dy, -dz else nx, ny, nz = nx / nl, ny / nl, nz / nl end
    -- back off along the path until the sphere just touches the surface (pushing out along the
    -- normal instead makes a resting drone creep down every slope)
    local hx, hy, hz = hit.x - ox, hit.y - oy, hit.z - oz
    local along = sqrt(hx * hx + hy * hy + hz * hz)
    local facing = math.max(-(dx * nx + dy * ny + dz * nz), 0.2)
    local t = math.max(along - r / facing, 0)
    s.px, s.py, s.pz = ox + dx * t, oy + dy * t, oz + dz * t

    local vn = s.vx * nx + s.vy * ny + s.vz * nz
    if vn >= 0 then return nil end
    local impact = -vn
    -- split into normal / tangential, bounce + scrape
    local tx, ty, tz = s.vx - vn * nx, s.vy - vn * ny, s.vz - vn * nz
    local keep = 1 - P.friction
    local bounce = -vn * P.restitution
    s.vx, s.vy, s.vz = tx * keep + nx * bounce, ty * keep + ny * bounce, tz * keep + nz * bounce

    -- props strike → tumble
    local spin = impact * P.impactSpin
    s.wx = s.wx + (random() * 2 - 1) * spin
    s.wy = s.wy + (random() * 2 - 1) * spin
    s.wz = s.wz + (random() * 2 - 1) * spin * 0.5

    if impact >= Config.Crash.destroySpeed then
        s.broken, s.armed = true, false
        return 'destroyed', impact
    elseif impact >= Config.Crash.disarmSpeed then
        s.armed = false
        return 'crash', impact
    elseif impact > 1.2 then
        return 'bump', impact
    end
    return nil
end

-- Ground contact, landing, settling, water.
function Flight.ground(s, inp, dt, ignore)
    local r = Config.Drone.radius
    local hit, n = ray(s.px, s.py, s.pz + 0.05, s.px, s.py, s.pz - 3.0, ignore)
    local nx, ny, nz = 0.0, 0.0, 1.0
    if hit then
        s.groundZ = hit.z
        s.height = s.pz - hit.z
        local nl = sqrt(n.x * n.x + n.y * n.y + n.z * n.z)
        if nl > 1e-3 then nx, ny, nz = n.x / nl, n.y / nl, n.z / nl end
    else
        s.height = 99.0
        -- world collision not streamed in yet: never fall through the map
        local found, gz = GetGroundZFor_3dCoord(s.px, s.py, s.pz + 2.0, false)
        if found and s.pz < gz - 0.5 then s.pz = gz + r; s.vz = 0.0 end
    end

    -- water: drone is done
    local inWater, wz = GetWaterHeight(s.px, s.py, s.pz + 0.5)
    if inWater and s.pz < wz then
        if not s.wet then s.wet, s.armed = true, false end
        s.pz = math.max(s.pz, wz - 0.25)
        s.vx, s.vy, s.vz = s.vx * 0.9, s.vy * 0.9, 0.0
        s.contact = true
        return
    end

    s.contact = hit ~= nil and s.height <= r + 0.03
    if not s.contact then return end

    if s.pz < s.groundZ + r then s.pz = s.groundZ + r end
    if s.vz < 0 then s.vz = 0.0 end
    local grip = (Flight.live(s) and s.motor > 0.3) and 1.5 or 8.0
    local f = exp(-dt * grip)
    s.vx, s.vy = s.vx * f, s.vy * f
    -- static friction: a drone sitting on the ground (disarmed or idling) doesn't slide in the wind
    -- or down gentle slopes; only a real skid (after a crash) keeps sliding until it stops
    if (not Flight.live(s) or s.motor < 0.15) and s.vx * s.vx + s.vy * s.vy < 1.5 * 1.5 then
        s.vx, s.vy = 0.0, 0.0
    end

    -- sitting on the ground: settle flat (or upside down) on the surface
    local flipping = s.turtle and inp.thr > 0.05
    if not flipping and (not Flight.live(s) or s.motor < 0.15) then
        local _, _, uz = qrot(s.qw, s.qx, s.qy, s.qz, 0, 0, 1)
        local sgn = (uz * nz >= -0.05) and 1 or -1
        s.qw, s.qx, s.qy, s.qz = FD.qalignUp(s.qw, s.qx, s.qy, s.qz, nx * sgn, ny * sgn, nz * sgn, 1 - exp(-dt * 8))
        local d = exp(-dt * 10)
        s.wx, s.wy = s.wx * d, s.wy * d
        if not Flight.live(s) then s.wz = s.wz * d end
    end
end

function Flight.speed(s)
    return sqrt(s.vx * s.vx + s.vy * s.vy + s.vz * s.vz)
end
