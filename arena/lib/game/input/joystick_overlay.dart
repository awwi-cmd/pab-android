import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/settings.dart';
import 'movement_input.dart';

/// Flutter-side touch capture for the three control schemes (PRD §7,
/// DECISIONS D-006). Rendered as an overlay on top of the `GameWidget` and
/// feeds the shared [MovementInput]; `PlayerComponent` never knows which of
/// these produced the vector it reads.
class MovementInputOverlay extends StatelessWidget {
  const MovementInputOverlay({
    super.key,
    required this.input,
    required this.scheme,
    required this.joystickSide,
  });

  final MovementInput input;
  final ControlScheme scheme;
  final JoystickSide joystickSide;

  @override
  Widget build(BuildContext context) {
    switch (scheme) {
      case ControlScheme.floatingJoystick:
        return _FloatingJoystick(input: input);
      case ControlScheme.fixedJoystick:
        return _FixedJoystick(input: input, side: joystickSide);
      case ControlScheme.dragAnywhere:
        return _DragAnywhere(input: input);
    }
  }
}

const _kStickRadius = 56.0;

/// Appears wherever the thumb first lands in the lower half of the screen
/// and follows drags from there.
class _FloatingJoystick extends StatefulWidget {
  const _FloatingJoystick({required this.input});

  final MovementInput input;

  @override
  State<_FloatingJoystick> createState() => _FloatingJoystickState();
}

class _FloatingJoystickState extends State<_FloatingJoystick> {
  Offset? _origin;
  Offset _knob = Offset.zero;

  void _start(Offset local, Size area) {
    if (local.dy < area.height / 2) return; // lower half only
    setState(() {
      _origin = local;
      _knob = Offset.zero;
    });
  }

  void _update(Offset local) {
    final origin = _origin;
    if (origin == null) return;
    var delta = local - origin;
    if (delta.distance > _kStickRadius) {
      delta = Offset.fromDirection(delta.direction, _kStickRadius);
    }
    setState(() => _knob = delta);
    widget.input.set(delta.dx / _kStickRadius, delta.dy / _kStickRadius);
  }

  void _end() {
    setState(() {
      _origin = null;
      _knob = Offset.zero;
    });
    widget.input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (d) => _start(d.localPosition, area),
          onPanUpdate: (d) => _update(d.localPosition),
          onPanEnd: (_) => _end(),
          onPanCancel: _end,
          child: Stack(
            children: [
              if (_origin != null)
                Positioned(
                  left: _origin!.dx - _kStickRadius,
                  top: _origin!.dy - _kStickRadius,
                  child: _StickVisual(knob: _knob),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Always drawn in the lower corner (side per Settings); only responds to
/// touches starting near it.
class _FixedJoystick extends StatefulWidget {
  const _FixedJoystick({required this.input, required this.side});

  final MovementInput input;
  final JoystickSide side;

  @override
  State<_FixedJoystick> createState() => _FixedJoystickState();
}

class _FixedJoystickState extends State<_FixedJoystick> {
  static const _margin = 32.0;

  bool _active = false;
  Offset _knob = Offset.zero;

  Offset _originFor(Size area) {
    final dx = widget.side == JoystickSide.left
        ? _margin + _kStickRadius
        : area.width - _margin - _kStickRadius;
    final dy = area.height - _margin - _kStickRadius;
    return Offset(dx, dy);
  }

  void _start(Offset local, Size area) {
    if ((local - _originFor(area)).distance > _kStickRadius * 1.5) return;
    _active = true;
    _update(local, area);
  }

  void _update(Offset local, Size area) {
    if (!_active) return;
    var delta = local - _originFor(area);
    if (delta.distance > _kStickRadius) {
      delta = Offset.fromDirection(delta.direction, _kStickRadius);
    }
    setState(() => _knob = delta);
    widget.input.set(delta.dx / _kStickRadius, delta.dy / _kStickRadius);
  }

  void _end() {
    setState(() {
      _active = false;
      _knob = Offset.zero;
    });
    widget.input.clear();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        final origin = _originFor(area);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onPanStart: (d) => _start(d.localPosition, area),
          onPanUpdate: (d) => _update(d.localPosition, area),
          onPanEnd: (_) => _end(),
          onPanCancel: _end,
          child: Stack(
            children: [
              Positioned(
                left: origin.dx - _kStickRadius,
                top: origin.dy - _kStickRadius,
                child: _StickVisual(knob: _knob, dim: !_active),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// No visible stick — a drag anywhere on screen moves the character
/// relative to the drag delta.
class _DragAnywhere extends StatelessWidget {
  const _DragAnywhere({required this.input});

  final MovementInput input;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (d) => input.set(d.delta.dx, d.delta.dy),
      onPanEnd: (_) => input.clear(),
      onPanCancel: input.clear,
      child: const SizedBox.expand(),
    );
  }
}

class _StickVisual extends StatelessWidget {
  const _StickVisual({required this.knob, this.dim = false});

  final Offset knob;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: _kStickRadius * 2,
        height: _kStickRadius * 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (dim ? ArenaColors.surfaceAlt : ArenaColors.surface)
                    .withValues(alpha: 0.6),
                border: Border.all(color: ArenaColors.textDim),
              ),
            ),
            Transform.translate(
              offset: knob,
              child: Container(
                width: _kStickRadius * 0.7,
                height: _kStickRadius * 0.7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ArenaColors.accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
