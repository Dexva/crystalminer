package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local S = require("symmetry")
local L = require("lessons")
local T = require("testlib")
local content = require("content")

print("content")

-- Crystal class (point group of the linear parts) of each space-group region.
local SPACE_GROUP_CLASS = { P1 = "1", P2_1 = "2", Pa = "m" }

local function region(id)
	return S.region(L.region_spec(L.area(content, id)))
end

T.run("every region builds and has the symmetry its name claims", function()
	for _, a in ipairs(content.regions) do
		local r = S.region(L.region_spec(a))
		local found = S.identify(S.linear_parts(r.group)).symbol
		local expected = a.hidden or (a.periodic and SPACE_GROUP_CLASS[a.symbol]) or a.symbol
		T.eq(found, expected, a.id)
	end
end)

T.run("group orders stated in quizzes match the engine", function()
	local orders = { mirror_plaza = 2, twofold_yard = 2, fourfold_tower = 4, twin_mirrors = 4,
		monoclinic_cube = 4, square_court = 8, orthorhombic_cube = 8, diagonal_cube = 3, kaleidoscope = 48 }
	for id, n in pairs(orders) do T.eq(#region(id).group.ops, n, id) end
	local hall = L.area(content, "translation_hall")
	T.eq(#S.images(region("translation_hall"), hall.at[1], hall.at[2], hall.at[3]), 27, "translation hall")
end)

T.run("quiz answers point at an option and explain why", function()
	for t = 0, L.max_tier(content) do
		for _, q in ipairs(L.questions_for_tier(content, t)) do
			T.ok(q.answer >= 0 and q.answer < #q.options, q.id)
			T.ok(q.why and #q.why > 0, q.id)
		end
	end
end)

T.run("every tier below the top has questions", function()
	for t = 0, L.max_tier(content) - 1 do T.ok(#L.questions_for_tier(content, t) > 0, "tier " .. t) end
end)

T.run("regions do not overlap each other or the gate", function()
	local boxes = {}
	for _, a in ipairs(content.regions) do
		local r = S.region(L.region_spec(a))
		boxes[#boxes + 1] = { a.id, r.min, r.size }
	end
	local g = content.gate.at
	boxes[#boxes + 1] = { "gate", { g[1] - 3, g[2], g[3] - 5 }, { 58, 10, 10 } }
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, b = boxes[i], boxes[j]
			local apart = false
			for _, k in ipairs({ 1, 3 }) do
				if a[2][k] + a[3][k] + 3 <= b[2][k] or b[2][k] + b[3][k] + 3 <= a[2][k] then apart = true end
			end
			T.ok(apart, a[1] .. " overlaps " .. b[1])
		end
	end
end)

T.run("challenge targets can be built on the grid", function()
	for _, a in ipairs(content.regions) do
		for _, c in ipairs(a.challenges or {}) do T.ok(S.fits_grid(S.point_group(c.target).group), c.target) end
	end
end)

T.run("answering every question walks through the tiers", function()
	local p = L.new_progress()
	for t = 0, L.max_tier(content) - 1 do
		T.eq(p.tier, t)
		local qs = L.questions_for_tier(content, t)
		for i, q in ipairs(qs) do T.eq(L.record_correct(content, p, q.id), i == #qs, q.id) end
	end
	T.eq(p.tier, L.max_tier(content))
end)

T.run("question ids round-trip", function()
	local q = L.questions_for_tier(content, 0)[1]
	T.eq(L.question(content, q.id).q, q.q)
	T.eq(L.question(content, "nonsense"), nil)
end)

T.run("explanations grow with tier", function()
	local m = L.area(content, "mirror_plaza")
	T.ok(#L.explanation(m, 1) < #L.explanation(m, 3))
	T.eq(#L.explanation(m, 0), 0)
end)

T.finish()
