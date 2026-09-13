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

## D-002 — World objects: standing torches (solid obstacle) + gem vases (breakable)

**Date:** 2026-09-13 · **Status:** Accepted
**Context:** Developer added two new spritesheets (`scenes/torch-standing.png`,
8-frame flicker loop; `scenes/gem-vase.png`, 16-frame shimmer loop, both
native 16×16) and asked: torches scatter randomly through the map, not too
close to each other, solid to both the player and enemies; vases scatter
randomly too, and break on player touch — a "card chosen" SFX, the VFX
from when a chest card is chosen, and a burst of gems flying out left and
right — plus config knobs for torch/vase counts, spacing, and how many
gems a vase drops.

**Decision:**
- **Placement/lifecycle** — two new spawners, `TorchSpawner`/`VaseSpawner`,
  same camera-relative "random point in a rect around the visible view"
  shape `PotionSpawner`/`ChestSpawner` already use, each capped at a
  `GameConfig`-backed live count and rejecting a candidate point too close
  to an already-live sibling of the same type (`game_rules.dart`'s new
  `farEnoughFrom`, a few retries before giving up for that tick) — the
  "not too close to each other"/"how divided they are" asks. Torches also
  get a distance-based straggler cull identical in shape to `Spawner`'s
  enemy cull (`TorchSpawner._cullStragglers`): the world is unbounded and
  torches never move, so without one, one left behind by the roaming
  camera would sit in memory forever. Vases don't need this — a vase
  reaching the player is what removes it, same as any other pickup, so a
  slow one just becomes ordinary unclaimed loot rather than a permanent
  leak.
- **Torch collision** — a new pure function, `core/game_rules.dart`'s
  `resolveCircleObstacle` (circle-vs-circle push-out, mutates `position`
  in place per CLAUDE.md §4.4), called from both `PlayerComponent.update`
  and `EnemyComponent.update` against every live `game.torches` entry — the
  "player & enemy collision" ask. A new `ArenaPriority.obstacle` (8, between
  `pickup` and `enemy`) is the torch's render layer. No physics
  engine/new dependency (CLAUDE.md §4.9) — this project already hand-rolls
  every other piece of movement math the same way.
- **Vase break VFX** — `gem-vase.png` turned out to have no distinct
  shatter frames (16 frames are the same intact pose, just a shimmer sweep
  across it), so "breaking" is the component vanishing at the exact instant
  the SFX/VFX/gem burst fire, not a sprite transition — the same trick
  `ChestComponent`'s anima+explosion beat already leans on for a chest that
  also has no literal "breaking apart" frames of its own.
