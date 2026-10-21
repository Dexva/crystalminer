-- The guide window: what to do in a place, in numbered steps, with a picture. Shown the first time
-- a player arrives somewhere (the Gate, the Try-it Pad, each world), and again with /explain.

local cm = crystalminer
local GD = cm.GUIDES
local L = cm.L
local modpath = core.get_modpath(core.get_current_modname())

-- Pictures exist for some places (tools/make_figures.py); the window works without one.
local function picture(id)
	local f = io.open(modpath .. "/textures/crystalminer_guide_" .. id .. ".png", "rb")
	if not f then return nil end
	f:close()
	return "crystalminer_guide_" .. id .. ".png"
end

local function esc(t)
	-- hypertext markup: escape the formspec, then the markup characters.
	return core.formspec_escape((t:gsub("\\", "\\\\"):gsub("<", "\\<")))
end

--- Formspec for a place's guide. extra: further lines (for a higher tier), locked: a note.
function cm.guide_formspec(id, extra, locked)
	local g = GD[id]
	local pic = picture(id)
	-- Sized for a 1280x800 screen at default GUI scaling: the formspec then gets about 53 pixels per
	-- unit, so the text column is about 540 pixels wide and the title, the summary and every step
	-- fit without scrolling. "What you will see" and "The word for it" follow below.
	local text_x = pic and 6.3 or 0.5
	local text_w = pic and 10.2 or 16
	local parts = { "<global size=16 color=#F0F0F0>",
		"<style size=22 color=#FFD866><b>" .. esc(g.title) .. "</b></style>\n\n",
		locked and ("<style color=#FFB070>" .. esc(locked) .. "</style>\n\n") or "",
		esc(g.what), "\n\n", "<style color=#9FD8FF><b>What to do</b></style>\n" }
	for i, s in ipairs(g.steps) do parts[#parts + 1] = "<b>" .. i .. ".</b> " .. esc(s) .. "\n" end
	parts[#parts + 1] = "\n<style color=#9FD8FF><b>What you will see</b></style>\n" .. esc(g.see) .. "\n\n"
	if g.example then
		parts[#parts + 1] = "<style color=#9FD8FF><b>In the real world</b></style>\n" .. esc(g.example) .. "\n\n"
	end
	parts[#parts + 1] = "<style color=#9FD8FF><b>The word for it</b></style>\n" .. esc(g.word) .. "\n"
	if extra and #extra > 0 then
		parts[#parts + 1] = "\n<style color=#9FD8FF><b>More, for your tier</b></style>\n"
		for _, l in ipairs(extra) do parts[#parts + 1] = esc(l) .. "\n" end
	end
	local fs = { "formspec_version[4]size[17,10.4]bgcolor[#141A26F0;true]",
		"hypertext[" .. text_x .. ",0.4;" .. text_w .. ",8.6;guide;" .. table.concat(parts) .. "]",
		"button_exit[" .. (17 - 5.4) .. ",9.3;5,0.8;ok;OK, let's go]",
		"label[0.5,9.7;" .. core.formspec_escape("Type /explain to see this again.") .. "]" }
	if pic then table.insert(fs, 2, "image[0.4,0.6;5.6,5.6;" .. pic .. "]") end
	return table.concat(fs)
end

--- Shows the guide for a place; returns false if it has none.
function cm.show_guide(name, id)
	if not GD[id] then return false end
	local extra, locked = nil, nil
	local live = cm.live_by_id and cm.live_by_id(id)
	if live then
		local a, p = live.area, cm.progress(name)
		if p.tier < a.tier then
			locked = "You can look around now. Building here opens at tier " .. a.tier
				.. ": answer the /quiz questions of the places you have already unlocked."
		else
			extra = {}
			for t = a.tier + 1, p.tier do
				for _, l in ipairs((a.explain or {})[t] or {}) do extra[#extra + 1] = l end
			end
		end
	end
	core.show_formspec(name, "crystalminer:guide", cm.guide_formspec(id, extra, locked))
	return true
end

---------------------------------------------------------------------------- one window at a time

-- Which crystalminer window each player has open, as far as the server can know: set when one is
-- shown, cleared when it is closed by the server (close_formspec, or show_formspec with "") or by
-- the player (the engine then sends fields.quit = "true"). Windows of other mods are not tracked.
local open_window = {}   -- name -> { form = formname, since = seconds }
local STALE = 600        -- a window "open" this long is assumed lost (e.g. a missed quit)

local function now() return core.get_us_time() / 1e6 end

function cm.note_window(name, formname, formspec)
	if type(formname) ~= "string" or formname:sub(1, 13) ~= "crystalminer:" then return end
	if formspec == "" then
		if open_window[name] and open_window[name].form == formname then open_window[name] = nil end
	else
		open_window[name] = { form = formname, since = now() }
	end
end

function cm.note_window_closed(name, formname)
	if formname == "" then open_window[name] = nil
	elseif open_window[name] and open_window[name].form == formname then open_window[name] = nil end
end

--- The crystalminer window the player has open, or nil.
function cm.window_open(name)
	local w = open_window[name]
	if w and now() - w.since > STALE then open_window[name] = nil w = nil end
	return w and w.form or nil
end

-- core.show_formspec and core.close_formspec are looked up at call time everywhere, so wrapping
-- them here sees every window the game opens or closes.
local raw_show, raw_close = core.show_formspec, core.close_formspec
core.show_formspec = function(name, formname, formspec)
	cm.note_window(name, formname, formspec)
	return raw_show(name, formname, formspec)
end
core.close_formspec = function(name, formname)
	cm.note_window_closed(name, formname)
	return raw_close(name, formname)
end

-- Callbacks run newest first and stop at the first that returns true, so this one is registered
-- last of all (after every mod has loaded) to see each quit before a handler swallows it.
core.register_on_mods_loaded(function()
	core.register_on_player_receive_fields(function(player, formname, fields)
		if fields.quit then cm.note_window_closed(player:get_player_name(), formname) end
		return false
	end)
end)

--- True while a guide must wait: a crystalminer window is open, or the pre-test is about to be
-- offered (learning.lua sets cm.pretest_due).
function cm.guide_busy(name)
	if cm.window_open(name) then return true end
	return cm.pretest_due ~= nil and cm.pretest_due(name) == true
end

---------------------------------------------------------------------------- guide queue

-- First arrival in a place with a guide: the guide is queued and shown once nothing else is open.
-- If the player passed through several places meanwhile, only the guide for where they are now
-- (or, if they are nowhere with a guide, the last place) is shown; the others are marked unseen
-- again, so they show on the next arrival there.
local queue = {}   -- name -> { ids = { id, ... }, ready = seconds }
local DELAY = 1.5  -- so the arrival title shows first
cm.guide_queue = queue

function cm.guide_enqueue(name, id, t)
	local q = queue[name] or { ids = {} }
	queue[name] = q
	for i, x in ipairs(q.ids) do if x == id then table.remove(q.ids, i) break end end
	q.ids[#q.ids + 1] = id
	q.ready = (t or now()) + DELAY
end

--- Pure choice: which queued id to show for a player standing in `here`.
function cm.guide_pick(ids, here)
	for _, x in ipairs(ids) do if x == here then return x end end
	return ids[#ids]
end

--- Shows the queued guide if nothing is in the way. Returns the id shown, or nil and a reason.
--- `show` (default cm.show_guide) and `t` are for tests.
function cm.guide_flush(name, here, t, show)
	local q = queue[name]
	if not q or #q.ids == 0 then return nil, "empty" end
	if (t or now()) < q.ready then return nil, "wait" end
	if cm.guide_busy(name) then return nil, "busy" end
	local id = cm.guide_pick(q.ids, here)
	local p = cm.progress(name)
	p.guided = p.guided or {}
	for _, x in ipairs(q.ids) do if x ~= id then p.guided[x] = nil end end
	queue[name] = nil
	cm.save_progress(name)
	;(show or cm.show_guide)(name, id)
	return id
end

table.insert(cm.on_area, function(name, id)
	if not id or not GD[id] then return end
	local p = cm.progress(name)
	p.guided = p.guided or {}
	if p.guided[id] then return end
	p.guided[id] = true
	cm.save_progress(name)
	cm.guide_enqueue(name, id)
end)

local flush_timer = 0
core.register_globalstep(function(dtime)
	flush_timer = flush_timer + dtime
	if flush_timer < 0.5 then return end
	flush_timer = 0
	for name in pairs(queue) do
		if core.get_player_by_name(name) then
			cm.guide_flush(name, cm.current_area[name])
		end
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	-- A guide that never showed is shown on the next arrival instead.
	local q = queue[name]
	if q then
		local p = cm.progress(name)
		for _, x in ipairs(q.ids) do if p.guided then p.guided[x] = nil end end
		cm.save_progress(name)
	end
	queue[name], open_window[name] = nil, nil
end)

core.register_on_player_receive_fields(function(_, formname)
	return formname == "crystalminer:guide"
end)
