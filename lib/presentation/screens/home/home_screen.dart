import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:contador_app/config/theme/app_colors.dart';
import 'package:contador_app/presentation/providers/auth_provider.dart';
import 'package:contador_app/presentation/providers/match_provider.dart';
import 'package:contador_app/presentation/widgets/coins_chip.dart';
import 'package:contador_app/presentation/widgets/crest_logo.dart';

/// Panel principal del club: escudo, saldo de monedas y accesos a las
/// secciones (Plantilla, Mercado; Liga y Partido llegan más adelante).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // Encabezado: escudo, nombre del club y cerrar sesión.
              Row(
                children: [
                  const CrestLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ultime Team Manager',
                          style: TextStyle(
                            color: AppColors.texto,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          user?.email ?? 'jugador',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.gris, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    icon: const Icon(Icons.logout, color: AppColors.gris),
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Saldo del club.
              const Row(children: [CoinsChip()]),
              const SizedBox(height: 24),
              // Accesos a las secciones.
              _MenuCard(
                icon: Icons.groups,
                title: 'Plantilla',
                subtitle: 'Tu 11 titular y la banca (4-3-3)',
                onTap: () => context.push('/squad'),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.storefront,
                title: 'Mercado',
                subtitle: 'Compra y vende jugadores',
                onTap: () => context.push('/market'),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.emoji_events,
                title: 'Liga',
                subtitle: 'Grupos y eliminatorias',
                onTap: () => context.push('/league'),
              ),
              const SizedBox(height: 12),
              _MenuCard(
                icon: Icons.sports_soccer,
                title: 'Partido',
                subtitle: 'Amistoso rápido',
                onTap: () {
                  ref.read(matchRequestProvider.notifier).state = null;
                  context.push('/match');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de acceso del panel; sin [onTap] se muestra deshabilitada.
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: AppColors.carbon,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minHeight: 72),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borde),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.verde2.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.verde, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            color: AppColors.gris, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(Icons.chevron_right,
                      color: AppColors.gris, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
