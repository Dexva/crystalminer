# crystalminer

A free, open-source [Luanti](https://www.luanti.org) game for learning symmetry, the foundation
of crystallography. Built for the Open Scientific Intelligence (OSI) Hackathon 2026.

Every region of the world has a symmetry group. Whatever a student builds in a region is copied
by every operation of that group: build half a butterfly in Mirror Plaza and the mirror finishes
it; place one block in the Kaleidoscope and it becomes 48. Students move up through five tiers,
from "what is a symmetry operation?" to screw axes, glide planes and identifying a hidden point
group. An optional tutor powered by Claude answers questions using only the reviewed lesson text.

## Playing it (free)

1. Download **Luanti** from [luanti.org](https://www.luanti.org/downloads/) (Windows, macOS,
   Linux, Android). It is free and open source.
2. Download this repository (green **Code** button → **Download ZIP**, or `git clone`), and put
   the folder, named `crystalminer`, into the `games` folder of Luanti's user data folder.
   The main menu's **About** tab has a button that opens the user data folder.
3. Start Luanti, pick **crystalminer** in the row of game icons, create a new world and play.
   For a classroom, tick **Host Server** and have students join your computer's address.

Nothing else is needed: crystalminer is a complete game with its own blocks and textures.

In game: press **K** to fly, **J** to go fast, and **T** or **/** to open chat for commands.
All blocks in your inventory are free and never run out.

## The museum and the worlds

Players start in the foyer of the **Museum of Crystals and Symmetry**, a building with a glass
roof, doors and signs, meant to be toured and read like a real science museum:

- **Foyer**: a welcome board with a plan of the building; the **Workshop** (the Try-it Pad) to the
  west and **Visitor information** with a "words to know" board to the east.
- **Gallery 1, Four kinds of symmetry**: the four displays A to D of the Symmetry Gate, each with a
  plaque, and an introduction board.
- **Gallery 2, A history of crystallography**: a timeline of twelve panels from Steno (1669) to the
  International Year of Crystallography (2014), and Haüy's stepped octahedron built from cubes.
- **Gallery 3, Crystals at the atomic scale**: the six crystal-structure models of the Crystal
  Museum, each with a panel and a clue crystal.
- **Portal Hall**: one portal per symmetry region, ordered by tier, each framed with a plaque
  giving the region's name, symmetry and idea. Punching a portal takes you there.

Each symmetry region is a **world of its own**, after MolCraft: an island far from the museum with
a landscape, an arrival plaza with two information boards (what the region teaches; what to do
there), an entrance arch with the region's name, and a portal back to the Portal Hall. The build
spaces are larger than in earlier versions (for example 25 × 16 × 25 for the floors and
21 × 21 × 21 for the cubes) so the copies have room to be seen.

**Guides for first-time players.** The first time a player arrives anywhere (Gallery 1, the
Try-it Pad, each world), a window explains the place in plain words: what it is, numbered steps
of what to do, what they will see, and the word for it, with a picture. `/explain` shows it again,
and the same steps are on the boards on site. Every number a guide states (how many copies one
block makes) is checked against the engine by the tests, and the pictures are drawn from data the
engine computes (`tools/figure_data.lua`, `tools/make_figures.py`).

**Pictures and furnishings.** Each exhibit in Gallery 3 has a picture of one unit cell beside its
panel, and each history panel a diagram of its idea (Steno's constant angles, Haüy's stacked
cubes, the 32 crystal classes, cubic lattices, Bragg's law, a computed ten-fold diffraction
pattern and more; simplified ones are labelled "schematic"). There are no portraits: the game
only draws what can be drawn from the science, and adding public-domain portraits is left to
whoever installs it. The rooms have carpets, benches, plants, an information desk with a plan of
the building, mineral sculptures (fluorite, pyrite, halite) and two symmetry puzzles in Gallery 1
whose symmetry (4 and -1) the tests check.

Signs are drawn with real lettering: textures assembled from glyphs of DejaVu Sans Mono
(Bitstream Vera licence, free to redistribute), rendered by `tools/make_glyphs.py`.

## How the game works

| Tier | Regions | Idea |
|---|---|---|
| 0 | Symmetry Gate, Try-it Pad | The four basic operations: translation, rotation, reflection, inversion; predicting handedness |
| 1 | Mirror Plaza (m), Twofold Yard (2), Fourfold Tower (4), Inversion Core (-1), Translation Hall (P1) | One operation at a time |
| 2 | Twin Mirrors (mm2), Monoclinic Cube (2/m), Square Court (4mm), Orthorhombic Cube (mmm) | Combining operations creates new ones |
| 3 | Diagonal Cube (3), Rotoinversion Room (-4), Bar-Three Room (-3), Kaleidoscope (m-3m), Impossible Room | 3D, cubic symmetry, the crystallographic restriction |
| 4 | Screw Hall (P2₁), Spiral Tower (P4₁), Glide Hall (Pa), Mystery Lab, Free Lab; Pattern Garden: Mirror Tiles (pmm), Glide Tiles (pgg), Pinwheel Tiles (p4), Weave Tiles (p4g) | Space-group operations, plane groups, identifying symmetry |

- Each region is built to look like its name: a paved plaza, a fenced yard, a tower with a crown,
  colonnaded halls with glass roofs, display-case cubes, brick rooms and hedged gardens. The
  architecture always stays outside the build space, so it never interferes with the copies.
- At the **Try-it Pad** next to the Gate, students build any shape, punch a lever (T, R, M, I),
  predict whether the result can be moved to match their shape, and then see it. The answer is
  computed from the shape: a mirror image matches only if the shape has a mirror plane or
  inversion centre of its own.
- Entering a region shows its explanation for the player's tier; coming back at a higher tier
  shows more.
- Particles mark the symmetry elements with the symbols of International Tables, so they do not
  rely on colour alone: 2-fold axes as lenses (yellow), 3-fold as triangles (green; with a ring
  for -3), 4-fold as squares (red), -4 as a square with a lens (purple), mirror planes as sheets
  of light blue dots, inversion centres as a white disc. Lattice regions show the unit cells in
  orange and a floor whose tint alternates cell by cell. `/elements` shows one kind at a time.
- A **stereogram** in the corner shows the region's point group as International Tables draws it:
  copies of one direction as dots (above) and rings (below), axis symbols and mirror lines.
- The quiz window sits at the bottom of the screen so the scene stays visible; questions about a
  Gate display turn the player towards it. A wrong option is greyed out and a hint is shown.
- Press **I** for the progress board: what is left at your tier, with a button to go to each place.
- To build inside the floating cubes, fly (K) and right-click while pointing at nothing: the block
  goes 3 nodes in front of you.
- It stays daytime (setting `crystalminer.always_day`), so colours and symbols stay readable.
- Answering every quiz question of a tier unlocks the next. Regions above a player's tier can be
  visited but not built in. Progress is saved with the world.

Commands: `/guide`, `/quiz`, `/explain`, `/regions`, `/goto <region>`, `/progress`,
`/elements <all|axes|mirrors|centres|cells|none>`, `/stereogram on|off`, `/step`, `/byhand`,
`/predict`, `/tour`, `/hunt`, `/pretest`, `/posttest`, `/ask <question>`, `/whatsymmetry`,
`/symmetry <description or symbol>`, `/challenge`, `/clearlab`, `/spawn`. Teachers (the `teacher`
privilege; grant it with `/grant <name> teacher`) can use `/settier <tier> [player]`, `/class`,
which shows every student's tier, scores and predictions, `/exportdata` and
`/showcase [region | clear]`.

**For a demonstration:** `/showcase` fills 20 regions with example builds: a butterfly in Mirror
Plaza, a windmill in the Fourfold Tower, a 48-fold star in the Kaleidoscope, a spiral staircase in
the Screw Hall, tiled floors in the Pattern Garden and more. Only one seed piece is placed in each;
the region's symmetry makes every copy, so what visitors see is the engine at work. The tests
check that each finished build has exactly its region's symmetry. `/showcase clear` empties those
regions again (including anything built there since).

## Learning and teaching

These follow what research says helps students with symmetry and crystallography: predicting
before seeing, doing the operations by hand rather than watching them, and moving between 3D
models and the 2D diagrams of textbooks. Screw axes and glide planes, which students find hardest
(Graw & Stalke, *J. Appl. Cryst.* 55, 144–148, 2022), get the most help.

- **Measuring learning.** New players are offered 11 short questions before they start, and the
  same ones again when they reach the top tier (`/pretest`, `/posttest`; setting
  `crystalminer.pretest`). Each question has an "I don't know" option. Answers are stored with an
  anonymous id. `/class` shows teachers each student's scores and the class's mean normalized gain;
  `/exportdata` saves the answers, predictions and discoveries as CSV files without names. If you
  publish such data as research, you need your institution's ethics approval and informed consent;
  the notice in the game is not a substitute.
- **Predict, then see.** The first block a player places in each region waits for a prediction:
  how many blocks will there be? The count comes from the engine for that exact spot, so a block on
  a symmetry element (fewer copies) is explained correctly. Teachers see the predictions.
- **Slow motion and by hand.** `/step` makes copies appear one at a time, each named ("three
  quarters of a turn (270 degrees, anticlockwise seen from above) about the vertical axis", "a
  screw: ..."). `/byhand` turns the copying off: the student places every copy and each one is
  checked; `/byhand hint` shows one that is missing.
- **The Crystal Museum.** Copper, iron, rock salt, caesium chloride, strontium titanate
  (perovskite) and diamond, one block per atom, in a hall to fly around. In front of each, a gold
  clue crystal asks a question about it (a scavenger hunt; `/hunt`). Since the redesign the
  models stand in Gallery 3 of the museum, and the Portal Hall leads to every region.
  These ideas, and the separate world for each region reached through the Portal Hall, come
  from MolCraft (University of Hull, 2015), a Minecraft world
  of molecules with a central hall of teleporters, giant models and hidden quiz chests.
- **The visitor tour.** `/tour` is a ten-minute guided route for open days and museums, with a
  short panel at each stop; visitors may build at the stops whatever their tier.

## The tutor (optional, paid)

The game is complete and free without the tutor. With it, `/ask` answers questions and
`/symmetry` understands descriptions such as "a fourfold axis with mirrors". It uses the Claude
API, which is **charged per request** by Anthropic.

To turn it on, in Luanti's **Settings** (show advanced settings):
- set **Mods → HTTP mods** (`secure.http_mods`) to `crystalminer`;
- set **crystalminer → Tutor: Anthropic API key**, or start Luanti with the environment
  variable `ANTHROPIC_API_KEY`.

What Claude does and doesn't do:
- `/ask`: answers using only the reviewed text in `mods/crystalminer/content.lua`. It is told to
  say when that text does not cover a question rather than guess, and it is never given the
  Mystery Lab answer.
- `/symmetry`: Claude only picks a point-group symbol (structured output). The symmetry engine
  checks it, builds the group and writes every statement about it. A request for a 6-fold axis is
  refused by the engine, with the reason. Typing a symbol directly (`/symmetry 4mm`) works without
  the tutor.
- `/whatsymmetry` is pure code: it tests all 48 cubic-grid operations against the build.

Model: `claude-opus-5-5` at low effort, with server-side fallbacks in case a safety classifier
declines a request.

## Science checks

The tests check the claims the world makes, rather than relying on memory:

- All 32 crystallographic point groups have the correct orders (International Tables for
  Crystallography, Vol. A).
- Exactly 25 of them fit a cubic grid. The other 7 (hexagonal) cannot in any orientation: each
  contains a 6 or -6 operation, no grid operation is one, and determinant and trace (which tell
  the kinds of operation apart) do not change with orientation.
- Counting operations by kind tells all 32 groups apart, so `/whatsymmetry` names a group however
  it is oriented.
- Every region's stated symmetry, and every quiz answer about group order, matches the engine.
- Combination rules taught in tier 2 hold: mm2 contains a 2-fold axis, 2/m an inversion centre;
  -4 contains a 2-fold axis but no 4-fold axis and no inversion centre; -3 contains both a 3-fold
  axis and an inversion centre.
- Exactly 12 of the 17 plane groups fit the block grid, each with the multiplicity listed in
  International Tables; the other 5 contain a 3-fold rotation, which no grid operation that keeps
  up pointing up can be. The statements about the Pattern Garden hold: pgg has glides but no
  mirrors, p4 has neither, pmm's mirrors cross at 2-fold points, and in p4g no mirror passes
  through a 4-fold point.
- Each Gate display can be explained by exactly one operation, the one the quiz says, because
  the motif has no symmetry of its own.
- The museum's models are measured, not trusted: every atom inside them has the textbook number of
  nearest neighbours (copper 12, iron 8, rock salt 6, caesium chloride 8, titanium in perovskite 6
  oxygens, diamond 4), every clue answer equals the count measured on its model, the models have
  full cubic symmetry about their centre, and a carbon atom in diamond has the site symmetry -43m.
- Every stereogram has one dot or ring per operation, for all 25 grid point groups, with the
  right axis symbols; operations are named with the correct sense of turning (the world's axes are
  left-handed, which the code accounts for).
- Every example build from `/showcase` has exactly its region's symmetry, and the counts its text
  gives (48, 8, 6, ...) are right.

## Tests

```bash
tests/run_all.sh
```

Needs `luajit` (or `lua5.1`) and a Luanti server binary (`luantiserver`, or `minetestserver` for
older versions). It runs the unit tests (`test_symmetry`, `test_content`, `test_science`,
`test_elements`, `test_decor`, `test_showcase`, `test_assess`, `test_museum`, `test_signs`,
`test_guides`, `test_tutor`; `test_signs` checks that the text of every sign fits it and has
glyphs, `test_guides` that every guide's numbers match the engine), then
starts a real server with `crystalminer.selftest = true`, which places and digs blocks through the
registered callbacks, checks locking, quizzes, saving, the gate, the Try-it Pad, the floor
tilings, the architecture, predictions, step mode, the museum and its clues, the teleporters, the
tour, the data export, the teacher view, the Free Lab, the museum's signs, doors and doorways,
the Portal Hall and every world's plaza, arch and portal back, and shuts down.

## Project layout

```
game.conf                     Luanti game definition
mods/crystalminer/
  init.lua                    blocks, world, events, quizzes, progress board, commands
  symmetry.lua                engine: operations, groups, 32 point groups, 17 plane groups, regions, detection
  gate.lua                    geometry of the Symmetry Gate displays
  decor.lua                   architecture of each region and the landscape of its world
  lobby.lua                   the museum building: rooms, doors, signs, Portal Hall
  worlds.lua                  each world's arrival plaza, boards, arch and portal back
  signs.lua, doors.lua        signs with lettering and framed pictures; doors
  guides.lua, guide_window.lua  plain-language guides, and the window that shows them
  furniture.lua, sculptures.lua  carpets, benches, plants, desk, plan; the sculptures
  lessons.lua                 tiers, questions, explanations, progress
  learning.lua, assess.lua    pre- and post-test, predictions, class view, data export
  modes.lua                   /step and /byhand
  museum.lua, structures.lua  the Crystal Museum, clue crystals, teleport pads; crystal structure models
  stereo.lua                  the stereogram (International Tables style)
  tour.lua                    the visitor tour
  elements.lua                where to draw axes, mirror planes and centres
  tutor.lua                   Claude API requests (raw HTTP)
  content.lua                 all text players read; edit without touching code
  selftest.lua                in-server checks
  textures/                   generated by tools/make_textures.py, make_glyphs.py, make_figures.py
                              (with figure_data.lua and history.py) and make_furniture.py
tests/                        unit tests and test runners
```

Crystal axes (z up) map to the world as x → east, y → north, z → up.

## Known limitations

- The self-test passes on a Minetest 5.4.1 server. The game has been played in a Luanti 5.17
  client on macOS: Gate, quiz, regions, showcase, museum and a clue crystal, the stereogram,
  predictions, step mode and the tour; after the museum redesign, the foyer, Gallery 1 and its
  plaques, the doors, the Portal Hall and a world's plaza. It has not yet been played by students,
  and the learning check has not yet produced data.
- The first start of a new world builds the museum and all 23 worlds, which takes about half a
  minute.
- The tutor has not been run against the live API (no key was available during development).
  Request building and response handling are unit-tested.
- The Free Lab's symmetry is shared by everyone on the server and resets when the server restarts.
  The Try-it Pad is also shared: in a class, students take turns or build in the regions.
- Worlds made with an earlier version are rebuilt on start. Since the museum redesign the regions
  stand in new places, so blocks built in them in an earlier version are not carried over;
  players' tiers and answers are kept.
