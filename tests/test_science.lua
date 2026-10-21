-- Checks the scientific claims the game's text makes, beyond group orders (see test_content.lua).
package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local S = require("symmetry")
local content = require("content")
local G = loadfile("mods/crystalminer/gate.lua")(S)
local T = require("testlib")

print("science claims")

T.run("the gate motif has no symmetry, so each display shows exactly one operation", function()
	local nodes = {}
	for _, m in ipairs(G.MOTIF) do nodes[(2 * m[1] + 1) .. "," .. (2 * m[2] + 1) .. "," .. (2 * m[3] + 1)] = "a" end
	T.eq(#S.detect(nodes).ops, 1, "motif symmetry")
	local expect = { A = "m", B = "2", C = "1", D = "-1" }
	for _, d in ipairs(G.displays(content.gate.at)) do
		-- Every grid operation (any translation) that maps the original onto the copy.
		local A, B = {}, {}
		for _, p in ipairs(d.original) do A[#A + 1] = { 2 * p.x + 1, 2 * p.y + 1, 2 * p.z + 1 } end
		for _, p in ipairs(d.copy) do B[(2 * p.x + 1) .. "," .. (2 * p.y + 1) .. "," .. (2 * p.z + 1)] = true end
		local kinds = {}
		for _, o in ipairs(S.point_group("m-3m").group.ops) do
			for k in pairs(B) do
				local bx, by, bz = k:match("(-?%d+),(-?%d+),(-?%d+)")
				local w = S.apply(o, A[1])
				local t = { tonumber(bx) - w[1], tonumber(by) - w[2], tonumber(bz) - w[3] }
				local ok = true
				for _, p in ipairs(A) do
					local q = S.apply(o, p)
					if not B[(q[1] + t[1]) .. "," .. (q[2] + t[2]) .. "," .. (q[3] + t[3])] then ok = false break end
				end
				if ok then kinds[#kinds + 1] = S.kind(o) end
			end
		end
		T.eq(#kinds, 1, "display " .. d.letter .. " operations")
		T.eq(kinds[1], expect[d.letter], "display " .. d.letter)
	end
end)

T.run("gate displays read A to D from left to right, originals on the left", function()
	-- Players spawn facing south (-Z), so larger x is further left.
	local prev = math.huge
	for _, d in ipairs(G.displays(content.gate.at)) do
		T.ok(d.label.x < prev, "order")
		prev = d.label.x
		local omin, cmax = math.huge, -math.huge
		for _, p in ipairs(d.original) do omin = math.min(omin, p.x) end
		for _, p in ipairs(d.copy) do cmax = math.max(cmax, p.x) end
		T.ok(omin > cmax, "display " .. d.letter .. ": original east of copy")
	end
end)

T.run("exactly 12 of the 17 plane groups fit the block grid, with the right multiplicities", function()
	T.eq(#S.plane_catalog, 17)
	local fit = 0
	for _, e in ipairs(S.plane_catalog) do
		for _, cell in ipairs({ 4, 6, 8 }) do
			local g = S.plane_group(e.symbol, cell, cell)
			T.eq(#g.ops, e.multiplicity, e.symbol .. " multiplicity")
			T.eq(S.fits_grid(g), not e.hexagonal_basis, e.symbol .. " fits")
		end
		if not e.hexagonal_basis then fit = fit + 1 end
	end
	T.eq(fit, 12)
	-- Why the other 5 cannot: each has a 3-fold rotation, and no grid operation that keeps up
	-- pointing up has order 3 (they form 4/mmm, whose operations have orders 1, 2 and 4).
	for _, e in ipairs(S.plane_catalog) do
		if e.hexagonal_basis then T.ok(S.signature(S.plane_group(e.symbol))["3"], e.symbol .. " has a 3-fold rotation") end
	end
	for _, o in ipairs(S.point_group("m-3m").group.ops) do
		if o.w[9] == 1 then T.ok(S.kind(o) ~= "3", "vertical-preserving 3-fold") end
	end
end)

-- Points of the doubled grid of one cell (period P) fixed by an operation, modulo the lattice.
local function fixed_points(o, P)
	local out = {}
	for x = 0, P - 1 do
		for y = 0, P - 1 do
			if (o.w[1] * x + o.w[2] * y + o.t[1] - x) % P == 0 and (o.w[4] * x + o.w[5] * y + o.t[2] - y) % P == 0 then
				out[#out + 1] = x .. "," .. y
			end
		end
	end
	return out
end

local function elements(symbol)
	local g = S.plane_group(symbol, 6, 6)
	local mirrors, glides, fourfold = {}, 0, {}
	for _, o in ipairs(g.ops) do
		if S.kind(o) == "m" then
			local f = fixed_points(o, 12)
			if #f > 0 then mirrors[#mirrors + 1] = f else glides = glides + 1 end
		elseif S.kind(o) == "4" then
			for _, p in ipairs(fixed_points(o, 12)) do fourfold[#fourfold + 1] = p end
		end
	end
	return mirrors, glides, fourfold
end

T.run("pgg has glide lines and no mirror lines; p4 has neither", function()
	local m, g = elements("pgg")
	T.eq(#m, 0, "pgg mirrors")
	T.ok(g > 0, "pgg glides")
	m, g = elements("p4")
	T.eq(#m + g, 0, "p4 reflections")
end)

T.run("pmm has mirror lines that cross at 2-fold points", function()
	local m = elements("pmm")
	T.ok(#m >= 2, "two mirror directions")
	local g = S.plane_group("pmm", 6, 6)
	for _, o in ipairs(g.ops) do
		if S.kind(o) == "2" then
			for _, p in ipairs(fixed_points(o, 12)) do
				local on = 0
				for _, f in ipairs(m) do
					for _, q in ipairs(f) do if q == p then on = on + 1 break end end
				end
				T.eq(on, 2, "2-fold point " .. p .. " lies on both mirrors")
			end
		end
	end
end)

T.run("p4g has mirrors and glides, but no mirror passes through a 4-fold point", function()
	local m, g, four = elements("p4g")
	T.ok(#m > 0 and g > 0 and #four > 0)
	for _, p in ipairs(four) do
		for _, f in ipairs(m) do
			for _, q in ipairs(f) do T.ok(q ~= p, "4-fold point " .. p .. " on a mirror") end
		end
	end
end)

T.run("screw and glide facts in the text: 4_1 four times is one cell, its mirror image is 4_3, a glide twice is a cell", function()
	local cell = { 16, 16, 16 }
	local s41 = S.parse("-y,x,z+1/4", cell)
	local p = S.IDENTITY
	for _ = 1, 4 do p = S.compose(s41, p) end
	T.eq(S.key(p), S.key(S.op({ 1, 0, 0, 0, 1, 0, 0, 0, 1 }, { 0, 0, 16 })), "(4_1)^4 = one cell up")
	-- Mirror image: conjugate by a reflection; the result is a quarter turn the other way with the same rise (4_3 = 4_1^3 mod lattice).
	local m = S.parse("-x,y,z")
	local mirrored = S.compose(S.compose(m, s41), m)
	local s43 = S.parse("y,-x,z+1/4", cell)
	T.eq(S.key(mirrored), S.key(s43), "mirror image of 4_1 is y,-x,z+1/4")
	local s41_cubed = S.modulo(S.compose(s41, S.compose(s41, s41)), cell)
	T.ok(S.key(S.modulo(s43, cell)) ~= S.key(S.modulo(s41, cell)), "4_3 differs from 4_1")
	T.eq(S.linear(s43).w[2], S.linear(s41_cubed).w[2], "same turn sense as (4_1)^3")
	-- A glide twice is a whole-cell translation along the plane.
	local g = S.parse("x+1/2,-y,z", cell)
	T.eq(S.key(S.compose(g, g)), S.key(S.op({ 1, 0, 0, 0, 1, 0, 0, 0, 1 }, { 16, 0, 0 })))
	-- Screws and glides have a non-zero intrinsic translation; a plain rotation does not.
	local sum = S.intrinsic(s41)
	T.ok(sum[3] ~= 0, "4_1 intrinsic")
	sum = S.intrinsic(S.parse("-x,-y,z"))
	T.ok(sum[1] == 0 and sum[2] == 0 and sum[3] == 0, "2-fold has none")
end)

T.run("-3 contains a 3-fold axis and an inversion centre; -4 contains neither 4 nor -1", function()
	local g = S.point_group("-3").group
	T.eq(#g.ops, 6)
	T.ok(S.signature(g)["3"] == 2 and S.signature(g)["-1"] == 1)
	local m4 = S.signature(S.point_group("-4").group)
	T.ok(not m4["4"] and not m4["-1"])
end)

T.run("a shape matches its mirror image exactly when it has an improper symmetry", function()
	local function has_improper(nodes)
		for _, o in ipairs(S.detect(nodes).ops) do if S.det(o) < 0 then return true end end
		return false
	end
	local L_shape = {}
	for _, m in ipairs(G.MOTIF) do L_shape[(2 * m[1] + 1) .. "," .. (2 * m[2] + 1) .. "," .. (2 * m[3] + 1)] = "a" end
	T.ok(not has_improper(L_shape), "the chiral motif")
	T.ok(has_improper({ ["1,1,1"] = "a", ["3,1,1"] = "a", ["1,3,1"] = "a" }), "a flat L is achiral (it lies in a mirror plane)")
end)

T.run("turns are named with the right sense: the Fourfold Tower's generator turns east to north", function()
	local o = S.conjugate(S.parse("-y,x,z"), S.CRYSTAL_TO_WORLD)
	local v = S.apply_linear(o, { 1, 0, 0 })
	T.ok(v[1] == 0 and v[2] == 0 and v[3] == 1, "east goes to north")
	-- Seen from above with north up and east to the right, east to north is anticlockwise.
	T.eq(S.describe_op(o), "a quarter turn (90 degrees, anticlockwise seen from above) about the vertical axis")
	local o3 = S.compose(o, S.compose(o, o))
	T.eq(S.describe_op(o3), "three quarters of a turn (270 degrees, anticlockwise seen from above) about the vertical axis")
	T.eq(S.describe_op(S.parse("-x,-y,-z")), "an inversion through the centre")
end)

T.finish()
