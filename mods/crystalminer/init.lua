-- crystalminer: learn symmetry by building in regions that copy everything you place.

local modpath = core.get_modpath("crystalminer")
local S = dofile(modpath .. "/symmetry.lua")
local L = dofile(modpath .. "/lessons.lua")
local content = dofile(modpath .. "/content.lua")
local E = loadfile(modpath .. "/elements.lua")(S)
local Tutor = loadfile(modpath .. "/tutor.lua")(S, content)

-- Must be requested at load time; only granted if the server lists crystalminer in secure.http_mods.
local http = core.request_http_api and core.request_http_api()

local storage = core.get_mod_storage()
local WORLD_VERSION = "1"
local GROUND_Y = 0
local SPAWN = { x = 0, y = 1, z = 5 }

crystalminer = { S = S, L = L, content = content, storage = storage }

---------------------------------------------------------------------------- nodes

local COLOURS = {
	"white", "light_grey", "grey", "black", "brown", "red", "orange", "yellow",
	"lime", "green", "cyan", "light_blue", "blue", "purple", "magenta", "pink",
}

local function title_case(s)
	return (s:gsub("_", " "):gsub("^%l", string.upper))
end

local buildable = {}
for _, c in ipairs(COLOURS) do
	local name = "crystalminer:" .. c
	core.register_node(name, {
		description = title_case(c) .. " block",
		tiles = { "crystalminer_" .. c .. ".png" },
		groups = { dig_immediate = 3, crystalminer_block = 1 },
		is_ground_content = false,
	})
	buildable[#buildable + 1] = name
end
core.register_node("crystalminer:glass", {
	description = "Glass",
	drawtype = "glasslike",
	tiles = { "crystalminer_glass.png" },
	use_texture_alpha = "blend",
	paramtype = "light",
	sunlight_propagates = true,
	groups = { dig_immediate = 3, crystalminer_block = 1 },
	is_ground_content = false,
})
buildable[#buildable + 1] = "crystalminer:glass"

-- Scenery players cannot dig (no dig groups).
local function scenery(name, desc, tile, extra)
	local def = { description = desc, tiles = { tile }, groups = { not_in_creative_inventory = 1 }, is_ground_content = false }
	for k, v in pairs(extra or {}) do def[k] = v end
	core.register_node("crystalminer:" .. name, def)
end
scenery("ground", "Ground", "crystalminer_ground.png")
scenery("dirt", "Dirt", "crystalminer_dirt.png")
scenery("floor", "Region floor", "crystalminer_floor.png")
for i = 0, 4 do scenery("border_" .. i, "Tier " .. i .. " border", "crystalminer_border_" .. i .. ".png") end
scenery("frame", "Region frame", "crystalminer_frame.png", {
	drawtype = "glasslike", use_texture_alpha = "blend", paramtype = "light", sunlight_propagates = true,
})

core.register_item(":", {
	type = "none",
	wield_image = "crystalminer_hand.png",
	wield_scale = { x = 1, y = 1, z = 2.5 },
	range = 12,
	tool_capabilities = {
		full_punch_interval = 0.3,
		max_drop_level = 0,
		groupcaps = { dig_immediate = { times = { [3] = 0 }, uses = 0, maxlevel = 1 } },
	},
})

core.register_alias("mapgen_stone", "crystalminer:dirt")
core.register_alias("mapgen_water_source", "crystalminer:glass")
core.register_alias("mapgen_river_water_source", "crystalminer:glass")

---------------------------------------------------------------------------- flat world

core.set_mapgen_setting("mg_name", "singlenode", true)

local c_ground = core.get_content_id("crystalminer:ground")
local c_dirt = core.get_content_id("crystalminer:dirt")

core.register_on_generated(function(minp, maxp)
	if minp.y > GROUND_Y then return end
	local vm, emin, emax = core.get_mapgen_object("voxelmanip")
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	for z = minp.z, maxp.z do
		for y = minp.y, math.min(maxp.y, GROUND_Y) do
			local vi = area:index(minp.x, y, z)
			local id = (y == GROUND_Y) and c_ground or c_dirt
			for _ = minp.x, maxp.x do
				data[vi] = id
				vi = vi + 1
			end
		end
	end
	vm:set_data(data)
	vm:calc_lighting()
	vm:write_to_map()
end)

---------------------------------------------------------------------------- regions

-- Live regions: area (from content), engine region, dots to draw, symbol shown.
local regions = {}

local function set_symmetry(live, symbol, generators)
	live.region = S.region(L.region_spec(live.area, generators))
	live.symbol = symbol
	live.dots = live.area.hidden and {} or E.dots(live.region)
end

for _, a in ipairs(content.regions) do
	local live = { area = a }
	set_symmetry(live, a.symbol, a.generators)
	regions[#regions + 1] = live
end
crystalminer.regions = regions

local function region_at(pos)
	for _, live in ipairs(regions) do
		if S.contains_pos(live.region, pos.x, pos.y, pos.z) then return live end
	end
end

--- The region a player is in or standing next to.
local function region_near(pos, margin)
	margin = margin or 2
	for _, live in ipairs(regions) do
		local r = live.region
		if pos.x >= r.min[1] - margin - 0.5 and pos.x <= r.min[1] + r.size[1] + margin - 0.5
			and pos.y >= r.min[2] - margin - 2 and pos.y <= r.min[2] + r.size[2] + margin
			and pos.z >= r.min[3] - margin - 0.5 and pos.z <= r.min[3] + r.size[3] + margin - 0.5 then
			return live
		end
	end
end

local function near_gate(pos)
	local g = content.gate.at
	return pos.x >= g[1] - 3 and pos.x <= g[1] + 55 and pos.z >= g[3] - 5 and pos.z <= g[3] + 6
end

---------------------------------------------------------------------------- progress

local function load_progress(name)
	local s = storage:get_string("progress:" .. name)
	local p = s ~= "" and core.deserialize(s) or nil
	return p or L.new_progress()
end

local progress_cache = {}

local function progress(name)
	if not progress_cache[name] then progress_cache[name] = load_progress(name) end
	return progress_cache[name]
end

local function save_progress(name)
	storage:set_string("progress:" .. name, core.serialize(progress(name)))
end

crystalminer.progress = progress

---------------------------------------------------------------------------- building

local function unlocked(name, live)
	return progress(name).tier >= live.area.tier
end

-- Regions above a player's tier are protected: they can look but not build.
local old_is_protected = core.is_protected
function core.is_protected(pos, name)
	local live = region_at(pos)
	if live and name ~= "" and not unlocked(name, live) then return true end
	return old_is_protected(pos, name)
end

core.register_on_protection_violation(function(pos, name)
	local live = region_at(pos)
	if live then
		core.chat_send_player(name, core.colorize("#FF6060", "Locked: reach tier " .. live.area.tier
			.. " to build in " .. live.area.name .. ". Type /quiz to progress."))
	end
end)

local function copy_to_images(pos, node)
	local live = region_at(pos)
	if not live then return end
	for _, im in ipairs(S.images(live.region, pos.x, pos.y, pos.z)) do
		if im.x ~= pos.x or im.y ~= pos.y or im.z ~= pos.z then
			core.set_node({ x = im.x, y = im.y, z = im.z }, node)
		end
	end
end
crystalminer.copy_to_images = copy_to_images

core.register_on_placenode(function(pos, newnode, placer)
	copy_to_images(pos, { name = newnode.name })
	-- Blocks are free: do not take the item from the stack.
	return true
end)

core.register_on_dignode(function(pos)
	copy_to_images(pos, { name = "air" })
end)

-- Blocks are free, so digging does not put them into the inventory.
local old_handle_node_drops = core.handle_node_drops
function core.handle_node_drops(pos, drops, digger)
	if digger and digger:is_player() then return end
	return old_handle_node_drops(pos, drops, digger)
end

---------------------------------------------------------------------------- world construction

local function spawn_label(pos, text)
	core.add_entity(pos, "crystalminer:label", text)
end

core.register_entity("crystalminer:label", {
	initial_properties = {
		visual = "sprite",
		textures = { "crystalminer_blank.png" },
		visual_size = { x = 0.01, y = 0.01 },
		physical = false,
		pointable = false,
		static_save = true,
		nametag = "",
		nametag_color = "#FFD700",
	},
	on_activate = function(self, staticdata)
		self.text = staticdata or ""
		self.object:set_properties({ nametag = self.text })
	end,
	get_staticdata = function(self)
		return self.text
	end,
})

local function build_region(live)
	local r = live.region
	local tier = live.area.tier
	local border = "crystalminer:border_" .. math.min(tier, 4)
	for x = r.min[1] - 1, r.min[1] + r.size[1] do
		for z = r.min[3] - 1, r.min[3] + r.size[3] do
			local edge = x == r.min[1] - 1 or x == r.min[1] + r.size[1] or z == r.min[3] - 1 or z == r.min[3] + r.size[3]
			core.set_node({ x = x, y = GROUND_Y, z = z }, { name = edge and border or "crystalminer:floor" })
		end
	end
	if r.min[2] > GROUND_Y + 1 then
		local x0, x1 = r.min[1] - 1, r.min[1] + r.size[1]
		local y0, y1 = r.min[2] - 1, r.min[2] + r.size[2]
		local z0, z1 = r.min[3] - 1, r.min[3] + r.size[3]
		for x = x0, x1 do
			for y = y0, y1 do
				for z = z0, z1 do
					local n = ((x == x0 or x == x1) and 1 or 0) + ((y == y0 or y == y1) and 1 or 0) + ((z == z0 or z == z1) and 1 or 0)
					if n >= 2 then core.set_node({ x = x, y = y, z = z }, { name = "crystalminer:frame" }) end
				end
			end
		end
	end
	spawn_label({ x = r.min[1] + r.size[1] / 2 - 0.5, y = r.min[2] + r.size[2] + 1.5, z = r.min[3] + r.size[3] / 2 - 0.5 },
		live.area.name .. "\nSymmetry " .. live.symbol .. "\nTier " .. tier)
end

-- A chiral motif: an L on the ground with a post at one end. Offsets from its anchor node.
local MOTIF = { { 0, 0, 0 }, { 1, 0, 0 }, { 2, 0, 0 }, { 2, 0, 1 }, { 0, 1, 0 }, { 0, 2, 0 } }
crystalminer.MOTIF = MOTIF

--- Four displays of the motif and its copy under one operation: A reflection, B 2-fold rotation
-- about a vertical axis, C translation, D inversion. Operations in doubled coordinates.
local function build_gate()
	local g = content.gate.at
	local colours = { "blue", "red", "green", "yellow" }
	for i = 0, 3 do
		local ax = g[1] + 14 * i
		local cx, cy, cz = 2 * ax + 9, 2 * (g[2] + 3), 2 * g[3] + 1
		local o
		if i == 0 then
			o = S.op({ -1, 0, 0, 0, 1, 0, 0, 0, 1 }, { 2 * cx, 0, 0 })
		elseif i == 1 then
			o = S.op({ -1, 0, 0, 0, 1, 0, 0, 0, -1 }, { 2 * cx, 0, 2 * cz })
		elseif i == 2 then
			o = S.op({ 1, 0, 0, 0, 1, 0, 0, 0, 1 }, { 12, 0, 0 })
		else
			o = S.op({ -1, 0, 0, 0, -1, 0, 0, 0, -1 }, { 2 * cx, 2 * cy, 2 * cz })
		end
		for x = ax - 2, ax + 10 do
			for z = g[3] - 4, g[3] + 3 do core.set_node({ x = x, y = GROUND_Y, z = z }, { name = "crystalminer:floor" }) end
		end
		local node = { name = "crystalminer:" .. colours[i + 1] }
		for _, m in ipairs(MOTIF) do
			local p = { x = ax + m[1], y = g[2] + m[2], z = g[3] + m[3] }
			core.set_node(p, node)
			local d = S.apply(o, { 2 * p.x + 1, 2 * p.y + 1, 2 * p.z + 1 })
			core.set_node({ x = (d[1] - 1) / 2, y = (d[2] - 1) / 2, z = (d[3] - 1) / 2 }, node)
		end
		spawn_label({ x = ax + 4, y = g[2] + 7, z = g[3] }, "Display " .. ({ "A", "B", "C", "D" })[i + 1])
	end
	spawn_label({ x = g[1] + 25, y = g[2] + 10, z = g[3] }, "Symmetry Gate\nType /quiz to begin")
end

local world_ready = false
local on_world_ready = {}

local function build_world()
	build_gate()
	for _, live in ipairs(regions) do build_region(live) end
	storage:set_string("world_version", WORLD_VERSION)
	world_ready = true
	for _, f in ipairs(on_world_ready) do f() end
end

core.after(0, function()
	if storage:get_string("world_version") == WORLD_VERSION then
		world_ready = true
		for _, f in ipairs(on_world_ready) do f() end
		return
	end
	-- Generate the part of the map the world uses, then build on it.
	local lo, hi = { x = 1e9, y = GROUND_Y - 1, z = 1e9 }, { x = -1e9, y = GROUND_Y + 1, z = -1e9 }
	local g = content.gate.at
	local boxes = { { min = { g[1] - 4, g[2], g[3] - 6 }, size = { 60, 12, 12 } } }
	for _, live in ipairs(regions) do boxes[#boxes + 1] = live.region end
	for _, b in ipairs(boxes) do
		lo.x, lo.z = math.min(lo.x, b.min[1] - 2), math.min(lo.z, b.min[3] - 2)
		hi.x, hi.z = math.max(hi.x, b.min[1] + b.size[1] + 2), math.max(hi.z, b.min[3] + b.size[3] + 2)
		hi.y = math.max(hi.y, b.min[2] + b.size[2] + 4)
	end
	core.emerge_area(lo, hi, function(_, _, remaining)
		if remaining == 0 then build_world() end
	end)
end)

crystalminer.when_ready = function(f)
	if world_ready then f() else on_world_ready[#on_world_ready + 1] = f end
end

---------------------------------------------------------------------------- messages

local function say(name, text, colour)
	core.chat_send_player(name, colour and core.colorize(colour, text) or text)
end

local function show_title(player, text, subtitle)
	local def = {
		hud_elem_type = "text", type = "text",
		position = { x = 0.5, y = 0.25 }, alignment = { x = 0, y = 0 },
		text = text .. (subtitle and ("\n" .. subtitle) or ""),
		number = 0xFFD700, size = { x = 2 }, z_index = 100,
	}
	local id = player:hud_add(def)
	local pname = player:get_player_name()
	core.after(3.5, function()
		local p = core.get_player_by_name(pname)
		if p then p:hud_remove(id) end
	end)
end

local function welcome(name)
	say(name, "crystalminer", "#40C0FF")
	for _, l in ipairs(content.intro) do say(name, l) end
	say(name, "Commands: /quiz  /explain  /regions  /goto <region>  /progress  /ask <question>  /guide", "#A0A0A0")
end

local function explain(name, live, with_title)
	local player = core.get_player_by_name(name)
	local p = progress(name)
	local a = live.area
	if with_title and player then
		show_title(player, a.name, "Symmetry " .. live.symbol .. (p.tier < a.tier and ("  (locked: tier " .. a.tier .. ")") or ""))
	end
	say(name, "-- " .. a.name .. " (" .. live.symbol .. ") --", "#FFD700")
	if p.tier < a.tier then
		say(name, "You can look around, but building here unlocks at tier " .. a.tier
			.. ". Finish the quizzes of tier " .. p.tier .. " first (/quiz).", "#A0A0A0")
		return
	end
	for _, l in ipairs(L.explanation(a, p.tier)) do say(name, l) end
	if #live.dots > 0 then
		say(name, "Coloured dots: " .. core.colorize(E.COLOURS.axis2, "2-fold ") .. core.colorize(E.COLOURS.axis3, "3-fold ")
			.. core.colorize(E.COLOURS.axis4, "4-fold ") .. core.colorize(E.COLOURS.rotoinversion, "rotoinversion ")
			.. core.colorize(E.COLOURS.mirror, "mirror ") .. core.colorize(E.COLOURS.inversion, "inversion centre"))
	end
	for _, q in ipairs(L.questions(a, p.tier)) do
		if not p.answered[q.id] then
			say(name, "Type /quiz for questions about this region.", "#40C0FF")
			break
		end
	end
end

---------------------------------------------------------------------------- tracking and visuals

local current_area = {}
local timer, dot_timer = 0, 0

core.register_globalstep(function(dtime)
	timer, dot_timer = timer + dtime, dot_timer + dtime
	if timer >= 0.5 then
		timer = 0
		for _, player in ipairs(core.get_connected_players()) do
			local name = player:get_player_name()
			local pos = player:get_pos()
			local live = region_near(pos)
			local id = live and live.area.id or (near_gate(pos) and content.gate.id or "")
			if id ~= current_area[name] then
				current_area[name] = id
				if live then
					explain(name, live, true)
				elseif id == content.gate.id then
					show_title(player, "Symmetry Gate", "Type /quiz to test yourself")
				end
			end
		end
	end
	-- Particles last 2.2 s and are refreshed every 2 s, to keep network traffic down.
	if dot_timer >= 2 then
		dot_timer = 0
		for _, player in ipairs(core.get_connected_players()) do
			local name = player:get_player_name()
			local live = region_near(player:get_pos(), 6)
			if live and #live.dots > 0 and unlocked(name, live) then
				for _, d in ipairs(live.dots) do
					core.add_particle({
						pos = d.pos, velocity = { x = 0, y = 0, z = 0 }, expirationtime = 2.2, size = 1.5,
						texture = "crystalminer_dot.png^[colorize:" .. d.colour .. ":255", glow = 14,
						playername = name,
					})
				end
			end
		end
	end
end)

---------------------------------------------------------------------------- players

core.register_privilege("teacher", { description = "Can change players' tiers", give_to_singleplayer = true })

core.register_on_newplayer(function(player)
	player:set_pos(SPAWN)
end)

core.register_on_respawnplayer(function(player)
	player:set_pos(SPAWN)
	return true
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	local privs = core.get_player_privs(name)
	privs.interact, privs.shout, privs.fly, privs.fast = true, true, true, true
	core.set_player_privs(name, privs)
	local inv = player:get_inventory()
	inv:set_size("main", 32)
	for _, item in ipairs(buildable) do
		if not inv:contains_item("main", item) then inv:add_item("main", item .. " 99") end
	end
	player:set_inventory_formspec("formspec_version[4]size[10.5,6]label[0.4,0.5;Blocks are free: you never run out.]"
		.. "list[current_player;main;0.4,1;8,4;]")
	player:set_look_horizontal(math.pi)
	core.after(1, function() welcome(name) end)
end)

---------------------------------------------------------------------------- quiz

local function quiz_formspec(q)
	local fs = { "formspec_version[4]size[12,", 3.2 + 1 * #q.options, "]",
		"textarea[0.5,0.5;11,2;;;", core.formspec_escape(q.q), "]" }
	for i, opt in ipairs(q.options) do
		fs[#fs + 1] = "button[0.5," .. (2.4 + (i - 1)) .. ";11,0.8;opt_" .. (i - 1) .. ";"
			.. core.formspec_escape(string.char(64 + i) .. ") " .. opt) .. "]"
	end
	return table.concat(fs)
end

local pending_question = {}

local function ask_question(name, q)
	pending_question[name] = q.id
	core.show_formspec(name, "crystalminer:quiz", quiz_formspec(q))
end

local function show_quiz(name)
	local p = progress(name)
	local here = current_area[name] or ""
	local area = p.tier == 0 and content.gate or L.area(content, here)
	if area then
		for _, q in ipairs(L.questions(area, p.tier)) do
			if not p.answered[q.id] then
				ask_question(name, q)
				return
			end
		end
	end
	local open = {}
	for _, a in ipairs(content.regions) do
		for _, q in ipairs(L.questions(a, p.tier)) do
			if not p.answered[q.id] then
				open[#open + 1] = a
				break
			end
		end
	end
	if #open == 0 then
		say(name, "No questions left at your tier.", "#60FF60")
		return
	end
	say(name, "Questions for tier " .. p.tier .. " are waiting in:", "#FFFF60")
	for _, a in ipairs(open) do say(name, "  " .. a.name .. "   (/goto " .. a.id .. ")") end
end
crystalminer.show_quiz = show_quiz

--- Checks an answer. Returns true if correct.
local function answer(name, id, choice)
	local q = L.question(content, id)
	local p = progress(name)
	if not q or p.answered[id] then return false end
	local in_tier = false
	for _, t in ipairs(L.questions_for_tier(content, p.tier)) do
		if t.id == id then in_tier = true end
	end
	if not in_tier then return false end
	if choice ~= q.answer then
		say(name, "Not quite. Look at the copies again and try another option.", "#FF6060")
		return false
	end
	say(name, core.colorize("#60FF60", "Correct! ") .. q.why)
	local before = p.tier
	local levelled = L.record_correct(content, p, id)
	save_progress(name)
	if levelled then
		local player = core.get_player_by_name(name)
		if player then show_title(player, "Tier " .. p.tier .. " unlocked", content.tiers[p.tier]) end
		say(name, "You finished tier " .. before .. ". New regions are open: type /regions.", "#60FF60")
	else
		say(name, L.remaining(content, p) .. " question(s) left in tier " .. p.tier .. ". Type /quiz for the next.", "#A0A0A0")
	end
	return true
end
crystalminer.answer = answer

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "crystalminer:quiz" then return false end
	local name = player:get_player_name()
	local id = pending_question[name]
	if not id then return true end
	for k in pairs(fields) do
		local choice = k:match("^opt_(%d+)$")
		if choice then
			if answer(name, id, tonumber(choice)) then
				pending_question[name] = nil
				core.close_formspec(name, "crystalminer:quiz")
				core.after(0.2, function() show_quiz(name) end)
			else
				ask_question(name, L.question(content, id))
			end
			return true
		end
	end
	pending_question[name] = nil
	return true
end)

---------------------------------------------------------------------------- commands

local function cmd(name, def)
	core.register_chatcommand(name, def)
end

cmd("guide", {
	description = "List what you can do",
	func = function(name)
		local rows = {
			{ "/quiz", "answer questions to unlock the next tier" },
			{ "/explain", "repeat the explanation for the region you are in" },
			{ "/regions", "list all regions" },
			{ "/goto <region>", "teleport to a region" },
			{ "/progress", "see your tier" },
			{ "/ask <question>", "ask the tutor about symmetry" },
			{ "/whatsymmetry", "work out the exact symmetry of what you built in a region" },
			{ "/symmetry <description>", "give the Free Lab a symmetry (tier 4)" },
			{ "/challenge", "get a build challenge for the Free Lab (tier 4)" },
			{ "/clearlab", "empty the Free Lab" },
			{ "/spawn", "go back to the start" },
		}
		for _, r in ipairs(rows) do say(name, core.colorize("#40C0FF", r[1]) .. "  " .. r[2]) end
		say(name, "Press K to fly (with J for fast). Every block in your inventory is free.", "#A0A0A0")
		return true
	end,
})

cmd("quiz", { description = "Answer questions to unlock the next tier", func = function(name) show_quiz(name) return true end })

cmd("explain", {
	description = "Repeat the explanation for this region",
	func = function(name)
		local player = core.get_player_by_name(name)
		local live = player and region_near(player:get_pos())
		if live then explain(name, live, false) else welcome(name) end
		return true
	end,
})

cmd("regions", {
	description = "List all regions",
	func = function(name)
		local tier = progress(name).tier
		say(name, "Regions (you are tier " .. tier .. "). Teleport with /goto <id>:", "#FFD700")
		say(name, "  " .. content.gate.id .. ": Symmetry Gate (tier 0)")
		for _, live in ipairs(regions) do
			local a = live.area
			local line = "  " .. a.id .. ": " .. a.name .. " (" .. live.symbol .. ", tier " .. a.tier .. ")"
			say(name, line, tier >= a.tier and nil or "#707070")
		end
		return true
	end,
})

local function teleport(name, id)
	local player = core.get_player_by_name(name)
	if not player then return false, "Not in game." end
	if id == content.gate.id then
		player:set_pos(SPAWN)
		player:set_look_horizontal(math.pi)
		return true
	end
	for _, live in ipairs(regions) do
		if live.area.id == id then
			local r = live.region
			-- Stand just south of the region, looking north into it.
			player:set_pos({ x = r.min[1] + r.size[1] / 2 - 0.5, y = GROUND_Y + 1, z = r.min[3] - 4 })
			player:set_look_horizontal(0)
			return true
		end
	end
	return false, "No region called " .. id .. ". Type /regions for the list."
end

cmd("goto", { params = "<region>", description = "Teleport to a region", func = function(name, param) return teleport(name, param:trim()) end })
cmd("spawn", { description = "Go back to the start", func = function(name) return teleport(name, content.gate.id) end })

cmd("progress", {
	description = "Show your tier",
	func = function(name)
		local p = progress(name)
		return true, "Tier " .. p.tier .. ": " .. (content.tiers[p.tier] or "") .. ". "
			.. L.remaining(content, p) .. " question(s) left in this tier."
	end,
})

cmd("settier", {
	params = "<tier> [player]",
	description = "Set a player's tier (teachers)",
	privs = { teacher = true },
	func = function(name, param)
		local t, who = param:match("^(%d+)%s*(%S*)$")
		t = tonumber(t)
		if not t or t > L.max_tier(content) then return false, "Usage: /settier <0-" .. L.max_tier(content) .. "> [player]" end
		who = (who and who ~= "") and who or name
		progress(who).tier = t
		save_progress(who)
		return true, who .. " is now tier " .. t .. "."
	end,
})

---------------------------------------------------------------------------- symmetry analysis and the Free Lab

--- Exact point symmetry of everything built in a region: group, catalog entry (nil if empty).
local function analyse(live)
	local r = live.region
	local nodes, any = {}, false
	for x = r.min[1], r.min[1] + r.size[1] - 1 do
		for y = r.min[2], r.min[2] + r.size[2] - 1 do
			for z = r.min[3], r.min[3] + r.size[3] - 1 do
				local n = core.get_node({ x = x, y = y, z = z }).name
				if n ~= "air" and n ~= "ignore" then
					nodes[(2 * x + 1) .. "," .. (2 * y + 1) .. "," .. (2 * z + 1)] = n
					any = true
				end
			end
		end
	end
	if not any then return nil end
	return S.detect(nodes)
end
crystalminer.analyse = analyse

local function whatsymmetry(name)
	local player = core.get_player_by_name(name)
	local live = player and region_near(player:get_pos())
	if not live then return false, "Stand in or next to a region first." end
	local g, entry = analyse(live)
	if not g then return true, "Nothing built here yet." end
	local symbol = entry and entry.symbol or "?"
	say(name, "Your build has point symmetry " .. symbol .. " (" .. #g.ops .. " operation" .. (#g.ops == 1 and "" or "s") .. ").", "#FFD700")
	say(name, S.describe(g))
	local cs = live.area.challenges
	local p = progress(name)
	if cs and cs[p.challenge] then
		local c = cs[p.challenge]
		if c.target == symbol then
			say(name, "Challenge complete: " .. c.text, "#60FF60")
			p.challenge = p.challenge + 1
			save_progress(name)
			say(name, "Type /challenge for the next one.", "#A0A0A0")
		else
			say(name, "Your challenge wants " .. c.target .. ".", "#FFFF60")
		end
	end
	return true
end

cmd("whatsymmetry", { description = "Work out the exact symmetry of your build", func = whatsymmetry })

local function free_lab(name)
	for _, live in ipairs(regions) do
		if live.area.free then
			if progress(name).tier < live.area.tier then
				return nil, "The Free Lab unlocks at tier " .. live.area.tier .. "."
			end
			return live
		end
	end
	return nil, "There is no Free Lab in this world."
end

local function apply_symmetry(name, live, symbol, reason)
	if symbol:lower() == "none" then
		say(name, "That does not match any of the 32 crystallographic point groups. "
			.. "Crystals can only have 1-, 2-, 3-, 4- and 6-fold rotation axes.", "#FFFF60")
		return
	end
	local e = S.point_group(symbol)
	if not e then
		say(name, "'" .. symbol .. "' is not a crystallographic point group.", "#FF6060")
		return
	end
	if reason then say(name, core.colorize("#D080FF", "Tutor: ") .. reason) end
	if not S.fits_grid(e.group) then
		local sig = S.signature(e.group)
		say(name, e.symbol .. " is a real crystal symmetry, but it cannot be built here: it needs a "
			.. (sig["6"] and "6-fold" or "-6") .. " axis, and turning a square grid by 60 degrees moves grid "
			.. "points off the grid. Hexagonal crystals need a hexagonal lattice.", "#FFFF60")
		return
	end
	set_symmetry(live, e.symbol, e.generators)
	say(name, "The Free Lab now has symmetry " .. e.symbol .. " (" .. #e.group.ops .. " operations, " .. e.system .. ").", "#60FF60")
	say(name, S.describe(e.group))
	say(name, "Blocks already in the lab were not changed. /clearlab empties it.", "#A0A0A0")
end
crystalminer.apply_symmetry = apply_symmetry

local api_key = core.settings:get("crystalminer.anthropic_api_key")
if not api_key or api_key == "" then api_key = os.getenv("ANTHROPIC_API_KEY") end
local tutor_on = http ~= nil and api_key ~= nil and api_key ~= ""
local waiting = {}

if not tutor_on then
	core.log("action", "[crystalminer] Tutor off: " .. (http and "no API key set" or "add crystalminer to secure.http_mods"))
end

cmd("symmetry", {
	params = "<description>",
	description = "Give the Free Lab a symmetry, e.g. /symmetry a fourfold axis with mirrors",
	func = function(name, param)
		local live, err = free_lab(name)
		if not live then return false, err end
		param = param:trim()
		if param == "" then return false, "Usage: /symmetry <description or symbol>" end
		-- A symbol works without the tutor.
		if S.point_group(param) or param:lower() == "none" or not tutor_on then
			apply_symmetry(name, live, param, nil)
			return true
		end
		if waiting[name] then return false, "The tutor is still thinking." end
		waiting[name] = true
		say(name, "Working out which symmetry you mean...", "#A0A0A0")
		Tutor.send(http, api_key, Tutor.symmetry_body(param), core.write_json, core.parse_json, function(text, err2)
			waiting[name] = nil
			local choice = text and core.parse_json(text)
			if type(choice) ~= "table" or type(choice.symbol) ~= "string" then
				say(name, err2 or "The tutor could not read that. Try a point-group symbol, like /symmetry 4mm.", "#FF6060")
				return
			end
			apply_symmetry(name, live, choice.symbol, choice.reason)
		end)
		return true
	end,
})

cmd("ask", {
	params = "<question>",
	description = "Ask the tutor about symmetry",
	func = function(name, param)
		if not tutor_on then return false, "The tutor is not set up on this server. See the README." end
		param = param:trim()
		if param == "" then return false, "Usage: /ask <your question>" end
		if waiting[name] then return false, "The tutor is still thinking about your last question." end
		waiting[name] = true
		local player = core.get_player_by_name(name)
		local live = player and region_near(player:get_pos())
		say(name, "You asked: " .. param, "#A0A0A0")
		Tutor.send(http, api_key, Tutor.ask_body(param, progress(name).tier, live and live.area.name),
			core.write_json, core.parse_json, function(text, err)
				waiting[name] = nil
				say(name, core.colorize("#D080FF", "Tutor: ") .. (text or err))
			end)
		return true
	end,
})

cmd("challenge", {
	description = "Get a build challenge for the Free Lab",
	func = function(name)
		local live, err = free_lab(name)
		if not live then return false, err end
		local cs, i = live.area.challenges or {}, progress(name).challenge
		if not cs[i] then return true, "You have completed every challenge!" end
		say(name, "Challenge " .. i .. "/" .. #cs .. ": " .. cs[i].text, "#FFFF60")
		say(name, "Build it in the Free Lab (/symmetry 1 lets you build without copies), then type /whatsymmetry.", "#A0A0A0")
		return true
	end,
})

cmd("clearlab", {
	description = "Empty the Free Lab",
	func = function(name)
		local live, err = free_lab(name)
		if not live then return false, err end
		local r = live.region
		for x = r.min[1], r.min[1] + r.size[1] - 1 do
			for y = r.min[2], r.min[2] + r.size[2] - 1 do
				for z = r.min[3], r.min[3] + r.size[3] - 1 do core.set_node({ x = x, y = y, z = z }, { name = "air" }) end
			end
		end
		return true, "The Free Lab is empty."
	end,
})

---------------------------------------------------------------------------- self-test (used by tests/run_server_test.sh)

if core.settings:get_bool("crystalminer.selftest", false) then
	dofile(modpath .. "/selftest.lua")
end
