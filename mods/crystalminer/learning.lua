-- Measuring and supporting learning at run time: the pre- and post-test, predictions before the
-- copies appear, the teacher's class view and data export. The logic is in assess.lua.

local cm = crystalminer
local S, L, content, storage = cm.S, cm.L, cm.content, cm.storage
local A = dofile(core.get_modpath("crystalminer") .. "/assess.lua")
cm.A = A

local ITEMS = content.assessment.items
local say = cm.say

---------------------------------------------------------------------------- records

local records = {}

local function new_id()
	local r = PcgRandom(core.get_us_time() % 2147483647)
	return string.format("%04x%04x", r:next(0, 65535), r:next(0, 65535))
end

local function record(name)
	if not records[name] then
		local s = storage:get_string("assess:" .. name)
		records[name] = (s ~= "" and core.deserialize(s)) or A.new(new_id())
	end
	return records[name]
end
cm.record = record

local function save_record(name)
	storage:set_string("assess:" .. name, core.serialize(record(name)))
end

--- Every stored record, keyed by player name (names never leave this function's callers' scope).
local function all_records()
	local out = {}
	for key, value in pairs(storage:to_table().fields) do
		local who = key:match("^assess:(.+)$")
		if who then out[who] = records[who] or core.deserialize(value) end
	end
	for who, rec in pairs(records) do out[who] = rec end
	return out
end
cm.all_records = all_records

---------------------------------------------------------------------------- pre- and post-test

local testing = {}

