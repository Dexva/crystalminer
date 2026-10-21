-- The plain-language guides: one for every place, and every number they state is the engine's.
package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local S = require("symmetry")
local L = require("lessons")
local content = require("content")
local GD = require("guides")
local SG = require("signs")
local T = require("testlib")

print("guides")

T.run("every region, the Gate and the Try-it Pad have a guide", function()
	for _, a in ipairs(content.regions) do T.ok(GD[a.id] ~= nil, "no guide for " .. a.id) end
	T.ok(GD[content.gate.id] ~= nil, "gate")
	T.ok(GD[content.tryit.id] ~= nil, "try-it pad")
	for id, g in pairs(GD) do
		if type(g) == "table" then
			T.ok(g.title and g.what and g.steps and #g.steps >= 2 and g.see and g.word, id .. " is incomplete")
		end
	end
end)

T.run("each guide's count is what one block becomes, and its text says so", function()
	for _, a in ipairs(content.regions) do
		local g = GD[a.id]
		if g.count then
			local r = S.region(L.region_spec(a))
			-- The largest number of distinct images over every position: a block on no element.
			local best = 0
			for x = r.min[1], r.min[1] + r.size[1] - 1, 1 do
				for y = r.min[2], r.min[2] + math.min(r.size[2], 6) - 1 do
					for z = r.min[3], r.min[3] + r.size[3] - 1, 1 do
						local n = #S.images(r, x, y, z)
						if n > best then best = n end
					end
				end
			end
			T.eq(best, g.count, a.id .. " count")
			T.ok((g.see .. " " .. g.what .. " " .. table.concat(g.steps, " ")):find(tostring(g.count), 1, true) ~= nil,
				a.id .. ": the text does not state " .. g.count)
		end
	end
end)

T.run("the first shape suggested at the Try-it Pad is chiral, so M shows a mirror twin", function()
	-- "three blocks in a row, a tower of two blocks on top of one end, and one block sticking out
	-- sideways at the other end"
	local shape = { { 0, 0, 0 }, { 1, 0, 0 }, { 2, 0, 0 }, { 0, 1, 0 }, { 0, 2, 0 }, { 2, 0, 1 } }
	local nodes = {}
	for _, b in ipairs(shape) do nodes[(2 * b[1] + 1) .. "," .. (2 * b[2] + 1) .. "," .. (2 * b[3] + 1)] = "a" end
	for _, o in ipairs(S.detect(nodes).ops) do T.ok(S.det(o) > 0, "the shape has a mirror or centre of its own") end
	-- and the plain row suggested for comparison is not chiral
	local row = { ["1,1,1"] = "a", ["3,1,1"] = "a", ["5,1,1"] = "a" }
	local improper = false
	for _, o in ipairs(S.detect(row).ops) do if S.det(o) < 0 then improper = true end end
	T.ok(improper, "a row has a mirror")
end)

T.run("guide boards fit their signs", function()
	for id, g in pairs(GD) do
		if type(g) == "table" then
			local _, fits = SG.texture("board", GD.board_text(g) .. "\n\nBuilding here opens at tier 4. You reach a new tier by answering all the /quiz questions of the places you have already opened. Press I to see your tier.")
			T.ok(fits, id .. " guide does not fit a board")
		end
	end
	local _, fits = SG.texture("board", GD.howto)
	T.ok(fits, "howto does not fit")
end)

T.run("every guide, exhibit and history panel has its picture", function()
	local function exists(f)
		local h = io.open("mods/crystalminer/textures/" .. f, "rb")
		if h then h:close() end
		return h ~= nil
	end
	for id, g in pairs(GD) do
		if type(g) == "table" and id ~= "mystery_lab" then T.ok(exists("crystalminer_guide_" .. id .. ".png"), "guide picture " .. id) end
	end
	for _, ex in ipairs(content.museum.exhibits) do T.ok(exists("crystalminer_fig_" .. ex.id .. ".png"), "exhibit " .. ex.id) end
	for _, h in ipairs(content.lobby.history) do T.ok(exists("crystalminer_hist_" .. h.year .. ".png"), "history " .. h.year) end
end)

T.run("the museum plan picture shows the walls and doorways of lobby.lua", function()
	local function walls(text, pat)
		local out = {}
		for axis, v, doors in text:gmatch(pat) do out[#out + 1] = axis .. v .. ":" .. doors:gsub("%s", "") end
		return table.concat(out, ";")
	end
	local lua = io.open("mods/crystalminer/lobby.lua"):read("*a")
	local py = io.open("tools/make_figures.py"):read("*a")
	local a = walls(lua, '{ "(%a)", (%-?%d+), [^{]-{ ([%-%d, ]+) } }')
	local b = walls(py, '%("(%a)", (%-?%d+), [%-%d]+, [%-%d]+, %[([%-%d, ]+)%]%)')
	T.ok(#a > 0, "walls found in lobby.lua")
	T.eq(b, a, "plan walls")
end)

T.run("the sculptures' symmetry is what their plaques say", function()
	local SC = require("sculptures")
	for _, sc in ipairs(SC.list) do
		if sc.symmetry then
			local nodes = {}
			for _, b in ipairs(sc.blocks) do nodes[(2 * b[1] + 1) .. "," .. (2 * b[2] + 1) .. "," .. (2 * b[3] + 1)] = b[4] end
			local _, entry = S.detect(nodes)
			T.eq(entry and entry.symbol, sc.symmetry, sc.id)
			T.ok(sc.plaque:find(sc.symmetry, 1, true) ~= nil, sc.id .. " plaque names its symmetry")
		end
	end
end)

T.finish()
