# LIB_UNICODE

The registry of every Unicode character we use, what it means to us, and what we plan to use
it for, so a character means the same thing every time it appears (the owner, 18 Nov 2026).

It is also a list of content to generate: a character can name a procedure that builds the
thing it stands for. One little house character dragged into a scene becomes a 3D house,
built by its procedure. Tool icons are characters too, instead of chasing PNG files around.

## The rule

1. Before using a character anywhere (a button label, a tool icon, a game entity), look it up
   in `REGISTRY.tsv`.
2. If it is there, use it for that meaning only. If it is not, add a line first.
3. One meaning per character. If two places want the same one, it goes under **Clashes** below
   until the owner picks.

## REGISTRY.tsv

Tab-separated, one character a line. Lines starting with `#` are comments.

| Column | Holds |
|---|---|
| char | the character itself |
| code | `U+2302` |
| name | its Unicode name |
| meaning | what it means to us (one meaning) |
| kind | `tool` (an icon you click) or `entity` (a thing in a world) or `mark` (UI decoration: arrows, ticks) |
| procedure | for entities: the handler that builds it in 3D (planned names until written) |
| used_in | where it is used now (LIBs, games), blank if only planned |
| status | `used`, `planned` or `clash` |
| notes | anything else |

## Things to know

- **Fonts.** Not every font has every character. Raylib's default font has none of them
  (`LIB_RAYGUI/PLAN.md`, "The symbol problem"), and LiveCode shows a box when the font lacks the glyph.
  Prefer characters in the Basic Multilingual Plane (code U+FFFF or below); emoji above that are
  noted as a second choice.
- **Groups give us content lists.** Unicode blocks (Miscellaneous Symbols, Transport and Map
  Symbols, Weather...) are ready-made lists of things to generate.
- Easiest by math first: the first procedures should be simple shapes built in code.

## Clashes

Settled by the owner, 18 Nov 2026: ⚙ is the **Tools menu**, ✎ is the **Editor button**.
The iGame3D XT editor used them for level and the path tool; those get new characters
(candidates ▤ level, ⤳ path tool, marked planned in the registry).

## The library (19 Nov 2026)

`livecode/lib_unicode.livecodescript`, script stack "lib_unicode". Needs nothing from the engines,
so it runs in Vibecode3D (XT), xRay and headless alike.

| Call | Gives |
|---|---|
| `Unicode.Char("house")` | the character for a meaning |
| `Unicode.Meaning(c)` / `Unicode.Procedure(c)` / `Unicode.Field(c, "notes")` | a column of its line |
| `Unicode.Code(c)` | `U+2302`, worked out from the character |
| `Unicode.List(kind, status)` | the characters, one a line (both may be empty) |
| `Unicode.Check()` | lines where the registry disagrees with itself (empty = good) |
| `Unicode.Build(c, width)` | the raw mesh its procedure builds; empty + `Unicode.LastError()` when there is none yet |
| `Unicode.Reload` / `Unicode.SetRegistry path` | read again after an edit / use another file |

A mesh from `Unicode.Build` is in the engine's own format (what `Mesh.New`/`MeshBox` make), so:

    Mesh.Define "house", Unicode.Build(Unicode.Char("house"), 40)

**Procedures written:** `Proc.House pW, pH, pD, pRoof` (⌂): four walls, a gable roof (ridge front to
back), a door drawn on the front; stands on y = 0, up is negative y; sizes follow the width.
Picture: `preview/house_by_math.svg` (drawn by Python from the same numbers).

Tests (no window): `python3 -I ~/projects/LIB_BIT/editor/tests/run_headless.py tests/lc_unicode_test.txt tests/lc_unicode_engine_test.txt tests/lc_person_test.txt`

**More procedures (19 Nov, evening):** `Proc.Car` (🚗 body, cabin, four octagon wheels standing flat
on y = 0, front at +x), `Proc.Truck` (⛟ chassis, cargo box, cab), `Proc.Cloud` (☁ five round puffs,
no randomness; it floats 1.5 widths above the spot), `Proc.StormCloud` (⛈ the cloud + a zigzag bolt
of wire lines to the ground). All are closed solids, so occlusion culling hides with them.

## The picker palette (19 Nov 2026, evening)

`livecode/UnicodePicker.oxtstack` (script: `livecode/unicode_picker.livecodescript`; `Picker.Build`
makes every control again). Open it in OXT-Beyond next to a game window (HOWTO's Run, the
GAME_Browser, any Game Player "Play <Game>" window).

- **Entities**: drag a character into a game window and let go: its procedure builds it there,
  on the ground (y = 0) under the mouse. Where the ground is not under the mouse (a level camera),
  it lands as deep as the world's centre. A click (no drag) drops it in the middle of the front
  game window. Dim characters are planned: no procedure written yet.
