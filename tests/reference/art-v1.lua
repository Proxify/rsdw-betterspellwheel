-- Procedural wheel artwork. The mod ships no image files (CurseForge allows
-- only .lua/.txt/.dll/.pak/.utoc/.ucas in Dragonwilds UE4SS mods), so the six
-- textures are drawn here on first launch and cached as PNGs in Assets/.
-- Same geometry as the original tools/build_art.py: annular sectors sharing
-- the model's radii, a centre disc and the tooltip bar. Anti-aliasing comes
-- from analytic distances instead of supersampling.
local A = {}
A.VERSION = '1' -- bump when the drawing changes; cached files are redrawn
local GOLD = {208, 177, 108}
local floor, sqrt, sin, cos, rad, deg, abs, exp, atan =
    math.floor, math.sqrt, math.sin, math.cos, math.rad, math.deg, math.abs, math.exp, math.atan
local function clamp(x) return x < 0 and 0 or (x > 1 and 1 or x) end

-- Premultiplied-free "over" compositing into a float RGBA pixel {r,g,b,a}.
local function over(p, r, g, b, a)
    if a <= 0 then return end
    local da = p[4]
    local oa = a + da * (1 - a)
    if oa <= 0 then return end
    p[1] = (r * a + p[1] * da * (1 - a)) / oa
    p[2] = (g * a + p[2] * da * (1 - a)) / oa
    p[3] = (b * a + p[3] * da * (1 - a)) / oa
    p[4] = oa
end

-- ---------------------------------------------------------------- PNG writer
local crcTable = {}
for i = 0, 255 do
    local c = i
    for _ = 1, 8 do
        if c & 1 == 1 then c = 0xEDB88320 ~ (c >> 1) else c = c >> 1 end
    end
    crcTable[i] = c
