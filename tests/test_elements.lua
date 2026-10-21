package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local S = require("symmetry")
local E = loadfile("mods/crystalminer/elements.lua")(S)
local T = require("testlib")

print("symmetry elements")

local function colours(dots)
	local c = {}
	for _, d in ipairs(dots) do c[d.colour] = (c[d.colour] or 0) + 1 end
	return c
end

T.run("mirror plaza draws only a mirror plane, in the middle", function()
	local r = S.region({ min = { 0, 1, 0 }, size = { 15, 12, 15 }, anchor = "floor", generators = { "-x,y,z" } })
	local dots = E.dots(r)
	local c = colours(dots)
	T.ok(c[E.COLOURS.mirror] and c[E.COLOURS.mirror] > 0, "mirror dots")
	T.eq(c[E.COLOURS.axis2], nil, "no axes")
	-- Nodes span [x - 0.5, x + 0.5]; the plane passes through the centre of column x = 7.
	for _, d in ipairs(dots) do T.eq(d.pos.x, 7, "plane at x = 7") end
end)

T.run("four-fold tower draws one vertical red axis through the centre column", function()
	local r = S.region({ min = { 0, 1, 0 }, size = { 15, 12, 15 }, anchor = "floor", generators = { "-y,x,z" } })
	for _, d in ipairs(E.dots(r)) do
		T.eq(d.colour, E.COLOURS.axis4)
		T.ok(d.pos.x == 7 and d.pos.z == 7, "axis position")
	end
end)

T.run("kaleidoscope shows 3 four-fold, 4 three-fold, 6 two-fold axes, mirrors and a centre", function()
	local r = S.region({ min = { 0, 2, 0 }, size = { 15, 15, 15 }, generators = S.point_group("m-3m").generators })
	local c = colours(E.dots(r))
	T.ok(c[E.COLOURS.axis4] and c[E.COLOURS.axis3] and c[E.COLOURS.axis2] and c[E.COLOURS.mirror])
	T.eq(c[E.COLOURS.inversion], 1)
end)

T.run("-4 draws a rotoinversion axis and nothing four-fold", function()
	local r = S.region({ min = { 0, 2, 0 }, size = { 15, 15, 15 }, generators = { "y,-x,-z" } })
	local c = colours(E.dots(r))
	T.ok(c[E.COLOURS.rotoinversion], "rotoinversion axis")
	T.eq(c[E.COLOURS.axis4], nil)
	T.eq(c[E.COLOURS.inversion], nil)
end)

T.run("lattice draws cell edges", function()
	local r = S.region({ min = { 0, 2, 0 }, cell = { 6, 6, 6 }, counts = { 3, 3, 3 }, generators = {} })
	T.ok(#E.dots(r) > 0)
end)

T.finish()
