# crystalminer: plan

A Minecraft world for learning symmetry, the foundation of crystallography.
Built for the Open Scientific Intelligence (OSI) Hackathon, 21–22 Oct 2026.

## Core mechanic: symmetry regions

The world is split into regions, and each region has a symmetry group G.
When a player places or breaks a block at position r inside a region, the
server repeats the action at every image r' = W·r + w for each operation
(W, w) in G.

- Positions use doubled coordinates (block centre = 2x+1), so mirror planes
  and axes can pass through a block's centre or between blocks while every
  operation stays integer-valued.
- A region is defined by its generators. The full group is built by
  multiplying generators until the set closes, and its order is reported.
- Images placed by the server are not player actions, so they don't trigger
  further copies.
- An image that lands outside its region is dropped, except in translation
  regions, where it wraps around (periodic, like a crystal).
- Symmetry elements are made visible: particle lines for axes, glass sheets
  for mirror planes, a marker for an inversion centre.

### Which groups fit on the block grid

A block-grid point has to map to a block-grid point. That only works if every
W is a signed permutation matrix, and those matrices form exactly the cubic
point group m-3m (order 48). So the realisable crystallographic point groups
are the subgroups of m-3m: 25 of the 32 (checked in `PointGroupsTest`). The 7
hexagonal groups (6, -6, 6/m, 622, 6mm, -62m, 6/mmm) can't be built. For plane
groups we expect 12 of the 17 to work; that count is **not yet checked** and
plane groups are not implemented. That limitation is the crystallographic
restriction, and the world teaches it rather than hiding it.

## Learning progression (tiers)

Each tier unlocks the next. Every region shows an explanation fitted to the
player's current tier, so the same region can be revisited later with a
deeper explanation.

### Tier 0: onboarding ("Symmetry Gate")
Concept: a symmetry operation is an action that leaves an object looking
unchanged.
- Introduce the four basic operations: translation, rotation, reflection,
  inversion.
- Interactive: a statue and levers that apply each operation. The player
  predicts whether the result matches the original, then sees the answer.
- Done when the player has correctly predicted one example of each operation.

### Tier 1: single operations (one region per operation)
| Region | Group | Example task | Key idea |
|---|---|---|---|
| Mirror Plaza | m | Build a butterfly | Mirroring swaps left and right (handedness); a left hand becomes a right hand |
| Twofold Yard | 2 | Build a propeller | Two half turns bring you back to the start |
| Fourfold Tower | 4 | Build a windmill with 4 blades | n-fold rotation is a turn of 360°/n; doing it n times returns to the start |
| Inversion Core | -1 | Build a shape that looks the same through the centre | (x,y,z) → (−x,−y,−z) |
| Translation Hall | P1 lattice | Build one tile and watch it repeat | A motif plus a lattice gives a pattern |

Checks are simple, e.g. "How many copies appear in the Fourfold Tower?",
answered by counting.

### Tier 2: combining operations (groups)
Regions: 2/m, mm2, 4mm, mmm.
- Two mirrors meeting at angle θ produce a rotation by 2θ about the line where
  they meet. Two perpendicular mirrors give a 2-fold axis.
- A 2-fold axis plus a mirror perpendicular to it produces an inversion
  centre: 2/m contains -1.
- The group order: how many copies one block makes.
- How to read Hermann–Mauguin symbols (4mm, 2/m, mmm).

### Tier 3: three dimensions and cubic symmetry
Regions: 3-fold axis along the cube diagonal, rotoinversions (-4, -3), the
m-3m Kaleidoscope (48 copies), and the "Impossible Room" where a 6-fold axis
fails on the grid (crystallographic restriction).

### Tier 4: lattices and space groups
- Plane groups as floor tilings.
- Screw axes (2₁) and glide planes: operations that combine with a translation.
- Telling groups apart, e.g. "build something with symmetry 2/m but not mmm".
- Mystery regions: work out a hidden symmetry from what you build.

## Explanations

- Content is data, not code: `src/main/resources/content.yaml` holds, per
  region and tier, the explanation lines and quiz questions.
- Delivered in game as a title on entering a region, an action-bar hint, and a
  written book with the full text.
- All text is written and reviewed by people. The LLM does not write it on the
  fly.

## LLM role (it translates and explains; it never decides)

- `/ask <question>`: tutor answers using the region's reviewed text and the
  player's tier as context. If an answer isn't grounded in that text, it says
  so.
- `/symmetry <description>` (Free Lab, Tier 4): turns words into generators. Code
  builds the group, checks it is realisable, names it, and applies it. If the
  group can't be built, the request is refused and the LLM explains why.
- `/whatsymmetry`: code tests all 48 operations against the build to
  find its exact symmetry; the LLM only explains the result.
- All task checks are done in code.

## Stack

- Server: Minestom (Apache-2.0, on Maven Central). Players use the official
  Java client at the version that Minestom release supports.
- Symmetry engine: plain Java with no game dependency, unit-tested.
- LLM: Claude API (`claude-opus-5-5`, low effort, server-side fallbacks).

## Build order and status

1. Done: symmetry engine + tests (closure, group orders, 25/32,
   doubled-coordinate images).
2. Done: Minestom server with region mirroring, Tier 0 gate and Tier 1 regions.
3. Done: tier-aware explanations from data files; tier progression.
4. Done: Tier 2 regions; `/ask` tutor.
5. Done: Tiers 3–4, `/symmetry`, `/whatsymmetry`, directional blocks
   (facing, axis, half, stair shape, connections).

Next:
- Run the tutor against the live API and review its answers for accuracy.
- Save player progress to disk.
- Restrict `/settier` to teachers.
- Plane groups as floor tilings (check the 12-of-17 count first).
- Playtest with students; pre/post quiz to measure learning.
