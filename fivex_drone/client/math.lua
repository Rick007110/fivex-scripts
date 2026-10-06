-- Quaternion helpers on plain numbers (w, x, y, z). Body frame: +X right, +Y forward (nose), +Z up.
FD = {}

local sqrt, sin, cos, acos = math.sqrt, math.sin, math.cos, math.acos

function FD.clamp(v, a, b)
    if v < a then return a elseif v > b then return b end
    return v
end

function FD.qmul(aw, ax, ay, az, bw, bx, by, bz)
    return aw * bw - ax * bx - ay * by - az * bz,
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw
end

function FD.qnorm(w, x, y, z)
    local l = sqrt(w * w + x * x + y * y + z * z)
    if l < 1e-9 then return 1.0, 0.0, 0.0, 0.0 end
    return w / l, x / l, y / l, z / l
end

-- rotate (vx, vy, vz) from body to world
function FD.qrot(w, x, y, z, vx, vy, vz)
    local tx = 2 * (y * vz - z * vy)
    local ty = 2 * (z * vx - x * vz)
    local tz = 2 * (x * vy - y * vx)
    return vx + w * tx + (y * tz - z * ty),
        vy + w * ty + (z * tx - x * tz),
        vz + w * tz + (x * ty - y * tx)
end

-- rotate (vx, vy, vz) from world to body
function FD.qrotInv(w, x, y, z, vx, vy, vz)
    return FD.qrot(w, -x, -y, -z, vx, vy, vz)
end

function FD.qaxis(ax, ay, az, angle)
    local h = angle * 0.5
    local s = sin(h)
    return cos(h), ax * s, ay * s, az * s
end

-- advance orientation by body-frame angular velocity (rad/s)
function FD.qintegrate(w, x, y, z, wx, wy, wz, dt)
    local mag = sqrt(wx * wx + wy * wy + wz * wz)
    if mag < 1e-9 then return w, x, y, z end
    local dw, dx, dy, dz = FD.qaxis(wx / mag, wy / mag, wz / mag, mag * dt)
    return FD.qnorm(FD.qmul(w, x, y, z, dw, dx, dy, dz))
end

-- rotate q in world space so its up axis moves toward (tx, ty, tz) by fraction f
function FD.qalignUp(w, x, y, z, tx, ty, tz, f)
    local ux, uy, uz = FD.qrot(w, x, y, z, 0, 0, 1)
    local cx, cy, cz = uy * tz - uz * ty, uz * tx - ux * tz, ux * ty - uy * tx
    local s = sqrt(cx * cx + cy * cy + cz * cz)
    local d = FD.clamp(ux * tx + uy * ty + uz * tz, -1, 1)
    if s < 1e-6 then
        if d > 0 then return w, x, y, z end
        cx, cy, cz, s = 1, 0, 0, 1 -- exactly opposite: flip over the side
    end
    local aw, ax, ay, az = FD.qaxis(cx / s, cy / s, cz / s, acos(d) * f)
    return FD.qnorm(FD.qmul(aw, ax, ay, az, w, x, y, z))
end

function FD.qslerp(aw, ax, ay, az, bw, bx, by, bz, t)
    local d = aw * bw + ax * bx + ay * by + az * bz
    if d < 0 then bw, bx, by, bz, d = -bw, -bx, -by, -bz, -d end
    if d > 0.9995 then
        return FD.qnorm(aw + (bw - aw) * t, ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t)
    end
    local th = acos(d)
    local s = sin(th)
    local ka, kb = sin((1 - t) * th) / s, sin(t * th) / s
    return aw * ka + bw * kb, ax * ka + bx * kb, ay * ka + by * kb, az * ka + bz * kb
end
