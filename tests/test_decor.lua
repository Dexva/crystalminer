package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local S = require("symmetry")
local L = require("lessons")
local content = require("content")
local D = require("decor")
local T = require("testlib")

print("decor")

local regions = {}
for _, a in ipairs(content.regions) do
	regions[#regions + 1] = { id = a.id, r = S.region(L.region_spec(a)), style = a.style }
end

local placements = {}
for _, e in ipairs(regions) do
	for _, p in ipairs(D.region(e.r, e.style)) do p.from = e.id .. " architecture"; placements[#placements + 1] = p end
	for _, p in ipairs(D.island(e.r, e.style)) do p.from = e.id .. " landscape"; placements[#placements + 1] = p end
end

T.run("every region has a known style", function()
	for _, e in ipairs(regions) do T.ok(D.STYLES[e.style], e.id .. " style " .. tostring(e.style)) end
end)

T.run("no decoration enters a build space or its border, below the roofs", function()
	for _, e in ipairs(regions) do
		local b = D.extent(e.r)
		for _, p in ipairs(placements) do
			local inside = p.x >= b.x0 - 1 and p.x <= b.x1 + 1 and p.z >= b.z0 - 1 and p.z <= b.z1 + 1
			T.ok(not (inside and p.y <= b.y1 + 1), p.n .. " from " .. p.from .. " at " .. p.x .. "," .. p.y .. "," .. p.z .. " is inside " .. e.id)
		end
	end
end)

T.run("the arrival plaza, the arch and the path to each region are clear", function()
	local solid = {}
	for _, p in ipairs(placements) do if p.y >= 1 then solid[p.x .. "," .. p.y .. "," .. p.z] = p.from end end
	for _, e in ipairs(regions) do
		local b, pl = D.extent(e.r), D.plaza(e.r)
		for x = pl.x0, pl.x1 do
			for z = pl.z0, pl.z1 do
				for y = 1, 6 do T.ok(not solid[x .. "," .. y .. "," .. z], e.id .. " plaza blocked by " .. tostring(solid[x .. "," .. y .. "," .. z])) end
			end
		end
		for z = pl.z1, b.z0 - 2 do
			for x = b.cx - 2, b.cx + 2 do
				for y = 1, 3 do T.ok(not solid[x .. "," .. y .. "," .. z], e.id .. " approach blocked at " .. x .. "," .. y .. "," .. z) end
			end
		end
	end
end)

T.run("worlds do not touch each other or the museum", function()
	local boxes = {}
	for _, e in ipairs(regions) do
		local b = D.extent(e.r)
		local cz = math.floor((b.z0 + b.z1) / 2)
		boxes[#boxes + 1] = { e.id, b.cx - D.ISLAND_RADIUS - 3, b.cx + D.ISLAND_RADIUS + 3, math.min(cz - D.ISLAND_RADIUS, D.plaza(e.r).z0) - 3, cz + D.ISLAND_RADIUS + 3 }
	end
	boxes[#boxes + 1] = { "museum", -61, 61, -51, 91 }
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, c = boxes[i], boxes[j]
			T.ok(a[3] < c[2] or c[3] < a[2] or a[5] < c[4] or c[5] < a[4], a[1] .. " overlaps " .. c[1])
		end
	end
end)

T.run("decorations of different worlds do not collide", function()
	local owner = {}
	for _, p in ipairs(placements) do
		local k = p.x .. "," .. p.y .. "," .. p.z
		local world = p.from:match("^(%S+)")
		if owner[k] and owner[k] ~= world and p.y >= 1 then error(k .. ": " .. owner[k] .. " and " .. world) end
		owner[k] = owner[k] or world
	end
end)

T.run("every world has trees and crystal formations", function()
	for _, e in ipairs(regions) do
		local _, counts = D.island(e.r, e.style)
		T.ok(counts.trees >= 8, e.id .. " trees " .. counts.trees)
		T.ok(counts.formations >= 10, e.id .. " formations " .. counts.formations)
	end
end)

T.finish()
