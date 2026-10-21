-- The /showcase builds: each seed stays inside its region, its copies never clash, the finished
-- build has exactly the symmetry its region claims, and the counts the text gives are right.
package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local S = require("symmetry")
local L = require("lessons")
local content = require("content")
local T = require("testlib")

print("showcase")

--- Builds a region's showcase in the engine: map "x,y,z" -> colour, and per-seed image counts.
local function build(a)
	local r = S.region(L.region_spec(a))
	local nodes, counts = {}, {}
	for i, b in ipairs(L.showcase_blocks(a)) do
		local x, y, z = r.min[1] + b[1], r.min[2] + b[2], r.min[3] + b[3]
		T.ok(S.contains_pos(r, x, y, z), a.id .. " seed " .. i .. " outside the region")
		local ims = S.images(r, x, y, z)
		counts[i] = #ims
		for _, im in ipairs(ims) do
			local k = im.x .. "," .. im.y .. "," .. im.z
			T.ok(nodes[k] == nil or nodes[k] == b[4], a.id .. ": two colours land on " .. k)
			nodes[k] = b[4]
		end
	end
	return r, nodes, counts
end

T.run("showcases exist for the regions used in a demo", function()
	local n = 0
	for _, a in ipairs(content.regions) do if a.showcase then n = n + 1 end end
	T.ok(n >= 15, "showcases: " .. n)
end)

T.run("every showcase stays inside its region and its copies never clash", function()
	for _, a in ipairs(content.regions) do
		if a.showcase then build(a) end
	end
end)

T.run("each finished point-group build has exactly its region's symmetry", function()
	for _, a in ipairs(content.regions) do
		if a.showcase and not a.periodic then
			local _, nodes = build(a)
			local doubled = {}
			for k, c in pairs(nodes) do
				local x, y, z = k:match("(-?%d+),(-?%d+),(-?%d+)")
				doubled[(2 * x + 1) .. "," .. (2 * y + 1) .. "," .. (2 * z + 1)] = c
			end
			local _, e = S.detect(doubled)
			T.eq(e and e.symbol, a.symbol, a.id)
		end
	end
end)

T.run("the counts the showcase text gives are right", function()
	local _, _, k = build(L.area(content, "kaleidoscope"))
	T.eq(k[1], 48, "yellow, general position")
	T.eq(k[2], 8, "green, on a 3-fold axis")
	T.eq(k[3], 6, "red, on a 4-fold axis")
	local _, _, d = build(L.area(content, "diagonal_cube"))
	T.eq(d[1], 3, "cyan hook")
	T.eq(d[4], 1, "white block on the 3-fold axis")
	local _, _, t = build(L.area(content, "twin_mirrors"))
	T.eq(t[1], 4, "seat")
	local _, _, b = build(L.area(content, "bar_three_room"))
	T.eq(b[1], 6, "-3 hook")
	local _, _, m = build(L.area(content, "rotoinversion_room"))
	T.eq(m[1], 4, "-4 hook")
	local _, _, f = build(L.area(content, "fourfold_tower"))
	T.eq(f[9], 4, "sail")
	local _, _, p = build(L.area(content, "mirror_plaza"))
	local body, wing = 0, 0
	for _, c in ipairs(p) do if c == 1 then body = body + 1 else wing = wing + 1 end end
	T.ok(body > 0 and wing > 0, "butterfly has a body on the mirror and wings off it")
end)

T.run("the -4 copies alternate up and down", function()
	local a = L.area(content, "rotoinversion_room")
	local r = S.region(L.region_spec(a))
	local seed = L.showcase_blocks(a)[1]
	local up, down = 0, 0
	for _, im in ipairs(S.images(r, r.min[1] + seed[1], r.min[2] + seed[2], r.min[3] + seed[3])) do
		if im.y - r.min[2] > 7 then up = up + 1 else down = down + 1 end
	end
	T.eq(up, 2) T.eq(down, 2)
end)

T.finish()
