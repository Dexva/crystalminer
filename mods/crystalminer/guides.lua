-- Plain-language guides: what to do in each place, step by step, what you will see, and the word
-- for it. Shown in a window (with a picture) the first time a player arrives, again with /explain,
-- and on the boards on site. Written for a first-time visitor of about 12: short sentences, one
-- new word at a time, and the word explained before it is used.
--
-- count: how many blocks one block placed away from every symmetry element becomes. The tests
-- check it against the symmetry engine, and that the "see" text states it.
-- Directions: north is the way you face when you arrive in a world.

local G = {}

G.symmetry_gate = {
	title = "Gallery 1: Four kinds of symmetry",
	what = "Each of the four displays, A to D, shows the same small shape twice: the original on the left, "
		.. "and on the right a copy made by one move.",
	steps = {
		"Stand in front of the displays, facing them. A is on the left, D on the right.",
		"For each display, compare the copy with the original. Was it just slid along? Turned around? "
			.. "Is it a mirror image? Or was every block sent through a centre point to the opposite side?",
		"Press T, type /quiz and press Enter. Answer which move made each copy.",
	},
	see = "Answer all five questions correctly and the first worlds in the Portal Hall open for building.",
	word = "These moves are called symmetry operations: translation (slide), rotation (turn), "
		.. "reflection (mirror) and inversion (through a point).",
}

G.tryit_pad = {
	title = "The Try-it Pad",
	what = "Make your own shape and see what each of the four moves does to it.",
	steps = {
		"Pick a coloured block from the bar at the bottom of the screen (keys 1 to 8).",
		"Build a small shape in the glass box on the left, marked YOUR SHAPE. Right-click places a block, "
			.. "left-click removes one. A good first shape: three blocks in a row, a tower of two blocks on top "
			.. "of one end, and one block sticking out sideways at the other end.",
		"Hit one of the four levers in front of the boxes with a left-click: T slides your shape, R turns it "
			.. "half a turn, M makes its mirror image, I sends it through its centre point.",
		"A question appears: if you could pick the copy up and turn it any way you like, could it look exactly "
			.. "like your shape? Answer, then look at the box on the right, marked COPY.",
	},
	see = "T and R always give a copy you could turn back to match. M and I give a mirror twin, like your left "
		.. "and right hands, which no turning can match. Unless your shape is symmetric itself: try a plain "
		.. "row of blocks with M.",
	word = "A shape that cannot be turned to match its mirror image is called chiral, from the Greek word for hand.",
}

G.mirror_plaza = {
	title = "Mirror Plaza",
	count = 2,
	what = "An invisible mirror stands across the middle of this square, running north to south. It copies "
		.. "everything you build onto the other side.",
	steps = {
		"Walk through the gate onto the square. A sheet of light-blue dots in the air shows where the mirror is.",
		"Stand on one side of the sheet and place a block on the ground.",
		"Now build half of something: half a butterfly, half a heart, or the letter F.",
	},
	see = "Every block gets one copy at the same distance on the other side, so 2 blocks for each one you "
		.. "place. Build an F and its copy is a backwards F. A block right in the sheet of dots is its own "
		.. "reflection, so it stays single.",
	word = "The mirror is called a mirror plane, written m. A mirror swaps left and right.",
}

G.twofold_yard = {
	title = "Twofold Yard",
	count = 2,
	what = "An invisible pole stands upright in the middle of this yard. Everything you build is copied half a "
		.. "turn around the pole, to its opposite side.",
	steps = {
		"Find the middle of the yard: yellow lens shapes, like lemons, float one above the other there. They mark the pole.",
		"Place a block a few steps away from the pole.",
		"Build one blade of a propeller: a line of blocks reaching out from the pole.",
	},
	see = "Each block gets one copy on the exact opposite side of the pole: 2 blocks for each one. The copy is "
		.. "turned around, but it is not a mirror image: walk around it and it matches.",
	word = "A half-turn symmetry is called a 2-fold rotation axis, written 2: two half turns make a full turn.",
}

G.fourfold_tower = {
	title = "Fourfold Tower",
	count = 4,
	what = "An invisible pole stands upright in the middle of this tower. Everything you build is copied a "
		.. "quarter turn around the pole, again and again, so every block appears in four places.",
	steps = {
		"Go into the tower and find the middle: red squares float one above the other there. They mark the pole.",
		"Place one block on the floor a few steps away from the pole, and count the blocks.",
		"Now make a windmill: build a post straight up from the middle, then one sail sticking out sideways from its top.",
	},
	see = "Each block appears 4 times, a quarter turn apart, like the four sails of a windmill. Blocks built "
		.. "right on the pole are not copied, because turning leaves them where they are.",
	word = "This is a 4-fold rotation axis, written 4: four quarter turns make one full turn.",
}

