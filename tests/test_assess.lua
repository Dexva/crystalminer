package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local S = require("symmetry")
local A = require("assess")
local content = require("content")
local T = require("testlib")

print("assessment")

local items = content.assessment.items

T.run("every item has a correct option that is not 'I don't know yet'", function()
	local ids = {}
	for _, it in ipairs(items) do
		T.ok(not ids[it.id], "duplicate id " .. it.id)
		ids[it.id] = true
		T.ok(it.answer >= 0 and it.answer < #it.options - 1, it.id .. " answer index")
		T.eq(it.options[#it.options], "I don't know yet", it.id)
		T.ok(it.tag and #it.tag > 0, it.id .. " tag")
	end
end)

local function opt(id)
	for _, it in ipairs(items) do if it.id == id then return it.options[it.answer + 1] end end
end

T.run("answers that depend on symmetry facts agree with the engine", function()
	T.eq(opt("order4"), tostring(#S.point_group("4").group.ops))
	T.eq(opt("order6"), tostring(#S.point_group("6").group.ops))
	-- A block on a mirror plane is its own image.
	local r = S.region({ min = { 0, 1, 0 }, size = { 15, 12, 15 }, anchor = "floor", generators = { "-x,y,z" } })
	T.eq(opt("on_element"), tostring(#S.images(r, 7, 3, 4)))
	-- Inversion: (2 east, 3 up) -> (2 west, 3 down).
	local v = S.apply(S.parse("-x,-y,-z"), { 2, 0, 3 })
	T.ok(v[1] == -2 and v[3] == -3 and opt("inversion") == "2 west and 3 down")
	-- Two perpendicular mirrors contain a 2-fold axis, but no 4-fold axis and no inversion.
	local mm2 = S.point_group("mm2").group
	T.ok(S.contains(mm2, S.parse("-x,-y,z")) and not S.signature(mm2)["4"] and not S.signature(mm2)["-1"])
	T.eq(opt("combine_mm"), "A half turn about the line where the mirrors meet")
	-- -4 does not contain a 4-fold rotation.
	T.ok(not S.signature(S.point_group("-4").group)["4"] and opt("rotoinversion") == "No")
	-- No crystallographic point group has a 5-fold operation: all 32 have kinds 1, 2, 3, 4, 6 only.
	for _, e in ipairs(S.catalog) do
		for k in pairs(S.signature(e.group)) do T.ok(k ~= "?", e.symbol) end
	end
	T.eq(opt("restriction"), "No")
end)

T.run("records score, complete and compute normalized gain", function()
	local rec = A.new("abc")
	for _, it in ipairs(items) do A.answer(rec, "pre", items, it.id, (it.id == "order4") and it.answer or #it.options - 1, 1) end
	T.ok(A.complete(rec, "pre", items))
	T.eq(select(1, A.score(rec, "pre", items)), 1)
	for _, it in ipairs(items) do A.answer(rec, "post", items, it.id, it.answer, 2) end
	T.eq(select(1, A.score(rec, "post", items)), #items)
	T.eq(A.gain(1, #items, #items), 1)
	T.eq(A.gain(#items, #items, #items), nil)
	local s = A.summary({ rec }, items)
	T.eq(s.n_paired, 1)
	T.eq(s.mean_gain, 1)
end)

T.run("exports contain anonymous ids only and escape commas", function()
	local rec = A.new("p01")
	A.answer(rec, "pre", items, items[1].id, 0, 5)
	A.record_prediction(rec, "mirror_plaza", 2, 2, 2, 6)
	local csv = A.tests_csv({ alice = rec }, items)
	T.ok(not csv:find("alice"), "name leaked")
	T.ok(csv:find("p01,pre," .. items[1].id, 1, true))
	T.ok(A.predictions_csv({ rec }):find("p01,mirror_plaza,2,2,2,1,6", 1, true))
	T.ok(A.tests_csv({ rec }, { { id = "x", tag = "a,b", options = { "1", "I don't know" }, answer = 0 } }) ~= nil)
end)

T.run("count options include the true count and the number of operations", function()
	local o = A.count_options(4, 8)
	local has4, has8 = false, false
	for _, n in ipairs(o) do has4, has8 = has4 or n == 4, has8 or n == 8 end
	T.ok(has4 and has8 and #o == 4)
	T.eq(A.count_options(1, 2)[1], 1)
end)

T.finish()
