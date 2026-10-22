-- Short, gentle sound effects (synthesised by tools/make_sounds.py, CC BY-SA 4.0 like the rest of the media).
-- Files live in sounds/ as crystalminer_<name>.ogg; Luanti refers to them by name without ".ogg".
-- Footsteps have variants (crystalminer_step_hard.1.ogg, .2, ...): Luanti picks one at random.
-- Switch off with the setting crystalminer.sounds. Loaded before any node is registered.

local cm = crystalminer

local GAIN = { crystalminer_copy = 0.5, crystalminer_right = 0.5, crystalminer_wrong = 0.45,
	crystalminer_door = 0.6, crystalminer_portal = 0.5 }

local function enabled()
	return core.settings:get_bool("crystalminer.sounds", true)
end

--- Plays a sound to one player only (not positional). Does nothing if sounds are off.
function cm.sound(sound_name, player_name)
	if not enabled() or not player_name or not core.get_player_by_name(player_name) then return end
	core.sound_play(sound_name, { to_player = player_name, gain = GAIN[sound_name] or 0.5 }, true)
end

--- Plays a sound at a position, for players within max_hear_distance (positional; mono files).
function cm.sound_at(sound_name, pos)
	if not enabled() or not pos then return end
	core.sound_play(sound_name, { pos = pos, gain = GAIN[sound_name] or 0.5, max_hear_distance = 16 }, true)
end

-- Node sounds per material: footsteps, digging (dig: as it is hit; dug: when it goes), placing.
-- dig is always given: left out, Luanti would look for a "default_dig_<group>" sound this game lacks.
local DIG = { name = "crystalminer_dig", gain = 0.2 }
local DUG = { name = "crystalminer_dug", gain = 0.35 }
local PLACE = { name = "crystalminer_place", gain = 0.4 }
local FAILED = { name = "crystalminer_place_failed", gain = 0.3 }
local GLASS = { name = "crystalminer_glass", gain = 0.25 }
local MATERIALS = {
	hard = { footstep = { name = "crystalminer_step_hard", gain = 0.3 }, dig = DIG, dug = DUG, place = PLACE,
		place_failed = FAILED },
	glass = { footstep = { name = "crystalminer_step_glass", gain = 0.3 }, dig = DIG, dug = GLASS, place = GLASS,
		place_failed = FAILED },
	soft = { footstep = { name = "crystalminer_step_soft", gain = 0.35 }, dig = DIG, dug = DUG, place = PLACE,
		place_failed = FAILED },
	wood = { footstep = { name = "crystalminer_step_wood", gain = 0.3 }, dig = DIG, dug = DUG, place = PLACE,
		place_failed = FAILED },
}
cm.SOUND_MATERIALS = MATERIALS

--- The sounds table for a node of the given material (hard, glass, soft or wood); a fresh copy, so
--- that a node definition can be changed without touching the others. Empty when sounds are off:
--- node definitions are fixed at start-up, so the setting takes effect after a restart.
function cm.node_sounds(material)
	local m = MATERIALS[material]
	assert(m, "unknown sound material " .. tostring(material))
	if not enabled() then return {} end
	local t = {}
	for k, v in pairs(m) do t[k] = { name = v.name, gain = v.gain } end
	return t
end

-- The engine plays "player_jump" by that name whenever a player jumps, if the game has such a file.
-- It lives outside sounds/, so it is only sent to players when sounds are on. Luanti 5.9 and newer
-- accept media at start-up; older versions only once the server runs, hence the fallback. Before
-- 5.5 the function took just a file path.
local JUMP = (core.get_modpath and core.get_modpath(core.get_current_modname() or "crystalminer") or ".")
	.. "/optional_sounds/player_jump.ogg"
cm.jump_sound = { path = JUMP, added = false }
local function add_jump_later()
	core.after(0, function()
		local ok, res
		if core.features and core.features.dynamic_add_media_table then
			ok, res = pcall(core.dynamic_add_media, { filepath = JUMP }, function() end)
		else
			ok, res = pcall(core.dynamic_add_media, JUMP)
		end
		cm.jump_sound.added = (ok and res) and "after start" or false
		if not cm.jump_sound.added then
			core.log("warning", "[crystalminer] could not add the jump sound: " .. tostring(res))
		end
	end)
end
if enabled() and core.dynamic_add_media then
	local ok, res = false, nil
	if core.features and core.features.dynamic_add_media_table then
		ok, res = pcall(core.dynamic_add_media, { filepath = JUMP })
	end
	if ok and res then cm.jump_sound.added = "startup" else add_jump_later() end
end
