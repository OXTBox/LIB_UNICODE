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

Tests (no window): `python3 -I ~/projects/LIB_BIT/editor/tests/run_headless.py tests/lc_unicode_test.txt tests/lc_unicode_engine_test.txt`

## Next

- A picker palette: drag a character into a scene, its procedure builds the object.
- More procedures by math: car, cloud, truck, person.
