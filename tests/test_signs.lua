-- Every sign in the game: its text fits its frame, and every character has a glyph.
package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local L = require("lessons")
local content = require("content")
local SG = require("signs")
local T = require("testlib")

print("signs")

local LB, W = content.lobby, content.worlds

--- Every sign the game builds, as { format, text, where }, mirroring lobby.lua, worlds.lua and museum.lua.
local function all_signs()
	local out = {}
	local function add(format, text, where) out[#out + 1] = { format, text, where } end
	add("banner", "# MUSEUM OF CRYSTALS AND SYMMETRY\nWelcome. The doors open with a click.", "front door")
	for _, k in ipairs({ "welcome", "information", "workshop", "gallery1", "gallery2", "gallery3", "portals" }) do
		add("board", LB[k], k)
	end
	local words = { "# Words to know" }
	for i = 1, 9 do words[#words + 1] = content.glossary[i] end
	add("board", table.concat(words, "\n"), "words to know")
	for _, l in ipairs({ "A", "B", "C", "D" }) do add("plaque", string.format(LB.display, l), "display " .. l) end
	for _, h in ipairs(LB.history) do add("panel", "# " .. h.year .. "  " .. h.who .. "\n" .. h.text, "history " .. h.year) end
	add("plaque", "# Haüy's idea, in blocks\nIdentical cubes, stacked, make an octahedron with stepped faces. From far away the steps vanish and the faces look flat.", "Haüy")
	for _, ex in ipairs(content.museum.exhibits) do add("panel", "# " .. ex.name .. "\n" .. table.concat(ex.facts, " "), ex.id) end
	for _, a in ipairs(content.regions) do
		local idea = ((a.explain or {})[a.tier] or {})[1] or ""
		add("plaque", "# " .. a.name .. "\nSymmetry " .. a.symbol .. " · tier " .. a.tier .. "\n" .. idea, "portal " .. a.id)
		local lines = { "# " .. a.name, "Symmetry " .. a.symbol .. " · tier " .. a.tier, "" }
		for _, l in ipairs(L.explanation(a, a.tier)) do lines[#lines + 1] = l end
		lines[#lines + 1] = ""
		lines[#lines + 1] = string.format(W.locked, a.tier)
		add("board", table.concat(lines, "\n"), "board " .. a.id)
		add("banner", "# " .. a.name:upper() .. "\nSymmetry " .. a.symbol .. " · tier " .. a.tier, "arch " .. a.id)
	end
	local GD = require("guides")
	for _, sc in ipairs(require("sculptures").list) do add("plaque", sc.plaque, "sculpture " .. sc.id) end
	add("banner", "# INFORMATION\nAsk, read, and take the tour: /tour", "information desk")
	add("board", GD.howto, "how to")
	add("plaque", "# YOUR SHAPE\nBuild your shape in this box.", "pad build")
	add("plaque", "# COPY\nThe lever's copy appears here.", "pad copy")
	for _, w in ipairs({ "T\nslide", "R\nturn half a turn", "M\nmirror", "I\nthrough the centre" }) do
		add("label", "# " .. w, "lever " .. w:sub(1, 1))
	end
	add("plaque", "# To the museum\nPunch the portal to go back to the Portal Hall.", "portal back")
	return out
end

T.run("every sign's text fits its frame", function()
	for _, s in ipairs(all_signs()) do
		local _, fits = SG.texture(s[1], s[2])
		T.ok(fits, s[3] .. " does not fit a " .. s[1])
	end
end)

T.run("every character on every sign has a glyph", function()
	for _, s in ipairs(all_signs()) do
		local text = s[2]:gsub("%?", ""):gsub("\n", " ")
		for _, c in ipairs(SG.codepoints(text)) do
			T.ok(c ~= 63, s[3] .. ": a character has no glyph in: " .. s[2]:sub(1, 60))
		end
	end
end)

T.run("glyph files exist for every known character", function()
	local seen = {}   -- each character once: opening files on a shared folder is slow
	for _, s in ipairs(all_signs()) do
		for _, c in ipairs(SG.codepoints(s[2])) do
			if not seen[c] then seen[c] = true for _, prefix in ipairs({ "gd", "gl", "hd", "hl" }) do
				local f = io.open("mods/crystalminer/textures/crystalminer_" .. prefix .. "_" .. c .. ".png", "rb")
				T.ok(f ~= nil, "missing glyph " .. prefix .. " " .. c)
				if f then f:close() end
			end end
		end
	end
end)

T.run("wrapping keeps words whole and headings big", function()
	local lines = SG.wrap("# Title\nalpha beta gamma delta", 11, 7)
	T.ok(lines[1].heading and #lines[1].cps == 5, "heading")
	T.eq(#lines, 3, "two body lines")
	local tex = SG.texture("label", "# Hi")
	T.ok(tex:find("crystalminer_hd_72.png", 1, true) ~= nil, "big H in dark ink")
end)

T.finish()