local function test_formspec(phase, it, k)
	local fs = { "formspec_version[4]size[16,", 4.1 + 0.95 * #it.options, "]",
		"label[0.4,0.5;", core.formspec_escape((phase == "pre" and "Before you start" or "Now that you have played")
			.. ": question " .. k .. " of " .. #ITEMS), "]",
		"textarea[0.4,0.9;15.2,2.4;;;", core.formspec_escape(it.q), "]" }
	local y = 3.4
	for i, opt in ipairs(it.options) do
		fs[#fs + 1] = "button[0.4," .. y .. ";15.2,0.8;opt_" .. (i - 1) .. ";" .. core.formspec_escape(opt) .. "]"
		y = y + 0.95
	end
	return table.concat(fs)
end

local function show_next_item(name)
	local st = testing[name]
	if not st then return end
	local rec = record(name)
	local it = A.next_item(rec, st.phase, ITEMS)
	if not it then
		testing[name] = nil
		core.close_formspec(name, "crystalminer:test")
		local score = A.score(rec, st.phase, ITEMS)
		if st.phase == "pre" then
			say(name, "Thank you! Now explore. You will see these questions again at the end.", "#60FF60")
		else
			local pre = A.score(rec, "pre", ITEMS)
			say(name, "Thank you! At the start you got " .. pre .. " of " .. #ITEMS .. "; now " .. score .. " of " .. #ITEMS .. ".", "#60FF60")
		end
		return
	end
	local k = 1
	for i, x in ipairs(ITEMS) do if x.id == it.id then k = i end end
	st.item = it.id
	core.show_formspec(name, "crystalminer:test", test_formspec(st.phase, it, k))
end

local function intro_formspec(phase)
	local lines = phase == "pre" and content.assessment.intro or content.assessment.post_intro
	return "formspec_version[4]size[14,6.4]textarea[0.4,0.4;13.2,4.4;;;"
		.. core.formspec_escape(table.concat(lines, "\n\n")) .. "]"
		.. "button[0.4,5.2;6.4,0.8;start;Start]button[7.2,5.2;6.4,0.8;later;Not now (/pretest later)]"
end

local function offer_test(name, phase)
	testing[name] = { phase = phase, intro = true }
	core.show_formspec(name, "crystalminer:test", intro_formspec(phase))
end
cm.offer_test = offer_test

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "crystalminer:test" then return false end
	local name = player:get_player_name()
	local st = testing[name]
	if not st then return true end
	if st.intro then
		if fields.start then
			st.intro = false
			show_next_item(name)
		else
			-- A plain button leaves the window open in the client; close it.
			testing[name] = nil
			core.close_formspec(name, "crystalminer:test")
			say(name, "You can take the questions later with /" .. (st.phase == "pre" and "pretest" or "posttest") .. ".", "#A0A0A0")
		end
		return true
	end
	for k in pairs(fields) do
		local choice = k:match("^opt_(%d+)$")
		if choice then
			A.answer(record(name), st.phase, ITEMS, st.item, tonumber(choice), os.time())
			save_record(name)
			show_next_item(name)
			return true
		end
	end
	-- Closed with Escape: keep what was answered; the rest can be finished later.
	testing[name] = nil
	return true
end)

table.insert(cm.on_join, function(name)
	if core.settings:get_bool("crystalminer.pretest", true) and not A.complete(record(name), "pre", ITEMS)
		and cm.progress(name).tier == 0 then
		core.after(2, function()
			if core.get_player_by_name(name) then offer_test(name, "pre") end
		end)
	end
end)

table.insert(cm.on_levelled, function(name)
	if cm.progress(name).tier == L.max_tier(content) and not A.complete(record(name), "post", ITEMS) then
		core.after(4, function()
			if core.get_player_by_name(name) then offer_test(name, "post") end
		end)
	end
end)

core.register_chatcommand("pretest", {
	description = "Answer the questions from the start of the game",
	func = function(name)
		if A.complete(record(name), "pre", ITEMS) then return true, "You have already answered these. /posttest asks them again at the end." end
		offer_test(name, "pre")
		return true
	end,
})

core.register_chatcommand("posttest", {
	description = "Answer the questions again, now that you have played",
	func = function(name)
		if not A.complete(record(name), "pre", ITEMS) then return false, "Take /pretest first, so there is something to compare with." end
		if A.complete(record(name), "post", ITEMS) then return true, "You have already answered the questions at the end. Thank you!" end
		offer_test(name, "post")
		return true
	end,
})

---------------------------------------------------------------------------- predict before you see

-- The first block a player places in a region waits until they predict how many blocks there
-- will be. The true count comes from the engine for that exact spot, so a block on a symmetry
-- element (fewer copies) is handled correctly, and the explanation says why.
local pending = {}
local predict_disabled = {}

--- Count for a node: distinct images, group operations per cell, number of cells.
local function counts(live, pos)
	local r = live.region
	local n = #S.images(r, pos.x, pos.y, pos.z)
	local ops = #r.group.ops
	local cells = 1
	if r.cell then cells = (r.size[1] / r.cell[1]) * (r.size[2] / r.cell[2]) * (r.size[3] / r.cell[3]) end
	return n, ops, cells
end
cm.counts = counts

local function wants_prediction(name, live)
	if predict_disabled[name] or live.area.free or live.area.hidden then return false end
	if #live.region.group.ops == 1 and not live.region.cell then return false end
	local p = cm.progress(name)
	p.predicted = p.predicted or {}
	return not p.predicted[live.area.id]
end

local function predict_formspec(options)
	local fs = { "formspec_version[4]size[11,3.6]position[0.5,0.97]anchor[0.5,1]bgcolor[#1E2433E6;false]",
		"textarea[0.4,0.35;10.2,1.4;;;", core.formspec_escape("This place copies every block you build. Guess before "
			.. "you look: how many blocks will there be in all, counting the one you just placed?"), "]" }
	local w = 10.2 / #options
	for i, n in ipairs(options) do
		fs[#fs + 1] = "button[" .. (0.4 + (i - 1) * w) .. ",2;" .. (w - 0.15) .. ",0.9;n_" .. n .. ";" .. n .. "]"
	end
	return table.concat(fs)
end

table.insert(cm.on_place, function(name, pos, node)
	local live = cm.region_at(pos)
	if not live or not wants_prediction(name, live) then return false end
	local n, ops, cells = counts(live, pos)
	pending[name] = { pos = pos, node = node, live = live, n = n, ops = ops, cells = cells,
		options = A.count_options(n, ops * cells) }
	core.show_formspec(name, "crystalminer:predict_count", predict_formspec(pending[name].options))
	return true
end)

local function explain_count(name, pd, guess)
	local symbol = pd.live.symbol
	if guess then
		say(name, guess == pd.n and core.colorize("#60FF60", "Right: " .. pd.n .. " blocks.")
			or core.colorize("#FF9060", "You predicted " .. guess .. "; there are " .. pd.n .. "."))
	end
	local full = pd.ops * pd.cells
	if pd.cells > 1 then
		if pd.n == full then
			say(name, "This place has " .. pd.ops .. " symmetry move(s) (" .. symbol .. ") in each of its " .. pd.cells
				.. " boxes, and each one makes a copy: " .. pd.ops .. " x " .. pd.cells .. " = " .. full .. ".")
		else
			say(name, "This place has " .. pd.ops .. " symmetry move(s) in each of its " .. pd.cells .. " boxes, but your "
				.. "block sits right on a pole, mirror or centre point, so some copies land on top of each other: "
				.. pd.n .. " different places.")
		end
	elseif pd.n == pd.ops then
		say(name, "This place has " .. pd.ops .. " symmetry moves (" .. symbol .. "), and each one puts a copy in a "
			.. "different place.")
	else
		say(name, "This place has " .. pd.ops .. " symmetry moves (" .. symbol .. "), but your block sits right on a "
			.. "pole, mirror or centre point, so some copies land on top of each other: " .. pd.n
			.. " different places. Try a block further from the middle.")
	end
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "crystalminer:predict_count" then return false end
	local name = player:get_player_name()
	local pd = pending[name]
	pending[name] = nil
	if not pd then return true end
	local guess
	for k in pairs(fields) do
		local n = k:match("^n_(%d+)$")
		if n then guess = tonumber(n) end
	end
	core.close_formspec(name, formname)
	-- The copies appear whether or not a prediction was made.
	if core.get_node(pd.pos).name == pd.node.name then cm.copy_to_images(pd.pos, pd.node) end
	local p = cm.progress(name)
	p.predicted = p.predicted or {}
	p.predicted[pd.live.area.id] = true
	cm.save_progress(name)
	if guess then
		A.record_prediction(record(name), pd.live.area.id, guess, pd.n, pd.ops * pd.cells, os.time())
		save_record(name)
	end
	explain_count(name, pd, guess)
	return true
end)

core.register_chatcommand("predict", {
	params = "[on|off]",
	description = "Predict again in this region (or turn predictions on or off)",
	func = function(name, param)
		param = param:trim()
		if param == "off" then predict_disabled[name] = true return true, "Predictions off." end
		if param == "on" then predict_disabled[name] = nil return true, "Predictions on." end
		local player = core.get_player_by_name(name)
		local live = player and cm.region_near(player:get_pos())
		if not live then return false, "Stand in a region first." end
		local p = cm.progress(name)
		p.predicted = p.predicted or {}
		p.predicted[live.area.id] = nil
		predict_disabled[name] = nil
		return true, "Place a block in " .. live.area.name .. " and predict how many there will be."
	end,
})

---------------------------------------------------------------------------- teacher: class view and export

local function prediction_stats(rec)
	local right = 0
	for _, p in ipairs(rec.predictions) do if p.guess == p.actual then right = right + 1 end end
	return right, #rec.predictions
end

core.override_chatcommand("class", {
	func = function(name)
		local rows = cm.class_rows()
		local recs = all_records()
		local fs = { "formspec_version[4]size[14,9.6]label[0.4,0.5;Class progress (" .. #rows .. " players)]",
			"tablecolumns[text;text,align=center;text,align=center;text,align=center;text,align=center;text,align=center;text,align=center;text]",
			"table[0.4,1;13.2,7.2;class;Name,Tier,Answered,Pre-test,Post-test,Predictions right,Discoveries,Online" }
		for _, r in ipairs(rows) do
			local rec = recs[r.name]
			local pre, post, pred = "", "", ""
			if rec then
				if A.complete(rec, "pre", ITEMS) then pre = A.score(rec, "pre", ITEMS) .. "/" .. #ITEMS end
				if A.complete(rec, "post", ITEMS) then post = A.score(rec, "post", ITEMS) .. "/" .. #ITEMS end
				local right, n = prediction_stats(rec)
				if n > 0 then pred = right .. "/" .. n end
			end
			local disc = 0
			for _ in pairs(cm.progress(r.name).discoveries or {}) do disc = disc + 1 end
			fs[#fs + 1] = "," .. core.formspec_escape(r.name) .. "," .. r.tier .. "," .. r.answered .. "," .. pre .. "," .. post
				.. "," .. pred .. "," .. (disc > 0 and disc or "") .. "," .. (r.online and "yes" or "")
		end
		fs[#fs + 1] = ";1]"
		local s = A.summary(recs, ITEMS)
		local line = "Pre-test: " .. s.n_pre .. " done"
			.. (s.mean_pre and string.format(", mean %.1f/%d", s.mean_pre, s.items) or "")
			.. ".  Post-test: " .. s.n_post .. " done"
			.. (s.mean_post and string.format(", mean %.1f/%d", s.mean_post, s.items) or "")
			.. (s.mean_gain and string.format(".  Mean normalized gain (%d pairs): %.2f", s.n_gain, s.mean_gain) or "")
			.. ".  /exportdata saves the answers without names."
		fs[#fs + 1] = "textarea[0.4,8.4;13.2,1;;;" .. core.formspec_escape(line) .. "]"
		core.show_formspec(name, "crystalminer:class", table.concat(fs))
		return true
	end,
})

local function export(dir)
	local recs = all_records()
	local files = {
		["crystalminer_tests.csv"] = A.tests_csv(recs, ITEMS),
		["crystalminer_predictions.csv"] = A.predictions_csv(recs),
	}
	-- Discoveries per anonymous participant.
	local rows = { "participant,discovery" }
	for who, rec in pairs(recs) do
		for id in pairs(cm.progress(who).discoveries or {}) do rows[#rows + 1] = rec.id .. "," .. id end
	end
	table.sort(rows, function(a, b) return a == "participant,discovery" or (b ~= "participant,discovery" and a < b) end)
	files["crystalminer_discoveries.csv"] = table.concat(rows, "\n") .. "\n"
	for fname, text in pairs(files) do
		local f = io.open(dir .. "/" .. fname, "w")
		f:write(text)
		f:close()
	end
	return A.summary(recs, ITEMS)
end
cm.export = export

core.register_chatcommand("exportdata", {
	description = "Save test answers, predictions and discoveries (no names) as CSV files in the world folder (teachers)",
	privs = { teacher = true },
	func = function()
		local s = export(core.get_worldpath())
		return true, "Saved crystalminer_tests.csv, crystalminer_predictions.csv and crystalminer_discoveries.csv in the "
			.. "world folder. " .. s.n_pre .. " pre-tests, " .. s.n_post .. " post-tests, " .. s.n_paired .. " pairs."
	end,
})
