# crystalminer: handoff for local refinement

This document is for whoever continues the work on a local machine, whether a person or a
Claude session running there. It records what exists, what has been verified, what has not,
and what to do next. Read it together with `README.md` (how to play) and `PLAN.md` (design).

Branch: `claude/minecraft-crystallography-module-upikhq` (not merged into `main`; no pull
request opened yet).
Context: entry for the Open Scientific Intelligence (OSI) Hackathon, 21–22 October 2026.

---

## 1. What it is, in one paragraph

A free Luanti game that teaches symmetry, the foundation of crystallography. The world is split
into 17 regions, and each region has a symmetry group: any block a player places or digs there
is repeated by every operation of the group. Players progress through tiers 0–4 by answering
quizzes, from the four basic operations (translation, rotation, reflection, inversion) up to
screw axes, glide planes and identifying a hidden point group. An optional tutor powered by
Claude answers questions using only the reviewed lesson text, and turns plain-language
descriptions into point-group symbols that the game's own code then checks.

## 2. Current state

| Area | State |
|---|---|
| Symmetry engine (`symmetry.lua`) | Complete; 22 unit tests pass |
| Lessons and tiers (`content.lua`, `lessons.lua`) | Complete; 9 consistency tests pass |
| Symmetry-element visuals (`elements.lua`) | Complete; 5 tests pass |
| Tutor (`tutor.lua`) | Complete; 5 tests pass for request building and reply handling; **never called against the live API** |
| Game wiring (`init.lua`) | Complete; 14 checks pass inside a real **Luanti 5.6.1** server (Linux, headless) |
| Played with a Luanti client | **Not yet.** Nothing visual has been checked by a person |
| Tested on macOS / current Luanti release | **Not yet** |

Everything above was run in a Linux cloud container. The user has Luanti installed at
`/Applications/luanti.app` on a MacBook; it has not yet been used for testing.

## 3. Set up locally (macOS)

```bash
git clone https://github.com/vzordillo/crystalminer
cd crystalminer
git checkout claude/minecraft-crystallography-module-upikhq
tests/run_all.sh                        # finds /Applications/luanti.app automatically
```

- `tests/run_all.sh` runs the unit tests if `luajit` or `lua5.1` is installed
  (`brew install luajit`), then the in-server self-test. The last line must be `PASS`.
- To play, link the repo into Luanti's `games` folder. On macOS this is probably
  `~/Library/Application Support/minetest/games/`, but **that path is unconfirmed** for the
  installed Luanti version. The main menu's About tab has a button that opens the user data
  folder; use the `games` folder inside it.
- After editing Lua files, restart the world (or Luanti) to reload the mod.

## 4. First tasks, in priority order

1. **Run `tests/run_all.sh` on the Mac.** It is the first check against a current Luanti
   release. If it fails, start with the server log it prints. The likely causes are in
   section 8.
2. **Play-test with the client** using the checklist in section 7. Fix what looks wrong.
3. **Check particle load.** Near the Kaleidoscope (1,458 dots) and Translation Hall (912), each
   player receives that many particles every 2 seconds. If it lags, thin the dots in
   `elements.lua` (larger `step` in `line()`, fewer outline points) or switch to particle
   spawners.
4. **Try the tutor live** (see section 6) and have someone with crystallography knowledge
   review about 10 answers. Tighten `tutor_system_prompt()` in `tutor.lua` if an answer is
   wrong or overconfident.
5. **Expert read of `content.lua`.** All text players see is there. It was checked once while
   writing, and the tests check every number the text states about group orders, but a domain
   expert should read it.
6. **Prepare the hackathon submission.** The submission guidelines on llmhackathon.github.io
   could not be opened from the development environment, so their requirements are unknown.
   Likely needs: a demo video (gate quiz → Mirror Plaza → 48 copies in the Kaleidoscope →
   `/symmetry a sixfold axis` refused → `/ask`), a short write-up, and the repo link. Merge the
   branch into `main` or open a pull request so judges see a finished repo.

## 5. How the code is organised

```
game.conf                     Luanti game definition (forces the singlenode mapgen)
mods/crystalminer/
  init.lua                    blocks, flat world, building events, locking, region tracking,
                              particles, quiz windows, commands, tutor commands
  symmetry.lua                pure engine: Jones-notation parser, operations, group closure,
                              32 point groups, regions and images, symmetry detection
  lessons.lua                 pure: tiers, question ids, explanations, progress
  elements.lua                pure: dot positions for axes, mirror planes, centres, lattices
  tutor.lua                   pure request/response code for the Claude API, plus send()
  content.lua                 all player-facing text (regions, explanations, quizzes, glossary)
  selftest.lua                in-server checks, run when crystalminer.selftest = true
  settingtypes.txt            settings shown in Luanti's menu (API key, self-test)
  textures/                   generated; do not edit by hand
tests/                        LuaJIT unit tests, test runners
tools/make_textures.py        regenerates textures (standard library only)
```

Pure modules have no Luanti calls, so they run in plain LuaJIT. Keep it that way; it is what
makes the science testable.

### Key ideas

- **Doubled coordinates.** A node at integer x has its centre at 2x+1. Mirror planes and axes
  can then pass through node centres (odd values) or between nodes (even), and every operation
  stays an integer matrix plus a translation.
- **Crystal axes vs world axes.** Generators are written in crystal axes (x east, y north,
  z up) and converted with `CRYSTAL_TO_WORLD = "x,z,y"` because Luanti's Y is up and +Z is
  north.
