-- Symmetry engine: operations, groups, the 32 point groups, regions and detection.
--
-- Pure Lua with no Luanti calls, so it can be unit-tested with plain LuaJIT.
--
-- Coordinates are "doubled": a node at integer position x has its centre at 2x+1. Mirror planes
-- and rotation axes can then pass through node centres (odd values) or between nodes (even
-- values), and every operation stays integer-valued.
--
-- An operation is r' = W r + t, with W a 3x3 integer matrix (row-major, 9 entries) and t a vector.

local S = {}

---------------------------------------------------------------------------- operations

local function op(w, t)
	return { w = w, t = t or { 0, 0, 0 } }
end
S.op = op

S.IDENTITY = op({ 1, 0, 0, 0, 1, 0, 0, 0, 1 })

function S.key(o)
	return table.concat(o.w, ",") .. "|" .. table.concat(o.t, ",")
end

--- Parses Jones faithful notation such as "-y,x,z" or "-x,-y,z+1/2".
-- Fractional translations are fractions of cell_doubled (per axis, doubled units). Without
-- cell_doubled any translation is an error.
function S.parse(jones, cell_doubled)
	local parts = {}
	for p in (jones:gsub("%s", ""):lower() .. ","):gmatch("([^,]*),") do parts[#parts + 1] = p end
	if #parts ~= 3 then error("Expected 3 components: " .. jones) end
	local w, t = { 0, 0, 0, 0, 0, 0, 0, 0, 0 }, { 0, 0, 0 }
	for row = 1, 3 do
		local s, i = parts[row], 1
		while i <= #s do
			local sign = 1
			local c = s:sub(i, i)
			if c == "+" or c == "-" then
				sign = (c == "-") and -1 or 1
				i = i + 1
				c = s:sub(i, i)
			end
			if c == "x" or c == "y" or c == "z" then
				local col = ({ x = 1, y = 2, z = 3 })[c]
				w[(row - 1) * 3 + col] = w[(row - 1) * 3 + col] + sign
				i = i + 1
			elseif c:match("%d") then
				local frac = s:match("^[%d/]+", i)
				if not cell_doubled then error("Translation not allowed in a point operation: " .. jones) end
				local num, den = frac:match("^(%d+)/(%d+)$")
				num, den = tonumber(num or frac), tonumber(den or 1)
				local scaled = num * cell_doubled[row]
				if scaled % den ~= 0 then
					error("Translation " .. frac .. " does not land on a whole number of half-nodes")
				end
				t[row] = t[row] + sign * scaled / den
				i = i + #frac
			else
				error("Unexpected '" .. c .. "' in " .. jones)
			end
		end
	end
	return op(w, t)
end

function S.apply(o, r)
	local w, t = o.w, o.t
	return {
		w[1] * r[1] + w[2] * r[2] + w[3] * r[3] + t[1],
		w[4] * r[1] + w[5] * r[2] + w[6] * r[3] + t[2],
		w[7] * r[1] + w[8] * r[2] + w[9] * r[3] + t[3],
	}
end

function S.apply_linear(o, v)
	local w = o.w
	return {
		w[1] * v[1] + w[2] * v[2] + w[3] * v[3],
		w[4] * v[1] + w[5] * v[2] + w[6] * v[3],
		w[7] * v[1] + w[8] * v[2] + w[9] * v[3],
	}
end

--- a ∘ b: apply b first, then a.
function S.compose(a, b)
	local w = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do s = s + a.w[i * 3 + k + 1] * b.w[k * 3 + j + 1] end
			w[i * 3 + j + 1] = s
		end
	end
	local t = S.apply_linear(a, b.t)
	for i = 1, 3 do t[i] = t[i] + a.t[i] end
	return op(w, t)
end

function S.modulo(o, periods)
	return op(o.w, { o.t[1] % periods[1], o.t[2] % periods[2], o.t[3] % periods[3] })
end

function S.linear(o)
	return op(o.w)
end

function S.transpose(o)
	local w = o.w
	return op({ w[1], w[4], w[7], w[2], w[5], w[8], w[3], w[6], w[9] })
end

--- P · o · P⁻¹ for a signed permutation P (whose inverse is its transpose).
function S.conjugate(o, p)
	return S.compose(S.compose(p, o), S.transpose(p))
end

function S.det(o)
	local w = o.w
	return w[1] * (w[5] * w[9] - w[6] * w[8]) - w[2] * (w[4] * w[9] - w[6] * w[7]) + w[3] * (w[4] * w[8] - w[5] * w[7])
end

function S.trace(o)
	return o.w[1] + o.w[5] + o.w[9]
end

function S.is_signed_permutation(o)
	for i = 0, 2 do
		local rn, cn = 0, 0
		for j = 0, 2 do
			local r, c = o.w[i * 3 + j + 1], o.w[j * 3 + i + 1]
			if r ~= 0 then
				if math.abs(r) ~= 1 then return false end
				rn = rn + 1
			end
			if c ~= 0 then cn = cn + 1 end
		end
		if rn ~= 1 or cn ~= 1 then return false end
	end
	return true
end

local PROPER = { [3] = "1", [-1] = "2", [0] = "3", [1] = "4", [2] = "6" }
local IMPROPER = { [-3] = "-1", [1] = "m", [0] = "-3", [-1] = "-4", [-2] = "-6" }

--- Crystallographic kind of the linear part, from determinant and trace:
-- rotations 1, 2, 3, 4, 6 and rotoinversions -1, m, -3, -4, -6. These do not depend on the basis.
function S.kind(o)
	local d, tr = S.det(o), S.trace(o)
	if d == 1 then return PROPER[tr] or "?" end
	if d == -1 then return IMPROPER[tr] or "?" end
	return "?"
end

--- Order of the linear part: the smallest n with W^n = identity (1, 2, 3, 4 or 6).
function S.order(o)
	local p = S.linear(o)
	for n = 1, 6 do
		if S.key(p) == S.key(S.IDENTITY) then return n end
		p = S.compose(S.linear(o), p)
	end
	return nil
end

--- Intrinsic translation (doubled units): the average of t, Wt, ..., W^(n-1)t. It is non-zero
-- exactly for screw rotations and glide reflections (and pure translations), whatever the origin.
-- Returned as n times the average, to stay integer, together with n.
function S.intrinsic(o)
	local n = S.order(o)
	local sum, p = { 0, 0, 0 }, S.linear(S.IDENTITY)
	for _ = 1, n do
		local v = S.apply_linear(p, o.t)
		for a = 1, 3 do sum[a] = sum[a] + v[a] end
		p = S.compose(S.linear(o), p)
	end
	return sum, n
end

--- A small integer direction v with W v = sign v, or nil. For a rotation (sign 1) this is the
-- axis; for a mirror (sign -1) the plane's normal; for a rotoinversion (sign -1) its axis.
function S.fixed_direction(o, sign)
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

local AXIS_NAMES = { ["0,1,0"] = "the vertical axis", ["1,0,0"] = "an east-west axis", ["0,0,1"] = "a north-south axis" }
local PLANE_NAMES = { ["0,1,0"] = "a horizontal plane", ["1,0,0"] = "a vertical plane running north-south",
	["0,0,1"] = "a vertical plane running east-west" }
local TURNS = { ["2"] = "a half turn", ["3"] = "a third of a turn", ["4"] = "a quarter turn", ["6"] = "a sixth of a turn" }

local function dir_name(v, names, fallback)
	local s = 1
	for _, x in ipairs(v) do
		if x ~= 0 then s = x > 0 and 1 or -1 break end
	end
	-- "x == 0 and 0" turns -0 into 0: Lua 5.1 prints -0 as "-0", LuaJIT as "0".
	local function z(x) return x == 0 and 0 or x end
	return names[z(s * v[1]) .. "," .. z(s * v[2]) .. "," .. z(s * v[3])] or fallback
end

--- Plain-words description of an operation in WORLD axes (x east, y up, z north), as used by
-- regions. periods: the region's cell in doubled units, or nil for a point group.
function S.describe_op(o, periods)
	local k = S.kind(o)
	local glide = false
	if periods then
		local sum, n = S.intrinsic(o)
		for a = 1, 3 do
			if (sum[a] / n) % periods[a] ~= 0 then glide = true end
		end
	end
	if k == "1" then return glide and "a translation" or "the block you placed" end
	if k == "-1" then return "an inversion through the centre" end
	if k == "m" then
		local n = S.fixed_direction(o, -1)
		return (glide and "a glide: a reflection in " or "a reflection in ") .. dir_name(n, PLANE_NAMES, "a diagonal plane")
			.. (glide and ", then a slide along it" or "")
	end
	-- The exact angle, so the 90- and 270-degree turns of a 4-fold axis are told apart. Around the
	-- vertical axis it is anticlockwise seen from above; S.turn_angle handles the left-handed axes.
	local FRACTION = { [60] = "a sixth of a turn", [90] = "a quarter turn", [120] = "a third of a turn",
		[180] = "a half turn", [240] = "two thirds of a turn", [270] = "three quarters of a turn", [300] = "five sixths of a turn" }
	local function turn_words(lin, v)
		local deg = S.turn_angle(lin, S.fixed_dir(lin, 1))
		local vertical = dir_name(v, AXIS_NAMES, "") == "the vertical axis"
		if deg == 180 then return "a half turn" end
		return FRACTION[deg] .. " (" .. deg .. " degrees" .. (vertical and ", anticlockwise seen from above" or "") .. ")"
	end
	if TURNS[k] then
		local v = S.fixed_direction(o, 1)
		return (glide and "a screw: " or "") .. turn_words(S.linear(o), v) .. " about " .. dir_name(v, AXIS_NAMES, "a diagonal axis")
			.. (glide and ", then a shift along it" or "")
	end
	local v = S.fixed_direction(o, -1)
	local rot = S.compose(S.op({ -1, 0, 0, 0, -1, 0, 0, 0, -1 }), S.linear(o))
	return turn_words(rot, v) .. " about " .. dir_name(v, AXIS_NAMES, "a diagonal axis") .. ", then an inversion"
end

---------------------------------------------------------------------------- groups

S.MAX_ORDER = 192

--- Closes generators into a group. With periods (doubled units), translations are reduced
-- modulo the cell so the group stays finite.
function S.group(generators, periods)
	local seen, list, queue = {}, {}, {}
	local function add(o)
		local k = S.key(o)
		if seen[k] then return end
		seen[k] = true
		list[#list + 1] = o
		queue[#queue + 1] = o
		if #list > S.MAX_ORDER then error("Generators do not close into a finite group") end
	end
	for _, g in ipairs(generators) do
		if not periods and (g.t[1] ~= 0 or g.t[2] ~= 0 or g.t[3] ~= 0) then
			error("Point-group generator has a translation")
		end
	end
	add(S.IDENTITY)
	local head = 1
	while head <= #queue do
		local a = queue[head]
		head = head + 1
		for _, g in ipairs(generators) do
			local p = S.compose(g, a)
			if periods then p = S.modulo(p, periods) end
			add(p)
		end
	end
	return { ops = list, periods = periods, set = seen }
end

function S.contains(g, o)
	if g.periods then o = S.modulo(o, g.periods) end
	return g.set[S.key(o)] == true
end

function S.fits_grid(g)
	for _, o in ipairs(g.ops) do
		if not S.is_signed_permutation(o) then return false end
	end
	return true
end

--- Count of operations of each kind. Unchanged by a change of basis.
function S.signature(g)
	local sig = {}
	for _, o in ipairs(g.ops) do
		local k = S.kind(o)
		sig[k] = (sig[k] or 0) + 1
	end
	return sig
end

local function sig_key(sig)
	local keys = {}
	for k in pairs(sig) do keys[#keys + 1] = k end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. sig[k] end
	return table.concat(parts, ";")
end
S.signature_key = function(g) return sig_key(S.signature(g)) end

--- Point group of the linear parts (for a periodic group: its crystal class).
function S.linear_parts(g)
	local seen, ops = {}, {}
	for _, o in ipairs(g.ops) do
		local l = S.linear(o)
		local k = S.key(l)
		if not seen[k] then
			seen[k] = true
			ops[#ops + 1] = l
		end
	end
	return { ops = ops, set = seen }
end

---------------------------------------------------------------------------- the 32 point groups

-- Generators in crystal axes with z up. The 25 groups that fit a cubic grid use an orthonormal
-- basis, with trigonal 3-fold axes along the cube diagonal [111]. The 7 hexagonal groups are given
-- in a hexagonal basis (a and b at 120 degrees), the only basis in which they have integer matrices.
S.POINT_GROUPS = {
	{ "1", "triclinic", {} },
	{ "-1", "triclinic", { "-x,-y,-z" } },
	{ "2", "monoclinic", { "-x,-y,z" } },
	{ "m", "monoclinic", { "x,-y,z" } },
	{ "2/m", "monoclinic", { "-x,-y,z", "x,y,-z" } },
	{ "222", "orthorhombic", { "-x,-y,z", "-x,y,-z" } },
	{ "mm2", "orthorhombic", { "x,-y,z", "-x,y,z" } },
	{ "mmm", "orthorhombic", { "-x,y,z", "x,-y,z", "x,y,-z" } },
	{ "4", "tetragonal", { "-y,x,z" } },
	{ "-4", "tetragonal", { "y,-x,-z" } },
	{ "4/m", "tetragonal", { "-y,x,z", "x,y,-z" } },
	{ "422", "tetragonal", { "-y,x,z", "-x,y,-z" } },
	{ "4mm", "tetragonal", { "-y,x,z", "x,-y,z" } },
	{ "-42m", "tetragonal", { "y,-x,-z", "-x,y,-z" } },
	{ "4/mmm", "tetragonal", { "-y,x,z", "x,-y,z", "x,y,-z" } },
	{ "3", "trigonal", { "z,x,y" } },
	{ "-3", "trigonal", { "-z,-x,-y" } },
	{ "32", "trigonal", { "z,x,y", "-y,-x,-z" } },
	{ "3m", "trigonal", { "z,x,y", "y,x,z" } },
	{ "-3m", "trigonal", { "-z,-x,-y", "y,x,z" } },
	{ "23", "cubic", { "z,x,y", "-x,-y,z" } },
	{ "m-3", "cubic", { "z,x,y", "-x,-y,z", "-x,-y,-z" } },
	{ "432", "cubic", { "z,x,y", "-y,x,z" } },
	{ "-43m", "cubic", { "z,x,y", "y,-x,-z" } },
	{ "m-3m", "cubic", { "z,x,y", "-y,x,z", "-x,-y,-z" } },
	{ "6", "hexagonal", { "x-y,x,z" }, true },
	{ "-6", "hexagonal", { "-y,x-y,z", "x,y,-z" }, true },
	{ "6/m", "hexagonal", { "x-y,x,z", "x,y,-z" }, true },
	{ "622", "hexagonal", { "x-y,x,z", "y,x,-z" }, true },
	{ "6mm", "hexagonal", { "x-y,x,z", "-y,-x,z" }, true },
	{ "-62m", "hexagonal", { "-y,x-y,z", "x,y,-z", "-y,-x,z" }, true },
	{ "6/mmm", "hexagonal", { "x-y,x,z", "y,x,-z", "x,y,-z" }, true },
}

local catalog, by_symbol = {}, {}
for _, e in ipairs(S.POINT_GROUPS) do
	local gens = {}
	for i, s in ipairs(e[3]) do gens[i] = S.parse(s) end
	local entry = { symbol = e[1], system = e[2], generators = e[3], hexagonal_basis = e[4] == true }
	entry.group = S.group(gens)
	entry.signature_key = S.signature_key(entry.group)
	catalog[#catalog + 1] = entry
	by_symbol[e[1]] = entry
end
S.catalog = catalog

--- Accepts common spellings: "m3m" for "m-3m", "43m" for "-43m", spaces ignored.
function S.normalize(symbol)
	local s = symbol:gsub("%s", ""):gsub("‾", "-"):gsub("−", "-")
	if by_symbol[s] then return s end
	local bare = s:gsub("%-", "")
	for _, e in ipairs(catalog) do
		if e.symbol:gsub("%-", "") == bare then return e.symbol end
	end
	return s
end

function S.point_group(symbol)
	return by_symbol[S.normalize(symbol)]
end

--- Names a point group from its signature, whatever its orientation.
function S.identify(g)
	local k = sig_key(S.signature(S.linear_parts(g)))
	for _, e in ipairs(catalog) do
		if e.signature_key == k then return e end
	end
	return nil
end

---------------------------------------------------------------------------- the 17 plane groups

-- Generators of the 17 plane groups (two-dimensional space groups), standard settings of
-- International Tables for Crystallography, Vol. A. x and y lie in the floor, z is up and never
-- changes. Fractions are fractions of the cell. Multiplicity: copies of a general point per cell.
-- The 5 hexagonal ones are given in a hexagonal basis (a and b at 120 degrees) by their point
-- operations only; all 5 are symmorphic, so their multiplicity is the order of that point group.
S.PLANE_GROUPS = {
	{ "p1", "oblique", {}, 1 },
	{ "p2", "oblique", { "-x,-y,z" }, 2 },
	{ "pm", "rectangular", { "-x,y,z" }, 2 },
	{ "pg", "rectangular", { "-x,y+1/2,z" }, 2 },
	{ "cm", "rectangular", { "-x,y,z", "x+1/2,y+1/2,z" }, 4 },
	{ "pmm", "rectangular", { "-x,y,z", "x,-y,z" }, 4 },
	{ "pmg", "rectangular", { "-x,-y,z", "-x+1/2,y,z" }, 4 },
	{ "pgg", "rectangular", { "-x,-y,z", "-x+1/2,y+1/2,z" }, 4 },
	{ "cmm", "rectangular", { "-x,-y,z", "-x,y,z", "x+1/2,y+1/2,z" }, 8 },
	{ "p4", "square", { "-y,x,z" }, 4 },
	{ "p4m", "square", { "-y,x,z", "-x,y,z" }, 8 },
	{ "p4g", "square", { "-y,x,z", "-x+1/2,y+1/2,z" }, 8 },
	{ "p3", "hexagonal", { "-y,x-y,z" }, 3, true },
	{ "p3m1", "hexagonal", { "-y,x-y,z", "-y,-x,z" }, 6, true },
	{ "p31m", "hexagonal", { "-y,x-y,z", "y,x,z" }, 6, true },
	{ "p6", "hexagonal", { "x-y,x,z" }, 6, true },
	{ "p6m", "hexagonal", { "x-y,x,z", "-y,-x,z" }, 12, true },
}

S.plane_catalog = {}
for _, e in ipairs(S.PLANE_GROUPS) do
	S.plane_catalog[#S.plane_catalog + 1] = {
		symbol = e[1], system = e[2], generators = e[3], multiplicity = e[4], hexagonal_basis = e[5] == true,
	}
end

--- Group of a plane group on a cell of cx by cy nodes (doubled periods), or of its point
-- operations alone for the hexagonal ones.
function S.plane_group(symbol, cx, cy)
	for _, e in ipairs(S.plane_catalog) do
		if e.symbol == symbol then
			local gens = {}
			if e.hexagonal_basis then
				for i, j in ipairs(e.generators) do gens[i] = S.parse(j) end
				return S.group(gens), e
			end
			local cell = { 2 * cx, 2 * cy, 2 }
			for i, j in ipairs(e.generators) do gens[i] = S.parse(j, cell) end
			return S.group(gens, cell), e
		end
	end
end

---------------------------------------------------------------------------- regions

-- Crystal axes (x east, y north, z up) to Luanti world axes (X east, Y up, Z north).
S.CRYSTAL_TO_WORLD = S.parse("x,z,y")

--- A box in which every placed or removed node is repeated by a symmetry group.
-- spec: { min = {x,y,z}, size = {sx,sy,sz}, anchor = "centre"|"floor", generators = {...} }
--   or  { min = ..., cell = {cx,cy,cz}, counts = {nx,ny,nz}, generators = {...} } for a lattice.
-- Generators are in crystal axes; fractions in a lattice are fractions of the cell.
function S.region(spec)
	local r = { min = spec.min }
	local gens = {}
	if spec.cell then
		local cell, counts = spec.cell, spec.counts
		r.cell = cell
		r.size = { cell[1] * counts[1], cell[2] * counts[2], cell[3] * counts[3] }
		-- Cell lengths along crystal x, y, z = world X, Z, Y.
		local crystal_cell = { 2 * cell[1], 2 * cell[3], 2 * cell[2] }
		local world_cell = { 2 * cell[1], 2 * cell[2], 2 * cell[3] }
		for i, s in ipairs(spec.generators) do
			local g = S.modulo(S.conjugate(S.parse(s, crystal_cell), S.CRYSTAL_TO_WORLD), world_cell)
			for a = 1, 3 do
				if g.t[a] % 2 ~= 0 then
					error("Translation in '" .. s .. "' is not a whole number of nodes; use an even cell length for 1/2")
				end
			end
			gens[i] = g
		end
		r.group = S.group(gens, world_cell)
		r.origin = { 2 * spec.min[1], 2 * spec.min[2], 2 * spec.min[3] }
	else
		r.size = spec.size
		for i, s in ipairs(spec.generators) do gens[i] = S.conjugate(S.parse(s), S.CRYSTAL_TO_WORLD) end
		r.group = S.group(gens)
		r.origin = {}
		for a = 1, 3 do r.origin[a] = 2 * spec.min[a] + spec.size[a] end
		if spec.anchor == "floor" then r.origin[2] = 2 * spec.min[2] + 1 end
	end
	S.validate(r, spec.anchor)
	return r
end

function S.contains_pos(r, x, y, z)
	return x >= r.min[1] and x < r.min[1] + r.size[1]
		and y >= r.min[2] and y < r.min[2] + r.size[2]
		and z >= r.min[3] and z < r.min[3] + r.size[3]
end

local function add_image(out, seen, r, d, shift, o)
	local p = {}
	for a = 1, 3 do
		local v = d[a] + shift[a] + r.origin[a]
		if v % 2 ~= 1 then error("Image is not on a node centre; check region size parity") end
		p[a] = (v - 1) / 2
	end
	local k = p[1] .. "," .. p[2] .. "," .. p[3]
	if not seen[k] then
		seen[k] = true
		out[#out + 1] = { x = p[1], y = p[2], z = p[3], op = o }
	end
end

--- All distinct images of the node at (x, y, z), including itself.
function S.images(r, x, y, z)
	local c = { 2 * x + 1 - r.origin[1], 2 * y + 1 - r.origin[2], 2 * z + 1 - r.origin[3] }
	local out, seen = {}, {}
	if not r.cell then
		for _, o in ipairs(r.group.ops) do add_image(out, seen, r, S.apply(o, c), { 0, 0, 0 }, o) end
	else
		local cd = { 2 * r.cell[1], 2 * r.cell[2], 2 * r.cell[3] }
		local loc = { c[1] % cd[1], c[2] % cd[2], c[3] % cd[3] }
		local n = { r.size[1] / r.cell[1], r.size[2] / r.cell[2], r.size[3] / r.cell[3] }
		for _, o in ipairs(r.group.ops) do
			local p = S.apply(o, loc)
			for a = 1, 3 do p[a] = p[a] % cd[a] end
			for i = 0, n[1] - 1 do
				for j = 0, n[2] - 1 do
					for k = 0, n[3] - 1 do
						add_image(out, seen, r, p, { i * cd[1], j * cd[2], k * cd[3] }, o)
					end
				end
			end
		end
	end
	return out
end

function S.validate(r, anchor)
	if not S.fits_grid(r.group) then error("Group does not fit the node grid") end
	if anchor == "floor" then
		for _, o in ipairs(r.group.ops) do
			if o.w[5] ~= 1 then error("A floor region needs operations that keep up pointing up") end
		end
	end
	-- Every image of every node must land inside the box, so no copy is ever lost. The box is
	-- convex and the operations are affine, so it is enough to check its 8 corner nodes: the image
	-- of the box is the convex hull of the images of its corners. (Lattice regions wrap.)
	if r.cell then return end
	for _, x in ipairs({ 0, r.size[1] - 1 }) do
		for _, y in ipairs({ 0, r.size[2] - 1 }) do
			for _, z in ipairs({ 0, r.size[3] - 1 }) do
				for _, im in ipairs(S.images(r, r.min[1] + x, r.min[2] + y, r.min[3] + z)) do
					if not S.contains_pos(r, im.x, im.y, im.z) then
						error("Image falls outside the region (the box must match the symmetry, e.g. a cube for 3-fold axes)")
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------- detection

--- Exact point symmetry of a build: every one of the 48 cubic-grid operations about the centre
-- of the build's bounding box that maps each node onto a node of the same type. Any grid symmetry
-- of the build maps its bounding box onto itself, so the box centre is the only candidate centre.
-- nodes: map "x,y,z" (doubled coordinates) -> node name. Returns group, catalog entry, centre.
function S.detect(nodes)
	local mn, mx = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	local pts = {}
	for k, name in pairs(nodes) do
		local x, y, z = k:match("^(-?%d+),(-?%d+),(-?%d+)$")
		local p = { tonumber(x), tonumber(y), tonumber(z) }
		for a = 1, 3 do
			mn[a] = math.min(mn[a], p[a])
			mx[a] = math.max(mx[a], p[a])
		end
		pts[#pts + 1] = { p, name }
	end
	if #pts == 0 then error("Nothing to analyse") end
	-- Node centres are odd in doubled coordinates, so min + max is even and the centre is an integer.
	local centre = { (mn[1] + mx[1]) / 2, (mn[2] + mx[2]) / 2, (mn[3] + mx[3]) / 2 }
	local rel = {}
	for _, e in ipairs(pts) do
		rel[(e[1][1] - centre[1]) .. "," .. (e[1][2] - centre[2]) .. "," .. (e[1][3] - centre[3])] = e[2]
	end
	local found = {}
	for _, o in ipairs(by_symbol["m-3m"].group.ops) do
		local ok = true
		for _, e in ipairs(pts) do
			local v = S.apply(o, { e[1][1] - centre[1], e[1][2] - centre[2], e[1][3] - centre[3] })
			if rel[v[1] .. "," .. v[2] .. "," .. v[3]] ~= e[2] then
				ok = false
				break
			end
		end
		if ok then found[#found + 1] = o end
	end
	local g = S.group(found)
	return g, S.identify(g), centre
end

--- Describes a group's operations by kind, e.g. "1 identity, 1 two-fold rotation, 2 mirror reflections."
function S.describe(g)
	local sig = S.signature(g)
	local names = {
		{ "1", "identity", "identity" }, { "2", "two-fold rotation", "two-fold rotations" },
		{ "3", "three-fold rotation", "three-fold rotations" }, { "4", "four-fold rotation", "four-fold rotations" },
		{ "6", "six-fold rotation", "six-fold rotations" }, { "m", "mirror reflection", "mirror reflections" },
		{ "-1", "inversion", "inversions" }, { "-3", "-3 rotoinversion", "-3 rotoinversions" },
		{ "-4", "-4 rotoinversion", "-4 rotoinversions" }, { "-6", "-6 rotoinversion", "-6 rotoinversions" },
	}
	local parts = {}
	for _, n in ipairs(names) do
		local c = sig[n[1]]
		if c then parts[#parts + 1] = c .. " " .. (c == 1 and n[2] or n[3]) end
	end
	return "Operations: " .. table.concat(parts, ", ") .. "."
end

---------------------------------------------------------------------------- words and pictures

--- Smallest integer direction v (|components| <= 1) with W v = sign * v, normalised so its first
-- non-zero component is positive; nil if there is none.
local function fixed_dir(o, sign)
	for a = -1, 1 do
		for b = -1, 1 do
			for c = -1, 1 do
				if a ~= 0 or b ~= 0 or c ~= 0 then
					local w = S.apply_linear(o, { a, b, c })
					if w[1] == sign * a and w[2] == sign * b and w[3] == sign * c then
						local first = (a ~= 0 and a) or (b ~= 0 and b) or c
						local f = first > 0 and 1 or -1
						return { f * a, f * b, f * c }
					end
				end
			end
		end
	end
end
S.fixed_dir = fixed_dir

--- A world direction (X east, Y up, Z north) in words.
function S.direction_words(v)
	local n = (v[1] ~= 0 and 1 or 0) + (v[2] ~= 0 and 1 or 0) + (v[3] ~= 0 and 1 or 0)
	if n == 1 then
		if v[1] ~= 0 then return "east-west" end
		if v[2] ~= 0 then return "vertical" end
		return "north-south"
	end
	if n == 3 then return "cube-diagonal" end
	if v[2] == 0 then return "horizontal diagonal" end
	return "sloping diagonal"
end

--- Rotation angle in degrees (0..359) of a proper rotation about axis a, measured anticlockwise
-- when a points towards the viewer. World coordinates (X east, Y up, Z north) are left-handed, so
-- the right-handed cross product below gives the opposite sense; it is flipped.
function S.turn_angle(o, a)
	local k = S.kind(o)
	local n = ({ ["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["6"] = 6 })[k]
	if n == 1 then return 0 end
	if n == 2 then return 180 end
	-- A vector perpendicular to a, its image, and the sense of turning from one to the other.
	local u = (a[1] == 0 and a[2] == 0) and { 1, 0, 0 } or { -a[2], a[1], 0 }
	local w = S.apply_linear(o, u)
	local cross = { u[2] * w[3] - u[3] * w[2], u[3] * w[1] - u[1] * w[3], u[1] * w[2] - u[2] * w[1] }
	local dot = cross[1] * a[1] + cross[2] * a[2] + cross[3] * a[3]
	local step = 360 / n
	return dot < 0 and step or 360 - step
end

--- Linear parts of a region's group, back in crystal axes (z up), for the stereogram.
function S.crystal_ops(g)
	local out = {}
	for _, o in ipairs(S.linear_parts(g).ops) do out[#out + 1] = S.conjugate(o, S.CRYSTAL_TO_WORLD) end
	return out
end

return S