- **Tools / Marks**: a click copies the character to the clipboard, for button labels.
- **S M L**: built 20, 40 or 80 wide. **Take back**: removes the last thing dropped.
- Game Player windows (Vibecode3D, XT) and **the xt3d window** (19 Nov): the games bench
  `xt3dTestBenchLibMCP` (HOWTO's xt3d side, view-only). Its raylib camera is the engine's own
  (camera space, field of view from the focal length), drawn into its image "view", so the same
  ground math holds: the picker only maps the mouse into that image and puts the engine's view
  centre back to the bench's (`Vibe.ApplyRect`; both windows share the engine's globals).
  Only while a game plays there (its `xbGameTick` is waiting): a stopped bench draws nothing, so
  the picker says so instead of dropping. People there move while it plays and are let go when
  it stops.
- Tried 19 Nov in OXT-Beyond on Simple_Test1 by calling the drop (house, car, storm cloud, take
  back). The drag itself with the real mouse is the owner's first try.

Tests (no window): add `tests/lc_picker_test.txt`, `tests/lc_picker_person_test.txt` and `tests/lc_picker_xt3d_test.txt` to the line above: the palette builds, and
`Picker.GroundAt` gives back the world point the engine projected (4 points, two cameras).

## 웃 Person: a stick figure with bones (19 Nov 2026, late)

`Proc.Person pW` builds a standing stick figure **0.4 * pW tall** (the car's scale: 40 wide is a
4.5 m car, so a 1.75 m person is 16; door-high next to a house of the same size). One wire line a
bone, the head a ball. It **faces -z** (like the house's door), so its left hand is at -x.

The bones are **LIB_MOCAP's 25 joints** (Hips, Spine ... LeftArm, LeftForeArm, LeftHand ...
RightToe_End: the same names, parents and lines as its stick clips), so the math and a captured
clip move the same figure.

| Call | Gives |
|---|---|
| `Person.Pose(motion, phase, height)` | the 25 joint points, one `x,y,z` a line. Motions: `stand` (slow sway), `walk`, `run`, `wave`; phase 0..1 through one cycle |
| `Person.Mesh(pose, edges, head, top)` | the mesh of a pose (edges empty = `Person.Edges()`; head ball between joints 6 and 7) |
| `Person.Frames(motion, height, count)` | one cycle as meshes `[1..count]` + `["frames"]`, `["fps"]` |
| `Person.Stride(motion, height)` | how far one cycle carries it, so the feet don't skate (walk 0.72 h, run 1.2 h) |
| `Person.FromClip(text, height, max, every)` | a LIB_MOCAP `*_stick.txt` clip as meshes, scaled to the height, turned to face -z; walks keep only their loop cycle; `["travel"]` per second, scaled |
| `Person.Names()` / `Person.Edges()` / `Person.Motions()` | the joints, the bones (`a-b`, 1-based), the motions |

How the math moves it: legs swing from the hips with the knee bent while that foot swings
forward; the hips sit as high as the longer leg allows, so the lowest foot is always on the ground
and the body bobs by itself. Arms swing against the legs. Every bone keeps its length in every
frame (tested). Picture: `preview/person_by_math.svg` (8 phases of each motion, side and front).

**In the picker**: the new **웃 moves** button says what a dropped person does: stands, walks
round, runs round (a ring 1.5 heights wide round the spot, at the speed its feet carry it),
waves, or dances (`LIB_MOCAP/library/FreeBVH_DANCE`, 8 s at 15 fps, only when that clip is in the
local library). Dropped people move on their own (the picker's timer swaps their frame meshes,
needs the Game Player's `Entity.SetMesh`); a window whose game is stopped or still is drawn by
the picker; a paused game (Escape) holds them still. Take back removes them too.

Tests (no window): `tests/lc_person_test.txt` (the figure, bones in every motion, the proc_walk
clip) and `tests/lc_picker_person_test.txt` (drop into a game window with the Game Player's
engine, it walks round its ring, pause, take back). Not yet seen in a real window.

## Next

- xt3d drop: tried headless only (`tests/lc_picker_xt3d_test.txt`: a stand-in bench whose view
  is not at the card's corner; a ground point the engine projects comes back exactly). The full
  bench (not view-only) scales its stack, which misplaces windows in OXT-Beyond: view-only is the
  one meant. Engine MOVEX/MOVEY offsets (raylib's camera does not shift) would put drops off.
- People in games: `Person.FromClip` + `Person.Stride` give a game everything Amazing Couple does
  by hand (its own clip loader could use them).
