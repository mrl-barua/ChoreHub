import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/dashboard_screen.dart';
import 'screens/chores/chore_list_screen.dart';
import 'screens/chores/create_chore_screen.dart';
import 'screens/chores/chore_detail_screen.dart';
import 'screens/family/family_screen.dart';
import 'screens/family/create_family_screen.dart';
import 'screens/family/invite_screen.dart';
import 'screens/family/invitations_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'widgets/shell_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      if (authState.isLoading) return null;

      final isAuth = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (_, __, child) => ShellScreen(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/chores', builder: (_, __) => const ChoreListScreen()),
          GoRoute(path: '/family', builder: (_, __) => const FamilyScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/chores/create', builder: (_, __) => const CreateChoreScreen()),
      GoRoute(
        path: '/chores/:id',
        builder: (_, state) => ChoreDetailScreen(choreId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/family/create', builder: (_, __) => const CreateFamilyScreen()),
      GoRoute(path: '/family/invite', builder: (_, __) => const InviteScreen()),
      GoRoute(path: '/family/invitations', builder: (_, __) => const InvitationsScreen()),
    ],
  );
});

class ChoreHubApp extends ConsumerWidget {
  const ChoreHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ChoreHub',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
