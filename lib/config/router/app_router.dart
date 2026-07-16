import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:contador_app/presentation/providers/auth_provider.dart';
import 'package:contador_app/presentation/screens/auth/login_screen.dart';
import 'package:contador_app/presentation/screens/home/home_screen.dart';
import 'package:contador_app/presentation/screens/squad/squad_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Un notifier que "despierta" al router cuando cambia el estado de sesión.
  final refresh = ValueNotifier<AuthStatus>(AuthStatus.unknown);
  ref.listen(
    authControllerProvider.select((s) => s.status),
    (previous, next) => refresh.value = next,
    fireImmediately: true,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;

      // Mientras restauramos la sesión, no decidimos nada todavía.
      if (status == AuthStatus.unknown) return null;

      final loggingIn = state.matchedLocation == '/login';
      final loggedIn = status == AuthStatus.authenticated;

      if (!loggedIn) return loggingIn ? null : '/login';
      if (loggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/squad', builder: (_, _) => const SquadScreen()),
    ],
  );
});
