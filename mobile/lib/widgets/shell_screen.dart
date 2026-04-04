import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../providers/connectivity_provider.dart';
import '../providers/message_provider.dart';

class ShellScreen extends ConsumerWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/chores')) return 1;
    if (location.startsWith('/chat')) return 2;
    if (location.startsWith('/family')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  static const _routes = ['/dashboard', '/chores', '/chat', '/family', '/profile'];
  static const _labels = ['Home', 'Chores', 'Chat', 'Family', 'Profile'];
  static const _icons = [
    Icons.home_rounded,
    Icons.checklist_rounded,
    Icons.chat_bubble_rounded,
    Icons.people_rounded,
    Icons.person_rounded,
  ];
  static const _outlinedIcons = [
    Icons.home_outlined,
    Icons.checklist_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.people_outline_rounded,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final currentIndex = _currentIndex(context);
    final unreadCount = ref.watch(messageProvider).unreadCount;

    return Scaffold(
      body: Column(
        children: [
          if (!isOnline)
            Container(
              width: double.infinity,
              color: Colors.orange.shade700,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 4,
                bottom: 6, left: 16, right: 16,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Offline - changes will sync later',
                      style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLow,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final isSelected = currentIndex == index;
                final isChatTab = index == 2;

                return Semantics(
                  label: _labels[index],
                  button: true,
                  selected: isSelected,
                  child: GestureDetector(
                  onTap: () => context.go(_routes[index]),
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Icon with scale animation
                        AnimatedScale(
                          scale: isSelected ? 1.1 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: AnimatedOpacity(
                            opacity: isSelected ? 1.0 : 0.4,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isSelected ? _icons[index] : _outlinedIcons[index],
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Active indicator dot
                        if (isSelected)
                          Positioned(
                            bottom: 4,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: AppTheme.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        // Unread badge on chat tab
                        if (isChatTab && unreadCount > 0 && !isSelected)
                          Positioned(
                            top: 6,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accent.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
