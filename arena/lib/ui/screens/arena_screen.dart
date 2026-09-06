import 'package:flutter/material.dart';

import '../../core/constants.dart';

/// Placeholder route for Phase 1 (TASKS 1.9/1.10): proves the arena ->
/// death -> Round Over -> Main Menu leg of the flow with no game in it yet.
/// The debug "die" button matches PRD §3's note that the arena has no other
/// exit besides death in debug builds.
///
/// Real Round Over is a Flame overlay (DECISIONS D-010), not a Flutter
/// widget — this stands in for it until `ArenaGame` exists in Phase 3+, at
/// which point this whole file gets replaced by the `GameWidget` host.
class ArenaScreen extends StatefulWidget {
  const ArenaScreen({super.key});

  static const route = '/arena';

  @override
  State<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends State<ArenaScreen> {
  bool _roundOver = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ArenaColors.background,
      body: Stack(
        children: [
          if (!_roundOver)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _roundOver = true),
                child: const Text(
                  'DIE (debug)',
                  style: TextStyle(color: ArenaColors.danger, fontSize: 18),
                ),
              ),
            ),
          if (_roundOver) const _RoundOverOverlay(),
        ],
      ),
    );
  }
}

class _RoundOverOverlay extends StatelessWidget {
  const _RoundOverOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ROUND OVER',
                style: TextStyle(
                  color: ArenaColors.danger,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 24),
              // Dummy numbers — real round state lands with ArenaGame (Phase 4.12).
              const _StatRow(label: 'Time survived', value: '00:00.000'),
              const _StatRow(label: 'Enemies killed', value: '0'),
              const _StatRow(label: 'Damage dealt', value: '0'),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ArenaColors.accent),
                  ),
                  onPressed: () => Navigator.of(context)
                      .popUntil((route) => route.isFirst),
                  child: const Text(
                    'MAIN MENU',
                    style: TextStyle(color: ArenaColors.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: ArenaColors.textDim)),
          Text(value, style: const TextStyle(color: ArenaColors.textPrimary)),
        ],
      ),
    );
  }
}
