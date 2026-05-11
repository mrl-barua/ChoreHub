import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../providers/progression_provider.dart';

/// Friendly names for unlock keys. Keep stable keys on the wire and translate
/// at the edge so renames don't break stored data (PRD: Naming).
const Map<String, String> _unlockLabels = {
  'STREAK_MEND': 'Streak Mend',
  'STREAK_FREEZE': 'Streak Freeze',
  'DISPLAY_TITLE': 'Display Title',
  'MEND_COOLDOWN_HALVED': 'Faster mend recovery',
};

String _unlockLabel(String key) => _unlockLabels[key] ?? key;

/// Globally-listening wrapper that triggers the level-up takeover whenever
/// the progression provider's `pendingLevelUp` flips from null to a value.
///
/// Mounted inside [ShellScreen] so the takeover plays no matter which tab
/// the kid is currently on. The widget itself just listens; the actual modal
/// is pushed into the navigator with `barrierDismissible: false` so the kid
/// has to tap "Continue" to clear it.
class LevelUpListener extends ConsumerStatefulWidget {
  final Widget child;
  const LevelUpListener({super.key, required this.child});

  @override
  ConsumerState<LevelUpListener> createState() => _LevelUpListenerState();
}

class _LevelUpListenerState extends ConsumerState<LevelUpListener> {
  bool _isShowing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<LevelUpEvent?>(
      progressionProvider.select((s) => s.pendingLevelUp),
      (prev, next) {
        if (next != null && !_isShowing) {
          if (mounted) {
            setState(() {
              _isShowing = true;
            });
          }
          // Schedule the dialog push for the next frame so we never push
          // during a build phase.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showLevelUpDialog(next);
          });
        }
      },
    );
    return widget.child;
  }

  Future<void> _showLevelUpDialog(LevelUpEvent event) async {
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Level up',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim, secondary) =>
          _LevelUpModal(event: event),
      transitionBuilder: (ctx, anim, secondary, child) {
        final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
        return FadeTransition(opacity: fade, child: child);
      },
    );
    // The dialog itself calls clearPendingLevelUp() before popping, but we
    // also clear here for safety in case the platform dismisses without a
    // tap (e.g. system back gesture).
    if (mounted) {
      ref.read(progressionProvider.notifier).clearPendingLevelUp();
      setState(() {
        _isShowing = false;
      });
    }
  }
}

/// Full-screen level-up takeover. Confetti animation + level number +
/// unlocks list + dismiss button.
class _LevelUpModal extends ConsumerStatefulWidget {
  final LevelUpEvent event;
  const _LevelUpModal({required this.event});

  @override
  ConsumerState<_LevelUpModal> createState() => _LevelUpModalState();
}

class _LevelUpModalState extends ConsumerState<_LevelUpModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final disable = MediaQuery.of(context).disableAnimations;
    if (mounted) {
      setState(() {
        _reduceMotion = disable;
      });
    }
    if (!disable) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          if (!_reduceMotion)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (ctx, _) => CustomPaint(
                  painter: _EmojiRainPainter(progress: _controller.value),
                ),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceL),
              child: Container(
                padding: const EdgeInsets.all(AppTheme.spaceL),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color ?? AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusL),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.4),
                    width: 2,
                  ),
                  boxShadow: AppTheme.shadowLarge,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Semantics(
                      label: 'Level up celebration',
                      child: const Text(
                        '\u{1F389}',
                        style: TextStyle(fontSize: 56),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceM),
                    const Text(
                      'LEVEL UP',
                      style: TextStyle(
                        fontSize: AppTheme.fontL,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceS),
                    Text(
                      'Level ${event.newLevel}!',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceS),
                    Text(
                      '+${event.xpAwarded} XP',
                      style: const TextStyle(
                        fontSize: AppTheme.fontL,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentGreen,
                      ),
                    ),
                    if (event.unlocksGained.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spaceL),
                      const Text(
                        'Unlocked',
                        style: TextStyle(
                          fontSize: AppTheme.fontS,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spaceS),
                      ...event.unlocksGained.map(
                        (key) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_open_rounded,
                                color: AppTheme.accentGold,
                                size: AppTheme.iconSizeM,
                              ),
                              const SizedBox(width: AppTheme.spaceS),
                              Text(
                                _unlockLabel(key),
                                style: const TextStyle(
                                  fontSize: AppTheme.fontM,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppTheme.spaceL),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          ref
                              .read(progressionProvider.notifier)
                              .clearPendingLevelUp();
                          Navigator.of(context).pop();
                        },
                        child: const Text("Let's go"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiParticle {
  final double angle;
  final double velocity;
  final int glyphIndex;
  const _EmojiParticle(this.angle, this.velocity, this.glyphIndex);
}

class _EmojiRainPainter extends CustomPainter {
  final double progress;
  static const _emojis = ['\u{2728}', '\u{1F389}', '\u{1F38A}', '\u{2B50}'];
  static const _count = 24;

  static final List<TextPainter> _glyphPainters = _buildGlyphPainters();
  static final List<_EmojiParticle> _particles = _buildParticles();

  static List<TextPainter> _buildGlyphPainters() {
    return List<TextPainter>.generate(_emojis.length, (i) {
      final tp = TextPainter(
        text: TextSpan(
          text: _emojis[i],
          style: const TextStyle(
            fontSize: 22,
            color: Color.fromRGBO(255, 255, 255, 1.0),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    }, growable: false);
  }

  static List<_EmojiParticle> _buildParticles() {
    final rng = math.Random(7);
    return List<_EmojiParticle>.generate(_count, (i) {
      final angle = rng.nextDouble() * math.pi * 2;
      final velocity = 0.5 + rng.nextDouble() * 0.5;
      return _EmojiParticle(angle, velocity, i % _emojis.length);
    }, growable: false);
  }

  _EmojiRainPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final origin = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final t = progress.clamp(0.0, 1.0);
    final opacity = t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
    final gravity = 0.5 * (t * t) * size.height * 0.6;

    canvas.saveLayer(null, Paint()..color = Color.fromRGBO(255, 255, 255, opacity));
    for (int i = 0; i < _count; i++) {
      final p = _particles[i];
      final radius = p.velocity * maxRadius * t;
      final dx = origin.dx + math.cos(p.angle) * radius;
      final dy = origin.dy + math.sin(p.angle) * radius + gravity;
      final tp = _glyphPainters[p.glyphIndex];
      tp.paint(canvas, Offset(dx - tp.width / 2, dy - tp.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EmojiRainPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
