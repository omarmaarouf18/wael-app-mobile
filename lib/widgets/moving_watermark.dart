import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Semi-transparent identity text (the student's name and phone) that jumps
/// to a new position every [interval] (about 20 seconds). It ignores all
/// touches, is hidden from accessibility, and has no way to be closed, so a
/// screen capture of the video always carries the viewer's identity.
class MovingWatermark extends StatefulWidget {
  const MovingWatermark({
    super.key,
    required this.text,
    this.interval = const Duration(seconds: 20),
    this.random,
  });

  final String text;
  final Duration interval;

  /// Injected in tests to make the sequence of positions predictable.
  final Random? random;

  /// The spots the watermark visits: a 3 x 3 grid, avoiding the exact edges.
  static const positions = <Alignment>[
    Alignment(-0.8, -0.7),
    Alignment(0.0, -0.7),
    Alignment(0.8, -0.7),
    Alignment(-0.8, 0.0),
    Alignment(0.0, 0.0),
    Alignment(0.8, 0.0),
    Alignment(-0.8, 0.6),
    Alignment(0.0, 0.6),
    Alignment(0.8, 0.6),
  ];

  @override
  State<MovingWatermark> createState() => _MovingWatermarkState();
}

class _MovingWatermarkState extends State<MovingWatermark> {
  late final Random _random = widget.random ?? Random();
  late Alignment _alignment = _pick(null);
  Timer? _timer;

  Alignment _pick(Alignment? not) {
    Alignment next;
    do {
      next = MovingWatermark
          .positions[_random.nextInt(MovingWatermark.positions.length)];
    } while (next == not);
    return next;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      if (mounted) setState(() => _alignment = _pick(_alignment));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Current position (tests).
  @visibleForTesting
  Alignment get alignment => _alignment;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedAlign(
            alignment: _alignment,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            child: FractionallySizedBox(
              widthFactor: 0.6,
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: AppTypography.labelMd().copyWith(
                  color: AppColors.textPrimary.withValues(alpha: 0.35),
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: AppColors.scrimBlack.withValues(alpha: 0.35),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
