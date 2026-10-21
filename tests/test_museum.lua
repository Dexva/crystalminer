package.path = "mods/crystalminer/?.lua;tests/?.lua;" .. package.path
local S = require("symmetry")
local M = require("structures")
local P = require("stereo")
local T = require("testlib")

print("museum and diagram")

-- Nearest neighbours of every interior atom of the given element, among atoms of the listed
-- elements: all must agree with the textbook coordination number.
local function check_cn(kind, n, centre_el, around, expected, expected_d2)
	local atoms = M.model(kind, n)
	local checked = 0
	for _, a in ipairs(atoms) do
		local interior = a[1] >= 2 and a[1] <= n - 2 and a[2] >= 2 and a[2] <= n - 2 and a[3] >= 2 and a[3] <= n - 2
		if interior and a[4] == centre_el then
			local cn, d2 = M.coordination(atoms, a, around)
			T.eq(cn, expected, kind .. " coordination of " .. centre_el)
			if expected_d2 then T.eq(d2, expected_d2, kind .. " nearest distance squared") end
			checked = checked + 1
		end
	end
	T.ok(checked > 0, kind .. ": no interior atom checked")
end

T.run("copper (fcc): every atom has 12 nearest neighbours", function()
	check_cn("fcc", 8, "cu", nil, 12, 2)
end)
T.run("alpha iron (bcc): 8 nearest neighbours", function()
	check_cn("bcc", 8, "fe", nil, 8, 3)
end)
T.run("rock salt: each ion has 6 nearest neighbours, all of the other kind", function()
	check_cn("rocksalt", 8, "na", nil, 6, 1)
	check_cn("rocksalt", 8, "na", { cl = true }, 6, 1)
	check_cn("rocksalt", 8, "cl", { na = true }, 6, 1)
end)
T.run("caesium chloride: 8 ions of the other kind around each ion", function()
	check_cn("cscl", 8, "cs", { cl = true }, 8, 3)
	check_cn("cscl", 8, "cl", { cs = true }, 8, 3)
end)
T.run("perovskite: 6 oxygens around each titanium; 12 around each strontium", function()
	check_cn("perovskite", 8, "ti", { o = true }, 6, 1)
	check_cn("perovskite", 8, "sr", { o = true }, 12, 2)
end)
T.run("diamond: each carbon has 4 nearest neighbours", function()
	check_cn("diamond", 12, "c", nil, 4, 3)
end)

T.run("the models of size 6 have full cubic symmetry about their centre; diamond's centre is an atom with -43m", function()
	local function sym(kind, n)
		local nodes = {}
		for _, a in ipairs(M.model(kind, n)) do nodes[(2 * a[1] + 1) .. "," .. (2 * a[2] + 1) .. "," .. (2 * a[3] + 1)] = a[4] end
		return select(2, S.detect(nodes)).symbol
	end
	for _, k in ipairs({ "fcc", "bcc", "rocksalt", "cscl", "perovskite" }) do T.eq(sym(k, 6), "m-3m", k) end
	T.eq(sym("diamond", 8), "-43m", "diamond")
end)

T.run("CsCl's lattice is primitive: the body-centre translation does not map the structure onto itself", function()
	local atoms = M.model("cscl", 6)
	local at = {}
	for _, a in ipairs(atoms) do at[a[1] .. "," .. a[2] .. "," .. a[3]] = a[4] end
	-- (1,1,1) is half a cell along the body diagonal: it sends Cl sites to Cs sites.
	T.eq(at["0,0,0"], "cl")
	T.eq(at["1,1,1"], "cs")
end)

