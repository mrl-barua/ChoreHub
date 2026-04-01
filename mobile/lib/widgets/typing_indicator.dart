import 'package:flutter/material.dart';

class TypingIndicator extends StatefulWidget {
  final List<String> userNames;
  const TypingIndicator({super.key, required this.userNames});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userNames.isEmpty) return const SizedBox.shrink();

    final text = widget.userNames.length == 1
        ? '${widget.userNames.first} is typing'
        : '${widget.userNames.join(", ")} are typing';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                children: List.generate(3, (i) {
                  final delay = i * 0.2;
                  final t = (_controller.value - delay).clamp(0.0, 1.0);
                  final y = -3 * (1 - (2 * t - 1) * (2 * t - 1));
                  return Transform.translate(
                    offset: Offset(0, y),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
