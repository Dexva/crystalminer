package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local T = require("testlib")

print("sounds")

local MOD = "mods/crystalminer"

--- Loads sounds.lua with a stand-in for the engine (its own environment, so two copies can coexist);
--- sounds_on is the setting crystalminer.sounds; old_engine: before Luanti 5.5 (file path only).
local function load(sounds_on, old_engine)
	local added = {}
	local afters = {}
	local cm = {}
	local env = setmetatable({ crystalminer = cm, core = {
		settings = { get_bool = function(_, key, default)
			if key == "crystalminer.sounds" then return sounds_on end
			return default
		end },
		get_modpath = function() return MOD end,
		get_current_modname = function() return "crystalminer" end,
		features = old_engine and {} or { dynamic_add_media_table = true },
		dynamic_add_media = function(opts)
			added[#added + 1] = type(opts) == "table" and opts.filepath or ("string " .. opts)
			return true
		end,
		after = function(_, f) afters[#afters + 1] = f end,
		log = function() end,
	} }, { __index = _G })
	setfenv(assert(loadfile(MOD .. "/sounds.lua")), env)()
	return cm, added, afters
end

local function exists(path)
	local f = io.open(path, "rb")
	if f then f:close() end
	return f ~= nil
end

--- The files of a sound group: name.ogg and name.0.ogg ... name.9.ogg.
local function group_files(dir, name)
	local found = {}
	for _, suffix in ipairs({ "", ".0", ".1", ".2", ".3", ".4", ".5", ".6", ".7", ".8", ".9" }) do
		local p = dir .. "/" .. name .. suffix .. ".ogg"
		if exists(p) then found[#found + 1] = p end
	end
	return found
end

local function list(dir)
	local out = {}
	local p = io.popen('ls "' .. dir .. '"')
	for line in p:lines() do out[#out + 1] = line end
	p:close()
	return out
end

local KEYS = { "footstep", "dig", "dug", "place", "place_failed" }
local cm_on, added_on = load(true)
local cm_off, added_off, afters_off = load(false)

T.run("every material has footstep, dig, dug, place and place_failed sounds", function()
	local n = 0
	for mat in pairs(cm_on.SOUND_MATERIALS) do
		n = n + 1
		local s = cm_on.node_sounds(mat)
		for _, k in ipairs(KEYS) do
			T.ok(type(s[k]) == "table" and type(s[k].name) == "string" and s[k].name ~= "", mat .. " " .. k)
			T.ok(s[k].gain > 0 and s[k].gain <= 0.5, mat .. " " .. k .. " gain " .. tostring(s[k].gain))
		end
	end
	T.eq(n, 4, "materials")
end)

T.run("every sound a node uses has a file in sounds/", function()
	for mat in pairs(cm_on.SOUND_MATERIALS) do
		for _, k in ipairs(KEYS) do
			local name = cm_on.node_sounds(mat)[k].name
			T.ok(#group_files(MOD .. "/sounds", name) > 0, mat .. " " .. k .. ": no file for " .. name)
		end
	end
end)

T.run("footsteps come in several variants", function()
	for mat in pairs(cm_on.SOUND_MATERIALS) do
		local name = cm_on.node_sounds(mat).footstep.name
		T.ok(#group_files(MOD .. "/sounds", name) >= 3, name)
	end
end)

T.run("node_sounds returns a fresh copy", function()
	local a = cm_on.node_sounds("hard")
	a.footstep.gain = 9
	a.dig = nil
	local b = cm_on.node_sounds("hard")
	T.ok(b.footstep.gain < 1 and b.dig, "changing one table changed another")
end)

T.run("an unknown material is an error", function()
	T.fails(function() cm_on.node_sounds("cheese") end, "cheese")
end)

T.run("sounds off: every material gives an empty table", function()
	for mat in pairs(cm_off.SOUND_MATERIALS) do
		T.eq(next(cm_off.node_sounds(mat)), nil, mat)
	end
end)

T.run("jump sound: added when sounds are on, not when off", function()
	T.eq(#added_on, 1, "added with sounds on")
	T.eq(added_on[1], MOD .. "/optional_sounds/player_jump.ogg")
	T.ok(exists(added_on[1]), "file exists")
	T.eq(#added_off + #afters_off, 0, "nothing added or scheduled with sounds off")
end)

T.run("jump sound on engines before 5.5: added by file path once the server runs", function()
	local cm, added, afters = load(true, true)
	T.eq(#added, 0, "nothing at load time")
	T.eq(#afters, 1, "scheduled")
	afters[1]()
	T.eq(added[1], "string " .. MOD .. "/optional_sounds/player_jump.ogg")
	T.eq(cm.jump_sound.added, "after start")
end)

T.run("engine-played sounds are not in sounds/ (the setting could not switch them off)", function()
	for _, f in ipairs(list(MOD .. "/sounds")) do
		T.ok(not f:find("^player_") and not f:find("^default_"), f)
	end
end)

T.run("every sound file is used by the Lua code", function()
	local src = ""
	for _, f in ipairs(list(MOD)) do
		if f:find("%.lua$") then
			local h = io.open(MOD .. "/" .. f)
			src = src .. h:read("*a")
			h:close()
		end
	end
	for _, f in ipairs(list(MOD .. "/sounds")) do
		local name = f:gsub("%.%d%.ogg$", ""):gsub("%.ogg$", "")
		T.ok(src:find('"' .. name .. '"', 1, true), f .. " is not referenced")
	end
end)

T.run("all sound files are small mono 44.1 kHz Ogg Vorbis", function()
	local n = 0
	for _, dir in ipairs({ MOD .. "/sounds", MOD .. "/optional_sounds" }) do
		for _, f in ipairs(list(dir)) do
			T.ok(f:find("%.ogg$"), dir .. "/" .. f .. " is not .ogg")
			local h = io.open(dir .. "/" .. f, "rb")
			local data = h:read("*a")
			h:close()
			-- First page: 27-byte header, a 1-entry segment table, then the identification packet:
			-- 0x01 "vorbis", version (4 bytes), channels (1), sample rate (4, little-endian).
			T.eq(data:sub(1, 4), "OggS", f)
			T.eq(data:sub(30, 35), "vorbis", f)
			T.eq(data:byte(40), 1, f .. " channels")
			local b1, b2, b3, b4 = data:byte(41, 44)
			T.eq(b1 + 256 * b2 + 65536 * b3 + 16777216 * b4, 44100, f .. " sample rate")
			T.ok(#data < 10000, f .. " is " .. #data .. " bytes")
			n = n + 1
		end
	end
	T.ok(n >= 24, "files: " .. n)
end)

T.finish()
