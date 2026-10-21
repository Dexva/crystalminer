-- Two ways to slow the symmetry down so it can be seen and done, not just watched:
--   /step   : copies appear one at a time, each named ("a quarter turn about the vertical axis").
--   /byhand : the region makes no copies; the player places them and the game checks each one.
-- Students find screw axes and glide planes hardest; both modes work in every region, including
-- the screw and glide halls.

local cm = crystalminer
local S = cm.S
local say = cm.say

local step_on, byhand, huds = {}, {}, {}

local function hud(name, text)
	local player = core.get_player_by_name(name)
	if not player then return end
	if huds[name] then
		if text then player:hud_change(huds[name], "text", text) return end
		player:hud_remove(huds[name])
		huds[name] = nil
		return
	end
	if not text then return end
	huds[name] = player:hud_add({
		hud_elem_type = "text", type = "text", position = { x = 0.5, y = 0.12 }, alignment = { x = 0, y = 0 },
		text = text, number = 0xFFFFFF, size = { x = 1.4 }, z_index = 90,
	})
end

local function key(p) return p.x .. "," .. p.y .. "," .. p.z end

--- Images of a node with plain-words descriptions, the seed's own image first.
local function described_images(live, pos)
	local r = live.region
	local periods = r.cell and { 2 * r.cell[1], 2 * r.cell[2], 2 * r.cell[3] } or nil
	local function cell_of(p)
		if not r.cell then return "" end
		return math.floor((p.x - r.min[1]) / r.cell[1]) .. "," .. math.floor((p.y - r.min[2]) / r.cell[2]) .. ","
			.. math.floor((p.z - r.min[3]) / r.cell[3])
	end
	local seed_cell = cell_of(pos)
	local out = {}
	for _, im in ipairs(S.images(r, pos.x, pos.y, pos.z)) do
		if not (im.x == pos.x and im.y == pos.y and im.z == pos.z) then
			local d = S.describe_op(im.op, periods)
			if r.cell and cell_of(im) ~= seed_cell then
				d = (d == "the block you placed") and "a lattice translation into another unit cell"
					or (d .. ", in another unit cell")
			end
			out[#out + 1] = { x = im.x, y = im.y, z = im.z, text = d }
		end
	end
	return out
end
cm.described_images = described_images

---------------------------------------------------------------------------- step mode

table.insert(cm.on_place, function(name, pos, node)
	if not step_on[name] or byhand[name] then return false end
	local live = cm.region_at(pos)
	if not live then return false end
	local ims = described_images(live, pos)
	local dt = #ims > 12 and 0.25 or 0.7
	hud(name, "Copy 0 of " .. #ims .. ": the block you placed")
	for i, im in ipairs(ims) do
		core.after(i * dt, function()
			-- Stop if the seed was removed meanwhile.
			if core.get_node(pos).name ~= node.name then return end
			core.set_node({ x = im.x, y = im.y, z = im.z }, node)
			hud(name, "Copy " .. i .. " of " .. #ims .. ": " .. im.text)
		end)
	end
	core.after(#ims * dt + 2.5, function() hud(name, nil) end)
	return true
end)

core.register_chatcommand("step", {
	params = "[on|off]",
	description = "Make copies appear one at a time, each with the operation that made it",
	func = function(name, param)
		param = param:trim()
		if param == "" then param = step_on[name] and "off" or "on" end
		step_on[name] = param == "on" or nil
		return true, step_on[name] and "Step mode on: place a block in a region and watch each copy appear, with its name."
			or "Step mode off: copies appear all at once."
	end,
})

---------------------------------------------------------------------------- by-hand mode

local function finish(name, text, colour)
	byhand[name] = nil
	hud(name, nil)
	if text then say(name, text, colour) end
end

local function progress_text(st)
	return "By hand in " .. st.live.area.name .. ": " .. st.found .. " of " .. st.total .. " copies placed"
end

-- First in the list, so a by-hand seed is not taken for a block to predict.
table.insert(cm.on_place, 1, function(name, pos, node)
	local st = byhand[name]
	if not st then return false end
	local live = cm.region_at(pos)
	if not live then return false end
	if not st.seed then
		local ims = described_images(live, pos)
		if #ims == 0 then
			say(name, "This spot is fixed by every operation: there are no copies to place. Try another spot.", "#FFFF60")
			return true
		end
		st.live, st.seed, st.node, st.expected, st.found, st.total = live, pos, node, {}, 0, #ims
		for _, im in ipairs(ims) do st.expected[key(im)] = { pos = { x = im.x, y = im.y, z = im.z }, text = im.text } end
		say(name, "Seed placed. " .. live.area.name .. " (" .. live.symbol .. ") would make " .. #ims
			.. " copies of it. Place them yourself, with the same block. /byhand hint shows one.", "#40C0FF")
		hud(name, progress_text(st))
		return true
	end
	if live ~= st.live then return false end
	local e = st.expected[key(pos)]
	if e and not e.done and node.name == st.node.name then
		e.done = true
		st.found = st.found + 1
		say(name, core.colorize("#60FF60", "Yes: ") .. e.text .. ".")
		if st.found == st.total then
			finish(name, "All " .. st.total .. " copies are in place: you have done what the symmetry " .. st.live.symbol
				.. " does. /byhand starts another.", "#60FF60")
		else
			hud(name, progress_text(st))
		end
	else
		say(name, e and "That is a copy position, but use the same block as your seed." or "No copy belongs there.", "#FF9060")
		core.after(0.8, function()
			if core.get_node(pos).name == node.name then core.remove_node(pos) end
		end)
	end
	return true
end)

table.insert(cm.on_dig, function(name, pos)
	local st = byhand[name]
	if not st or not st.seed then return false end
	if key(pos) == key(st.seed) then
		finish(name, "You removed the seed, so by-hand mode has ended.", "#A0A0A0")
		return true
	end
	local e = st.expected[key(pos)]
	if e and e.done then
		e.done = false
		st.found = st.found - 1
		hud(name, progress_text(st))
	end
	return true
end)

core.register_chatcommand("byhand", {
	params = "[hint|off]",
	description = "Place the copies yourself instead of the region, and have each one checked",
	func = function(name, param)
		param = param:trim()
		if param == "off" then finish(name) return true, "By-hand mode off." end
		if param == "hint" then
			local st = byhand[name]
			if not st or not st.seed then return false, "Start with /byhand, then place a seed block in a region." end
			for _, e in pairs(st.expected) do
				if not e.done then
					core.add_particlespawner({
						amount = 40, time = 3, minpos = vector.subtract(e.pos, 0.4), maxpos = vector.add(e.pos, 0.4),
						minexptime = 0.5, maxexptime = 1, minsize = 2, maxsize = 3, glow = 14,
						texture = "crystalminer_dot.png^[colorize:#FFD700:255", playername = name,
					})
					return true, "One missing copy is sparkling. It comes from " .. e.text .. "."
				end
			end
			return true
		end
		byhand[name] = {}
		hud(name, "By hand: place one seed block in a region")
		return true, "By-hand mode: the next block you place in a region is the seed. Then place its copies yourself."
	end,
})

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	step_on[name], byhand[name], huds[name] = nil, nil, nil
end)

cm.byhand, cm.step_on = byhand, step_on
