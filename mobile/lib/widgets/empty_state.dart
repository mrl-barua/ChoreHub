import 'package:flutter/material.dart';
import '../config/theme.dart';

class EmptyState extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _floatController;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    // Entrance animation
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scale = Tween(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack));
    _opacity = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));
    _entranceController.forward();

    // Floating loop animation
    _floatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _float = Tween(begin: 0.0, end: 6.0).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
    _floatController.repeat(reverse: true);
  }

  @override
  void deactivate() {
    _floatController.stop(); // Stop animation when widget leaves screen
    super.deactivate();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Floating icon with gradient container
                AnimatedBuilder(
                  animation: _float,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(0, -_float.value),
                    child: child,
                  ),
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.accent.withValues(alpha: 0.2),
                          AppTheme.accent.withValues(alpha: 0.06),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(widget.icon, size: 48, color: AppTheme.accent),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                  textAlign: TextAlign.center,
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (widget.action != null) ...[
                  const SizedBox(height: 28),
                  widget.action!,
                ],
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: widget.onAction,
                    child: Text(widget.actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
