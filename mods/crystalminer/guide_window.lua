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
	local text_x = pic and 7.2 or 0.5
	local text_w = pic and 9.3 or 16
	local parts = { "<global size=17 color=#F0F0F0>",
		"<style size=26 color=#FFD866><b>" .. esc(g.title) .. "</b></style>\n\n",
		locked and ("<style color=#FFB070>" .. esc(locked) .. "</style>\n\n") or "",
		esc(g.what), "\n\n", "<style color=#9FD8FF><b>What to do</b></style>\n" }
	for i, s in ipairs(g.steps) do parts[#parts + 1] = "<b>" .. i .. ".</b> " .. esc(s) .. "\n" end
	parts[#parts + 1] = "\n<style color=#9FD8FF><b>What you will see</b></style>\n" .. esc(g.see) .. "\n\n"
	parts[#parts + 1] = "<style color=#9FD8FF><b>The word for it</b></style>\n" .. esc(g.word) .. "\n"
	if extra and #extra > 0 then
		parts[#parts + 1] = "\n<style color=#9FD8FF><b>More, for your tier</b></style>\n"
		for _, l in ipairs(extra) do parts[#parts + 1] = esc(l) .. "\n" end
	end
	local fs = { "formspec_version[4]size[17,10.4]bgcolor[#141A26F0;true]",
		"hypertext[" .. text_x .. ",0.4;" .. text_w .. ",8.6;guide;" .. table.concat(parts) .. "]",
		"button_exit[" .. (17 - 5.4) .. ",9.3;5,0.8;ok;OK, let's go]",
		"label[0.5,9.7;" .. core.formspec_escape("Type /explain to see this again.") .. "]" }
	if pic then table.insert(fs, 2, "image[0.4,0.6;6.5,6.5;" .. pic .. "]") end
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

-- First arrival in a place with a guide: show it once per player and place.
table.insert(cm.on_area, function(name, id)
	if not id or not GD[id] then return end
	local p = cm.progress(name)
	p.guided = p.guided or {}
	if p.guided[id] then return end
	p.guided[id] = true
	cm.save_progress(name)
	-- A moment later, so the arrival title shows first; not over another open window.
	core.after(1.5, function()
		if core.get_player_by_name(name) then cm.show_guide(name, id) end
	end)
end)

core.register_on_player_receive_fields(function(_, formname)
	return formname == "crystalminer:guide"
end)