G.inversion_core = {
	title = "Inversion Core",
	count = 2,
	what = "An invisible point floats in the middle of this big cube. Every block you build is sent straight "
		.. "through that point to the other side, the same distance away.",
	steps = {
		"Press K to fly, then fly into the cube. Hold Space to rise and Shift to sink.",
		"To place a block in mid-air, point at empty space and right-click: it appears 3 steps in front of you.",
		"Build a small shape near one corner of the cube, then fly to the opposite corner.",
	},
	see = "The copy is upside down and back to front at the same time: up became down, east became west and "
		.. "north became south. Each block gives 2. A white disc marks the centre point.",
	word = "This is an inversion centre, written -1 (say 'bar one').",
}

G.translation_hall = {
	title = "Translation Hall",
	count = 27,
	what = "This hall works like a crystal. It is divided into 27 identical boxes, 3 by 3 by 3, each 8 blocks wide. "
		.. "Whatever you build in one box is copied into every other box.",
	steps = {
		"Press K to fly and go in. Orange lines mark the edges of the boxes.",
		"Choose one box and build a small object in it.",
		"Fly back and look along the rows of boxes.",
	},
	see = "Your object appears 27 times, once in each box, always the same way round. Nothing is turned or "
		.. "mirrored: each copy is only slid along.",
	word = "Each box is a unit cell, and the slides are translations. A real crystal repeats its unit cell "
		.. "billions of times in every direction.",
}

G.twin_mirrors = {
	title = "Twin Mirrors",
	count = 4,
	what = "Two invisible mirrors cross in the middle of this square: one runs north to south, the other east to west.",
	steps = {
		"Find the two sheets of light-blue dots that cross in the middle.",
		"Place one block in one of the four quarters, away from both sheets.",
		"Count the blocks and look at where each one is.",
	},
	see = "There are 4 blocks: one in each quarter. Two of them are reflections in the two mirrors. The fourth, "
		.. "in the opposite quarter, is your block turned half a turn about the line where the mirrors cross: "
		.. "two mirrors together make a turn.",
	word = "The name mm2 means: a mirror, another mirror, and the 2-fold axis they create.",
}

G.monoclinic_cube = {
	title = "Monoclinic Cube",
	count = 4,
	what = "In this cube, an invisible pole stands upright through the middle, and a flat mirror lies across "
		.. "the middle like a glass floor.",
	steps = {
		"Press K to fly and go in.",
		"Build a small shape near one of the top corners.",
		"Find its copies: one half a turn round the pole, one reflected in the flat mirror below it, and one more.",
	},
	see = "4 blocks for each one you place. The fourth copy is at the opposite bottom corner: your shape sent "
		.. "through the centre point. A half turn plus a mirror across it creates an inversion centre.",
	word = "2/m (say 'two over m'): a 2-fold axis with a mirror perpendicular to it.",
}

G.square_court = {
	title = "Square Court",
	count = 8,
	what = "An invisible quarter-turn pole stands in the middle of this square, and four mirrors pass through it: "
		.. "two parallel to the sides and two along the diagonals.",
	steps = {
		"Find the middle (red squares) and the four sheets of light-blue dots.",
		"Place one block a few steps from the middle, but not in a sheet of dots.",
		"Count the blocks, then build a small shape and watch the pattern.",
	},
	see = "Each block appears 8 times: 4 by turning, and each of those mirrored. It is the symmetry of a square "
		.. "tile seen from above.",
	word = "4mm: a 4-fold axis and two kinds of mirror.",
}

G.orthorhombic_cube = {
	title = "Orthorhombic Cube",
	count = 8,
	what = "Three invisible mirrors meet in the middle of this cube, all at right angles: one north to south, "
		.. "one east to west, and one lying flat.",
	steps = {
		"Press K to fly and go in.",
		"Build a small shape near one corner of the cube.",
		"Visit the other corners.",
	},
	see = "The three mirrors cut the cube into 8 corner pieces, and your shape appears once in each: 8 blocks "
		.. "for each one you place. Neighbouring copies are mirror images of each other.",
	word = "mmm: three mirrors. Every two of them also make a 2-fold axis, and all three make an inversion centre.",
}

G.diagonal_cube = {
	title = "Diagonal Cube",
	count = 3,
	what = "An invisible pole runs through this cube from one corner to the opposite corner, along its longest "
		.. "diagonal. Each copy is turned one third of a turn about it.",
	steps = {
		"Press K to fly and go in. Green triangles mark the diagonal pole.",
		"Build a short line of blocks pointing east, away from the diagonal.",
		"Look for the other two copies of your line.",
	},
	see = "Your line appears 3 times: once pointing east, once pointing north and once pointing up. A third of a "
		.. "turn about the diagonal swaps the three directions round.",
	word = "A 3-fold rotation axis, written 3. A cube has four of these diagonals.",
}

