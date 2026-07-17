import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:contador_app/config/theme/app_colors.dart';
import 'package:contador_app/presentation/providers/auth_provider.dart';
import 'package:contador_app/presentation/screens/auth/login_screen.dart';
import 'package:contador_app/presentation/screens/home/home_screen.dart';
import 'package:contador_app/presentation/screens/market/market_screen.dart';
import 'package:contador_app/presentation/screens/match/match_screen.dart';
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
    // Ruta inexistente -> pantalla de "no encontrada".
    errorBuilder: (context, state) => const _NotFoundScreen(),
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
      GoRoute(path: '/market', builder: (_, _) => const MarketScreen()),
      GoRoute(path: '/match', builder: (_, _) => const MatchScreen()),
    ],
  );
});

/// Pantalla simple para rutas inexistentes: un texto y un botón al login.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ruta no encontrada',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.texto,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.pildora,
                  foregroundColor: const Color(0xFF05210F),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => context.go('/login'),
                child: const Text('Ir al login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
