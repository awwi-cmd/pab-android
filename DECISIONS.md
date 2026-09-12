# DECISIONS.md — Pixel Arena Brawl (PAB)

Why things are the way they are. Log an entry any time you choose between
real alternatives — a package, an architectural split, a tuning approach,
a workaround for an engine limitation, a real bug's root cause. Do not
silently decide (CLAUDE.md §6).

**Numbering resets here.** Pre-alpha history (D-001 through D-091 of the
original build) lives in `docs/archive/DECISIONS_pre-alpha.md`, preserved
verbatim — that file is the real record of ~90 decisions across the
project's first build, including several root-caused bugs (an SFX
resource leak, a wrong Android audio backend, a double-prefixed asset
path, a wallet-write race) worth reading before assuming a fix is novel.
This file starts fresh at **D-001**.

---

## D-001 — Project rebrand: Pixel Arena Brawl (PAB), Alpha 1.0.0; docs reset to Phase 0

**Date:** 2026-09-12 · **Status:** Accepted
**Context:** Developer: "since we've been working on this project for a
while... remove obsolete work from all claude files... Consider this as
PAB_alpha_1.0.0 (Pixel Arena Brawl) -> and returning back to Phase0
(Alpha)... also replace the DIE (DEBUG) and version with our new name...
create build with an .apk and push/merge upload a release to github."

**Decision:** Renamed the project Pixel Arena Brawl (PAB); this baseline
is Alpha 1.0.0. `CLAUDE.md`/`TASKS.md`/`DECISIONS.md`/`NEXT.md` (the 4
files the developer named plus `DECISIONS.md`, implied by "etc" and by
being the largest source of pre-alpha bloat) were archived verbatim to
`docs/archive/*_pre-alpha.md` rather than deleted outright — nothing is
actually lost, git history would have preserved it either way, but an
archive copy stays browsable without needing git archaeology. Each active
file was then rewritten fresh: `CLAUDE.md` keeps every still-load-bearing
rule (architecture, conventions, working style, environment, bootstrap)
but replaces the old per-phase changelog in §1 with one condensed
"current baseline" paragraph; `TASKS.md` restarts numbering at **Phase
0 — Alpha baseline**, condensing 37 pre-alpha phases into one "what's
already built" summary plus one consolidated on-device verification
checklist (replacing the many scattered "on-device verification pending"
items that had piled up across those phases); `DECISIONS.md` (this file)
restarts at D-001; `NEXT.md` keeps every extension-point *pattern* that's
still true (they are — the architecture didn't change, only the history
attached to it) but rewrites them without decision-number citations that
no longer resolve in the active file. `PRD.md` is untouched — it already
correctly describes itself as a frozen record of the original demo, not
current spec, so it didn't need "cleaning up."

Also per the developer's explicit ask: the main menu's version text
(`'v0.1.0 (debug)'`) is now `'PAB Alpha 1.0.0'`; the debug DIE button's
label is unchanged (it's a debug utility, not a branding surface — the
developer confirmed this reading directly when asked). The installed
app's actual label (`AndroidManifest.xml`, `android:label`) and Dart
package name (`pubspec.yaml`'s `name: arena`) are both **unchanged** —
neither was named in the ask, and renaming either is a materially
different, riskier change (an installed-app identity change, or a
project-wide import rename) than updating on-screen text.

**Consequences:** Nothing about the actual game changed — this is a docs
and one-string rewrite, not a code behavior change. `flutter analyze`/
`test`/`build` all still need to pass after the version-string edit (pure
UI text, no logic touched). The next real decision logged here is D-002.

---

## Open questions

Carried forward from the pre-alpha archive — still genuinely open, not
yet settled by play-testing:

- **Enemy stacking** — no separation/steering exists; enemies can pile
  into a single column. Tolerable, or does it need real steering?
- **Difficulty curve shape** — the spawn-interval decay rate and per-level
  enemy scaling are still first-guess numbers, not validated against many
  real rounds.
- **Whether stats should be visible as raw numbers at all**, or only as
  derived effects — Character Select currently shows both.
- **Targeting rule** — "nearest enemy" is the only rule that exists.
  Nearest-in-front or lowest-HP might feel better once real enemy variety
  lands (see `TASKS.md`'s Backlog).