G.rotoinversion_room = {
	title = "Rotoinversion Room",
	count = 4,
	what = "The move here has two steps: turn a quarter turn about the upright pole in the middle, then send the "
		.. "block through the centre point to the other side.",
	steps = {
		"Press K to fly and go in.",
		"Build a small shape in the upper half of the room, away from the middle.",
		"Look for the copies all the way round the middle, above and below.",
	},
	see = "Each block appears 4 times, a quarter turn apart, and they take turns: above, below, above, below. "
		.. "A plain quarter turn alone would not make this pattern.",
	word = "-4 (say 'bar four') is a rotoinversion. Doing it twice gives a plain half turn, so -4 contains a 2-fold axis.",
}

G.bar_three_room = {
	title = "Bar-Three Room",
	count = 6,
	what = "Two steps again: turn one third of a turn about the long diagonal of the room, then send the block "
		.. "through the centre point.",
	steps = {
		"Press K to fly and go in.",
		"Build a small shape a few blocks away from one corner.",
		"Look for its copies near the other corners.",
	},
	see = "Each block appears 6 times: 3 by the thirds of a turn, and each of those sent through the centre. "
		.. "Here, unlike in the Rotoinversion Room, the plain turn and the plain trip through the centre are "
		.. "symmetries too.",
	word = "-3 (say 'bar three'). Calcite, the mineral in marble, has it.",
}

G.kaleidoscope = {
	title = "Kaleidoscope",
	count = 48,
	what = "This cube has the full symmetry of a cube: every way of turning a cube so that it still fits its box, "
		.. "and the mirror image of each.",
	steps = {
		"Press K to fly and go in.",
		"Place one block anywhere that is not in the middle and not on a marker.",
		"Then add two or three more blocks next to it.",
	},
	see = "One block becomes 48. A few blocks become a star.",
	word = "m-3m: the highest symmetry a crystal can have. Copper, iron and table salt have it.",
}

G.impossible_room = {
	title = "Impossible Room",
	count = 1,
	what = "This room was meant to have a six-fold pole: one sixth of a turn. That cannot work in a world made of "
		.. "square blocks, so the room copies nothing.",
	steps = {
		"Place a block: no copies appear, because 1 block stays 1.",
		"Look at the floor grid and imagine turning it by one sixth of a turn (60 degrees): the corners of the "
			.. "blocks no longer land on the grid.",
	},
	see = "Square blocks allow half turns and quarter turns, and thirds of a turn about a cube's diagonal, but "
		.. "never sixths. Six-fold symmetry needs a grid of hexagons, like a honeycomb.",
	word = "The crystallographic restriction: a crystal can only have 2-, 3-, 4- or 6-fold rotations, never 5-fold.",
}

G.screw_hall = {
	title = "Screw Hall",
	count = 54,
	what = "Here the copies climb like steps of a staircase: each one is turned half a turn and lifted half a box higher.",
	steps = {
		"Press K to fly and go in. The hall is divided into 27 boxes, 3 by 3 by 3, each 6 blocks wide.",
		"Build a small shape low down in one box.",
		"Follow its copies upward.",
	},
	see = "In each column your shape swaps sides as it climbs: turn and rise, turn and rise. 2 copies in every "
		.. "box, 54 in all.",
	word = "A 2_1 screw axis (say 'two-one'). Screw axes exist only in crystals, because they need a pattern that repeats.",
}

G.glide_hall = {
	title = "Glide Hall",
	count = 32,
	what = "Here the copies are like footprints in snow: each one is mirrored, then slid half a box forward.",
	steps = {
		"The hall is a floor of 16 boxes, 4 by 4, each 6 blocks wide and 6 high.",
		"Build an arrow pointing east in one box.",
		"Walk east along the row and watch the arrows.",
	},
	see = "Your arrow repeats in a zig-zag, left side, right side, left side, each a mirror image of the one "
		.. "before and 3 blocks further east. 2 in every box, 32 in all.",
	word = "A glide plane: a mirror and a slide along it, together.",
}

G.spiral_tower = {
	title = "Spiral Tower",
	count = 48,
	what = "Here the copies climb round the middle of the tower like a spiral staircase: each one turned a quarter "
		.. "turn and lifted 2 blocks.",
	steps = {
		"Press K to fly and go in.",
		"Near the bottom, beside the middle, build one step: a short line of 2 or 3 blocks.",
		"Watch the steps climb.",
	},
	see = "After four quarter turns a copy is right above your step again, 8 blocks higher. 48 copies in all.",
	word = "A 4_1 screw axis (say 'four-one'). Its mirror image turns the other way. Screw axes are why quartz "
		.. "crystals come left-handed and right-handed.",
}

