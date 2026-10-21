-- Sculptures in the museum: mineral shapes and two symmetry puzzles, each on a marble plinth with
-- a plaque. Pure data (tested in tests/test_guides.lua): blocks are { dx, dy, dz, colour } from the
-- top centre of the plinth; symmetry, where given, is checked against the engine.

local SC = {}

local function octahedron(r, colour)
	local out = {}
	for x = -r, r do
		for y = -r, r do
			for z = -r, r do
				if math.abs(x) + math.abs(y) + math.abs(z) <= r then out[#out + 1] = { x, y + r, z, colour } end
			end
		end
	end
	return out
end

local function cube(r, colour)
	local out = {}
	for x = -r, r do
		for y = 0, 2 * r do
			for z = -r, r do out[#out + 1] = { x, y, z, colour } end
		end
	end
	return out
end

-- A pinwheel: a post with four hooked arms, a quarter turn apart. Turning works; mirrors do not.
local function pinwheel()
	local out = {}
	for y = 0, 3 do out[#out + 1] = { 0, y, 0, "brown" } end
	local arm = { { 1, 3, 0 }, { 2, 3, 0 }, { 3, 3, 0 }, { 3, 3, 1 } }
	for k = 0, 3 do
		for _, a in ipairs(arm) do
			local x, z = a[1], a[3]
			for _ = 1, k do x, z = -z, x end
			out[#out + 1] = { x, a[2], z, "red" }
		end
	end
	return out
end

-- A lopsided shape and its partner straight through a centre point: symmetry -1 only.
local function inverted_pair()
	local half = { { 1, 1, 0 }, { 2, 1, 0 }, { 3, 1, 0 }, { 3, 2, 0 }, { 1, 1, 1 }, { 1, 1, 2 } }
	local out = {}
	for _, b in ipairs(half) do
		out[#out + 1] = { b[1], b[2] + 3, b[3], "blue" }
		out[#out + 1] = { -b[1], -b[2] + 3, -b[3], "blue" }
	end
	return out
end

SC.list = {
	{ id = "fluorite", room = "foyer", at = { -12, -40 }, blocks = octahedron(2, "purple"),
		plaque = "# Fluorite: an octahedron\nFluorite crystals often grow as cubes or octahedra, and they split "
			.. "along octahedron faces." },
	{ id = "pyrite", room = "foyer", at = { 12, -40 }, blocks = cube(1, "yellow"),
		plaque = "# Pyrite: a cube\nPyrite, 'fool's gold', often grows as near-perfect cubes, "
			.. "often with fine grooves across the faces." },
	{ id = "halite", room = "information", at = { 52, -40 }, blocks = cube(1, "white"),
		plaque = "# Halite: rock salt\nSalt crystals are cubes, and they break into smaller cubes. "
			.. "See their atoms in Gallery 3." },
	{ id = "pinwheel", room = "gallery1", at = { 46, -16 }, blocks = pinwheel(), symmetry = "4",
		plaque = "# What symmetry? 4\nA quarter turn about the post leaves this sculpture the same. It has no "
			.. "mirror: its mirror image would turn the other way." },
	{ id = "pair", room = "gallery1", at = { -46, -16 }, blocks = inverted_pair(), symmetry = "-1",
		plaque = "# What symmetry? -1\nEvery block has a partner straight through the centre point, the same "
			.. "distance away on the other side. No turn and no mirror leaves it the same: only this inversion." },
}

return SC
