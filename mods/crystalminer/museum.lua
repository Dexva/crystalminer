-- The Crystal Museum (Gallery 3 of the lobby), after MolCraft (University of Hull): a central place to
-- start from, teleporters to every area, large structures to fly around, and a scavenger hunt of
-- clue crystals with questions, tracked for the teacher.
--
-- Structures come from structures.lua (one block per atom, scale 2); content.lua holds the text.

local cm = crystalminer
local content, S = cm.content, cm.S
local M = dofile(core.get_modpath("crystalminer") .. "/structures.lua")
local say = cm.say

local MU = content.museum
local AT, SIZE = MU.at, MU.size
local box = { min = { AT[1], AT[2], AT[3] }, size = SIZE }
cm.extra_boxes[#cm.extra_boxes + 1] = box

local function inside_museum(p)
	return p.x >= AT[1] and p.x < AT[1] + SIZE[1] and p.z >= AT[3] and p.z < AT[3] + SIZE[3]
		and p.y >= AT[2] - 1 and p.y < AT[2] + SIZE[2]
end

---------------------------------------------------------------------------- layout

--- Where each exhibit's model sits: corner (x0, y0, z0), size, centre and clue position.
local function layout()
	local out = {}
	for i, ex in ipairs(MU.exhibits) do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local size = 2 * ex.n + 1
		local sx, sz = AT[1] + 4 + col * 23, AT[3] + 8 + row * 26
		local x0, z0 = sx + math.floor((19 - size) / 2), sz
		out[i] = {
			ex = ex, x0 = x0, y0 = AT[2] + 1, z0 = z0, size = size,
			centre = { x = x0 + ex.n, y = AT[2] + 1 + ex.n, z = z0 + ex.n },
			clue = { x = x0 + ex.n, y = AT[2], z = z0 - 3 },
		}
	end
	return out
end
local EXHIBITS = layout()

--- The words on an exhibit's panel.
local function exhibit_text(ex)
	return "# " .. ex.name .. "\n" .. table.concat(ex.facts, " ")
end
cm.exhibit_text = exhibit_text
cm.museum_layout = EXHIBITS

---------------------------------------------------------------------------- nodes

local pending_clue = {}

local function clue_formspec(ex, feedback)
	local c = ex.clue
	local fs = { "formspec_version[4]size[11,", 3.2 + (feedback and 1 or 0) + 0.95 * #c.options, "]",
		"position[0.5,0.97]anchor[0.5,1]bgcolor[#1E2433E6;false]",
		"label[0.4,0.5;", core.formspec_escape("Clue crystal: " .. ex.name), "]",
		"textarea[0.4,0.9;10.2,1.2;;;", core.formspec_escape(c.q), "]" }
	local y = 2.2
	if feedback then
		fs[#fs + 1] = "textarea[0.4," .. y .. ";10.2,0.9;;;" .. core.formspec_escape(feedback) .. "]"
		y = y + 1
	end
	for i, opt in ipairs(c.options) do
		fs[#fs + 1] = "button[0.4," .. y .. ";10.2,0.8;c_" .. (i - 1) .. ";" .. core.formspec_escape(opt) .. "]"
		y = y + 0.95
	end
	return table.concat(fs)
end

local function exhibit_by_id(id)
	for _, e in ipairs(EXHIBITS) do if e.ex.id == id then return e.ex end end
end

local function open_clue(name, pos)
	local id = core.get_meta(pos):get_string("exhibit")
	local ex = exhibit_by_id(id)
	if not ex then return end
	pending_clue[name] = id
	core.show_formspec(name, "crystalminer:clue", clue_formspec(ex))
end

cm.scenery("clue", "Clue crystal: punch it", "crystalminer_clue.png", {
	drawtype = "glasslike", use_texture_alpha = "blend", paramtype = "light", sunlight_propagates = true,
	light_source = 10,
	on_punch = function(pos, _, puncher) if puncher and puncher:is_player() then open_clue(puncher:get_player_name(), pos) end end,
	on_rightclick = function(pos, _, clicker) if clicker and clicker:is_player() then open_clue(clicker:get_player_name(), pos) end end,
})

cm.scenery("teleporter", "Teleporter: punch it", "crystalminer_teleporter.png", {
	paramtype = "light", light_source = 8,
	on_punch = function(pos, _, puncher)
		if puncher and puncher:is_player() then cm.teleport(puncher:get_player_name(), core.get_meta(pos):get_string("target")) end
	end,
	on_rightclick = function(pos, _, clicker)
		if clicker and clicker:is_player() then cm.teleport(clicker:get_player_name(), core.get_meta(pos):get_string("target")) end
	end,
})

--- Number of clue crystals a player has solved, and the total.
local function discoveries(name)
	local d = cm.progress(name).discoveries or {}
	local n = 0
	for _ in pairs(d) do n = n + 1 end
	return n, #EXHIBITS
end
cm.discoveries = discoveries

--- Records an answer to a clue. Returns true if it was right.
local function answer_clue(name, id, choice)
	local ex = exhibit_by_id(id)
	if not ex then return false end
	if choice ~= ex.clue.answer then return false end
	local p = cm.progress(name)
	p.discoveries = p.discoveries or {}
	local new = not p.discoveries[id]
	p.discoveries[id] = true
	cm.save_progress(name)
	local n, total = discoveries(name)
	say(name, core.colorize("#60FF60", "Discovery! ") .. ex.clue.why)
	if new then say(name, "Clue crystals solved: " .. n .. " of " .. total .. ".", n == total and "#60FF60" or "#A0A0A0") end
	return true
end
cm.answer_clue = answer_clue

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "crystalminer:clue" then return false end
	local name = player:get_player_name()
	local id = pending_clue[name]
	if not id then return true end
	for k in pairs(fields) do
		local choice = k:match("^c_(%d+)$")
		if choice then
			if answer_clue(name, id, tonumber(choice)) then
				cm.sound("crystalminer_right", name)
				pending_clue[name] = nil
				core.close_formspec(name, formname)
			else
				cm.sound("crystalminer_wrong", name)
				core.show_formspec(name, formname, clue_formspec(exhibit_by_id(id),
					"Not quite. Fly close to the model, pick one atom near the middle and count the atoms nearest to it."))
			end
			return true
		end
	end
	pending_clue[name] = nil
	return true
end)

---------------------------------------------------------------------------- building

-- The hall itself is part of the lobby (lobby.lua); here are the exhibits: a pedestal, the model,
-- a framed panel with its facts, and the clue crystal.
local function build_museum()
	cm.load_region({ min = { AT[1], AT[2] - 1, AT[3] }, size = { SIZE[1], SIZE[2] + 1, SIZE[3] } })
	for _, e in ipairs(EXHIBITS) do
		cm.fill(e.x0 - 1, e.x0 + e.size, AT[2], AT[2], e.z0 - 1, e.z0 + e.size, "crystalminer:stone_brick")
		for _, a in ipairs(M.model(e.ex.structure, e.ex.n)) do
			core.set_node({ x = e.x0 + 2 * a[1], y = e.y0 + 2 * a[2], z = e.z0 + 2 * a[3] },
				{ name = "crystalminer:" .. e.ex.colours[a[4]] })
		end
		core.set_node(e.clue, { name = "crystalminer:clue" })
		local meta = core.get_meta(e.clue)
		meta:set_string("exhibit", e.ex.id)
		meta:set_string("infotext", "Clue crystal: " .. e.ex.name .. " (punch it)")
		-- A stand for the panel, beside the clue crystal.
		local sx = e.x0 + 1
		for y = AT[2], AT[2] + 1 do core.set_node({ x = sx, y = y, z = e.clue.z }, { name = "crystalminer:stone_brick" }) end
		cm.SG.on_wall({ x = sx, y = AT[2] + 1.5, z = e.clue.z }, "s", "panel", exhibit_text(e.ex))
		-- A picture of one unit cell on its own stand, west of the panel.
		local px = e.x0 - 3
		core.set_node({ x = px, y = AT[2], z = e.clue.z }, { name = "crystalminer:stone_brick" })
		cm.SG.place_picture({ x = px, y = AT[2] + 1.7, z = e.clue.z - 0.52 }, "s",
			"crystalminer_fig_" .. e.ex.id .. ".png", 3, 2.25)
	end
end

table.insert(cm.on_build, function() build_museum() end)

---------------------------------------------------------------------------- labels, arrival, explanations

table.insert(cm.on_teleport, function(name, id, player)
	if id ~= MU.id then return false end
	-- Just inside Gallery 3, by its doorway from Gallery 1, looking north at the models.
	player:set_pos({ x = 22, y = cm.GROUND_Y + 1, z = AT[3] + 1 })
	player:set_look_horizontal(0)
	player:set_look_vertical(0)
	return true
end)

local told = {}   -- per player: what has been explained during this visit
local timer = 0
core.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer < 1 then return end
	timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local pos = player:get_pos()
		local t = told[name] or {}
		told[name] = t
		if inside_museum(vector.round(pos)) then
			if not t.museum then
				t.museum = true
				cm.show_title(player, MU.name, "Real crystals, one block per atom")
				say(name, "-- " .. MU.name .. " --", "#FFD700")
				for _, l in ipairs(MU.intro) do say(name, l) end
				local n, total = discoveries(name)
				say(name, "Clue crystals solved: " .. n .. " of " .. total .. ".", "#A0A0A0")
			end
			for _, e in ipairs(EXHIBITS) do
				local d = vector.distance(pos, e.centre)
				if d < e.size and not t[e.ex.id] then
					t[e.ex.id] = true
					say(name, "-- " .. e.ex.name .. " --", "#FFD700")
					for _, l in ipairs(e.ex.facts) do say(name, l) end
				end
			end
		elseif t.museum then
			told[name] = {}
		end
	end
end)

core.register_on_leaveplayer(function(player) told[player:get_player_name()] = nil end)

core.register_chatcommand("hunt", {
	description = "Show which clue crystals you have solved",
	func = function(name)
		local d = cm.progress(name).discoveries or {}
		local n, total = discoveries(name)
		say(name, "Clue crystals solved: " .. n .. " of " .. total .. ". They glow gold in the " .. MU.name .. " (/goto " .. MU.id .. ").", "#FFD700")
		for _, e in ipairs(EXHIBITS) do say(name, "  " .. (d[e.ex.id] and "solved " or "open   ") .. e.ex.name) end
		return true
	end,
})