end
local function crc32(s, crc)
    crc = (crc or 0) ~ 0xFFFFFFFF
    for i = 1, #s, 4096 do
        local bytes = {s:byte(i, math.min(i + 4095, #s))}
        for j = 1, #bytes do crc = crcTable[(crc ~ bytes[j]) & 0xFF] ~ (crc >> 8) end
    end
    return crc ~ 0xFFFFFFFF
end
local function adler32(s)
    local a, b = 1, 0
    for i = 1, #s, 4096 do
        local bytes = {s:byte(i, math.min(i + 4095, #s))}
        for j = 1, #bytes do a = (a + bytes[j]) % 65521; b = (b + a) % 65521 end
    end
    return (b << 16) | a
end
local function chunk(kind, data)
    return string.pack('>I4', #data) .. kind .. data .. string.pack('>I4', crc32(kind .. data))
end
-- rows: array of raw RGBA row strings (no filter byte).
function A.png(w, h, rows)
    local raw = {}
    for y = 1, h do raw[#raw + 1] = '\0' .. rows[y] end
    raw = table.concat(raw)
    local z = {'\120\1'} -- zlib header, no compression
    local n = #raw
    for i = 1, n, 65535 do
        local len = math.min(65535, n - i + 1)
        local last = (i + len > n) and 1 or 0
        z[#z + 1] = string.pack('<BI2I2', last, len, len ~ 0xFFFF) .. raw:sub(i, i + len - 1)
    end
    z[#z + 1] = string.pack('>I4', adler32(raw))
    return '\137PNG\r\n\26\n'
        .. chunk('IHDR', string.pack('>I4>I4BBBBB', w, h, 8, 6, 0, 0, 0))
        .. chunk('IDAT', table.concat(z)) .. chunk('IEND', '')
end

-- Render width x height with fn(x+.5, y+.5, pixel) over an optional box.
local function render(w, h, fn, box)
    local rows = {}
    local x0, y0, x1, y1 = 0, 0, w - 1, h - 1
    if box then x0, y0, x1, y1 = math.max(0, box[1]), math.max(0, box[2]), math.min(w - 1, box[3]), math.min(h - 1, box[4]) end
    local blank = string.rep('\0', w * 4)
    for y = 0, h - 1 do
        if y < y0 or y > y1 then rows[y + 1] = blank
        else
            local t = {}
            for x = 0, w - 1 do
                if x < x0 or x > x1 then t[#t + 1] = '\0\0\0\0'
                else
                    local p = {0, 0, 0, 0}
                    fn(x + .5, y + .5, p)
                    t[#t + 1] = string.char(floor(clamp(p[1] / 255) * 255 + .5), floor(clamp(p[2] / 255) * 255 + .5),
                        floor(clamp(p[3] / 255) * 255 + .5), floor(clamp(p[4]) * 255 + .5))
                end
            end
            rows[y + 1] = table.concat(t)
        end
    end
    return rows
end

-- ------------------------------------------------------------- wheel sectors
-- Annular sector centred on north, angle degrees wide, radii ri..ro, 848 px.
function A.sector(ri, ro, angle, active, skill)
    local side, c = 848, 424
    local a, b = -angle / 2 + .7, angle / 2 - .7
    local mid = (a + b) / 2
    local half = (b - a) / 2
    local edgeA = active and 240 / 255 or 120 / 255
    local edgeRGB = active and GOLD or {154, 135, 90}
    local edgeW = active and 2 or 1
    local pad = 20
    local sh = sin(rad(half))
    local box = {floor(c - ro * sh - pad), floor(c - ro - pad), floor(c + ro * sh + pad), floor(c - ri * cos(rad(half)) + pad)}
    local rows = render(side, side, function(x, y, p)
        local dx, dy = x - c, y - c
        local r = sqrt(dx * dx + dy * dy)
        local ang = deg(atan(dx, -dy))
        local da = ang - mid
        -- Signed distance (px) to the sector outline; positive inside.
        local side1 = r * sin(rad(half - da))
        local side2 = r * sin(rad(half + da))
        if abs(da) > 90 then side1, side2 = -r, -r end
        local d = math.min(r - ri, ro - r, side1, side2)
        if active then
            -- Soft gold glow around the outline (a 3 px line blurred by ~5 px).
            local g = exp(-(d * d) / (2 * 25)) * 30 / 255
            over(p, GOLD[1], GOLD[2], GOLD[3], g)
        end
        local fill = clamp(d + .5)
        if fill > 0 then
            local t = clamp((r - ri) / (ro - ri))
            local glow = sin(t * math.pi)
            if active then
                over(p, 26 + 24 * glow, 25 + 17 * glow, 20 + 7 * glow, fill * 245 / 255)
            else
                over(p, 15 + glow * 8, 19 + glow * 6, 20 + glow * 3, fill * 228 / 255)
            end
            -- Thin inner arcs 5 px inside each rim.
            if abs(da) <= half - .7 then
                for _, rr in ipairs({ri + 5, ro - 5}) do
                    local cov = clamp(1 - abs(r - rr))
                    if cov > 0 then over(p, GOLD[1], GOLD[2], GOLD[3], cov * (active and 90 or 35) / 255) end
                end
            end
            -- Skill sectors carry a small diamond near the outer rim.
            if skill then
                local u = abs(r - (ro - 15)) / 5
                local v = abs(r * rad(da)) / (r * rad(.9))
                local cov = clamp((1 - (u + v)) * 4)
                if cov > 0 then over(p, GOLD[1], GOLD[2], GOLD[3], cov * (active and 210 or 150) / 255) end
            end
        end
        local stroke = clamp(edgeW / 2 + .5 - abs(d))
        if stroke > 0 then over(p, edgeRGB[1], edgeRGB[2], edgeRGB[3], stroke * edgeA) end
    end, box)
    return A.png(side, side, rows)
end

function A.center()
    local side, c = 848, 424
    local rows = render(side, side, function(x, y, p)
        local dx, dy = x - c, y - c
        local r = sqrt(dx * dx + dy * dy)
        local cov = clamp(122.5 - r)
        if cov > 0 then
            local t = r / 122
            over(p, 12 + 7 * t, 17 + 7 * t, 19 + 5 * t, cov * 245 / 255)
        end
        for _, ring in ipairs({{124, 165}, {119, 75}, {112, 40}}) do
            local rc = clamp(1 - abs(r - ring[1]))
            if rc > 0 then over(p, GOLD[1], GOLD[2], GOLD[3], rc * ring[2] / 255) end
        end
        if r >= 124.5 and r <= 128.5 then
            local ang = deg(atan(dx, -dy)) % 30
            local off = math.min(ang, 30 - ang)
            local tc = clamp(1 - r * rad(off))
            if tc > 0 then over(p, GOLD[1], GOLD[2], GOLD[3], tc * 145 / 255) end
        end
    end, {c - 132, c - 132, c + 132, c + 132})
    return A.png(side, side, rows)
end

-- Tooltip bar: 1560x192 image, artwork x=245..1314 (see layout.lua).
function A.tooltip()
    local W, H = 1560, 192
    local l, r, t, b = 245, 1314, 18, 174
    local m, k = (t + b) / 2, 28
    -- Signed distance to the beveled hexagon (positive inside).
    local function hexDist(x, y)
        local d = math.min(y - t, b - y)
        -- Slanted ends: lines from (l+k,t)->(l,m) and (l,m)->(l+k,b), mirrored right.
        local nx, ny = (m - t), k -- normal of the left upper bevel
        local len = sqrt(nx * nx + ny * ny)
        local cx = x < (l + r) / 2 and x - l or r - x
        local cy = abs(y - m)
        -- distance to the line through (0,0) and (k, m-t) in (cx,cy) space
        local e = (cx * (m - t) - cy * k) / len
        return math.min(d, e)
    end
    local function diamond(x, y, cx, cy, rr)
        return rr - (abs(x - cx) + abs(y - cy))
    end
    local rows = render(W, H, function(x, y, p)
        local d = hexDist(x, y)
        local fill = clamp(d + .5)
        if fill > 0 then
            local i = math.min(25, floor(d / 1.6))
            if i < 1 then over(p, 30, 28, 22, fill * 250 / 255)
            else
                local tt = i / 26
                over(p, 34 - 14 * tt, 36 - 12 * tt, 32 - 10 * tt, fill * 250 / 255)
            end
        end
        local s1 = clamp(2 - abs(d - 3))
        if s1 > 0 then over(p, GOLD[1], GOLD[2], GOLD[3], s1 * 235 / 255) end
        local s2 = clamp(1 - abs(d - 10))
        if s2 > 0 then over(p, GOLD[1], GOLD[2], GOLD[3], s2 * 120 / 255) end
        for _, dm in ipairs({{779.5, 20, 13}, {280, 96, 9}, {1279, 96, 9}}) do
            local dd = diamond(x, y, dm[1], dm[2], dm[3])
            if dd > -1 then
                over(p, 70, 56, 30, clamp(dd + 1))
                local inner = clamp(dd - .5)
                if inner > 0 then over(p, GOLD[1], GOLD[2], GOLD[3], inner * 240 / 255) end
            end
        end
    end, {230, 0, 1330, H - 1})
    return A.png(W, H, rows)
end

A.textures = {
    skill = function() return A.sector(132, 264, 30, false, true) end,
    skill_active = function() return A.sector(132, 264, 30, true, true) end,
    spell = function() return A.sector(282, 408, 20, false, false) end,
    spell_active = function() return A.sector(282, 408, 20, true, false) end,
    center = A.center,
    tooltip = A.tooltip,
}
A.names = {'skill', 'skill_active', 'spell', 'spell_active', 'center', 'tooltip'}

-- Draw any missing or outdated texture into folder/Assets. Returns the number drawn.
function A.ensure(folder)
    local dir = folder .. '/Assets'
    local stampPath = dir .. '/art-version.txt'
    local f = io.open(stampPath, 'r')
    local stamp = f and f:read('a') or ''
    if f then f:close() end
    local fresh = stamp:match('^%s*(.-)%s*$') == A.VERSION
    -- A fresh install has no Assets folder: create it (cmd on Windows).
    local probe = io.open(dir .. '/.probe.txt', 'w')
    if probe then probe:close(); os.remove(dir .. '/.probe.txt')
    elseif package.config:sub(1, 1) == '\\' then os.execute('mkdir "' .. dir:gsub('/', '\\') .. '" 2>nul')
    else os.execute('mkdir -p "' .. dir .. '"') end
    local drawn = 0
    for _, n in ipairs(A.names) do
        local path = dir .. '/' .. n .. '.png'
        local existing = io.open(path, 'rb')
        if existing then existing:close() end
        if not fresh or not existing then
            local data = A.textures[n]()
            local out = assert(io.open(path, 'wb'), 'cannot write ' .. path)
            out:write(data); out:close()
            drawn = drawn + 1
        end
    end
    local s = assert(io.open(stampPath, 'w')); s:write(A.VERSION); s:close()
    return drawn
end

return A
