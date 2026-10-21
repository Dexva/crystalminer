-- Where to draw a region's symmetry elements: points along rotation axes, the outline of each
-- mirror plane, the inversion centre, and unit-cell edges for lattices. Pure Lua.
--
-- Luanti nodes are centred on integer positions, so a node at x spans [x - 0.5, x + 0.5] and
-- a doubled coordinate d is at world position d / 2 - 0.5.

-- Loaded with loadfile(...)(symmetry), since mod security does not allow require.
local S = ...

local E = {}

E.COLOURS = {
	axis2 = "#FFD700", axis3 = "#32CD32", axis4 = "#FF3030",
	rotoinversion = "#B040FF", mirror = "#40C0FF", inversion = "#FFFFFF", lattice = "#E0E0E0",
}

--- A small integer direction v with W v = sign v, or nil.
local function fixed_direction(o, sign)
	for a = -1, 1 do
		for b = -1, 1 do
			for c = -1, 1 do
				if a ~= 0 or b ~= 0 or c ~= 0 then
					local w = S.apply_linear(o, { a, b, c })
					if w[1] == sign * a and w[2] == sign * b and w[3] == sign * c then return { a, b, c } end
				end
			end
		end
	end
	return nil
end

--- Treats v and -v as the same line.
local function dir_key(v)
	local s = 1
	for _, x in ipairs(v) do
		if x ~= 0 then
			s = x > 0 and 1 or -1
			break
		end
	end
	return (s * v[1]) .. "," .. (s * v[2]) .. "," .. (s * v[3]), { s * v[1], s * v[2], s * v[3] }
end

local function inside(p, lo, hi)
	return p[1] >= lo[1] and p[1] <= hi[1] and p[2] >= lo[2] and p[2] <= hi[2] and p[3] >= lo[3] and p[3] <= hi[3]
end

local function add(dots, x, y, z, colour)
	dots[#dots + 1] = { pos = { x = x - 0.5, y = y - 0.5, z = z - 0.5 }, colour = colour }
end

local function line(dots, o, v, lo, hi, colour)
	local len = math.sqrt(v[1] ^ 2 + v[2] ^ 2 + v[3] ^ 2)
	for t = -30, 30, 0.75 do
		local p = { o[1] + t * v[1] / len, o[2] + t * v[2] / len, o[3] + t * v[3] / len }
		if inside(p, lo, hi) then add(dots, p[1], p[2], p[3], colour) end
	end
end

--- Where the plane cuts the faces of the box: its outline.
local function plane_outline(dots, o, n, lo, hi)
	for x = lo[1], hi[1], 0.5 do
		for y = lo[2], hi[2], 0.5 do
			for z = lo[3], hi[3], 0.5 do
				local on_face = x == lo[1] or x == hi[1] or y == lo[2] or y == hi[2] or z == lo[3] or z == hi[3]
				if on_face and n[1] * (x - o[1]) + n[2] * (y - o[2]) + n[3] * (z - o[3]) == 0 then
					add(dots, x, y, z, E.COLOURS.mirror)
				end
			end
		end
	end
end

local function lattice(r)
	local dots = {}
	for axis = 1, 3 do
		local a1, a2 = axis % 3 + 1, (axis + 1) % 3 + 1
		for i = 0, r.size[a1], r.cell[a1] do
			for j = 0, r.size[a2], r.cell[a2] do
				for t = 0, r.size[axis] do
					local p = {}
					p[axis], p[a1], p[a2] = r.min[axis] + t, r.min[a1] + i, r.min[a2] + j
					add(dots, p[1], p[2], p[3], E.COLOURS.lattice)
				end
			end
		end
	end
	return dots
end

--- Dots for a region from symmetry.region(). Coordinates are world positions.
function E.dots(r)
	if r.cell then return lattice(r) end
	local lo = { r.min[1], r.min[2], r.min[3] }
	local hi = { lo[1] + r.size[1], lo[2] + r.size[2], lo[3] + r.size[3] }
	local o = { r.origin[1] / 2, r.origin[2] / 2, r.origin[3] / 2 }

	local proper, proper_dir, roto, roto_dir, mirrors, inversion = {}, {}, {}, {}, {}, false
	for _, op in ipairs(r.group.ops) do
		local k = S.kind(op)
		if k == "2" or k == "3" or k == "4" or k == "6" then
			local v = fixed_direction(op, 1)
			if v then
				local key, dir = dir_key(v)
				proper[key] = math.max(proper[key] or 0, tonumber(k))
				proper_dir[key] = dir
			end
		elseif k == "-3" or k == "-4" or k == "-6" then
			local v = fixed_direction(op, -1)
			if v then
				local key, dir = dir_key(v)
				roto[key], roto_dir[key] = true, dir
			end
		elseif k == "m" then
			local v = fixed_direction(op, -1)
			if v then
				local key, dir = dir_key(v)
				mirrors[key] = dir
			end
		elseif k == "-1" then
			inversion = true
		end
	end

	local dots = {}
	for key, fold in pairs(proper) do
		local colour = fold == 4 and E.COLOURS.axis4 or fold == 3 and E.COLOURS.axis3 or E.COLOURS.axis2
		line(dots, o, proper_dir[key], lo, hi, colour)
	end
	for key in pairs(roto) do
		if not proper[key] or proper[key] == 2 then line(dots, o, roto_dir[key], lo, hi, E.COLOURS.rotoinversion) end
	end
	for _, n in pairs(mirrors) do plane_outline(dots, o, n, lo, hi) end
	if inversion then add(dots, o[1], o[2], o[3], E.COLOURS.inversion) end
	return dots
end

return E