- **Regions validate themselves.** `S.region()` refuses a group that does not fit the grid, a
  floor region whose operations flip up and down, and a box whose images would fall outside it
  (for example a 3-fold diagonal axis needs a cube). Building a region at load time is therefore
  a check of the content.
- **Lattice regions** work modulo the unit cell; half-cell translations (screw axes, glide
  planes) need even cell lengths.
- **Detection** (`/whatsymmetry`) tests all 48 grid operations about the build's bounding-box
  centre and names the group by counting operations of each kind (`S.identify`). The tests
  show this count tells all 32 groups apart.
- **Claude never decides science.** `/ask` answers from `content.lua` only, and the prompt
  never contains the Mystery Lab answer (a test checks this). `/symmetry` asks Claude only for
  a symbol (structured output); the engine validates it and writes all feedback.

### Luanti details that cost time

- Mod security blocks `require`. Modules that need others are loaded with
  `loadfile(path)(dependencies)` and start with `local S = ...`. Tests do the same.
- `core.get_mod_storage()` and `core.request_http_api()` only work while the mod loads. They
  are called at the top of `init.lua`; storage is shared via `crystalminer.storage`.
- Luanti nodes are centred on integer positions (a node at x spans x−0.5 to x+0.5). The dot
  code subtracts 0.5 when converting to world positions.
- Locking uses an override of `core.is_protected`; copies are written with `core.set_node`,
  which does not trigger placement callbacks, so there is no recursion.
- `register_on_placenode` returns `true` so blocks are not used up; `core.handle_node_drops`
  is overridden so digging does not fill the inventory.
- The HUD title sets both `hud_elem_type` (5.6) and `type` (newer versions).
- The world is built once and marked with `world_version` in mod storage. **If you change
  region positions or the gate, bump `WORLD_VERSION` in `init.lua` and use a new world**;
  otherwise old scenery stays.

## 6. The tutor (optional, paid per request)

- Model `claude-opus-5-5`, `output_config.effort = "low"`, `max_tokens = 16000`, system prompt
  cached, `fallbacks = "default"` with header `anthropic-beta: server-side-fallback-2026-07-01`
  (lets the API retry on another model if a safety classifier declines).
- Raw HTTP, because there is no Anthropic SDK for Lua.
- To enable: in Luanti's Settings set `secure.http_mods = crystalminer`, and set
  `crystalminer.anthropic_api_key` (or the `ANTHROPIC_API_KEY` environment variable).
- The server log says `[crystalminer] Tutor off: ...` and the reason when it is disabled.
- Untested live. Things to watch on first use: HTTP errors (the reply text is shown in chat),
  answer length in chat, and the 90-second timeout in `tutor.lua`.
- The user wants everything free. The tutor is the only paid part; a free local model would
  need a different HTTP endpoint and request format in `tutor.lua`. That has not been
  discussed further.

## 7. Play-test checklist

1. Welcome text appears; you face displays A–D with floating labels.
2. `/quiz` opens a window with answer buttons; 5 correct answers show "Tier 1 unlocked".
3. `/goto mirror_plaza`: a block placed off-centre is mirrored; blue dots mark the plane.
4. `/goto twin_mirrors` at tier 1: placing is refused with a "Locked" message.
5. `/settier 4`, `/goto kaleidoscope`, fly in (K), place one block: 48 copies and coloured axes.
6. `/goto free_lab`: `/symmetry 6mm` is refused with the reason; `/symmetry 4mm` works;
   build and run `/whatsymmetry`.
7. Watch for lag near the Kaleidoscope and Translation Hall.

## 8. Known risks and limitations

- **Only Luanti 5.6.1 has been tested.** Newer releases renamed the engine from Minetest; the
  code uses the `core` namespace and APIs present in 5.6, and should work, but this is
  unverified. Most likely breakages: game discovery in the test script (it links the game into
  several candidate folders and sets both `MINETEST_GAME_PATH` and `LUANTI_GAME_PATH`) and HUD
  definitions.
- **Labels** are invisible entities with a nametag. Their look and readability are unchecked.
- **Particle load** as described in section 4.
- **Free Lab symmetry** is shared by all players and resets on restart.
- **Plane groups** (floor tilings) are not built; the claim that 12 of the 17 fit a square grid
  is unchecked.
- **`/whatsymmetry`** compares block types only; all blocks are plain cubes, so orientation does
  not matter in this game.

## 9. Verified science (do not change without re-running the tests)

- Orders of all 32 crystallographic point groups (International Tables for Crystallography,
  Vol. A).
- Exactly 25 of the 32 fit a cubic grid; the 7 hexagonal groups cannot in any orientation,
  because each contains a 6 or −6 operation and no signed permutation matrix is one.
- Counting operations by kind (from determinant and trace) distinguishes all 32 groups.
- Every region's stated symmetry and every quiz answer about a group order matches the engine
  (`tests/test_content.lua`).
- Two of the original hand-written test expectations were wrong and were corrected by working
  them out, which is why claims here are tested rather than trusted.

## 10. History

| Commit | What |
|---|---|
| `e07b418` | Plan |
| `d319481`, `6ef193a` | First version: Java, Minestom server, Minecraft Java Edition 26.2 client |
| `e2d2d86` | Moved to Luanti so everything is free; engine ported to Lua |
| `91d6381` | Test script finds Luanti.app on macOS |

The Minestom version was dropped because it needed a paid Minecraft account. Minosoft (an
open-source Minecraft client) was considered and rejected: it supports only up to Minecraft
1.20.4, does not render block-display entities, and still downloads Mojang's assets.
