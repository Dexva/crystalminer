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
	-- Mirror Plaza: a block is mirrored across the plane through column min.x + 7.
	local m = live("mirror_plaza").region
	local p = { x = m.min[1] + 2, y = m.min[2], z = m.min[3] + 5 }
	place(p, "crystalminer:red")
	local mirror = core.get_node({ x = m.min[1] + 12, y = m.min[2], z = m.min[3] + 5 }).name
	check("mirror plaza copies a block across the plane", mirror == "crystalminer:red", mirror)
	dig(p)
	mirror = core.get_node({ x = m.min[1] + 12, y = m.min[2], z = m.min[3] + 5 }).name
	check("digging removes the mirror image", mirror == "air", mirror)

	-- Kaleidoscope: one block in a general position becomes 48.
	local k = live("kaleidoscope").region
	place({ x = k.min[1] + 8, y = k.min[2] + 9, z = k.min[3] + 10 }, "crystalminer:yellow")
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

	-- Gate displays: translation display C has the motif and its copy 6 nodes east.
	local g = content.gate.at
	local ok = true
	for _, o in ipairs(cm.MOTIF) do
		local a = core.get_node({ x = g[1] + 28 + o[1], y = g[2] + o[2], z = g[3] + o[3] }).name
		local b = core.get_node({ x = g[1] + 34 + o[1], y = g[2] + o[2], z = g[3] + o[3] }).name
		if a == "air" or b == "air" then ok = false end
	end
	check("gate display C shows the motif and its translated copy", ok)

	local labels = 0
	for _, obj in ipairs(core.get_objects_inside_radius({ x = g[1] + 25, y = g[2] + 10, z = g[3] }, 3)) do
		if obj:get_luaentity() and obj:get_luaentity().name == "crystalminer:label" then labels = labels + 1 end
	end
	check("gate title label exists", labels >= 1, tostring(labels))

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
	-- Let the map settle for a moment after building.
	core.after(1, function()
		local ok, err = pcall(run)
		if not ok then
			local out = io.open(core.get_worldpath() .. "/crystalminer_selftest.txt", "w")
			out:write("ERROR " .. tostring(err) .. "\n")
			out:close()
			core.request_shutdown()
		end
	end)
end)