local function grid_groups()
	local out = {}
	for _, e in ipairs(S.catalog) do if not e.hexagonal_basis then out[#out + 1] = e end end
	return out
end

T.run("the diagram draws one dot or ring per operation, for all 25 grid point groups", function()
	for _, e in ipairs(grid_groups()) do
		local n = 0
		for _, m in ipairs(P.marks(S, e.group.ops)) do
			if m.kind == "above" or m.kind == "below" then n = n + 1 end
			T.ok(m.u * m.u + m.v * m.v <= 1.0001, e.symbol .. " mark outside the disc")
		end
		T.eq(n, #e.group.ops, e.symbol)
	end
end)

T.run("diagram symbols: 4mm has a 4-fold symbol at the centre and mirror lines; m-3m has 3 four-fold symbols visible", function()
	local function axes(symbol)
		local out = {}
		for _, m in ipairs(P.marks(S, S.point_group(symbol).group.ops)) do
			if m.kind == "axis" then out[#out + 1] = m end
		end
		return out
	end
	local a = axes("4mm")
	T.eq(#a, 1)
	T.ok(a[1].symbol == "4" and math.abs(a[1].u) < 1e-9 and math.abs(a[1].v) < 1e-9)
	local fours = 0
	for _, m in ipairs(axes("m-3m")) do if m.symbol == "4" then fours = fours + 1 end end
	-- The vertical 4-fold axis at the centre, and the two horizontal ones at both ends on the rim.
	T.eq(fours, 5)
	local mirrors = 0
	for _, m in ipairs(P.marks(S, S.point_group("4mm").group.ops)) do if m.kind == "mirror" then mirrors = mirrors + 1 end end
	T.ok(mirrors > 0)
	-- -4 shows a -4 symbol and no 4.
	local m4 = axes("-4")
	T.ok(#m4 == 1 and m4[1].symbol == "m4")
end)

T.run("the diagram texture string is well formed", function()
	local tex = P.texture(P.marks(S, S.point_group("2/m").group.ops), 160)
	T.ok(tex:find("^%[combine:160x160:0,0=crystalminer_st_bg.png"))
	T.ok(not tex:find("nan", 1, true))
end)

T.run("every clue answer is the neighbour count measured on its exhibit's model", function()
	local content = require("content")
	for _, ex in ipairs(content.museum.exhibits) do
		local c = ex.clue
		local n = ex.n + 4
		local atoms = M.model(ex.structure, n)
		local around
		if c.check.around then
			around = {}
			for _, el in ipairs(c.check.around) do around[el] = true end
		end
		local checked = 0
		for _, a in ipairs(atoms) do
			local interior = a[1] >= 2 and a[1] <= n - 2 and a[2] >= 2 and a[2] <= n - 2 and a[3] >= 2 and a[3] <= n - 2
			if interior and a[4] == c.check.centre then
				T.eq(M.coordination(atoms, a, around), c.check.expected, ex.id)
				checked = checked + 1
			end
		end
		T.ok(checked > 0, ex.id .. ": nothing checked")
		T.eq(c.options[c.answer + 1], tostring(c.check.expected), ex.id .. ": the answer option shows the count")
		for el, colour in pairs(ex.colours) do T.ok(colour:match("^[%a_]+$"), ex.id .. " colour") end
		for _, a in ipairs(M.model(ex.structure, ex.n)) do T.ok(ex.colours[a[4]], ex.id .. ": no colour for " .. a[4]) end
	end
end)

T.run("the museum's exhibits fit inside the hall without overlapping", function()
	local content = require("content")
	local mu = content.museum
	local boxes = {}
	for i, ex in ipairs(mu.exhibits) do
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		local size = 2 * ex.n + 1
		local x0 = mu.at[1] + 4 + col * 23 + math.floor((19 - size) / 2)
		local z0 = mu.at[3] + 8 + row * 26
		T.ok(x0 - 1 > mu.at[1] and x0 + size < mu.at[1] + mu.size[1] - 1, ex.id .. " x")
		T.ok(z0 - 3 > mu.at[3] and z0 + size < mu.at[3] + mu.size[3] - 1, ex.id .. " z")
		T.ok(mu.at[2] + 1 + size < mu.at[2] + mu.size[2] - 1, ex.id .. " height")
		for _, b in ipairs(boxes) do
			T.ok(x0 + size < b[1] - 1 or b[1] + b[3] < x0 - 1 or z0 + size < b[2] - 3 or b[2] + b[3] < z0 - 3, ex.id .. " overlaps")
		end
		boxes[#boxes + 1] = { x0, z0, size }
	end
end)

T.finish()
