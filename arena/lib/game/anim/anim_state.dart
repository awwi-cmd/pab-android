/// Every animation state on the reference sheet (DECISIONS D-012), including
/// ones with no sprite yet — so adding a skill later is a data change, not a
/// refactor of `PlayerComponent`. Only the first six are wired for the demo
/// (PRD §8.1); the rest are named now, built in the skills phase (§8.2).
enum AnimState {
  idle,
  run,
  fire,
  spawn,
  hurt,
  death,

  // Defined now, built later (skills phase) — no `main-*.png` sheet is
  // loaded for these yet, so never set `PlayerComponent.current` to one.
  teleport,
  warp,
  fly,
  dash,
  pose,
  charge,
  channelStaff,
  channelWand,
  casting,
}
