-- Short, gentle sound effects (synthesised by tools/make_sounds.py, CC BY-SA 4.0 like the rest of the media).
-- Files live in sounds/ as crystalminer_<name>.ogg; Luanti refers to them by name without ".ogg".
-- Switch off with the setting crystalminer.sounds.

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
