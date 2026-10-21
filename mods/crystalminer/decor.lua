-- Architecture and scenery: what makes each region look like its name (a plaza, a tower, a hall)
-- and the world around them (paths, trees, crystal formations). Pure Lua: returns lists of
-- placements { x, y, z, n } with n a short node name; init.lua turns them into nodes.
--
-- Nothing here is ever placed inside a region's build space or its border ring (tests check
-- this), so decoration never interferes with symmetry copies. Each region keeps a clear
-- entrance on its south side, where /goto puts players.

local D = {}

local function put(out, x, y, z, n) out[#out + 1] = { x = x, y = y, z = z, n = n } end

--- Extent of a region's build space: x0..x1, y0..y1, z0..z1 (inclusive) and centre column.
local function extent(r)
	local b = { x0 = r.min[1], x1 = r.min[1] + r.size[1] - 1, y0 = r.min[2], y1 = r.min[2] + r.size[2] - 1,
		z0 = r.min[3], z1 = r.min[3] + r.size[3] - 1 }
	b.cx = math.floor((b.x0 + b.x1) / 2)
	return b
end
D.extent = extent

--- Calls f(x, z, side) for every column of the ring at distance d around the build space.
local function ring(b, d, f)
	for x = b.x0 - d, b.x1 + d do
		f(x, b.z0 - d, "south")
		f(x, b.z1 + d, "north")
	end
	for z = b.z0 - d + 1, b.z1 + d - 1 do
		f(b.x0 - d, z, "west")
		f(b.x1 + d, z, "east")
	end
end

local function in_entrance(b, x, side, half)
	return side == "south" and math.abs(x - b.cx) <= half
end

local function paving(out, b, d0, d1, n)
	for d = d0, d1 do ring(b, d, function(x, z) put(out, x, 0, z, n) end) end
end

local function corners(b, d)
	return { { b.x0 - d, b.z0 - d }, { b.x1 + d, b.z0 - d }, { b.x0 - d, b.z1 + d }, { b.x1 + d, b.z1 + d } }
end

local function lamp_post(out, x, z, h, post)
	for y = 1, h do put(out, x, y, z, post or "pillar") end
	put(out, x, h + 1, z, "lamp")
end

local STYLES = {}

-- An open square paved in chequered tiles, a low stone wall and four lamp obelisks.
STYLES.plaza = function(out, b)
	paving(out, b, 2, 4, "plaza")
	ring(b, 5, function(x, z, side)
		if not in_entrance(b, x, side, 3) then put(out, x, 1, z, "stone_brick") end
	end)
	for _, c in ipairs(corners(b, 5)) do lamp_post(out, c[1], c[2], 4) end
end

-- A gravel yard inside a wooden fence, with lamp posts at the corners.
STYLES.yard = function(out, b)
	paving(out, b, 2, 3, "path")
	ring(b, 4, function(x, z, side)
		if not in_entrance(b, x, side, 2) then put(out, x, 1, z, "fence") end
	end)
	for _, c in ipairs(corners(b, 4)) do lamp_post(out, c[1], c[2], 2, "planks") end
end

-- Four brick towers at the corners joined by a crown with battlements above the build space.
STYLES.tower = function(out, b)
	paving(out, b, 2, 4, "path")
	local top = b.y1 + 3
	for _, c in ipairs(corners(b, 3)) do
		-- Each corner tower rises above the crown and ends in battlements around a lamp.
		for dx = -1, 1 do
			for dz = -1, 1 do
				for y = 1, top + 3 do put(out, c[1] + dx, y, c[2] + dz, "brick") end
				if (dx + dz) % 2 ~= 0 or (dx ~= 0 and dz ~= 0) then put(out, c[1] + dx, top + 4, c[2] + dz, "brick") end
			end
		end
		put(out, c[1], top + 4, c[2], "lamp")
	end
	for d = 2, 4 do
		ring(b, d, function(x, z)
			local corner = (x <= b.x0 - 2 or x >= b.x1 + 2) and (z <= b.z0 - 2 or z >= b.z1 + 2)
			if not corner then put(out, x, top, z, "brick") end
		end)
	end
	ring(b, 4, function(x, z)
		if (x + z) % 2 == 0 then put(out, x, top + 1, z, "brick") end
	end)
end

-- A display case: a stone walk around the floating cube and a crystal-capped pillar at each corner.
STYLES.cube = function(out, b)
	paving(out, b, 2, 3, "stone_brick")
	for i, c in ipairs(corners(b, 2)) do
		for y = 1, b.y1 + 1 do put(out, c[1], y, c[2], "pillar") end
		put(out, c[1], b.y1 + 2, c[2], ({ "crystal_cyan", "crystal_purple", "crystal_pink", "crystal_cyan" })[i])
	end
end

-- A colonnade with a glass roof: pillars every 3 nodes on all sides, an open entrance south.
STYLES.hall = function(out, b)
	paving(out, b, 2, 3, "stone_brick")
	local roof = b.y1 + 2
	ring(b, 2, function(x, z, side)
		local along = (side == "south" or side == "north") and x - b.x0 or z - b.z0
		if along % 3 == 0 and not in_entrance(b, x, side, 2) then
			for y = 1, roof - 1 do put(out, x, y, z, "pillar") end
		end
	end)
	for x = b.x0 - 2, b.x1 + 2 do
		for z = b.z0 - 2, b.z1 + 2 do
			local edge = x == b.x0 - 2 or x == b.x1 + 2 or z == b.z0 - 2 or z == b.z1 + 2
			put(out, x, roof, z, edge and "stone_brick" or "glass")
		end
	end
end

-- Brick walls with windows and a wide doorway on the south side.
STYLES.room = function(out, b)
	paving(out, b, 2, 3, "path")
	ring(b, 4, function(x, z, side)
		if in_entrance(b, x, side, 4) then return end
		local along = (side == "north" or side == "south") and x or z
		for y = 1, 5 do
			local window = (y == 3 or y == 4) and along % 4 == 0
			if not window then put(out, x, y, z, "brick") end
		end
		put(out, x, 6, z, "stone_brick")
	end)
end

-- A hedge-lined garden with flower beds.
STYLES.garden = function(out, b)
	paving(out, b, 2, 2, "path")
	ring(b, 3, function(x, z, side)
		if not in_entrance(b, x, side, 2) then put(out, x, 1, z, "hedge") end
	end)
	local flowers = { "flower_pink", "flower_blue", "flower_white" }
	for d = 4, 4 do
		ring(b, d, function(x, z, side)
			if (x * 3 + z * 5) % 3 == 0 and not in_entrance(b, x, side, 2) then
				put(out, x, 1, z, flowers[(x * 7 + z * 3) % 3 + 1])
			end
		end)
	end
	for _, c in ipairs(corners(b, 3)) do lamp_post(out, c[1], c[2], 2) end
end

D.STYLES = STYLES

--- Placements for one region from symmetry.region() and its style name.
function D.region(r, style)
	local out = {}
	local f = STYLES[style or "cube"]
	if f then f(out, extent(r)) end
	return out
end

--- How far a style's decoration reaches beyond the build space (for spacing checks).
D.REACH = { plaza = 5, yard = 4, tower = 4, cube = 3, hall = 3, room = 4, garden = 4 }

---------------------------------------------------------------------------- the world around each region

-- Each region is a world of its own, reached by portal (after MolCraft). In front of it, to the
-- south, is the arrival plaza (built by worlds.lua with its signs and portal back), then a gate
-- arch, then a path to the region's entrance. Around it: trees and crystal formations.

D.ISLAND_RADIUS = 48

--- The arrival plaza in front of a region: x0, x1, z0, z1 (inclusive), and where players arrive.
function D.plaza(r)
	local b = extent(r)
	local p = { x0 = b.cx - 7, x1 = b.cx + 7, z0 = b.z0 - 22, z1 = b.z0 - 12 }
	p.arrive = { x = b.cx, z = b.z0 - 15 }
	p.portal = { x = b.cx, z = b.z0 - 20 }
	p.arch_z = b.z0 - 9
	return p
end

--- Landscape for one region: the approach path, trees and crystal formations.
function D.island(r, style)
	local out = {}
	local b = extent(r)
	local reach = D.REACH[style or "cube"] or 5
	local plaza = D.plaza(r)
	-- The path from the plaza to the paving around the region.
	for z = plaza.z1 + 1, b.z0 - reach - 1 do
		for x = b.cx - 1, b.cx + 1 do put(out, x, 0, z, "path") end
	end
	-- Keep-out areas: the region and its architecture, the plaza, and the approach.
	local keep = {
		{ b.x0 - reach - 3, b.x1 + reach + 3, b.z0 - reach - 3, b.z1 + reach + 3 },
		{ plaza.x0 - 3, plaza.x1 + 3, plaza.z0 - 3, plaza.z1 + 3 },
		{ b.cx - 7, b.cx + 7, plaza.z0, b.z0 },
	}
	local function blocked(x, z, r2)
		for _, k in ipairs(keep) do
			if x >= k[1] - r2 and x <= k[2] + r2 and z >= k[3] - r2 and z <= k[4] + r2 then return true end
		end
		return false
	end
	-- A fixed pseudo-random sequence per region, so every world is built the same way each time.
	local seed = (b.cx * 73856093 + b.z0 * 19349663) % 2147483648
	local function rnd(n)
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed % n
	end
	local taken = {}
	local function free(x, z, r2)
		if blocked(x, z, r2 + 1) then return false end
		for dx = -r2 - 1, r2 + 1 do
			for dz = -r2 - 1, r2 + 1 do
				if taken[(x + dx) .. "," .. (z + dz)] then return false end
			end
		end
		return true
	end
	local function claim(x, z, r2)
		for dx = -r2, r2 do
			for dz = -r2, r2 do taken[(x + dx) .. "," .. (z + dz)] = true end
		end
	end
	local R = D.ISLAND_RADIUS
	local cz = math.floor((b.z0 + b.z1) / 2)
	local trees, formations = 0, 0
	for _ = 1, 1500 do
		local x, z = b.cx - R + rnd(2 * R + 1), cz - R + rnd(2 * R + 1)
		local kind = rnd(3)
		if kind == 0 and trees < 18 and free(x, z, 2) then
			claim(x, z, 2)
			trees = trees + 1
			local h = 3 + rnd(2)
			for y = 1, h do put(out, x, y, z, "bark") end
			for dx = -2, 2 do
				for dz = -2, 2 do
					for dy = 0, 2 do
						local r2 = dx * dx + dz * dz + (dy - 1) * (dy - 1) * 2
						if r2 <= 5 and not (dx == 0 and dz == 0 and dy == 0) then put(out, x + dx, h + dy, z + dz, "leaves") end
					end
				end
			end
		elseif kind > 0 and formations < 22 and free(x, z, 1) then
			claim(x, z, 1)
			formations = formations + 1
			local colour = ({ "cyan", "purple", "pink" })[rnd(3) + 1]
			if rnd(3) == 0 then
				local h = 2 + rnd(3)
				for y = 1, h do put(out, x, y, z, "crystal_block_" .. colour) end
				put(out, x, h + 1, z, "crystal_" .. colour)
			else
				put(out, x, 1, z, "crystal_" .. colour)
				if rnd(2) == 0 then put(out, x + 1, 1, z, "crystal_" .. colour) end
			end
		end
	end
	return out, { trees = trees, formations = formations }
end

return D
