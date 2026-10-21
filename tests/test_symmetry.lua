package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local S = require("symmetry")
local T = require("testlib")

print("symmetry engine")

-- Orders of the 32 crystallographic point groups (International Tables for Crystallography, Vol. A).
local ORDERS = {
	["1"] = 1, ["-1"] = 2, ["2"] = 2, ["m"] = 2, ["2/m"] = 4, ["222"] = 4, ["mm2"] = 4, ["mmm"] = 8,
	["4"] = 4, ["-4"] = 4, ["4/m"] = 8, ["422"] = 8, ["4mm"] = 8, ["-42m"] = 8, ["4/mmm"] = 16,
	["3"] = 3, ["-3"] = 6, ["32"] = 6, ["3m"] = 6, ["-3m"] = 12,
	["6"] = 6, ["-6"] = 6, ["6/m"] = 12, ["622"] = 12, ["6mm"] = 12, ["-62m"] = 12, ["6/mmm"] = 24,
	["23"] = 12, ["m-3"] = 24, ["432"] = 24, ["-43m"] = 24, ["m-3m"] = 48,
}

local function set_of(images)
	local s = {}
	for _, im in ipairs(images) do s[im.x .. "," .. im.y .. "," .. im.z] = true end
	return s
end

local function count(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	return n
end

T.run("catalog has all 32 groups with correct orders", function()
	T.eq(#S.catalog, 32, "catalog size")
	for _, e in ipairs(S.catalog) do T.eq(#e.group.ops, ORDERS[e.symbol], "order of " .. e.symbol) end
end)

T.run("signatures tell all 32 groups apart", function()
	local seen = {}
	for _, e in ipairs(S.catalog) do
		T.ok(not seen[e.signature_key], "duplicate signature for " .. e.symbol)
		seen[e.signature_key] = true
	end
end)

T.run("exactly 25 groups fit the node grid", function()
	local n = 0
	for _, e in ipairs(S.catalog) do
		if S.fits_grid(e.group) then n = n + 1 end
		T.eq(S.fits_grid(e.group), not e.hexagonal_basis, e.symbol)
	end
	T.eq(n, 25, "groups that fit")
end)

-- The hexagonal groups cannot fit the grid in any orientation: each contains a 6 or -6 operation,
-- and no grid operation is one (determinant and trace do not depend on orientation).
T.run("no grid operation is six-fold", function()
	local cubic = S.point_group("m-3m").group
	T.eq(#cubic.ops, 48, "m-3m order")
	for _, o in ipairs(cubic.ops) do
		T.ok(S.is_signed_permutation(o))
		local k = S.kind(o)
		T.ok(k ~= "6" and k ~= "-6", "six-fold operation in m-3m")
	end
	for _, e in ipairs(S.catalog) do
		if e.hexagonal_basis then
			local sig = S.signature(e.group)
			T.ok(sig["6"] or sig["-6"], e.symbol .. " lacks a 6 or -6")
		end
	end
end)

T.run("the 25 grid groups are subgroups of m-3m", function()
	local cubic = S.point_group("m-3m").group
	for _, e in ipairs(S.catalog) do
		if not e.hexagonal_basis then
			for _, o in ipairs(e.group.ops) do T.ok(S.contains(cubic, o), e.symbol) end
		end
	end
end)

T.run("combining operations produces new ones", function()
	T.ok(S.contains(S.point_group("mm2").group, S.parse("-x,-y,z")), "mm2 has a 2-fold axis")
	T.ok(S.contains(S.point_group("2/m").group, S.parse("-x,-y,-z")), "2/m has an inversion centre")
	local m4 = S.point_group("-4").group
	T.ok(S.contains(m4, S.parse("-x,-y,z")), "-4 has a 2-fold axis")
	T.ok(not S.signature(m4)["4"], "-4 has no 4-fold axis")
	T.ok(not S.contains(m4, S.parse("-x,-y,-z")), "-4 has no inversion centre")
end)

T.run("identify works in any orientation", function()
	T.eq(S.identify(S.group({ S.parse("-x,y,z") })).symbol, "m")
	T.eq(S.identify(S.group({ S.parse("x,-z,y"), S.parse("x,-y,z") })).symbol, "4mm")
end)

T.run("normalize accepts common spellings", function()
	T.eq(S.normalize("m3m"), "m-3m")
	T.eq(S.normalize("43m"), "-43m")
	T.eq(S.normalize("4"), "4")
	T.eq(S.normalize("-4"), "-4")
	T.eq(S.normalize(" 2 / m "), "2/m")
end)

T.run("mirror perpendicular to x reflects east and west", function()
	local r = S.region({ min = { 0, 10, 0 }, size = { 15, 12, 15 }, anchor = "floor", generators = { "-x,y,z" } })
	local s = set_of(S.images(r, 2, 11, 5))
	T.ok(s["2,11,5"] and s["12,11,5"] and count(s) == 2, "mirror images")
	T.eq(#S.images(r, 7, 11, 5), 1, "node on the plane")
end)

T.run("four-fold axis makes four copies off the axis, one on it", function()
	local r = S.region({ min = { 0, 10, 0 }, size = { 15, 12, 15 }, anchor = "floor", generators = { "-y,x,z" } })
	T.eq(#S.images(r, 2, 15, 4), 4)
	T.eq(#S.images(r, 7, 15, 7), 1)
	for _, im in ipairs(S.images(r, 2, 15, 4)) do T.eq(im.y, 15, "height kept") end
end)

T.run("inversion maps through the centre", function()
	local r = S.region({ min = { 0, 11, 0 }, size = { 15, 15, 15 }, generators = { "-x,-y,-z" } })
	-- Centre node (7, 18, 7).
	local s = set_of(S.images(r, 1, 12, 3))
	T.ok(s["1,12,3"] and s["13,24,11"] and count(s) == 2)
end)

T.run("kaleidoscope makes 48 copies of a general node", function()
	local r = S.region({ min = { 0, 11, 0 }, size = { 15, 15, 15 }, generators = S.point_group("m-3m").generators })
	T.eq(#r.group.ops, 48)
	T.eq(#S.images(r, 8, 20, 10), 48)
end)

T.run("floor region rejects operations that flip up and down", function()
	T.fails(function()
		S.region({ min = { 0, 10, 0 }, size = { 15, 12, 15 }, anchor = "floor", generators = { "-x,-y,-z" } })
	end)
end)

T.run("three-fold axis needs a cube", function()
	T.fails(function() S.region({ min = { 0, 11, 0 }, size = { 15, 13, 15 }, generators = { "z,x,y" } }) end)
	local r = S.region({ min = { 0, 11, 0 }, size = { 15, 15, 15 }, generators = { "z,x,y" } })
	T.eq(#S.images(r, 8, 20, 10), 3)
end)

T.run("three-fold axis turns east to north to up", function()
	-- Crystal x is east, y north, z up; (x,y,z) -> (z,x,y) sends east to north.
	local o = S.conjugate(S.parse("z,x,y"), S.CRYSTAL_TO_WORLD)
	local v = S.apply_linear(o, { 1, 0, 0 }) -- world east
	T.ok(v[1] == 0 and v[2] == 0 and v[3] == 1, "east -> north (world +Z)")
	v = S.apply_linear(o, { 0, 0, 1 }) -- world north
	T.ok(v[1] == 0 and v[2] == 1 and v[3] == 0, "north -> up")
end)

T.run("hexagonal group cannot be a region", function()
	T.fails(function() S.region({ min = { 0, 11, 0 }, size = { 15, 15, 15 }, generators = { "x-y,x,z" } }) end)
end)

T.run("lattice repeats the node in every cell", function()
	local r = S.region({ min = { 0, 11, 0 }, cell = { 6, 6, 6 }, counts = { 3, 3, 3 }, generators = {} })
	local ims = S.images(r, 1, 12, 2)
	T.eq(#ims, 27)
	T.ok(set_of(ims)["13,24,14"])
end)

T.run("screw axis turns half a turn and rises half a cell", function()
	local r = S.region({ min = { 0, 11, 0 }, cell = { 6, 6, 6 }, counts = { 1, 2, 1 }, generators = { "-x,-y,z+1/2" } })
	T.eq(#r.group.ops, 2)
	local s = set_of(S.images(r, 1, 11, 2))
	T.ok(s["1,11,2"] and s["1,17,2"] and s["4,14,3"] and s["4,20,3"] and count(s) == 4)
end)

T.run("half-cell translation needs an even cell", function()
	T.fails(function()
		S.region({ min = { 0, 11, 0 }, cell = { 5, 5, 5 }, counts = { 2, 2, 2 }, generators = { "-x,-y,z+1/2" } })
	end)
end)

T.run("detector finds the symmetry of a build", function()
	local r = S.region({ min = { 0, 10, 0 }, size = { 15, 12, 15 }, anchor = "floor", generators = { "-y,x,z", "x,-y,z" } })
	local build = {}
	for _, b in ipairs({ { 2, 10, 5 }, { 3, 11, 5 }, { 9, 12, 13 } }) do
		for _, im in ipairs(S.images(r, b[1], b[2], b[3])) do
			build[(2 * im.x + 1) .. "," .. (2 * im.y + 1) .. "," .. (2 * im.z + 1)] = "stone"
		end
	end
	local _, e = S.detect(build)
	T.eq(e.symbol, "4mm")
end)

T.run("detector distinguishes node types", function()
	local build = { ["1,1,1"] = "stone", ["5,1,1"] = "stone" }
	-- Two equal nodes in a row: a 4-fold axis along the row, mirrors and an inversion centre.
	T.eq(select(2, S.detect(build)).symbol, "4/mmm")
	build["5,1,1"] = "gold"
	T.eq(select(2, S.detect(build)).symbol, "4mm")
end)

T.run("describe lists operations by kind", function()
	T.eq(S.describe(S.point_group("2/m").group),
		"Operations: 1 identity, 1 two-fold rotation, 1 mirror reflection, 1 inversion.")
end)

T.run("the corner check finds every misfit the full check finds", function()
	-- Compare with checking every node, for boxes that fit and boxes that do not.
	local function full_ok(spec)
		local ok, r = pcall(S.region, spec)
		if not ok then return false end
		for x = 0, r.size[1] - 1 do for y = 0, r.size[2] - 1 do for z = 0, r.size[3] - 1 do
			for _, im in ipairs(S.images(r, r.min[1] + x, r.min[2] + y, r.min[3] + z)) do
				if not S.contains_pos(r, im.x, im.y, im.z) then return false end
			end
		end end end
		return true
	end
	for _, gens in ipairs({ { "z,x,y" }, { "-y,x,z" }, { "-x,-y,-z" }, S.point_group("m-3m").generators }) do
		for _, size in ipairs({ { 9, 9, 9 }, { 9, 7, 9 }, { 7, 9, 9 }, { 8, 8, 8 } }) do
			local spec = { min = { 0, 5, 0 }, size = size, generators = gens }
			local corner_ok = pcall(S.region, spec)
			T.eq(corner_ok, full_ok(spec), table.concat(gens, ";") .. " " .. table.concat(size, "x"))
		end
	end
end)

T.finish()
