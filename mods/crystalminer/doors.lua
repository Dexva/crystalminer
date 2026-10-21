-- Doors for the museum and the worlds' gatehouses: two nodes high, opened and closed with a
-- right-click or a punch. A closed door is a thin panel across the doorway; an open one is turned
-- against the side of the frame. facedir (param2) gives the direction the doorway runs.

local cm = crystalminer

local CLOSED = { -0.5, -0.5, -0.0625, 0.5, 0.5, 0.0625 }   -- across the doorway (along x)
local OPEN = { -0.5, -0.5, -0.5, -0.375, 0.5, 0.5 }           -- against the left side of the frame

local function def(half, open)
	local tile = "crystalminer_door_" .. half .. ".png"
	return {
		description = "Door", drawtype = "nodebox", paramtype = "light", paramtype2 = "facedir",
		sunlight_propagates = true, use_texture_alpha = "clip",
		tiles = { "crystalminer_planks.png", "crystalminer_planks.png", "crystalminer_planks.png",
			"crystalminer_planks.png", tile, tile },
		node_box = { type = "fixed", fixed = open and OPEN or CLOSED },
		groups = { not_in_creative_inventory = 1 }, is_ground_content = false,
		on_rightclick = function(pos) cm.toggle_door(pos) end,
		on_punch = function(pos) cm.toggle_door(pos) end,
	}
end

for _, half in ipairs({ "bottom", "top" }) do
	core.register_node("crystalminer:door_" .. half, def(half, false))
	core.register_node("crystalminer:door_" .. half .. "_open", def(half, true))
end

local function other_half(pos, name)
	if name:find("bottom") then return { x = pos.x, y = pos.y + 1, z = pos.z } end
	return { x = pos.x, y = pos.y - 1, z = pos.z }
end

function cm.toggle_door(pos)
	local node = core.get_node(pos)
	if not node.name:find("^crystalminer:door_") then return end
	local open = node.name:find("_open$") ~= nil
	for _, p in ipairs({ pos, other_half(pos, node.name) }) do
		local n = core.get_node(p)
		if n.name:find("^crystalminer:door_") then
			local base = n.name:gsub("_open$", "")
			core.swap_node(p, { name = open and base or (base .. "_open"), param2 = n.param2 })
		end
	end
end

-- facedir for a doorway running along x (in a wall that runs east-west) or along z. The
-- mirrored leaf of a double door is turned half a turn, so that it opens against the other side.
local FACEDIR = { x = 0, z = 1 }

--- Places a door with its bottom at pos, in a wall running along "x" or "z". mirror = true for
--- the second leaf of a double door.
function cm.place_door(pos, along, open, mirror)
	local p2 = FACEDIR[along] + (mirror and 2 or 0)
	core.set_node(pos, { name = "crystalminer:door_bottom" .. (open and "_open" or ""), param2 = p2 })
	core.set_node({ x = pos.x, y = pos.y + 1, z = pos.z }, { name = "crystalminer:door_top" .. (open and "_open" or ""), param2 = p2 })
end
