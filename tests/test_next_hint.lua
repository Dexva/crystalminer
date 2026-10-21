-- The "Next:" line (next_hint.lua): what it says for each kind of progress, from the real quiz data.
package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local L = require("lessons")
local content = require("content")
local GD = require("guides")
local H = require("next_hint")
local T = require("testlib")

print("next_hint")

--- Progress with every question of tiers below `tier` answered, plus `extra` ids.
local function progress(tier, extra)
	local p = { tier = tier, answered = {} }
	for t = 0, tier - 1 do
		for _, q in ipairs(L.questions_for_tier(content, t)) do p.answered[q.id] = true end
	end
	for _, id in ipairs(extra or {}) do p.answered[id] = true end
	return p
end

local gate = content.gate.id

T.run("a new player is sent to the quiz in Gallery 1", function()
	T.eq(H.text(content, L, progress(0), ""), H.GATE_GO)
	T.eq(H.text(content, L, progress(0), "mirror_plaza"), H.GATE_GO)
	T.eq(H.text(content, L, progress(0), gate), H.GATE_HERE)
	-- Four of five answered: still the Gate.
	local qs = L.questions(content.gate, 0)
	local some = {}
	for i = 1, #qs - 1 do some[#some + 1] = qs[i].id end
	T.eq(H.text(content, L, progress(0, some), gate), H.GATE_HERE)
end)

T.run("after the Gate: the first world with open questions, and the Try-it Pad until visited", function()
	local p = progress(1)
	local first
	for _, a in ipairs(content.regions) do
		if not first and #L.questions(a, 1) > 0 then first = a end
	end
	T.eq(H.text(content, L, p, ""), H.PORTAL .. first.name .. "\n" .. H.TRYIT)
	p.visited = { [content.tryit.id] = true }
	T.eq(H.text(content, L, p, ""), H.PORTAL .. first.name)
	-- Answer that world's questions: the hint moves on to the next world.
	for _, q in ipairs(L.questions(first, 1)) do p.answered[q.id] = true end
	local text = H.text(content, L, p, "")
	T.ok(text:find(H.PORTAL, 1, true) == 1 and not text:find(first.name, 1, true), text)
end)

T.run("in a world with open questions: build, then /quiz; elsewhere the portal hint", function()
	local p = progress(2)
	p.visited = { [content.tryit.id] = true }
	T.eq(H.text(content, L, p, "square_court"), H.WORLD_HERE)
	-- A world of a lower tier with no questions at this tier is not "here".
	T.ok(H.text(content, L, p, "twofold_yard"):find(H.PORTAL, 1, true) == 1)
	-- Tier 3 has a question in Mirror Plaza (a tier 1 world): building there is suggested too.
	local p3 = progress(3)
	T.eq(H.text(content, L, p3, "mirror_plaza"), H.WORLD_HERE)
end)

T.run("everything answered: the Free Lab and the tour", function()
	local max = L.max_tier(content)
	local p = progress(max)
	for _, q in ipairs(L.questions_for_tier(content, max)) do p.answered[q.id] = true end
	T.eq(L.remaining(content, p), 0)
	T.eq(H.text(content, L, p, ""), H.DONE)
	T.eq(H.text(content, L, p, "free_lab"), H.DONE)
end)

T.run("there is a hint for every tier before the end, and each line is short", function()
	for t = 0, L.max_tier(content) do
		local text = H.text(content, L, progress(t), "")
		T.ok(text ~= nil, "no hint at tier " .. t)
		for line in text:gmatch("[^\n]+") do T.ok(#line <= 64, "too long: " .. line) end
	end
	for _, a in ipairs(content.regions) do
		T.ok(#(H.PORTAL .. a.name) <= 64, a.name)
	end
end)

T.run("the guide window's title, summary and steps fit without scrolling (estimate)", function()
	-- guide_window.lua: text column 10.2 units of about 53 px at 1280x800 (default scaling) and
	-- 16 px text, about 70 characters a line; 8.6 units = about 450 px, about 23 lines of 19 px.
	local per_line, lines_max = 66, 21
	local function lines(s) return math.ceil(#s / per_line) end
	for id, g in pairs(GD) do
		if type(g) == "table" then
			local n = 2 + lines(g.what) + 1 + 1   -- title + blank, summary, blank, "What to do"
			for i, s in ipairs(g.steps) do n = n + lines(i .. ". " .. s) end
			n = n + 3   -- the locked note (two lines and a blank) at most adds this
			T.ok(n <= lines_max, id .. ": about " .. n .. " lines")
		end
	end
end)

T.finish()
