-- Exports the data behind the guide and exhibit pictures, computed by the game's own engine, as
-- JSON for tools/make_figures.py. Run from the repository root: luajit tools/figure_data.lua > out.json
package.path = "mods/crystalminer/?.lua;" .. package.path
local S = require("symmetry")
local L = require("lessons")
local content = require("content")
local E = loadfile("mods/crystalminer/elements.lua")(S)
local G = loadfile("mods/crystalminer/gate.lua")(S)
local ST = require("structures")

local function json(v)
	local t = type(v)
	if t == "number" then return (v == math.floor(v)) and string.format("%d", v) or string.format("%.4f", v) end
	if t == "string" then return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"' end
	if t == "boolean" then return tostring(v) end
	if t == "table" then
		if #v > 0 or next(v) == nil then
			local o = {}
			for i, x in ipairs(v) do o[i] = json(x) end
			return "[" .. table.concat(o, ",") .. "]"
		end
		local o = {}
		for k, x in pairs(v) do o[#o + 1] = json(tostring(k)) .. ":" .. json(x) end
		return "{" .. table.concat(o, ",") .. "}"
	end
	return "null"
end

-- Motifs: flat (seen from above) and solid. Both have no symmetry of their own.
local FLAT = { { 0, 0, 0 }, { 1, 0, 0 }, { 2, 0, 0 }, { 0, 0, 1 } }
local SOLID = { { 0, 0, 0 }, { 1, 0, 0 }, { 2, 0, 0 }, { 0, 1, 0 }, { 2, 0, 1 } }
local SMALL = { { 0, 0, 0 }, { 1, 0, 0 }, { 0, 1, 0 } }
local ONE = { { 0, 0, 0 } }

local TOP = { mirror_plaza = true, twofold_yard = true, fourfold_tower = true, twin_mirrors = true,
	square_court = true, impossible_room = true, glide_hall = true, mirror_tiles = true, glide_tiles = true,
	pinwheel_tiles = true, weave_tiles = true }

--- Places the motif where every block is in a general position and no two images coincide.
local function place(r, motif, tries)
	local cells = 1
	if r.cell then cells = (r.size[1] / r.cell[1]) * (r.size[2] / r.cell[2]) * (r.size[3] / r.cell[3]) end
	local full = #r.group.ops * cells
	local best
	for _, b in ipairs(tries) do
		local blocks, seen, ok = {}, {}, true
		for _, m in ipairs(motif) do
			local p = { r.min[1] + b[1] + m[1], r.min[2] + b[2] + m[2], r.min[3] + b[3] + m[3] }
			if not S.contains_pos(r, p[1], p[2], p[3]) then ok = false break end
			local imgs = S.images(r, p[1], p[2], p[3])
			if #imgs < full then ok = false break end
			for i, q in ipairs(imgs) do
				local k = q.x .. "," .. q.y .. "," .. q.z
				if seen[k] then ok = false break end
				seen[k] = true
				blocks[#blocks + 1] = { q.x - r.min[1], q.y - r.min[2], q.z - r.min[3], i == 1 and 1 or 0 }
			end
			if not ok then break end
		end
		if ok then best = blocks break end
	end
	return best
end

local function candidates(r, top)
	local out = {}
	local ymax = top and 0 or r.size[2] - 1
	for y = 0, ymax do
		for x = 0, r.size[1] - 1 do
			for z = 0, r.size[3] - 1 do out[#out + 1] = { x, y, z } end
		end
	end
	-- Prefer spots a little off the middle of the first cell or of the region.
	local c = r.cell or r.size
	local target = { math.floor(c[1] * 0.62), top and 0 or math.floor(c[2] * 0.25), math.floor(c[3] * 0.58) }
	table.sort(out, function(a, b)
		local da = (a[1] - target[1]) ^ 2 + (a[2] - target[2]) ^ 2 + (a[3] - target[3]) ^ 2
		local db = (b[1] - target[1]) ^ 2 + (b[2] - target[2]) ^ 2 + (b[3] - target[3]) ^ 2
		return da < db
	end)
	return out
end

local regions = {}
for _, a in ipairs(content.regions) do
	if not a.hidden then
		local r = S.region(L.region_spec(a))
		local top = TOP[a.id] or false
		-- Weave Tiles has 8 copies per 6 x 6 tile: only a 3-block bend fits without overlaps.
		local motif = (a.id == "weave_tiles") and { { 0, 0, 0 }, { 1, 0, 0 }, { 1, 0, 1 } } or top and FLAT or (r.cell and SMALL) or (#r.group.ops >= 24 and ONE) or SOLID
		local blocks = place(r, motif, candidates(r, top))
		local dots = {}
		for _, d in ipairs(E.dots(r)) do
			dots[#dots + 1] = { d.pos.x + 0.5 - r.min[1], d.pos.y + 0.5 - r.min[2], d.pos.z + 0.5 - r.min[3], d.kind,
				d.symbol or "", d.colour }
		end
		regions[a.id] = { size = r.size, cell = r.cell or false, top = top, blocks = blocks or {}, dots = dots,
			symbol = a.symbol, name = a.name, order = #r.group.ops }
	end
end

-- The Gate displays: original and copy of each, relative to the gate's corner.
local gate = {}
local at = content.gate.at
for _, d in ipairs(G.displays(at)) do
	local o, c = {}, {}
	for _, p in ipairs(d.original) do o[#o + 1] = { p.x - at[1], p.y - at[2], p.z - at[3] } end
	for _, p in ipairs(d.copy) do c[#c + 1] = { p.x - at[1], p.y - at[2], p.z - at[3] } end
	gate[#gate + 1] = { letter = d.letter, operation = d.operation, original = o, copy = c }
end

-- One conventional unit cell of each museum structure, corners and faces included.
local cells = {}
for _, ex in ipairs(content.museum.exhibits) do
	local rule = ST.RULES[ex.structure]
	local atoms = {}
	for x = 0, rule.cell do
		for y = 0, rule.cell do
			for z = 0, rule.cell do
				local s = rule.site(x, y, z)
				if s then atoms[#atoms + 1] = { x, y, z, s } end
			end
		end
	end
	cells[ex.id] = { cell = rule.cell, atoms = atoms, colours = ex.colours }
end

-- The 32 point groups, and whether each fits the block grid.
local groups = {}
for _, e in ipairs(S.catalog) do groups[#groups + 1] = { e.symbol, S.fits_grid(e.group) and true or false, e.system } end

io.write(json({ regions = regions, gate = gate, cells = cells, groups = groups }))
