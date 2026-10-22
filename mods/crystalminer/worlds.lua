-- Each symmetry region is a world of its own, reached through the Portal Hall (after MolCraft).
-- Here: the arrival plaza with its information boards and the portal back, and the entrance arch
-- with the world's name. The region, its architecture and its landscape are built elsewhere.

local cm = crystalminer
local content, D, SG, L = cm.content, cm.D, cm.SG, cm.L
local GROUND = cm.GROUND_Y
local W = content.worlds

local function set(x, y, z, name) core.set_node({ x = x, y = y, z = z }, { name = name }) end

--- The words on a world's main board: its name, symmetry, tier and what it teaches.
local function info_text(live)
	local a = live.area
	local g = cm.GUIDES[a.id]
	if g then
		local t = cm.GUIDES.board_text(g)
		if a.tier > 0 then t = t .. "\n\n" .. string.format(W.locked, a.tier) end
		return t
	end
	local lines = { "# " .. a.name, "## Symmetry " .. live.symbol .. " · tier " .. a.tier, "" }
	for _, l in ipairs(L.explanation(a, a.tier)) do lines[#lines + 1] = l end
	if a.tier > 0 then lines[#lines + 1] = "" lines[#lines + 1] = string.format(W.locked, a.tier) end
	return table.concat(lines, "\n")
end
cm.world_info_text = info_text

local function build_world(live)
	local r = live.region
	local b = D.extent(r)
	local p = D.plaza(r)
	-- The plaza, with lamp posts at its corners.
	for x = p.x0, p.x1 do
		for z = p.z0, p.z1 do set(x, GROUND, z, "crystalminer:plaza") end
	end
	for _, c in ipairs({ { p.x0, p.z0 }, { p.x1, p.z0 }, { p.x0, p.z1 }, { p.x1, p.z1 } }) do
		for y = GROUND + 1, GROUND + 3 do set(c[1], y, c[2], "crystalminer:pillar") end
		set(c[1], GROUND + 4, c[2], "crystalminer:lamp")
	end
	-- Two walls carrying the boards, on either side of the plaza, facing in; centred on the plaza
	-- so that the lamp posts at its corners stand clear of them.
	local BZ = math.floor((p.z0 + p.z1) / 2)
	for _, side in ipairs({ { x = p.x0 - 1, face = "e" }, { x = p.x1 + 1, face = "w" } }) do
		for z = BZ - 3, BZ + 3 do
			for y = GROUND + 1, GROUND + 6 do set(side.x, y, z, "crystalminer:stone_brick") end
		end
	end
	SG.on_wall({ x = p.x0 - 1, y = GROUND + 3.5, z = BZ }, "e", "board", info_text(live))
	SG.on_wall({ x = p.x1 + 1, y = GROUND + 3.5, z = BZ }, "w", "board", cm.GUIDES.howto)
	-- The portal back, in a frame at the south end of the plaza.
	local px, pz = p.portal.x, p.portal.z
	for y = GROUND + 1, GROUND + 4 do
		set(px - 2, y, pz, "crystalminer:pillar")
		set(px + 2, y, pz, "crystalminer:pillar")
	end
	for x = px - 2, px + 2 do set(x, GROUND + 5, pz, "crystalminer:stone_brick") end
	set(px, GROUND + 1, pz, "crystalminer:teleporter")
	local meta = core.get_meta({ x = px, y = GROUND + 1, z = pz })
	meta:set_string("target", "portal_hall")
	meta:set_string("infotext", "Portal back to the museum (punch it)")
	SG.on_wall({ x = px, y = GROUND + 5, z = pz }, "n", "plaque", "# To the museum\nPunch the portal to go back to the Portal Hall.")
	-- The entrance arch, with the world's name.
	for y = GROUND + 1, GROUND + 6 do
		set(b.cx - 4, y, p.arch_z, "crystalminer:pillar")
		set(b.cx + 4, y, p.arch_z, "crystalminer:pillar")
	end
	for x = b.cx - 4, b.cx + 4 do
		for y = GROUND + 7, GROUND + 8 do set(x, y, p.arch_z, "crystalminer:stone_brick") end
	end
	SG.on_wall({ x = b.cx, y = GROUND + 7.5, z = p.arch_z }, "s", "banner",
		"# " .. live.area.name:upper() .. "\nSymmetry " .. live.symbol .. " · tier " .. live.area.tier)
end

table.insert(cm.on_build, function()
	for _, live in ipairs(cm.regions) do
		cm.load_region(cm.world_box(live))
		build_world(live)
	end
end)
