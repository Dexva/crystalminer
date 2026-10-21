-- Geometry of the Symmetry Gate: four displays, each a chiral motif and its copy under one
-- operation (A reflection, B 2-fold rotation about a vertical axis, C translation, D inversion).
-- Pure Lua, so the tests can check exactly what is built. Loaded with loadfile(...)(symmetry).
--
-- Players spawn facing south, so east is on their left. Displays run A to D from left to right,
-- and in each display the original is on the left (east) and the copy on the right (west).

local S = ...

local G = {}

-- A chiral motif: an L on the ground with a post at one end. Offsets from its anchor node.
-- It has no symmetry of its own, so each display's copy can only come from one operation.
G.MOTIF = { { 0, 0, 0 }, { -1, 0, 0 }, { -2, 0, 0 }, { -2, 0, 1 }, { 0, 1, 0 }, { 0, 2, 0 } }
G.LETTERS = { "A", "B", "C", "D" }
G.OPERATIONS = { "reflection", "rotation", "translation", "inversion" }
G.COLOURS = { "blue", "red", "green", "yellow" }

--- The four displays for a gate whose reference corner is at = {x, y, z}.
-- Each display: letter, operation, colour, op (doubled coordinates), original and copy (node
-- positions), floor box {x0, x1, z0, z1}, label position and the point a player should look at.
function G.displays(at)
	local out = {}
	for i = 0, 3 do
		-- Anchor of the original (its east end); the copy lies 6 nodes further west.
		local ax = at[1] + 50 - 14 * i
		local cx, cy, cz = 2 * ax - 7, 2 * (at[2] + 3), 2 * at[3] + 1
		local o
		if i == 0 then
			o = S.op({ -1, 0, 0, 0, 1, 0, 0, 0, 1 }, { 2 * cx, 0, 0 })
		elseif i == 1 then
			o = S.op({ -1, 0, 0, 0, 1, 0, 0, 0, -1 }, { 2 * cx, 0, 2 * cz })
		elseif i == 2 then
			o = S.op({ 1, 0, 0, 0, 1, 0, 0, 0, 1 }, { -12, 0, 0 })
		else
			o = S.op({ -1, 0, 0, 0, -1, 0, 0, 0, -1 }, { 2 * cx, 2 * cy, 2 * cz })
		end
		local original, copy = {}, {}
		for _, m in ipairs(G.MOTIF) do
			local p = { x = ax + m[1], y = at[2] + m[2], z = at[3] + m[3] }
			original[#original + 1] = p
			local d = S.apply(o, { 2 * p.x + 1, 2 * p.y + 1, 2 * p.z + 1 })
			copy[#copy + 1] = { x = (d[1] - 1) / 2, y = (d[2] - 1) / 2, z = (d[3] - 1) / 2 }
		end
		out[#out + 1] = {
			letter = G.LETTERS[i + 1], operation = G.OPERATIONS[i + 1], colour = G.COLOURS[i + 1],
			op = o, original = original, copy = copy,
			floor = { ax - 10, ax + 2, at[3] - 4, at[3] + 3 },
			label = { x = ax - 4, y = at[2] + 7, z = at[3] },
			look_at = { x = ax - 4, y = at[2] + 2, z = at[3] },
		}
	end
	return out
end

--- The box the gate occupies (for clearing, map generation and overlap checks).
function G.box(at)
	return { min = { at[1] - 3, at[2], at[3] - 5 }, size = { 58, 11, 10 } }
end

return G
