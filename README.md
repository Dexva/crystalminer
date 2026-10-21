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

## How the game works

| Tier | Regions | Idea |
|---|---|---|
| 0 | Symmetry Gate | The four basic operations: translation, rotation, reflection, inversion |
| 1 | Mirror Plaza (m), Twofold Yard (2), Fourfold Tower (4), Inversion Core (-1), Translation Hall (P1) | One operation at a time |
| 2 | Twin Mirrors (mm2), Monoclinic Cube (2/m), Square Court (4mm), Orthorhombic Cube (mmm) | Combining operations creates new ones |
| 3 | Diagonal Cube (3), Rotoinversion Room (-4), Kaleidoscope (m-3m), Impossible Room | 3D, cubic symmetry, the crystallographic restriction |
| 4 | Screw Hall (P2₁), Glide Hall (Pa), Mystery Lab, Free Lab | Space-group operations, identifying symmetry |

- Entering a region shows its explanation for the player's tier; coming back at a higher tier
  shows more.
- Coloured particles mark the symmetry elements: rotation axes (2-fold yellow, 3-fold green,
  4-fold red), rotoinversion axes (purple), mirror planes (light blue outline) and inversion
  centres (white). Lattice regions show the unit cells.
- Answering every quiz question of a tier unlocks the next. Regions above a player's tier can be
  visited but not built in. Progress is saved with the world.

Commands: `/guide`, `/quiz`, `/explain`, `/regions`, `/goto <region>`, `/progress`,
`/ask <question>`, `/whatsymmetry`, `/symmetry <description or symbol>`, `/challenge`,
`/clearlab`, `/spawn`. Teachers (the `teacher` privilege; grant it with `/grant <name> teacher`)
can use `/settier <tier> [player]`.

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
  -4 contains a 2-fold axis but no 4-fold axis and no inversion centre.

## Tests

```bash
tests/run_all.sh
```

Needs `luajit` (or `lua5.1`) and a Luanti server binary (`luantiserver`, or `minetestserver` for
older versions). It runs the unit tests, then starts a real server with
`crystalminer.selftest = true`, which places and digs blocks through the registered callbacks,
checks locking, quizzes, saving, the gate and the Free Lab, and shuts down.

## Project layout

```
game.conf                     Luanti game definition
mods/crystalminer/
  init.lua                    blocks, world, events, quizzes, commands
  symmetry.lua                engine: operations, groups, 32 point groups, regions, detection
  lessons.lua                 tiers, questions, explanations, progress
  elements.lua                where to draw axes, mirror planes and centres
  tutor.lua                   Claude API requests (raw HTTP)
  content.lua                 all text players read; edit without touching code
  selftest.lua                in-server checks
  textures/                   generated by tools/make_textures.py
tests/                        unit tests and test runners
```

Crystal axes (z up) map to the world as x → east, y → north, z → up.

## Known limitations

- Tested with the Luanti 5.6 server only; not yet played with a Luanti client, so the look of
  particles, labels and the quiz window has not been checked.
- The tutor has not been run against the live API (no key was available during development).
  Request building and response handling are unit-tested.
- The Free Lab's symmetry is shared by everyone on the server and resets when the server restarts.
