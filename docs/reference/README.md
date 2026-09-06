# Art reference

## `character_states.png`

The animation-state vocabulary for the player character (the wizard / "The
Apprentice"). This is the source of truth for **which states exist**, not for
final frame counts — see PRD §8 for the demo's required set and frame counts.

States shown on the sheet:

| Row | Cells |
|---|---|
| 1 | spawn, teleport, warp *(empty)* |
| 2 | fly, fly clr, idle, idle clr, run, run clr |
| 3 | dash 1, dash 2, pose 1, pose 2, flash 1 *(empty)*, flash 2 *(empty)* |
| 4 | fire, charge, channel staff, channel wand, casting, pose |

Notes:
- `clr` variants are the coloured/effect versions of the same state.
- The `flash` cells are empty — the demo implements the hurt flash as a white
  tint pass instead of sprite frames (DECISIONS D-013).
- **There is no death state on this sheet.** The demo uses a fade+shrink fallback;
  a real death animation is an open art task (TASKS 5.9).
