-- The "Next:" line: one short sentence above the hotbar that says what to do next, worked out from
-- the player's progress (tier, answered questions) and the quiz definitions. /hint off hides it.
--
-- H.text is pure (no Luanti calls), so the unit tests (tests/test_next_hint.lua) can call it with a
-- fake progress table; the rest of the file runs only inside the game.

local H = {}

H.GATE_GO = "Next: answer the quiz in Gallery 1 (type /quiz there)"
H.GATE_HERE = "Next: look at displays A to D, then type /quiz"
H.WORLD_HERE = "Next: build here, then type /quiz"
H.PORTAL = "Next: go to the Portal Hall and open "   -- .. the world's name
H.TRYIT = "(Optional first: the Try-it Pad, /goto tryit_pad)"
H.DONE = "You have finished every tier. Try the Free Lab or /tour."

local function has_open(L, area, p)
	for _, q in ipairs(L.questions(area, p.tier)) do
		if not p.answered[q.id] then return true end
	end
	return false
end

--- The hint for progress p = { tier, answered = { [id] = true }, guided?, visited? } of a player
--- standing in area id `here` ("" or nil: nowhere in particular). Returns a string, or nil when
--- there is nothing to suggest.
function H.text(content, L, p, here)
	local answered = p.answered or {}
	p = { tier = p.tier or 0, answered = answered, guided = p.guided or {}, visited = p.visited or {} }
	local gate = content.gate
	-- The first area (the Gate, then the regions in their order) with a question still open at the
	-- player's tier: the same questions L.remaining counts to raise the tier.
	local first, here_open = nil, false
	for _, a in ipairs(L.areas(content)) do
		if has_open(L, a, p) then
			first = first or a
			if a.id == here then here_open = true end
		end
	end
	if not first then
		if p.tier >= L.max_tier(content) then return H.DONE end
		return nil
	end
	if first.id == gate.id then
		return here == gate.id and H.GATE_HERE or H.GATE_GO
	end
	if here_open and here ~= gate.id then return H.WORLD_HERE end
	local line = H.PORTAL .. first.name
	local gate_done = not has_open(L, gate, { tier = 0, answered = answered })
	local pad = content.tryit.id
	if gate_done and not p.visited[pad] and not p.guided[pad] then line = line .. "\n" .. H.TRYIT end
	return line
end

if not (rawget(_G, "core") and rawget(_G, "crystalminer")) then return H end

---------------------------------------------------------------------------- in the game

local cm = crystalminer
local content, L = cm.content, cm.L
cm.next_hint = H

-- Above the hotbar, where the health and breath bars would be (init.lua turns those off): the
-- builtin bars sit at offset y = -(48 + 24 + 16) = -88 from the bottom centre, just above the
-- hotbar. The text grows upwards from there (alignment y = -1). Offsets are scaled with the HUD,
-- like the builtin bars, so the gap to the hotbar stays the same at any hud_scaling.
-- Clear of: the stereogram (bottom right; its caption reaches about 80 px up), the arrival titles
-- (y = 0.25) and the /step line (y = 0.12). The visitor tour has its own panel at y = 0.8, so
-- the hint is hidden during the tour.
local HUD_DEF = {
	hud_elem_type = "text", type = "text",
	position = { x = 0.5, y = 1 }, alignment = { x = 0, y = -1 }, offset = { x = 0, y = -88 },
	number = 0xFFE680, z_index = 20,
}

local huds = {}   -- name -> { id = HUD id, text = text shown }

local function remove(player, name)
	if huds[name] then
		player:hud_remove(huds[name].id)
		huds[name] = nil
	end
end

--- Recomputes and shows (or hides) the player's hint.
function cm.update_hint(name)
	local player = core.get_player_by_name(name)
	if not player then return end
	local p = cm.progress(name)
	local touring = cm.tour_state and cm.tour_state[name] ~= nil
	local text = (not p.hint_off and not touring) and H.text(content, L, p, cm.current_area[name] or "") or nil
	if not text then return remove(player, name) end
	local cur = huds[name]
	if cur then
		if cur.text ~= text then
			player:hud_change(cur.id, "text", text)
			cur.text = text
		end
		return
	end
	local def = {}
	for k, v in pairs(HUD_DEF) do def[k] = v end
	def.text = text
	huds[name] = { id = player:hud_add(def), text = text }
end

table.insert(cm.on_join, function(name) cm.update_hint(name) end)
table.insert(cm.on_levelled, function(name) cm.update_hint(name) end)
table.insert(cm.on_area, function(name, id)
	if id == content.tryit.id then
		local p = cm.progress(name)
		p.visited = p.visited or {}
		if not p.visited[id] then
			p.visited[id] = true
			cm.save_progress(name)
		end
	end
	-- After the other on_area hooks have run (this runs inside the area tracker's loop).
	core.after(0, cm.update_hint, name)
end)

-- Answers to single questions have no hook (init.lua's answer() is local), so the hint is also
-- refreshed every 2 seconds; it only sends anything when the text changes.
local poll = 0
core.register_globalstep(function(dtime)
	poll = poll + dtime
	if poll < 2 then return end
	poll = 0
	for _, player in ipairs(core.get_connected_players()) do cm.update_hint(player:get_player_name()) end
end)

core.register_on_leaveplayer(function(player) huds[player:get_player_name()] = nil end)

core.register_chatcommand("hint", {
	params = "[on|off]",
	description = "Show or hide the \"Next:\" line above the hotbar",
	func = function(name, param)
		param = param:trim()
		local p = cm.progress(name)
		if param == "off" then
			p.hint_off = true
		elseif param == "on" then
			p.hint_off = nil
		elseif param ~= "" then
			return false, "Usage: /hint on or /hint off"
		else
			local text = H.text(content, L, p, cm.current_area[name] or "")
			return true, (text or "Explore, or type /guide.") .. (p.hint_off and "  (/hint on shows this above the hotbar)" or "")
		end
		cm.save_progress(name)
		cm.update_hint(name)
		return true, p.hint_off and "Hint line hidden. /hint on shows it again." or "Hint line shown."
	end,
})

return H
