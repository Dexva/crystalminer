-- The visitor tour: about ten minutes through the ideas that matter most, for open days, museums
-- and anyone without a teacher. /tour starts it, /tour next and /tour back move between stops, and
-- /tour end stops it. During the tour, visitors may build in the regions the tour visits.

local cm = crystalminer
local STOPS = cm.content.tour

local state = {}   -- per player: { i = stop index, hud = { bg, text } }
local stop_regions = {}
for _, s in ipairs(STOPS) do stop_regions[s.at] = true end

local function clear_hud(name)
	local st = state[name]
	local player = core.get_player_by_name(name)
	if st and st.hud and player then
		player:hud_remove(st.hud.bg)
		player:hud_remove(st.hud.text)
	end
	if st then st.hud = nil end
end

local function wrap(text, width)
	local lines, line = {}, ""
	for word in text:gmatch("%S+") do
		if #line + #word + 1 > width and line ~= "" then
			lines[#lines + 1] = line
			line = word
		else
			line = line == "" and word or (line .. " " .. word)
		end
	end
	if line ~= "" then lines[#lines + 1] = line end
	return table.concat(lines, "\n")
end
cm.wrap = wrap

local function show_stop(name)
	local st = state[name]
	local player = core.get_player_by_name(name)
	if not st or not player then return end
	local stop = STOPS[st.i]
	cm.teleport(name, stop.at)
	clear_hud(name)
	local nav = st.i < #STOPS and "/tour next: go on    /tour back: go back    /tour end: stop"
		or "Last stop. /tour back: go back    /tour end: finish the tour"
	st.hud = {
		bg = player:hud_add({
			hud_elem_type = "image", type = "image", position = { x = 0.5, y = 0.8 }, alignment = { x = 0, y = 0 },
			scale = { x = -46, y = -13 }, text = "crystalminer_hud_bg.png", z_index = 80,
		}),
		text = player:hud_add({
			hud_elem_type = "text", type = "text", position = { x = 0.5, y = 0.8 }, alignment = { x = 0, y = 0 },
			number = 0xFFFFFF, z_index = 81,
			text = "Tour, stop " .. st.i .. " of " .. #STOPS .. ": " .. stop.title .. "\n\n" .. wrap(stop.text, 70) .. "\n\n" .. nav,
		}),
	}
end

table.insert(cm.unlock_override, function(name, live)
	return state[name] ~= nil and stop_regions[live.area.id] == true
end)

core.register_chatcommand("tour", {
	params = "[next|back|end]",
	description = "A ten-minute guided tour for visitors",
	func = function(name, param)
		param = param:trim()
		if param == "" or param == "start" then
			state[name] = state[name] or {}
			clear_hud(name)
			state[name].i = 1
			show_stop(name)
			return true
		end
		local st = state[name]
		if not st then return false, "Type /tour to start the tour." end
		if param == "next" then
			if st.i >= #STOPS then return true, "This is the last stop. /tour end finishes the tour." end
			st.i = st.i + 1
		elseif param == "back" then
			st.i = math.max(1, st.i - 1)
		elseif param == "end" then
			clear_hud(name)
			state[name] = nil
			return true, "Tour finished. Keep exploring: press I for your progress board, or type /guide."
		else
			return false, "Usage: /tour, /tour next, /tour back or /tour end"
		end
		show_stop(name)
		return true
	end,
})

core.register_on_leaveplayer(function(player) state[player:get_player_name()] = nil end)
cm.tour_state = state
