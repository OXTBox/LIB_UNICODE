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

## Next

- `livecode/lib_unicode.livecodescript`: `Unicode.Char(meaning)`, `Unicode.Meaning(char)`,
  `Unicode.Procedure(char)`, read from REGISTRY.tsv, so scripts never type the character itself.
- A first procedure: ⌂ house, by math (box + roof).
- A picker palette: drag a character into a scene, its procedure builds the object.
