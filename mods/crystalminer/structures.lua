-- Real crystal structures at block scale, for the Crystal Museum. Pure Lua.
--
-- Each structure is a rule that says which atom (if any) sits at integer grid point (x, y, z).
-- The cubic cell is 2 grid steps (4 for diamond), so a model of size n spans n/2 cells. These
-- are the standard descriptions of the structures; tests measure the models (nearest-neighbour
-- counts, symmetry) rather than trusting the rules.

local T = {}

local function even(v) return v % 2 == 0 end

T.RULES = {
	-- Face-centred cubic (copper): atoms at the cube corners and face centres.
	fcc = { cell = 2, site = function(x, y, z) if (x + y + z) % 2 == 0 then return "cu" end end },
	-- Body-centred cubic (alpha iron): atoms at the corners and the body centre.
	bcc = { cell = 2, site = function(x, y, z)
		if (even(x) and even(y) and even(z)) or (not even(x) and not even(y) and not even(z)) then return "fe" end
	end },
	-- Rock salt (NaCl): every grid point, alternating chloride and sodium.
	rocksalt = { cell = 2, site = function(x, y, z) return (x + y + z) % 2 == 0 and "cl" or "na" end },
	-- Caesium chloride: chloride at the corners, caesium at the body centre.
	cscl = { cell = 2, site = function(x, y, z)
		if even(x) and even(y) and even(z) then return "cl" end
		if not even(x) and not even(y) and not even(z) then return "cs" end
	end },
	-- Cubic perovskite (SrTiO3): Sr at the corners, Ti at the body centre, O at the face centres.
	perovskite = { cell = 2, site = function(x, y, z)
		local odd = (even(x) and 0 or 1) + (even(y) and 0 or 1) + (even(z) and 0 or 1)
		if odd == 0 then return "sr" elseif odd == 3 then return "ti" elseif odd == 2 then return "o" end
	end },
	-- Diamond: a face-centred cubic lattice (cell 4) with two carbon atoms per lattice point,
	-- at (0,0,0) and (1,1,1).
	diamond = { cell = 4, site = function(x, y, z)
		if even(x) and even(y) and even(z) and (x + y + z) % 4 == 0 then return "c" end
		if not even(x) and not even(y) and not even(z) and (x + y + z - 3) % 4 == 0 then return "c" end
	end },
}

--- Atoms of a model spanning 0..n in each direction: list of { x, y, z, element }.
function T.model(kind, n)
	local rule = T.RULES[kind]
	local out = {}
	for x = 0, n do
		for y = 0, n do
			for z = 0, n do
				local e = rule.site(x, y, z)
				if e then out[#out + 1] = { x, y, z, e } end
			end
		end
	end
	return out
end

--- Nearest neighbours of the atom at p among atoms of the given elements: their distance squared
-- and how many there are.
function T.coordination(atoms, p, elements)
	local best, count = math.huge, 0
	for _, a in ipairs(atoms) do
		if (a[1] ~= p[1] or a[2] ~= p[2] or a[3] ~= p[3]) and (not elements or elements[a[4]]) then
			local d = (a[1] - p[1]) ^ 2 + (a[2] - p[2]) ^ 2 + (a[3] - p[3]) ^ 2
			if d < best then best, count = d, 1 elseif d == best then count = count + 1 end
		end
	end
	return count, best
end

return T
