-- Runs inside a real Luanti server when crystalminer.selftest = true (see tests/run_server_test.sh).
-- Exercises the registered callbacks the way the engine calls them, writes the results to
-- <world>/crystalminer_selftest.txt and shuts the server down.

local cm = crystalminer
local S, L, content = cm.S, cm.L, cm.content
local results, failures = {}, 0

local function check(name, cond, detail)
	results[#results + 1] = (cond and "ok    " or "FAIL  ") .. name .. ((not cond and detail) and (" -- " .. detail) or "")
	if not cond then failures = failures + 1 end
end

local function live(id)
	for _, r in ipairs(cm.regions) do
		if r.area.id == id then return r end
	end
end

--- Places a node the way the engine does after a player places it: set it, then run every
-- registered on_placenode callback.
local function place(pos, name)
	local node = { name = name }
	local old = core.get_node(pos)
	core.set_node(pos, node)
	for _, cb in ipairs(core.registered_on_placenodes) do cb(pos, node, nil, old, ItemStack(name), nil) end
end

local function dig(pos)
	local old = core.get_node(pos)
	core.remove_node(pos)
	for _, cb in ipairs(core.registered_on_dignodes) do cb(pos, old, nil) end
end

local function count_in(r, name)
	local n = 0
	for x = r.min[1], r.min[1] + r.size[1] - 1 do
		for y = r.min[2], r.min[2] + r.size[2] - 1 do
			for z = r.min[3], r.min[3] + r.size[3] - 1 do
				if core.get_node({ x = x, y = y, z = z }).name == name then n = n + 1 end
			end
		end
	end
	return n
end

local function run()
	-- Mirror Plaza: a block is mirrored across the plane through column min.x + 12.
	local m = live("mirror_plaza").region
	local p = { x = m.min[1] + 2, y = m.min[2], z = m.min[3] + 5 }
	place(p, "crystalminer:red")
	local mirror = core.get_node({ x = m.min[1] + 22, y = m.min[2], z = m.min[3] + 5 }).name
	check("mirror plaza copies a block across the plane", mirror == "crystalminer:red", mirror)
	dig(p)
	mirror = core.get_node({ x = m.min[1] + 22, y = m.min[2], z = m.min[3] + 5 }).name
	check("digging removes the mirror image", mirror == "air", mirror)

	-- Kaleidoscope: one block in a general position becomes 48.
	local k = live("kaleidoscope").region
	place({ x = k.min[1] + 11, y = k.min[2] + 13, z = k.min[3] + 16 }, "crystalminer:yellow")
	local n = count_in(k, "crystalminer:yellow")
	check("kaleidoscope makes 48 copies", n == 48, tostring(n))

	-- Translation Hall: one block in each of the 27 unit cells.
	local t = live("translation_hall").region
	place({ x = t.min[1] + 1, y = t.min[2] + 1, z = t.min[3] + 2 }, "crystalminer:blue")
	n = count_in(t, "crystalminer:blue")
	check("translation hall repeats a block in 27 cells", n == 27, tostring(n))

	-- Square Court (4mm): /whatsymmetry's analysis recovers 4mm from what was built.
	local sq = live("square_court")
	local r = sq.region
	place({ x = r.min[1] + 2, y = r.min[2], z = r.min[3] + 5 }, "crystalminer:green")
	place({ x = r.min[1] + 3, y = r.min[2] + 1, z = r.min[3] + 5 }, "crystalminer:green")
	local _, entry = cm.analyse(sq)
	check("analysis of a build in Square Court finds 4mm", entry and entry.symbol == "4mm", entry and entry.symbol)

	-- Locked regions: a new player cannot build in a tier-1 region; a tier-4 player can.
	check("new player is locked out of tier 1", core.is_protected(p, "newbie") == true)
	cm.progress("teacher_test").tier = 4
	check("tier-4 player may build", core.is_protected(p, "teacher_test") == false)

	-- Gate quiz: correct answers unlock tier 1, a wrong one does not count.
	local qs = L.questions(content.gate, 0)
	cm.answer("student", qs[1].id, (qs[1].answer + 1) % #qs[1].options)
	check("wrong answer does not count", not cm.progress("student").answered[qs[1].id])
	for _, q in ipairs(qs) do cm.answer("student", q.id, q.answer) end
	check("gate quiz unlocks tier 1", cm.progress("student").tier == 1, tostring(cm.progress("student").tier))
	local saved = core.deserialize(cm.storage:get_string("progress:student"))
	check("progress is saved to mod storage", saved and saved.tier == 1)

	-- Gate displays: every display has its original and its copy in place.
	local ok = true
	for _, d in ipairs(cm.G.displays(content.gate.at)) do
		for _, p2 in ipairs(d.original) do if core.get_node(p2).name ~= "crystalminer:" .. d.colour then ok = false end end
		for _, p2 in ipairs(d.copy) do if core.get_node(p2).name ~= "crystalminer:" .. d.colour then ok = false end end
	end
	check("gate displays show each motif and its copy", ok)

	-- Try-it Pad: an L-shaped build is chiral, so its mirror image cannot be moved to match it,
	-- while a rotation always matches.
	local b = cm.PAD_BUILD
	for _, o in ipairs({ { 0, 0, 0 }, { 1, 0, 0 }, { 2, 0, 0 }, { 2, 0, 1 }, { 0, 1, 0 }, { 0, 2, 0 } }) do
		core.set_node({ x = b.x + 1 + o[1], y = b.y + o[2], z = b.z + 1 + o[3] }, { name = "crystalminer:red" })
	end
	local mirror_lever, rotate_lever
	for _, l in ipairs(cm.LEVERS) do
		if l.letter == "M" then mirror_lever = l elseif l.letter == "R" then rotate_lever = l end
	end
	local empty, matches = cm.apply_lever(mirror_lever)
	check("pad: a chiral build does not match its mirror image", empty == false and matches == false)
	local reds = 0
	local rr = cm.PAD_RESULT
	for dx = 0, 4 do for dy = 0, 4 do for dz = 0, 4 do
		if core.get_node({ x = rr.x + dx, y = rr.y + dy, z = rr.z + dz }).name == "crystalminer:red" then reds = reds + 1 end
	end end end
	check("pad: the result box shows all 6 blocks", reds == 6, tostring(reds))
	empty, matches = cm.apply_lever(rotate_lever)
	check("pad: a rotated build always matches", matches == true)

	-- Plane-group floor: one block becomes 8 per cell in 16 cells.
	local w = live("weave_tiles").region
	place({ x = w.min[1] + 1, y = w.min[2], z = w.min[3] + 2 }, "crystalminer:purple")
	n = count_in(w, "crystalminer:purple")
	check("weave tiles (p4g) make 8 copies in each of 36 cells", n == 288, tostring(n))

	-- -3 room: 6 copies.
	local t3 = live("bar_three_room").region
	place({ x = t3.min[1] + 2, y = t3.min[2] + 4, z = t3.min[3] + 9 }, "crystalminer:cyan")
	n = count_in(t3, "crystalminer:cyan")
	check("bar-three room makes 6 copies", n == 6, tostring(n))

	-- Architecture: the Fourfold Tower has brick corner towers, and nothing was built inside regions.
	local ft = live("fourfold_tower").region
	local corner = { x = ft.min[1] - 3, y = 5, z = ft.min[3] - 3 }
	core.load_area(corner)
	check("fourfold tower has a brick corner tower", core.get_node(corner).name == "crystalminer:brick", core.get_node(corner).name)
	check("Mirror Plaza is paved", core.get_node({ x = m.min[1] - 3, y = 0, z = m.min[3] + 3 }).name == "crystalminer:plaza")

	-- Lattice floors alternate their tint cell by cell.
	local mt = live("mirror_tiles").region
	check("lattice floor alternates by unit cell",
		core.get_node({ x = mt.min[1], y = 0, z = mt.min[3] }).name == "crystalminer:floor"
		and core.get_node({ x = mt.min[1] + 6, y = 0, z = mt.min[3] }).name == "crystalminer:floor_alt")

	-- Nothing stands in the strip in front of the gate where players view the displays.
	local clear = true
	for _, d in ipairs(cm.G.displays(content.gate.at)) do
		for dz = 4, 14 do
			for y = 1, 4 do
				if core.get_node({ x = d.look_at.x, y = y, z = d.look_at.z + dz }).name ~= "air" then clear = false end
			end
		end
	end
	check("the view of every gate display is clear", clear)

	check("the engine can load distant map blocks for /showcase", type(core.load_area) == "function")

	-- Showcase: the Twin Mirrors seat (6 blocks) appears 4 times; clear empties the region again.
	local tm = live("twin_mirrors").region
	cm.showcase("twin_mirrors")
	n = count_in(tm, "crystalminer:green")
	check("showcase builds the Twin Mirrors seat four times", n == 24, tostring(n))
	cm.showcase("clear")
	n = count_in(tm, "crystalminer:green")
	check("showcase clear empties the region", n == 0, tostring(n))
	check("showcase clear forgets that an example was built", cm.storage:get_string("showcase:twin_mirrors") == "")

	-- Learning: a full pre-test is recorded and exported without the player's name.
	for _, it in ipairs(content.assessment.items) do
		cm.A.answer(cm.record("student"), "pre", content.assessment.items, it.id, it.answer, 1)
	end
	cm.A.record_prediction(cm.record("student"), "mirror_plaza", 2, 2, 2, 1)
	local summary = cm.export(core.get_worldpath())
	local f = io.open(core.get_worldpath() .. "/crystalminer_tests.csv")
	local text = f and f:read("*a") or ""
	if f then f:close() end
	check("export writes the pre-test without names", summary.n_pre >= 1 and text:find("pre,order4", 1, true) ~= nil
		and not text:find("student", 1, true))
	-- Predictions use the engine's count for the exact spot: 2 off the mirror, 1 on it.
	local mp = live("mirror_plaza")
	local off = cm.counts(mp, { x = mp.region.min[1] + 2, y = mp.region.min[2], z = mp.region.min[3] + 3 })
	local on = cm.counts(mp, { x = mp.region.min[1] + 12, y = mp.region.min[2], z = mp.region.min[3] + 3 })
	check("prediction counts: 2 off the mirror, 1 on it", off == 2 and on == 1, off .. "," .. on)

	-- Step mode names each copy: the Screw Hall's copies include a screw and lattice translations.
	local sh = live("screw_hall")
	local texts = {}
	for _, im in ipairs(cm.described_images(sh, { x = sh.region.min[1] + 1, y = sh.region.min[2], z = sh.region.min[3] + 1 })) do
		texts[#texts + 1] = im.text
	end
	local joined = table.concat(texts, "|")
	check("step mode names screw copies", joined:find("a screw: a half turn about the vertical axis", 1, true) ~= nil
		and joined:find("lattice translation", 1, true) ~= nil, joined)
	-- Spiral Tower: 4 copies per cell in 3 cells.
	local st = live("spiral_tower").region
	place({ x = st.min[1] + 1, y = st.min[2], z = st.min[3] + 2 }, "crystalminer:lime")
	n = count_in(st, "crystalminer:lime")
	check("spiral tower (4_1) makes 4 copies in each of 12 cells", n == 48, tostring(n))

	-- Crystal Museum: the copper model is built (343 atoms for n = 6, one block per atom), each
	-- exhibit has its clue crystal, a right answer is a discovery, and visitors cannot dig exhibits.
	local copper = cm.museum_layout[1]
	local atoms = 0
	for dx = 0, copper.size - 1 do for dy = 0, copper.size - 1 do for dz = 0, copper.size - 1 do
		if core.get_node({ x = copper.x0 + dx, y = copper.y0 + dy, z = copper.z0 + dz }).name == "crystalminer:orange" then atoms = atoms + 1 end
	end end end
	local expect = #dofile(core.get_modpath("crystalminer") .. "/structures.lua").model("fcc", 6)
	check("museum: the copper model has one block per atom", atoms == expect, atoms .. " of " .. expect)
	local clues = 0
	for _, e in ipairs(cm.museum_layout) do
		if core.get_node(e.clue).name == "crystalminer:clue" and core.get_meta(e.clue):get_string("exhibit") == e.ex.id then clues = clues + 1 end
	end
	check("museum: every exhibit has its clue crystal", clues == #cm.museum_layout, tostring(clues))
	check("museum: a wrong clue answer is not a discovery", not cm.answer_clue("student", "copper", 0))
	check("museum: the right answer is a discovery", cm.answer_clue("student", "copper", 2) and cm.discoveries("student") == 1)
	check("museum: visitors cannot change an exhibit", core.is_protected({ x = copper.x0, y = copper.y0, z = copper.z0 }, "student"))

	-- Portal Hall: one portal per region, each with its destination; every world has a portal back,
	-- an entrance arch and its boards.
	local portals, backs, banners = 0, 0, 0
	for _, pt in ipairs(cm.lobby.portals()) do
		local pp = { x = pt.x, y = 1, z = cm.lobby.PORTAL_Z }
		if core.get_node(pp).name == "crystalminer:teleporter" and core.get_meta(pp):get_string("target") == pt.live.area.id then portals = portals + 1 end
		local pl = cm.D.plaza(pt.live.region)
		local back = { x = pl.portal.x, y = 1, z = pl.portal.z }
		if core.get_node(back).name == "crystalminer:teleporter" and core.get_meta(back):get_string("target") == "portal_hall" then backs = backs + 1 end
		for _, obj in ipairs(core.get_objects_inside_radius({ x = pl.arrive.x, y = 8, z = pl.arch_z + 0.5 }, 2)) do
			local e = obj:get_luaentity()
			if e and e.name == "crystalminer:sign" then banners = banners + 1 end
		end
	end
	check("portal hall: one portal per world, each with its destination", portals == #cm.regions, tostring(portals))
	check("every world has a portal back to the museum", backs == #cm.regions, tostring(backs))
	check("every world's entrance arch carries its name", banners == #cm.regions, tostring(banners))

	-- Signs and doors in the museum: the welcome board, a plaque above each display, the front door.
	local signs = 0
	for _, obj in ipairs(core.get_objects_inside_radius({ x = 0, y = 5, z = -30 }, 12)) do
		local e = obj:get_luaentity()
		if e and e.name == "crystalminer:sign" then signs = signs + 1 end
	end
	check("the foyer has its signs", signs >= 2, tostring(signs))
	local plaques = 0
	for _, d in ipairs(cm.G.displays(content.gate.at)) do
		for _, obj in ipairs(core.get_objects_inside_radius({ x = d.look_at.x, y = 7.5, z = -29.5 }, 1)) do
			local e = obj:get_luaentity()
			if e and e.name == "crystalminer:sign" then plaques = plaques + 1 end
		end
	end
	check("every display has its plaque", plaques == 4, tostring(plaques))
	local door = core.get_node({ x = cm.lobby.Z0 and -1 or 0, y = 1, z = cm.lobby.Z0 }).name
	check("the museum has a front door", door == "crystalminer:door_bottom", door)
	cm.toggle_door({ x = -1, y = 1, z = cm.lobby.Z0 })
	-- Open doors stand against the jambs: the leaves of a double door are turned opposite ways,
	-- and a doorway in a wall at fixed z runs along x (facedir 0/2), at fixed x along z (1/3).
	local function p2(x, z) local n = core.get_node({ x = x, y = 1, z = z }) return n.name .. "/" .. n.param2 end
	check("inner doors in an east-west wall open against its jambs",
		p2(-1, -30) == "crystalminer:door_bottom_open/0" and p2(0, -30) == "crystalminer:door_bottom_open/2",
		p2(-1, -30) .. " " .. p2(0, -30))
	check("inner doors in a north-south wall open against its jambs",
		p2(-21, -41) == "crystalminer:door_bottom_open/1" and p2(-21, -40) == "crystalminer:door_bottom_open/3",
		p2(-21, -41) .. " " .. p2(-21, -40))
	local function nm(x, y, z) return core.get_node({ x = x, y = y, z = z }).name end
	check("doorways are 3 high, so a flying visitor fits through",
		nm(-1, 3, -30) == "air" and nm(0, 3, -30) == "air" and nm(-1, 3, cm.lobby.Z0) == "air"
		and nm(-1, 4, -30) == "crystalminer:stone_brick", nm(-1, 3, -30) .. " " .. nm(-1, 4, -30))
	local stale = core.add_entity({ x = 0, y = 6, z = -20 }, "crystalminer:sign",
		core.serialize({ format = "label", text = "old", v = "an earlier build" }))
	check("a sign from an earlier build of the world removes itself", stale == nil or stale:get_pos() == nil)
	-- Guides: a first arrival marks the place as guided (the window opens a moment later), and the
	-- window carries the steps; the Try-it Pad has its labels.
	for _, f in ipairs(cm.on_area) do f("guidetester", "fourfold_tower", live("fourfold_tower")) end
	check("a first arrival shows the place's guide", (cm.progress("guidetester").guided or {}).fourfold_tower == true)
	local gfs = cm.guide_formspec("fourfold_tower")
	check("the guide window has the steps", gfs:find("What to do", 1, true) ~= nil and gfs:find("windmill", 1, true) ~= nil)
	local padsigns = 0
	for _, obj in ipairs(core.get_objects_inside_radius({ x = cm.PAD_BUILD.x - 2, y = 4, z = cm.PAD_BUILD.z }, 9)) do
		local e = obj:get_luaentity()
		if e and e.name == "crystalminer:sign" then padsigns = padsigns + 1 end
	end
	check("the Try-it Pad has its box signs and lever labels", padsigns >= 6, tostring(padsigns))
	-- Furniture: the foyer carpet, a bench, and every sculpture on its plinth.
	check("the foyer has its carpet", core.get_node({ x = 0, y = 1, z = -40 }).name == "crystalminer:carpet")
	check("Gallery 1 has benches facing the displays", core.get_node({ x = 0, y = 1, z = -9 }).name == "crystalminer:bench")
	local sculpted = 0
	for _, sc in ipairs(cm.SCULPTURES.list) do
		local b = sc.blocks[1]
		if core.get_node({ x = sc.at[1] + b[1], y = 2 + b[2], z = sc.at[2] + b[3] }).name == "crystalminer:" .. b[4]
			and core.get_node({ x = sc.at[1], y = 1, z = sc.at[2] }).name == "crystalminer:marble" then
			sculpted = sculpted + 1
		end
	end
	check("every sculpture stands on its plinth", sculpted == #cm.SCULPTURES.list, tostring(sculpted))
	check("the front door opens", core.get_node({ x = -1, y = 2, z = cm.lobby.Z0 }).name == "crystalminer:door_top_open")

	-- Tour: a visitor on the tour may build at a tour stop above their tier, and not elsewhere.
	cm.tour_state["visitor"] = { i = 3 }
	local kal = live("kaleidoscope").region
	check("tour: a visitor may build in the Kaleidoscope during the tour",
		core.is_protected({ x = kal.min[1] + 1, y = kal.min[2] + 1, z = kal.min[3] + 1 }, "visitor") == false)
	local sh = live("screw_hall").region
	check("tour: but not in regions the tour does not visit",
		core.is_protected({ x = sh.min[1] + 1, y = sh.min[2] + 1, z = sh.min[3] + 1 }, "visitor") == true)
	cm.tour_state["visitor"] = nil

	-- Teacher view lists the student who answered questions.
	local listed = false
	for _, r in ipairs(cm.class_rows()) do if r.name == "student" and r.tier == 1 then listed = true end end
	check("teacher class view lists students with their tier", listed)

	-- Progress board: lists the gate for a tier-0 player and has a button to go there.
	local fs = cm.board_formspec("newbie")
	check("progress board offers a button to the Symmetry Gate", fs:find("go_symmetry_gate", 1, true) ~= nil)

	-- Quiz window: a wrong option is greyed out and the hint shown.
	local q1 = L.questions(content.gate, 0)[1]
	local qfs = cm.quiz_formspec(q1, { wrong = { [0] = true }, feedback = "Not quite. " .. q1.hint })
	check("quiz window greys out a wrong option and shows the hint",
		qfs:find("not this one", 1, true) ~= nil and qfs:find("opt_0", 1, true) == nil and qfs:find("mirror image", 1, true) ~= nil)

	-- Free Lab: a hexagonal group is refused, 4mm is applied.
	local lab = live("free_lab")
	cm.apply_symmetry("teacher_test", lab, "6mm")
	check("free lab refuses 6mm", lab.symbol == "1", lab.symbol)
	cm.apply_symmetry("teacher_test", lab, "4mm")
	check("free lab accepts 4mm", lab.symbol == "4mm" and #lab.region.group.ops == 8, lab.symbol)

	local out = io.open(core.get_worldpath() .. "/crystalminer_selftest.txt", "w")
	out:write(table.concat(results, "\n") .. "\n" .. (failures == 0 and "PASS" or ("FAILURES " .. failures)) .. "\n")
	out:close()
	core.request_shutdown()
end

cm.when_ready(function()
	-- Signs placed while the world was built are stored in the map until a player comes near.
	-- Keep the places the checks look at loaded, so their signs wake up as they would for a player.
	local spots = { { x = 0, y = 5, z = -30 } }
	for _, d in ipairs(cm.G.displays(content.gate.at)) do spots[#spots + 1] = { x = d.look_at.x, y = 7, z = -30 } end
	spots[#spots + 1] = { x = cm.PAD_BUILD.x - 2, y = 4, z = cm.PAD_BUILD.z }
	for _, live in ipairs(cm.regions) do
		local pl = cm.D.plaza(live.region)
		spots[#spots + 1] = { x = pl.arrive.x, y = 8, z = pl.arch_z }
	end
	for _, p in ipairs(spots) do core.forceload_block(p, true) end
	core.after(4, function()
		local ok, err = pcall(run)
		if not ok then
			local out = io.open(core.get_worldpath() .. "/crystalminer_selftest.txt", "w")
			out:write("ERROR " .. tostring(err) .. "\n")
			out:close()
			core.request_shutdown()
		end
	end)
end)