- **"VFX from when we choose a card"** — the actual chest-reveal moment
  (DECISIONS D-072, archived) is a Flutter-widget radial `Icons.auto_awesome`
  burst living entirely in `ChestRevealOverlay`, an ordinary Flutter overlay
  (CLAUDE.md §4.1: Flutter owns menus, Flame owns the arena) — it cannot run
  inside the Flame world at all, and a vase breaking is very much a Flame
  world event. Substituted the closest Flame-side equivalent instead: a new
  one-shot copy of the existing `sparkleAnimation` sheet
  (`GameAssets.cardChosenBurstAnimation`, `loop: false` — the original
  `sparkleAnimation` loops forever since D-036, so it would never satisfy
  `spawnEffect`'s `removeOnFinish`), fired 8 times outward from the break
  point at random angles/distances (`ArenaGame.spawnCardChosenBurst`). Reads
  as the same "something good just landed" sparkle language without
  reimplementing Flutter Icon widgets inside a Flame component (impossible)
  or duplicating the overlay's exact burst math for a context it wasn't
  built for.
- **Gem burst** — `ArenaGame.breakVase` rolls a random gem count in
  `[GameConfig.vaseGemsMin, vaseGemsMax]`, alternating left/right per gem
  (`i.isEven` picks the side) rather than a fully random scatter, so a
  small count still visibly reads as "left AND right" rather than
  occasionally clustering on one side by chance — the developer's literal
  spec. Each is an ordinary `GemComponent`, same rarity roll/collect
  behavior as every other gem drop, just spawned scattered around the
  vase's position instead of dead-center.
- **Config** — a new `worldObjects` section in `game_config.json`/
  `GameConfig` (DECISIONS D-090's pattern): `torchCount`/`torchMinSpacingPx`/
  `vaseCount`/`vaseMinSpacingPx`/`vaseGemsMin`/`vaseGemsMax`, all with
  fallbacks matching the shipped defaults.

**Consequences:** `flutter analyze`/`test`/`build apk --debug` all pass.
One test fix was needed as a side effect of the *previous* CoinIcon-spin
change (not this feature): `test/widget_test.dart`'s "Menu -> Character
Select is navigable" used `pumpAndSettle()`, which hangs forever once a
perpetually-repeating `AnimationController` (the spinning coin icon,
Character Select's wallet row) is on screen — switched to two bounded
`pump()` calls, the standard workaround for a real animation that's
supposed to never settle. Not yet verified on-device (CLAUDE.md §4.11):
torch collision feel, vase break timing/VFX legibility, and whether the
spacing/count defaults actually read as "spread out" in practice all need
a real playthrough.

---

## D-003 — Every Character Upgrades dial is per-character; "UPGRADES" renamed "CHARACTER UPGRADES"; BONUSES SHOP + summary panels

**Date:** 2026-09-13 · **Status:** Accepted (revised same day — see
"Revision" below)
**Context:** Developer's spec verbatim: "Any upgrades you buy, are bought
per character, and will not carry once you buy a new character. When we
swipe a character in character select, you will not have the same
progression in upgrades. (also let's rename Upgrades in Character
Upgrades)... Per each character, we will reflect the additional STR VIT
DEX INT stats, into the bars, make them reach a maximum, and once they
reach it - turn a different color BUT also write how much additional +X
each stat has at the beginning of the panel, like STR +17 (with red)
-------BAR------ TOTAL STR. At the bottom, below ENTER ARENA, note any
CHAOS, HASTE, etc, the other upgrades. And make sure the implementation
for the SHOP remains the same, permanent bonuses FOR ALL characters."

Then, immediately as a correction: "No, all of character upgrades must be
SPECIFIC to character, not only stats STR VIT DEX INT, chaos haste luck
everything from character upgrades should be specific to character. Make
the SHOP and character upgrades buttons just a little bit more wider to
the left and right. Make the SHOP upgrades appear below the character
upgrades, in a separate panel called BONUSES, rename shop SHOP" — clarified
via follow-up questions to: the two new panels live on Character Select,
below the existing per-character summary and below ENTER ARENA, titled
"Stat Upgrades:" and "Shop Bonuses:"; and "rename shop SHOP" meant "change
shop to Bonuses Shop" (the SHOP button/screen becomes "BONUSES SHOP").

**Decision (first pass, superseded by the Revision below in every place
they conflict):** only STR/VIT/DEX/INT were made per-character; the other
8 dials stayed global. Kept here for the record, not as current behavior.

**Revision — every dial is per-character, not just the 4 attributes:**
- **Scope** — all 12 `MetaStat` members (STR/VIT/DEX/INT plus CHAOS/HASTE/
  FORTUNE/RESOLVE/MAGNET/LUCK/REGEN/CRIT) are now per-character. There is
  no global Character Upgrades dial left at all. SHOP (gem-priced,
  `MetaProgression.ownedItemIds`) is the one system confirmed to stay
  global/shared, per the developer's explicit "make sure... SHOP remains
  the same, permanent bonuses FOR ALL characters."
- **Data model** — `CharacterUpgradeLevels` (renamed from the first pass's
  `CharacterStatLevels`, which only held 4 fields) now holds all 12 ints,
  one field per `MetaStat`; `MetaProgression.characterUpgradeLevels` is a
  `Map<String, CharacterUpgradeLevels>` keyed by `CharacterDef.id`. The
  first pass's global fields (`corruptionLevel`/`hasteLevel`/.../`critLevel`)
  and its global `levelOf`/`buy`/`_setLevel` methods are gone outright —
  `levelsFor`/`levelOfFor`/`buyFor` are the *only* entry points now, for
  every dial, not a "STR/VIT/DEX/INT throw, everything else doesn't" split.
  `ArenaGame` gained a `metaLevel(MetaStat)` shortcut
  (`meta.levelOfFor(character.id, stat)`) so every gameplay call site that
  used to read a bare `meta.hasteLevel`-style getter (7 of them, across
  `arena_game.dart`/`player.dart`/`chest.dart`/`gem.dart`/`potion.dart`/
  `vase.dart`/`spawner.dart`) reads through one shared shortcut instead of
  repeating `character.id` at every site.
- **Persistence** — same JSON-blob shape the first pass established
  (`_kCharacterUpgradeLevels`, one `try`/`catch`-guarded `jsonEncode`/
  `jsonDecode`), now encoding all 12 fields per character through a shared
  `MetaStat -> JSON key` table (`_statJsonKeys`) both directions read, so
  encode/decode can't silently drift apart on a future 13th dial. Old keys
  (both the abandoned first-pass ones and the truly-original flat
  `meta.corruption`/etc.) stay abandoned, not migrated — still pre-release,
  no real save data to preserve.
- **Character Upgrades screen** — the `stat.isPerCharacter` branching the
  first pass added to `_buy`/`_UpgradeRow` is gone; every page (all 3) now
  buys/reads through `buyFor`/`levelOfFor` uniformly, scoped to whichever
  `CharacterDef` launched the screen (route argument, unchanged from the
  first pass).
- **Character Select page** — below ENTER ARENA / the locked-unlock panel,
  two new titled panels (`_SummaryPanel`, shared bordered-box look):
  **"Stat Upgrades:"** — this character's own CHAOS/HASTE/FORTUNE/RESOLVE/
  MAGNET/LUCK/REGEN/CRIT levels (`MetaStat.values.skip(4)`, the first pass's
  `_GlobalUpgradesSummary` chip row, now reading per-character and wrapped
  in a titled panel instead of a bare `Wrap`). **"Shop Bonuses:"** — the
  owned BONUSES SHOP items' labels (`kShopItems.where(meta.ownsItem)`),
  global, new — Character Select never showed owned SHOP items anywhere
  before this.
- **Rename** — SHOP → "BONUSES SHOP" everywhere (the Character Select
  button, `ShopScreen`'s own title) — the developer's clarified "change
  shop to Bonuses Shop," distinct wording from the new "Shop Bonuses:"
  summary panel so the two don't read as the same feature.
- **Button width** — the SHOP/CHARACTER UPGRADES button row got pulled out
  of the ambient 24px-margin `Padding` its neighbors (wallet row, page
  dots) still use, into its own 16px-margin `Padding` — 8px wider on each
  side, "a little bit more wide to the left and right." A negative-outset
  `Padding` past the ambient 24px was tried first and rejected outright by
  Flutter itself (`RenderPadding`'s `assert(padding.isNonNegative)` — a
  real regression this session caught via `flutter test`, not a design
  choice); a smaller non-negative margin of its own is the actual fix.

**Character Select bars (unchanged from the first pass, still current):**
`StatBar` gained two optional params, `bonus`/`bonusMax` (every other call
site passes neither and renders exactly as before): a red "+N" chip next
to the label (only shown when `bonus > 0`) and a fill-color switch to
`ArenaColors.xp` (gold) once `bonus >= bonusMax`. Character Select's own 4
STR/VIT/DEX/INT bars pass `value: base + bonus`, `max: base +
kMetaMaxLevel` (the purchasable ceiling, not a flat 10 — a high-STR
character like the Bruiser has a higher ceiling than a low-STR one). The
derived HP/DMG/shots-per-sec/speed line right below the bars reads the
same effective (base+bonus) `StatBlock`, not the character's bare base
stats — showing a boosted bar next to a stale unboosted HP number would
have read as a bug. The exact bar layout (delta-next-to-label, bare total
at the bar's end, not a literal "TOTAL" string) was confirmed with the
developer via a side-by-side mockup rather than guessed.

**FTUE:** the tutorial's 3rd slide ("LOOT, SHOP & UPGRADES") was rewritten
twice this session — first to distinguish SHOP-vs-Character-Upgrades at
all (the first pass), then again once the Revision above widened the
per-character split to every dial (now: BONUSES SHOP permanent/shared;
every CHARACTER UPGRADES dial, STR/VIT/DEX/INT included, per-character).
Separately, developer's ask ("add some line breaks... the text is too
close together... fill more to the bottom. Add bold and italics"):
`_TutorialSlide.body` changed from one dense `String` to a `List<Widget>`
of short `_TutorialParagraph`s (own gap between each), and that new
widget parses simple inline `**bold**`/`_italic_` markup into a
`TextSpan` list — deliberately minimal (no nesting/escaping, not a real
markdown renderer) since this is 3 fixed slides, not user-authored content.

**Consequences:** `flutter analyze`/`test`/`build apk --debug` all pass.
`meta_progression_test.dart`'s per-character group now covers all 12
dials (not just the first pass's 4), and the persistence round-trip test
covers every field for 2 characters. The button-width negative-padding
mistake was caught by `flutter test` itself (a real `RenderPadding`
assertion failure, not just a visual guess) before it ever reached
`rebuildinstall.bat`. Not yet verified on-device (CLAUDE.md §4.11): the
widened button row's actual on-screen width, the two new summary panels'
legibility, and that buying any dial for one character and swiping to
another genuinely shows 0 there for *every* dial, not just STR/VIT/DEX/INT.

**Follow-up, not yet done:** this branch (`feature/animation-updates`)
changed enough player-facing design (Character Select's own layout, the
renamed buttons, FTUE copy) that `README.md` — a GitHub visitor's first
look at the project — is now stale in at least those spots. **Update
`README.md` before/when merging this branch to `main`** — flagged here and
in `TASKS.md`'s Phase 1 so it isn't missed at merge time.

---

## D-004 — "Shop Bonuses:" panel: list → compact count + VIEW ALL

**Date:** 2026-09-13 · **Status:** Accepted
**Context:** Developer, on-device: "THE SHOP BONUSES RUN OUT OF SCREEN AND
THE USER NEEDS TO SCROLL DOWN, THERES TOO MUCH SHOP BONUSES WHAT SHOULD WE
DO?" — D-003's "Shop Bonuses:" panel listed every owned item's full label
in a `Wrap`, which only ever grows as the player buys more of BONUSES
SHOP's 15 items, eventually pushing Character Select's whole page tall
enough to need scrolling. Presented 4 concrete options (compact count+link,
capped list with "+N more," a panel-local scroll area, or something else);
developer picked the compact count.

**Decision:** `_ShopBonusesPanel` no longer lists item labels at all —
it shows a fixed-height `"N / 15 owned"` count plus a "VIEW ALL >"
`TextButton` that opens BONUSES SHOP (`ShopScreen`, the exact same
`Navigator.pushNamed` + reload-on-return the BONUSES SHOP button already
did — pulled into one shared `_openBonusesShop` method on
`_CharacterSelectScreenState` so both call sites can't drift). This
panel's own height is now constant regardless of how many of the 15
items are owned — 0 owned and 15 owned render identically sized, so
Character Select's page height stops growing as the player buys more,
the actual fix for "runs out of screen." The "VIEW ALL" tap plays the
shared tap SFX (`withTapSfx`, DECISIONS D-076), same as every other
button in this app.

**Consequences:** `flutter analyze`/`test`/`build apk --debug` all pass.
Not yet verified on-device: tapping "VIEW ALL" actually opens BONUSES
SHOP and the count updates correctly after a purchase there.

---

## D-005 — Character Select: no scrolling, ever

**Date:** 2026-09-13 · **Status:** Accepted
**Context:** Developer: "Make sure there is no scrolling in character
select." `_CharacterPage` had been a `SingleChildScrollView` since before
this session (portrait art, name/descriptor, 4 stat bars, HP/DMG line,
ENTER ARENA/locked panel) — D-003/D-004 added the two summary panels on
top of that same scrolling column without questioning whether scrolling
itself was still wanted.

**Decision:** `_CharacterPage` is a plain `Padding` + `Column`
(`mainAxisAlignment: spaceBetween`, no `SingleChildScrollView` at all) —
every gap between sections is now whatever slack `spaceBetween`
distributes, not a hand-picked `SizedBox`, so it adapts to whatever
height `PageView` actually gives this page rather than needing a second
round of gap-tuning later. Several sizes were tightened alongside the
scroll removal so the content actually fits without it: portrait art
120→84px, name 20→18px, descriptor capped at 2 lines (`maxLines`/
`overflow: ellipsis`) at 12px (was default ~14), the HP/DMG/speed line
12px (was default). First-guess sizes, like everything else in this
project — needs a real on-device check, not just the test harness.

**Test fix:** `test/widget_test.dart`'s "Menu -> Character Select is
navigable" started failing immediately — a real `RenderFlex overflowed by
75 pixels` on the *test harness's* default 800×600 logical surface, which
is shorter than any real phone in portrait (that 600 was only ever safe
before because the page could scroll past it). Fixed by giving that one
test a realistic tall-phone surface (`tester.view.physicalSize = Size(1080,
2340)` at 3.0 device pixel ratio → 360×780 logical, this app's own
`kDesignWidth` at a normal phone height) instead of the runner's arbitrary
default — the page is designed against a real phone's proportions, not
an 800×600 desktop-shaped test window, so the test should exercise that
shape now that nothing scrolls to compensate for a bad one. The
`ensureVisible` scroll-to-reveal step this test used to need is gone too
(nothing left to scroll to).

**Consequences:** `flutter analyze`/`test`/`build apk --debug` all pass.
Not yet verified on-device (the real risk this decision carries): a
genuinely small/short phone screen could still overflow where the test's
780-logical-px stand-in doesn't — this needs an actual on-device check,
ideally on the smallest screen available, not just trust in the test's
chosen size.

---

## D-006 — Vase break: drop the sparkle VFX, stagger the gem fly-out; LevelUp popup gets a real entrance/selection animation

**Date:** 2026-09-13 · **Status:** Accepted
**Context:** Developer: "Let's remove the vfx for when we break the vase.
But make the gems fly out of it more when we break it, like 1 by 1, 0.5
sec delay fly a generous amount of distance from the vase, not too far."
And separately: "Level up screen: let's animate it a bit, show the Level
up.. text first, then 0.5 second later, slide in each selection from the
left one by one (left meaning outside of the screen). And the selection
the player chooses, after the player taps it, the other 2 disappear
instant, and the one chose flashes, then 1 second later the level up
screen closes."

**Decision — vase break:**
- **VFX removed** — `VaseComponent` no longer calls `ArenaGame.
  spawnCardChosenBurst`; that method, `GameAssets.cardChosenBurstAnimation`
  (and its one-shot sheet load), and the `kCardChosenBurst*` constants are
  all deleted outright, not just left uncalled — dead code, not a toggle.
  The card-chosen SFX stays (never asked to remove it).
- **Staggered gem fly-out** — a new `VaseGemBurstComponent` (bare
  `Component`, not itself visible) replaces `ArenaGame.breakVase`'s old
  "spawn all N gems in the same frame" loop: it holds the still-to-spawn
  count and a countdown, spawning exactly one `GemComponent` every
  `kVaseGemBurstIntervalSec` (0.5s) — the first fires immediately, not
  after an initial 0.5s wait, so the burst reads as starting the instant
  the vase breaks. `GemComponent` itself gained an optional `launchFrom`
  param: when set, the gem visibly travels from that point to its landing
  spot over `kVaseGemLaunchDurationSec` (ease-out, hand-rolled per-frame
  lerp — CLAUDE.md §4.4's "mutate in place" convention, no Flame Effects
  package) before its normal float-bob/pickup behavior takes over; every
  other spawn site (enemy drops, chests) leaves it null and is completely
  unaffected. The scatter-distance constants (`kVaseGemScatterMinPx`/
  `MaxPx`) were widened (18-42px → 40-90px) for "a generous amount of
  distance... not too far."

**Decision — LevelUp popup:** `_LevelUpOverlayState` (`arena_screen.dart`)
gained two `AnimationController`s and 2 `Timer`s:
- **Entrance** — the title renders immediately; a `Timer` (500ms) then
  flips `_cardsVisible`, which is what actually mounts the 3
  `_LevelUpCard`s at all, and starts `_slideController`. Each card's own
  slide-in reads off one shared `Interval` on that single controller
  (start offset = `index * 150ms`, own duration 350ms) — the same
  "one controller, per-item `Interval` stagger" shape this file's
  `_CardLandSparkleSpec` (chest reveal) already established, not N
  separate controllers. Cards translate in from -500px (comfortably
  off-screen on any device width) with a fading-in opacity tied to the
  same interval.
- **Selection** — tapping a card no longer calls `ArenaGame.
  resolveLevelUpChoice` directly. It sets local `_chosenKind`, which (a)
  makes every *other* card's build method return `SizedBox.shrink()` —
  gone outright, no fade, matching "disappear instant" — and (b) starts
  `_flashController` (550ms), which the chosen card's own builder reads to
  overlay a pulsing accent-colored `Container` (`sin(t·4π).abs()`, a
  couple of visible pulses rather than one smooth glow, matching the
  developer's own plural "flashes"). A second `Timer` (1000ms) is what
  actually calls `resolveLevelUpChoice` — the real upgrade grant + the
  overlay's own removal both happen at the end of that delay, not at tap
  time. A second tap on the flashing card is a no-op (`_chosenKind != null`
  guard) since it can't be un-chosen mid-flash.

**Consequences:** `flutter analyze`/`test`/`build apk --debug` all pass —
no test exercises the LevelUp overlay itself (DECISIONS D-019: coverage
stops at Character Select) or vase breaking (no Flame-world test coverage
at all, CLAUDE.md §4.11), so none of this animation timing is verified by
the test suite; it needs a real on-device level-up and a real vase break
to confirm the timings/motion actually read the way they're written here.

---

## D-007 — Vase burst faster + a small explosion VFX; LevelUp title/upgrades-button fixes

**Date:** 2026-09-13 · **Status:** Accepted
**Context:** Developer, after seeing D-006 on-device: "make gems launch at
once almost 0.125 delay in between, the direction they go is good. Add a
explostion vfx like the 4th character has when we open the vase, the
sound can remain the current but make the explosion not that big." And:
"[LevelUp] Looks good, but the Level up text + view your upgrades appear
in the middle then move when the upgrades are coming. Let's make the
level up static, view your upgrades appear only if you have upgrades (and
never in the reveal animation of the level up, make it appear from the
right of the screen, after the upgrades appeared already)."

**Decision — vase:**
- `kVaseGemBurstIntervalSec` 0.5 → 0.125 (scatter direction/distance left
  as D-006 shipped them — "the direction they go is good").
- A small explosion VFX added at the break point — the exact same
  `explosionAnimation` sheet `WardenSlamAttack`'s own shockwave uses ("the
  4th character," the Warden), sized to `kVaseExplosionWidthPx` (36, well
  under the Skirmisher's `kSpiralExplosionWidthPx` of 64 and nowhere near
  the Warden's own arena-radius-scaled size — "not that big"). Called via
  the bare `ArenaGame.spawnEffect`, not `spawnExplosionEffect` — that
  helper also plays the explosion boom SFX, which isn't wanted here ("the
  sound can remain the current," i.e. only the existing card-chosen SFX).

**Decision — LevelUp:** the D-006 entrance animation had a real bug: the
card block was conditionally *absent from the tree* until the 0.5s reveal
timer fired, so the popup's total height (and the centered title's own
screen position) jumped the instant that block appeared, even though each
card's own opacity/translate was already correctly at 0 — the bug was the
tree membership, not the animation math. Fixed by always building the
card block (and, new this pass, the "VIEW YOUR UPGRADES" button) from
frame one, letting `AnimationController` values (which start at 0 and
only advance once `.forward()` is called) do 100% of the hiding — the
same fix shape for both: reserve the layout space immediately, animate
only opacity/position. "VIEW YOUR UPGRADES" also gained its own rules: a
`_hasUpgrades` check (`PlayerUpgrades.pickCounts` has any nonzero entry)
decided once at mount — a fresh character's very first level-up has
nothing to view yet, so the button isn't built at all that time, not
just hidden; and when it does exist, its own slide-in (from the right,
mirroring the cards' from-the-left) only starts once `_slideController`'s
own `.forward()` future completes — chained off that future directly
rather than a second hand-timed `Timer` that could drift from however
long the cards' stagger actually took.

**Consequences:** `flutter analyze`/`test`/`build apk --debug` all pass.
Same caveat as D-006: no test coverage for either the vase break or the
LevelUp overlay exists, so this is unverified until a real on-device pass.

---

## D-008 — Claimable achievements + a main-menu pip; a real SHOP/CHARACTER UPGRADES overflow fix

**Date:** 2026-09-13 · **Status:** Accepted
**Context:** Developer: "1. Make achievements claimable, put them on
pending and make user have to claim them by himself in the achievments
menu. 2. Have a PIP on achievements button in main menu when anything is
pending to claim. 3. Gave my game to a friend to play and most panels in
the game in shop upgrades and character upgrades are BOTTOM OVERFLOWED BY
12 14 (SHOP & UPGRADES) or 20 (STAT UPGRADES)."

**Decision — claimable achievements:**
- `MetaProgressionRepository.recordRoundEnd` no longer auto-claims/auto-
  grants anything the instant a threshold is crossed (the original D-091
  behavior) — it only updates the lifetime counters now. It still returns
  a `List<Achievement>`, but the meaning changed: achievements that just
  became eligible *this call* (met after this round's counters were
  applied, unmet before them, still unclaimed) — computed by snapshotting
  `buildStatValues` both before and after applying the round's deltas, so
  calling it again next round doesn't keep re-reporting an
  already-eligible-but-still-unclaimed achievement as "newly" anything.
  Nothing in the app currently consumes this return value (the one call
  site, `ArenaGame._persistRoundRewards`, always discarded it) — kept
  correct anyway for a future toast/notification to use.
- A new `MetaProgressionRepository.claimAchievement(id)` is the only way a
  reward is actually granted now — re-validates eligibility itself against
  a fresh `load()` (same "don't trust the caller's possibly-stale copy"
  shape `addCoins` already documents), refuses an already-claimed id, an
  id that isn't actually eligible yet, or an unknown id, and only then
  adds to `claimedAchievementIds` and grants the coins/gems.
- `AchievementsScreen`'s cards are 3-state now (was binary claimed/not):
  locked (below threshold, unchanged dimmed look), **pending** (threshold
  met, not claimed — reads like claimed visually, but with a CLAIM button
  instead of the checkmark, wired to `claimAchievement` then a full
  reload), claimed (unchanged checkmark look).
- A new pure helper, `achievements.dart`'s `anyAchievementPending`, answers
  "is there anything to claim" off plain `statValues`/`claimedIds` —
  keeps this file's deliberate zero-import-of-`meta_progression.dart` rule
  (see its own file-level doc comment) intact for the main menu's own
  check.
- `MainMenuScreen` loads a `MetaProgression` once at boot and again every
  time it returns from START or ACHIEVEMENTS (a round might cross a new
  threshold; claiming one clears its own pip) and shows a small solid red
  `_PendingPip` dot on the ACHIEVEMENTS button (`Positioned`, only built
  at all while something's pending) when `anyAchievementPending` is true.

**Decision — the overflow bug:** `ShopScreen`'s `_ShopPage` and
`CharacterUpgradesScreen`'s `_StatPage` both used to lay their rows out
with `Expanded` — an equal, fixed share of the page's height per row,
specifically so nothing would ever need to scroll (DECISIONS D-067/D-070,
"must not allow scrolling"). A friend's real device proved that
assumption wrong: a row's actual content plus its own padding doesn't
reliably fit inside its forced-equal slot on every real screen height.
Both pages are `SingleChildScrollView`s now — the same "can never overflow
regardless of screen height" fix D-058's chest reveal already established
for exactly this class of bug (a card/row whose real content might not
fit a fixed box). Not a reversal of D-005 (Character Select stays a
non-scrolling `Column` — that page's content was actually verified to fit
once tightened; this is a different pair of screens whose content
provably doesn't). Each row lost its `Expanded` wrapper and
`mainAxisAlignment: spaceBetween` (no longer forced to fill an exact
slot) in favor of `mainAxisSize: min` with small explicit gaps between
its label/description/button — rows size to their own natural content,
and the page only scrolls on a screen too
short to show every row without it.

**Consequences:** `flutter analyze`/`test`/`build apk --debug` all pass.
`meta_progression_test.dart`'s `recordRoundEnd` group was rewritten for
the new eligible-not-claimed semantics, plus a new `claimAchievement`
group; `achievements_test.dart` gained an `anyAchievementPending` group.
Not yet verified on-device: the claim flow's coins/gems actually land and
the pip appears/clears at the right times; and — the actual point of this
fix — that SHOP/CHARACTER UPGRADES genuinely no longer overflow on the
reporting friend's device.

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
