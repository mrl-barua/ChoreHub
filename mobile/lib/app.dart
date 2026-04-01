import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/dashboard_screen.dart';
import 'screens/chores/chore_list_screen.dart';
import 'screens/chores/create_chore_screen.dart';
import 'screens/chores/chore_detail_screen.dart';
import 'screens/chores/edit_chore_screen.dart';
import 'screens/family/family_screen.dart';
import 'screens/family/create_family_screen.dart';
import 'screens/family/invite_screen.dart';
import 'screens/family/invitations_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'widgets/shell_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

CustomTransitionPage<void> _slideUpPage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(begin: const Offset(0, 0.15), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      final fadeTween = Tween(begin: 0.0, end: 1.0)
          .chain(CurveTween(curve: Curves.easeOut));
      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(opacity: animation.drive(fadeTween), child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 350),
  );
}

CustomTransitionPage<void> _fadeScalePage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(curve), child: child),
      );
    },
    transitionDuration: const Duration(milliseconds: 300),
  );
}

/// A ChangeNotifier that listens to Riverpod auth state changes
/// so GoRouter can use refreshListenable instead of being recreated.
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) {
      notifyListeners();
    });
  }
}

final _authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  return AuthChangeNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(_authChangeNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      if (authState.isLoading) return null;

      final isAuth = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadeScalePage(const LoginScreen(), state),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (_, state) => _slideUpPage(const RegisterScreen(), state),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/chores', builder: (_, __) => const ChoreListScreen()),
          GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
          GoRoute(path: '/family', builder: (_, __) => const FamilyScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/chores/create',
        pageBuilder: (_, state) => _slideUpPage(const CreateChoreScreen(), state),
      ),
      GoRoute(
        path: '/chores/:id',
        pageBuilder: (_, state) => _slideUpPage(
          ChoreDetailScreen(choreId: state.pathParameters['id']!),
          state,
        ),
      ),
      GoRoute(
        path: '/analytics',
        pageBuilder: (_, state) => _slideUpPage(const AnalyticsScreen(), state),
      ),
      GoRoute(
        path: '/chores/:id/edit',
        pageBuilder: (_, state) => _slideUpPage(
          EditChoreScreen(choreId: state.pathParameters['id']!),
          state,
        ),
      ),
      GoRoute(
        path: '/family/create',
        pageBuilder: (_, state) => _slideUpPage(const CreateFamilyScreen(), state),
      ),
      GoRoute(
        path: '/family/invite',
        pageBuilder: (_, state) => _slideUpPage(const InviteScreen(), state),
      ),
      GoRoute(
        path: '/family/invitations',
        pageBuilder: (_, state) => _slideUpPage(const InvitationsScreen(), state),
      ),
    ],
  );
});

class ChoreHubApp extends ConsumerWidget {
  const ChoreHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'ChoreHub',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
