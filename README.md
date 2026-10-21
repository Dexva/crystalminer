# crystalminer

A Minecraft world for learning symmetry, the foundation of crystallography.
Built for the Open Scientific Intelligence (OSI) Hackathon 2026.

Every region of the world has a symmetry group. Whatever a student builds in a
region is copied by every operation of that group: build half a butterfly in
Mirror Plaza and the mirror finishes it; place one block in the Kaleidoscope and
it becomes 48. Students move up through five tiers, from "what is a symmetry
operation?" to screw axes, glide planes and identifying a hidden point group.
A tutor powered by Claude answers questions using only the reviewed lesson text.

## Running it

Requirements:

- Java 25 (Minestom, the server library, requires it)
- Minecraft Java Edition **26.2** for players

```bash
./gradlew run
```

Then in Minecraft: Multiplayer → Add Server → `localhost` (or the server's IP).

Settings (environment variables):

| Variable | Default | Meaning |
|---|---|---|
| `PORT` | `25565` | Port to listen on |
| `CRYSTALMINER_OFFLINE` | `false` | `true` lets players join without Mojang authentication (classroom LAN). Anyone can then join under any name. |
| `ANTHROPIC_API_KEY` | not set | Turns on the tutor (`/ask`) and natural-language `/symmetry`. Without it the game works and `/symmetry` accepts point-group symbols. |

Tests: `./gradlew test`

## How the game works

| Tier | Regions | Idea |
|---|---|---|
| 0 | Symmetry Gate | The four basic operations: translation, rotation, reflection, inversion |
| 1 | Mirror Plaza (m), Twofold Yard (2), Fourfold Tower (4), Inversion Core (-1), Translation Hall (P1) | One operation at a time |
| 2 | Twin Mirrors (mm2), Monoclinic Cube (2/m), Square Court (4mm), Orthorhombic Cube (mmm) | Combining operations creates new ones |
| 3 | Diagonal Cube (3), Rotoinversion Room (-4), Kaleidoscope (m-3m), Impossible Room | 3D, cubic symmetry, the crystallographic restriction |
| 4 | Screw Hall (P2₁), Glide Hall (Pa), Mystery Lab, Free Lab | Space-group operations, identifying symmetry |

- Entering a region shows its explanation for the player's tier. Coming back
  at a higher tier shows more.
- Coloured particles mark the symmetry elements: rotation axes (2-fold yellow,
  3-fold green, 4-fold red), rotoinversion axes (purple), mirror planes (light
  blue outline) and inversion centres (white). Lattice regions show the unit
  cells.
- Answering every quiz question of a tier unlocks the next. Regions above a
  player's tier can be visited but not built in.

Commands: `/guide`, `/quiz`, `/explain`, `/regions`, `/goto <region>`,
`/progress`, `/ask <question>`, `/whatsymmetry`, `/symmetry <description>`,
`/challenge`, `/clearlab`, `/spawn`, and `/settier <n>` for teachers and demos.

## What Claude does, and what it doesn't

Claude explains and translates; the symmetry engine decides.

- `/ask`: the tutor answers using only the reviewed text in
  `src/main/resources/content.yaml` (glossary and region explanations). It is
  told to say when the text does not cover a question rather than guess, and it
  is never given the Mystery Lab answer.
- `/symmetry a fourfold axis with mirrors`: Claude only picks a point-group
  symbol (structured output). The engine checks it, builds the group, and
  writes every statement about it (order, list of operations). Asking for a
  6-fold axis is refused by the engine, with the reason.
- `/whatsymmetry`: pure code. It tests all 48 cubic-grid operations against
  the build and names the point group.

Model: `claude-opus-5-5` at low effort, with server-side fallbacks enabled in
case a safety classifier declines a request.

## Science checks

The tests check the claims the world makes, rather than relying on memory:

- All 32 crystallographic point groups have the correct orders (International
  Tables for Crystallography, Vol. A).
- Exactly 25 of them fit a cubic block grid. The other 7 (the hexagonal ones)
  cannot in any orientation, because each contains a 6 or -6 operation, and no
  operation of the cubic grid is one. Determinant and trace, which tell the
  kinds of operation apart, do not change with orientation.
- Counting operations by kind tells all 32 groups apart, so `/whatsymmetry`
  can name a group however it is oriented.
- Every region's stated symmetry and every quiz answer about group order
  matches the engine (`ContentTest`).
- Combination rules taught in tier 2 are checked: mm2 contains a 2-fold axis,
  2/m contains an inversion centre, -4 contains a 2-fold axis but no 4-fold
  axis and no inversion centre.

## Project layout

```
src/main/java/crystalminer/
  symmetry/   engine: operations, groups, point-group catalog, regions, detector
  content/    loads content.yaml; player progress
  tutor/      Claude API tutor
  server/     Minestom server: world, events, commands
src/main/resources/content.yaml   all text players read; edit without code
```

Coordinates: crystal axes have z up. They map to Minecraft as x → east,
y → north, z → up, which keeps the axes right-handed.

## Known limitations

- The tutor has not been run against the live API from this repository's
  development environment (no API key was available there). Request
  construction is unit-tested.
- Player progress is kept in memory and is lost when the server restarts.
- `/settier` is open to every player.
- Blocks with 16-step rotation (signs, banners) are copied in their default
  orientation.
- `/whatsymmetry` compares block types but not which way a block faces.
- The Free Lab's symmetry is shared by everyone on the server.
