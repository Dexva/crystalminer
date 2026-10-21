-- The textbook diagram of a point group: a stereographic projection, as drawn in International
-- Tables. Looking down the vertical axis, the copies of one general point are drawn as filled
-- dots (above the equator) or rings (below), with symbols for rotation axes and lines for mirror
-- planes. Pure Lua: returns marks with coordinates u (east) and v (north) in the unit disc.

local P = {}

local function norm(v)
	local l = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	return { v[1] / l, v[2] / l, v[3] / l }
end

local function project(d)
	local z = math.abs(d[3])
	return d[1] / (1 + z), d[2] / (1 + z), d[3] >= 0
end

-- A general direction: not on any symmetry element of any of the 32 point groups.
P.GENERAL = norm({ 0.37, 0.16, 0.91 })

local SYMBOLS = { ["2"] = "2", ["3"] = "3", ["4"] = "4", ["6"] = "6", ["-3"] = "m3", ["-4"] = "m4", ["-6"] = "m6" }

--- Marks for a point group given by its linear operations in CRYSTAL axes (x east, y north,
-- z up). S is the symmetry engine. Each mark: { kind = "above"|"below"|"axis"|"mirror"|"rim",
-- u, v, symbol }.
function P.marks(S, ops)
	local marks, seen = {}, {}
	local function add(m)
		local k = m.kind .. (m.symbol or "") .. string.format("%.3f,%.3f", m.u, m.v)
		if not seen[k] then
			seen[k] = true
			marks[#marks + 1] = m
		end
	end
	local best_fold = {}
	for _, o in ipairs(ops) do
		-- The copy of the general point.
		local w = S.apply_linear(o, P.GENERAL)
		local u, v, up = project(w)
		add({ kind = up and "above" or "below", u = u, v = v })
		local k = S.kind(o)
		if SYMBOLS[k] then
			local sign = (k:sub(1, 1) == "-") and -1 or 1
			local d = S.fixed_direction(o, sign)
			if d then
				d = norm(d)
				if d[3] < 0 or (d[3] == 0 and (d[1] < 0 or (d[1] == 0 and d[2] < 0))) then d = { -d[1], -d[2], -d[3] } end
				local key = string.format("%.3f,%.3f,%.3f", d[1], d[2], d[3])
				-- Keep the highest-order symbol on each axis (a 4-fold axis is also 2-fold).
				local rank = ({ ["2"] = 1, ["3"] = 2, ["-3"] = 3, ["-4"] = 3, ["4"] = 4, ["-6"] = 5, ["6"] = 6 })[k]
				if not best_fold[key] or best_fold[key].rank < rank then best_fold[key] = { rank = rank, symbol = SYMBOLS[k], d = d } end
			end
		elseif k == "m" then
			local n = norm(S.fixed_direction(o, -1))
			if math.abs(n[3]) > 0.999 then
				for t = 0, 359, 6 do add({ kind = "rim", u = math.cos(math.rad(t)), v = math.sin(math.rad(t)) }) end
			else
				-- Two unit vectors in the plane; trace the half of the great circle above the equator.
				local a = norm({ n[2], -n[1], 0 })
				local b = { n[2] * a[3] - n[3] * a[2], n[3] * a[1] - n[1] * a[3], n[1] * a[2] - n[2] * a[1] }
				for t = 0, 180, 6 do
					local c, s = math.cos(math.rad(t)), math.sin(math.rad(t))
					local p = { c * a[1] + s * b[1], c * a[2] + s * b[2], c * a[3] + s * b[3] }
					if p[3] < 0 then p = { -p[1], -p[2], -p[3] } end
					local u, v = project(p)
					add({ kind = "mirror", u = u, v = v })
				end
			end
		end
	end
	for _, f in pairs(best_fold) do
		local u, v = project(f.d)
		add({ kind = "axis", u = u, v = v, symbol = f.symbol })
		if f.d[3] == 0 then add({ kind = "axis", u = -u, v = -v, symbol = f.symbol }) end
	end
	return marks
end

--- Luanti texture string drawing the marks on a disc of size px.
function P.texture(marks, px)
	local r = px / 2 - 6
	local c = px / 2
	local parts = { "[combine:" .. px .. "x" .. px .. ":0,0=crystalminer_st_bg.png" }
	local order = { rim = 1, mirror = 2, axis = 3, below = 4, above = 4 }
	table.sort(marks, function(a, b) return order[a.kind] < order[b.kind] end)
	local sizes = { rim = 3, mirror = 3, below = 9, above = 9, axis = 13 }
	for _, m in ipairs(marks) do
		local tex = m.kind == "axis" and ("crystalminer_st_" .. m.symbol .. ".png") or ("crystalminer_st_" .. m.kind .. ".png")
		local s = sizes[m.kind]
		local x = math.floor(c + r * m.u - s / 2 + 0.5)
		local y = math.floor(c - r * m.v - s / 2 + 0.5)
		parts[#parts + 1] = x .. "," .. y .. "=" .. tex
	end
	return table.concat(parts, ":")
end

return P
