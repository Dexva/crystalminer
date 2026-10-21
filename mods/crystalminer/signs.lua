-- Signs with real lettering. Luanti has no text on nodes, so a sign is a flat entity whose
-- texture is assembled from glyph images ([combine), rendered from DejaVu Sans Mono by
-- tools/make_glyphs.py. Lines starting with "# " are headings in a larger font.
--
-- The layout part is pure Lua (tested in tests/test_signs.lua); the entity is registered only
-- when running inside Luanti.

local SG = {}

-- Formats: size in px and nodes, background, and ink. 128 px per node: body text is then about
-- 14 cm tall, readable from a few steps away (at 192 px per node it was too small in play).
SG.FORMATS = {
	plaque = { px = { 384, 192 }, nodes = { 3, 1.5 }, ink = "d", margin = 20 },
	panel = { px = { 576, 384 }, nodes = { 4.5, 3 }, ink = "d", margin = 24 },
	board = { px = { 768, 576 }, nodes = { 6, 4.5 }, ink = "l", margin = 28 },
	banner = { px = { 768, 192 }, nodes = { 6, 1.5 }, ink = "l", margin = 22 },
	label = { px = { 192, 96 }, nodes = { 1.5, 0.75 }, ink = "d", margin = 12 },
}
SG.GLYPH = { 9, 18 }
SG.HEADING = { 14, 28 }

local KNOWN = {}
for c = 32, 126 do KNOWN[c] = true end
for _, c in ipairs({ 252, 233, 246, 228, 197, 229, 248, 224, 232, 176, 183, 8211, 8212, 8217, 8321, 8322, 8323, 8324 }) do
	KNOWN[c] = true
end

--- UTF-8 string to a list of code points; unknown characters become "?".
function SG.codepoints(s)
	local out, i = {}, 1
	while i <= #s do
		local b = s:byte(i)
		local c, n
		if b < 0x80 then c, n = b, 1
		elseif b < 0xE0 then c, n = (b % 0x20) * 64 + (s:byte(i + 1) % 64), 2
		elseif b < 0xF0 then c, n = (b % 0x10) * 4096 + (s:byte(i + 1) % 64) * 64 + (s:byte(i + 2) % 64), 3
		else c, n = 63, 4 end
		out[#out + 1] = KNOWN[c] and c or 63
		i = i + n
	end
	return out
end

--- Wraps text into lines of at most cols characters. Returns { heading = bool, cps = {...} }.
local function wrap(text, cols, hcols)
	local lines = {}
	for para in (text .. "\n"):gmatch("(.-)\n") do
		local heading = para:sub(1, 2) == "# "
		if heading then para = para:sub(3) end
		local width = heading and hcols or cols
		local line = {}
		if para == "" then lines[#lines + 1] = { heading = false, cps = {} } end
		for word in para:gmatch("%S+") do
			local cps = SG.codepoints(word)
			if #line > 0 and #line + 1 + #cps > width then
				lines[#lines + 1] = { heading = heading, cps = line }
				line = {}
			end
			if #line > 0 then line[#line + 1] = 32 end
			for _, c in ipairs(cps) do line[#line + 1] = c end
		end
		if #line > 0 then lines[#lines + 1] = { heading = heading, cps = line } end
	end
	return lines
end
SG.wrap = wrap

--- Texture string for a sign, and whether the text fitted.
function SG.texture(format, text)
	local f = SG.FORMATS[format]
	local w, h = f.px[1], f.px[2]
	local inner_w = w - 2 * f.margin
	local lines = wrap(text, math.floor(inner_w / SG.GLYPH[1]), math.floor(inner_w / SG.HEADING[1]))
	local parts = { "[combine:" .. w .. "x" .. h .. ":0,0=crystalminer_sign_" .. format .. ".png" }
	local y, fits = f.margin, true
	for _, line in ipairs(lines) do
		local gw, gh = SG.GLYPH[1], SG.GLYPH[2]
		local prefix = "g"
		if line.heading then gw, gh, prefix = SG.HEADING[1], SG.HEADING[2], "h" end
		if y + gh > h - f.margin + 4 then
			fits = false
			break
		end
		local x = f.margin
		for _, c in ipairs(line.cps) do
			if c ~= 32 then parts[#parts + 1] = x .. "," .. y .. "=crystalminer_" .. prefix .. f.ink .. "_" .. c .. ".png" end
			x = x + gw
		end
		y = y + gh + (line.heading and 6 or 2)
	end
	return table.concat(parts, ":"), fits
end

-- Yaw that makes a sign face each direction (towards the reader).
SG.YAW = { n = 0, w = math.pi / 2, s = math.pi, e = 3 * math.pi / 2 }
SG.DIR = { n = { x = 0, z = 1 }, s = { x = 0, z = -1 }, e = { x = 1, z = 0 }, w = { x = -1, z = 0 } }

if not core then return SG end

---------------------------------------------------------------------------- the entity

core.register_entity("crystalminer:sign", {
	initial_properties = {
		visual = "upright_sprite", textures = { "crystalminer_blank.png", "crystalminer_blank.png" },
		physical = false, pointable = false, static_save = true, visual_size = { x = 1, y = 1 },
	},
	on_activate = function(self, staticdata)
		local d = staticdata ~= "" and core.deserialize(staticdata) or nil
		-- A sign from an earlier build of the world removes itself: signs far from players are
		-- stored, not active, so a rebuild cannot find them to replace them.
		local known = d and (SG.FORMATS[d.format] or d.picture)
		if not known or d.v ~= crystalminer.WORLD_VERSION then
			self.object:remove()
			return
		end
		self.data = d
		if d.picture then
			self.object:set_properties({ textures = { d.picture, "crystalminer_sign_back.png" },
				visual_size = { x = d.w, y = d.h } })
			return
		end
		local f = SG.FORMATS[d.format]
		local tex = SG.texture(d.format, d.text)
		self.object:set_properties({ textures = { tex, "crystalminer_sign_back.png" }, visual_size = { x = f.nodes[1], y = f.nodes[2] } })
	end,
	get_staticdata = function(self) return core.serialize(self.data) end,
})

--- Places a sign whose centre is at pos, facing dir ("n", "e", "s" or "w"). Removes any sign
-- already within half a node of that spot, so rebuilding never doubles them.
function SG.place(pos, dir, format, text)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 0.6)) do
		local e = obj:get_luaentity()
		if e and e.name == "crystalminer:sign" then obj:remove() end
	end
	local obj = core.add_entity(pos, "crystalminer:sign",
		core.serialize({ format = format, text = text, v = crystalminer.WORLD_VERSION }))
	if obj then obj:set_yaw(SG.YAW[dir]) end
	return obj
end

--- A framed picture (a texture) whose centre is at pos, facing dir, w by h nodes.
function SG.place_picture(pos, dir, texture, w, h)
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 0.6)) do
		local e = obj:get_luaentity()
		if e and e.name == "crystalminer:sign" then obj:remove() end
	end
	local obj = core.add_entity(pos, "crystalminer:sign",
		core.serialize({ picture = texture, w = w, h = h, v = crystalminer.WORLD_VERSION }))
	if obj then obj:set_yaw(SG.YAW[dir]) end
	return obj
end

--- A sign on the face of a wall node: wall is the node, dir the side it faces.
function SG.on_wall(wall, dir, format, text, dy)
	local d = SG.DIR[dir]
	local p = { x = wall.x + d.x * 0.52, y = wall.y + (dy or 0), z = wall.z + d.z * 0.52 }
	return SG.place(p, dir, format, text)
end

return SG
