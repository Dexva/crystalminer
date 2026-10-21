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

T.run("axes carry their International Tables symbol: kaleidoscope 2, -3, 4; -4 room -4; -3 room -3", function()
	local function symbols(gens, size)
		local r = S.region({ min = { 0, 2, 0 }, size = { 15, 15, 15 }, generators = gens })
		local s = {}
		for _, d in ipairs(E.dots(r)) do if d.symbol then s[d.symbol] = true end end
		return s
	end
	local k = symbols(S.point_group("m-3m").generators)
	-- m-3m: its body diagonals are -3 axes (3-fold rotation plus inversion), its cube axes 4-fold.
	T.ok(k["2"] and k["-3"] and k["4"] and not k["3"] and not k["-4"], "kaleidoscope")
	T.ok(symbols({ "y,-x,-z" })["-4"], "-4")
	local m3 = symbols({ "-z,-x,-y" })
	T.ok(m3["-3"] and not m3["3"], "-3")
	local p3 = symbols({ "z,x,y" })
	T.ok(p3["3"] and not p3["-3"], "plain 3-fold")
end)

-- Markers: one spawner per shown dot, only differences are sent.
local function fake_engine()
	local f = { next = 0, live = {}, adds = 0, deletes = 0 }
	f.add = function(d) f.next = f.next + 1; f.adds = f.adds + 1; f.live[f.next] = d; return f.next end
	f.delete = function(id) T.ok(f.live[id], "deleting a live spawner"); f.live[id] = nil; f.deletes = f.deletes + 1 end
	f.count = function() local n = 0 for _ in pairs(f.live) do n = n + 1 end return n end
	return f
end
local function kaleidoscope_dots()
	return E.dots(S.region({ min = { 0, 1, 0 }, size = { 25, 25, 25 }, anchor = "centre",
		generators = S.point_group("m-3m").generators }))
end

T.run("markers: entering adds one spawner per dot, staying sends nothing", function()
	local dots, f = kaleidoscope_dots(), fake_engine()
	local m = E.sync_markers(nil, dots, nil, f.add, f.delete)
	T.eq(f.count(), #dots, "one per dot")
	for _ = 1, 100 do m = E.sync_markers(m, dots, nil, f.add, f.delete) end
	T.eq(f.adds, #dots, "no more adds while nothing changes")
	T.eq(f.deletes, 0, "no deletes while nothing changes")
	m = E.sync_markers(m, nil, nil, f.add, f.delete)
	T.eq(m, nil, "no state after leaving")
	T.eq(f.count(), 0, "leaving deletes every spawner")
end)

T.run("markers: the filter adds and deletes only the difference", function()
	local dots, f = kaleidoscope_dots(), fake_engine()
	local n = {}
	for _, d in ipairs(dots) do n[d.kind] = (n[d.kind] or 0) + 1 end
	T.ok(n.axes and n.mirrors and n.centres, "kaleidoscope has axes, mirrors and a centre")
	local m = E.sync_markers(nil, dots, nil, f.add, f.delete)
	m = E.sync_markers(m, dots, "axes", f.add, f.delete)
	T.eq(f.count(), n.axes, "only axes left")
	T.eq(f.adds, #dots, "axes were kept, not re-sent")
	for _, d in pairs(f.live) do T.eq(d.kind, "axes") end
	m = E.sync_markers(m, dots, "mirrors", f.add, f.delete)
	T.eq(f.count(), n.mirrors, "only mirrors")
	m = E.sync_markers(m, dots, nil, f.add, f.delete)
	T.eq(f.count(), #dots, "all again")
	-- A new dots table (the region's symmetry changed, or another region) replaces everything.
	local other = kaleidoscope_dots()
	m = E.sync_markers(m, other, nil, f.add, f.delete)
	T.eq(f.count(), #other, "replaced")
	local mine = {}
	for _, d in ipairs(other) do mine[d] = true end
	for _, d in pairs(f.live) do T.ok(mine[d], "only the new region's dots") end
	T.eq(E.sync_markers(m, {}, nil, f.add, f.delete), nil, "an empty region shows nothing")
	T.eq(f.count(), 0, "and deletes what it showed")
end)

T.run("markers: a failed add is not recorded", function()
	local dots = kaleidoscope_dots()
	for _, bad in ipairs({ -1, 4294967295, 0 }) do
		local m = E.sync_markers(nil, dots, nil, function() return bad end, function() error("nothing to delete") end)
		T.eq(next(m.ids), nil, "no ids for " .. bad)
	end
	local m = E.sync_markers(nil, dots, nil, function() return -1 end, function() error("nothing to delete") end)
	T.eq(E.sync_markers(m, nil, nil, nil, function() error("nothing to delete") end), nil)
end)

T.run("markers: the spawner sits still at the dot and looks like the old particle", function()
	local d = { pos = { x = 1, y = 2, z = 3 }, colour = "#FF3030", kind = "axes", symbol = "4", size = 2 }
	local def = E.marker_def(d, "ann")
	T.eq(def.time, 0, "endless")
	T.eq(def.minpos, d.pos); T.eq(def.maxpos, d.pos)
	T.eq(def.minsize, 2); T.eq(def.maxsize, 2)
	T.eq(def.maxvel.x + def.maxvel.y + def.maxvel.z + def.minacc.y, 0, "still")
	T.eq(def.minexptime, def.maxexptime)
	T.eq(def.texture, "crystalminer_sym_4.png^[colorize:#FF3030:255")
	T.eq(def.glow, 14); T.eq(def.playername, "ann")
	T.eq(E.marker_texture({ kind = "centres", colour = "#FFFFFF" }), "crystalminer_centre.png")
	T.eq(E.marker_texture({ kind = "mirrors", colour = "#40C0FF" }), "crystalminer_dot.png^[colorize:#40C0FF:255")
	-- A dot is blank a fraction exp(-(amount + 1) * exptime) of the time (see elements.lua).
	T.ok(math.exp(-(E.MARKER_AMOUNT + 1) * E.MARKER_EXPTIME) < 0.003, "rarely blank")
end)

T.finish()