G.mystery_lab = {
	title = "Mystery Lab",
	what = "This lab has a symmetry that is kept secret. Your job is to find out what it is.",
	steps = {
		"Press K to fly and go in.",
		"Place one block away from the middle and count all its copies.",
		"Look at the copies: are any of them mirror images? Is one straight through the centre point? Is one above or below yours?",
		"Type /quiz to name the symmetry.",
	},
	see = "The number of copies of one block tells you how many symmetry moves there are.",
	word = "Point group: the full set of symmetry moves of an object.",
}

G.free_lab = {
	title = "Free Lab",
	count = 1,
	what = "Your own lab. It starts with no symmetry at all, so 1 block stays 1: you decide what happens.",
	steps = {
		"Build anything, then type /whatsymmetry to find out the symmetry of what you built.",
		"Type /symmetry 4mm (or another symbol you have learned) to give the lab that symmetry, then build again.",
		"Try /symmetry 6 and read why it is refused. Type /challenge for a target to build.",
	},
	see = "/whatsymmetry tests your build against all 48 ways the block grid can be turned and mirrored.",
	word = "Every crystal has one of 32 point groups. 25 of them fit this block world.",
}

G.mirror_tiles = {
	title = "Mirror Tiles",
	count = 144,
	what = "The floor here is a repeating tile pattern, like a bathroom floor, with mirror lines in two directions.",
	steps = {
		"Walk onto the garden floor. The floor colour changes from square to square: each square is one "
			.. "tile, 6 blocks wide.",
		"Place blocks on the floor inside one tile.",
		"Watch the pattern spread over the whole garden.",
	},
	see = "Each block appears 4 times in every tile, and the tiles repeat over the floor: 144 blocks for one. "
		.. "Where two mirror lines cross, the pattern also has a half-turn point.",
	word = "A plane group is the symmetry of a flat repeating pattern. pmm: mirrors in two directions. "
		.. "There are exactly 17 plane groups.",
}

G.glide_tiles = {
	title = "Glide Tiles",
	count = 144,
	what = "A repeating floor pattern with half-turn points and glides, but no plain mirrors.",
	steps = {
		"Walk onto the garden floor (each tile is 6 blocks wide).",
		"Build an arrow on the floor inside one tile.",
		"Follow the copies of your arrow.",
	},
	see = "Some arrows are turned half a turn; the others are mirror images that are also slid half a tile, so "
		.. "no arrow is a plain reflection of a neighbour. 144 blocks for one.",
	word = "pgg: glides in two directions and half-turn points.",
}

G.pinwheel_tiles = {
	title = "Pinwheel Tiles",
	count = 144,
	what = "A repeating floor pattern with quarter-turn points and no mirrors at all.",
	steps = {
		"Walk onto the garden floor (each tile is 6 blocks wide).",
		"Build a short bent line on the floor inside one tile.",
		"Look at the pattern from above (press K, fly up).",
	},
	see = "The pattern spins one way, like a pinwheel; its mirror image would spin the other way. 144 blocks for one.",
	word = "p4: quarter-turn points only.",
}

G.weave_tiles = {
	title = "Weave Tiles",
	count = 288,
	what = "A repeating floor pattern with quarter-turn points, mirrors and glides; but no mirror passes "
		.. "through a quarter-turn point.",
	steps = {
		"Walk onto the garden floor (each tile is 6 blocks wide).",
		"Build a short bent line on the floor inside one tile.",
		"Compare it with Pinwheel Tiles.",
	},
	see = "Twice as many copies as in Pinwheel Tiles: 288 blocks for one. The extra mirrors and glides make the "
		.. "pattern look woven.",
	word = "p4g: quarter turns plus mirrors and glides.",
}

-- The board beside each world's arrival plaza: what to do in any world.
G.howto = "# What to do in a world\n"
	.. "1. Walk north through the gate into the build area.\n"
	.. "2. Pick a block (keys 1 to 8) and right-click to place it. This world copies every block you place.\n"
	.. "3. Watch where the copies appear. Your first block asks you to guess how many there will be.\n"
	.. "4. Type /quiz for questions about this world. Right answers open new worlds.\n\n"
	.. "Lost? /explain shows the guide again. /step shows the copies one at a time. "
	.. "Markers in the air: lens = half-turn pole, triangle = third-turn pole, square = quarter-turn pole, "
	.. "light-blue dots = mirror, white disc = centre point.\n"
	.. "The portal behind you goes back to the museum."

--- The guide as sign text: heading, what, numbered steps, what you will see, the word.
function G.board_text(g)
	local lines = { "# " .. g.title, g.what, "" }
	for i, s in ipairs(g.steps) do lines[#lines + 1] = i .. ". " .. s end
	lines[#lines + 1] = ""
	lines[#lines + 1] = g.see
	return table.concat(lines, "\n")
end

return G
